import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../core/realtime/socket_service.dart';
import '../data/models/json_utils.dart';
import '../data/models/report_models.dart';
import '../data/models/user.dart';
import '../data/models/vehicle.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

class FleetStats {
  const FleetStats({
    this.total = 0,
    this.moving = 0,
    this.idle = 0,
    this.stopped = 0,
    this.offline = 0,
    this.noData = 0,
    this.overspeeding = 0,
    this.expiringSoon = 0,
    this.totalDistanceToday = 0,
  });

  final int total;
  final int moving;
  final int idle;
  final int stopped;
  final int offline;
  final int noData;
  final int overspeeding;
  final int expiringSoon;
  final double totalDistanceToday;

  int get online => moving + idle + stopped;

  double get onlinePercent => total == 0 ? 0 : online / total;
  double get utilisation => total == 0 ? 0 : moving / total;

  factory FleetStats.from(List<Vehicle> vehicles) {
    int moving = 0, idle = 0, stopped = 0, offline = 0, noData = 0;
    int over = 0, expiring = 0;
    double distance = 0;

    for (final Vehicle v in vehicles) {
      switch (v.status) {
        case VehicleStatus.moving:
          moving++;
        case VehicleStatus.idle:
          idle++;
        case VehicleStatus.stopped:
          stopped++;
        case VehicleStatus.offline:
          offline++;
        case VehicleStatus.noData:
          noData++;
      }
      if (v.status != VehicleStatus.offline &&
          v.status != VehicleStatus.noData &&
          v.isOverspeeding) {
        over++;
      }
      if (v.isExpiringSoon) expiring++;
      distance += v.todayDistanceKm ?? 0;
    }

    return FleetStats(
      total: vehicles.length,
      moving: moving,
      idle: idle,
      stopped: stopped,
      offline: offline,
      noData: noData,
      overspeeding: over,
      expiringSoon: expiring,
      totalDistanceToday: distance,
    );
  }
}

class FleetState {
  const FleetState({
    this.vehicles = const <Vehicle>[],
    this.groups = const <FleetGroup>[],
    this.isLoading = true,
    this.isRefreshing = false,
    this.error,
    this.lastSyncedAt,
  });

  final List<Vehicle> vehicles;
  final List<FleetGroup> groups;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastSyncedAt;

  FleetStats get stats => FleetStats.from(vehicles);
  bool get isEmpty => vehicles.isEmpty && !isLoading;

  FleetState copyWith({
    List<Vehicle>? vehicles,
    List<FleetGroup>? groups,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? lastSyncedAt,
    bool clearError = false,
  }) =>
      FleetState(
        vehicles: vehicles ?? this.vehicles,
        groups: groups ?? this.groups,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: clearError ? null : (error ?? this.error),
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

final NotifierProvider<FleetController, FleetState> fleetProvider =
    NotifierProvider<FleetController, FleetState>(FleetController.new);

/// Owns the canonical vehicle list and folds socket frames into it.
///
/// Update strategy: socket frames land in a pending buffer and are flushed to
/// state on a timer ([AppConfig.mapThrottle]). With 300 vehicles each pushing
/// ~1Hz, naive setState would rebuild the tree 300×/second; buffering keeps
/// it at a steady ~2 rebuilds/second with zero perceptible lag.
class FleetController extends Notifier<FleetState> {
  StreamSubscription<SocketEvent>? _socketSub;
  Timer? _flushTimer;
  Timer? _staleTimer;
  bool _mounted = true;

  final Map<String, Vehicle> _pending = <String, Vehicle>{};
  final Map<String, Vehicle> _vehiclesById = <String, Vehicle>{};
  final Map<String, String> _identifierToVehicleId = <String, String>{};
  final Map<String, Map<String, dynamic>> _customOverrides =
      <String, Map<String, dynamic>>{};

  void _rebuildIndexes(List<Vehicle> list) {
    _vehiclesById.clear();
    _identifierToVehicleId.clear();
    for (int i = 0; i < list.length; i++) {
      final Vehicle v = list[i];
      if (_customOverrides.containsKey(v.id)) {
        final Map<String, dynamic> o = _customOverrides[v.id]!;
        list[i] = v.copyWith(
          name: o['name'] as String? ?? v.name,
          odometer: o['odometer'] as double? ?? v.odometer,
        );
      }
    }
    for (final Vehicle v in list) {
      if (v.id.isNotEmpty) {
        _vehiclesById[v.id] = v;
        _identifierToVehicleId[v.id] = v.id;
      }
      if (v.deviceId.isNotEmpty) {
        _identifierToVehicleId[v.deviceId] = v.id;
        _identifierToVehicleId[v.deviceId.toLowerCase()] = v.id;
      }
      if (v.imei.isNotEmpty) {
        _identifierToVehicleId[v.imei] = v.id;
        _identifierToVehicleId[v.imei.toLowerCase()] = v.id;
      }
      if (v.registrationNumber.isNotEmpty) {
        final String cleanReg = v.registrationNumber.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        _identifierToVehicleId[cleanReg] = v.id;
        _identifierToVehicleId[v.registrationNumber] = v.id;
      }
      if (v.name.isNotEmpty) {
        final String cleanName = v.name.toUpperCase().replaceAll(RegExp(r'\s+'), '');
        _identifierToVehicleId[cleanName] = v.id;
        _identifierToVehicleId[v.name] = v.id;
      }
    }
  }

  @override
  FleetState build() {
    _mounted = true;
    ref.onDispose(() {
      _mounted = false;
      _socketSub?.cancel();
      _flushTimer?.cancel();
      _staleTimer?.cancel();
    });
    return const FleetState();
  }

  // ── Loading ──────────────────────────────────────────────────────

  Future<void> load({bool silent = false}) async {
    if (!_mounted) return;
    if (!silent) {
      _safeSetState(state.copyWith(
        isLoading: state.vehicles.isEmpty,
        isRefreshing: true,
        clearError: true,
      ));
    }

    try {
      final List<Vehicle> vehicles =
          await ref.read(vehicleRepositoryProvider).getVehicles();

      if (!_mounted) return;

      // Preserve fresher socket data: prefer in-flight pending frames,
      // then existing state, over the REST snapshot.
      final Map<String, Vehicle> current = <String, Vehicle>{
        for (final Vehicle v in state.vehicles) v.id: v,
        // Pending frames are always fresher than anything REST returns.
        ..._pending,
      };

      // Deduplicate incoming API response by ID to prevent duplicate ValueKey crashes
      final Map<String, Vehicle> incomingMap = <String, Vehicle>{
        for (final Vehicle v in vehicles) v.id: v,
      };

      final List<Vehicle> merged = incomingMap.values.map((Vehicle incoming) {
        // If an in-flight socket frame is buffered, prefer the live socket frame
        final Vehicle? pendingSocketFrame = _pending[incoming.id];
        if (pendingSocketFrame != null) return pendingSocketFrame;

        final Vehicle? existing = current[incoming.id];
        if (existing == null) return incoming;

        if (incoming.lastPacketAt == null && existing.lastPacketAt != null) {
          return existing;
        }

        final DateTime? a = existing.lastPacketAt;
        final DateTime? b = incoming.lastPacketAt;
        // Never let REST polling rewind an active vehicle to an older packet.
        // If the vehicle is currently moving, give live socket telemetry precedence over REST snapshots
        // unless REST is significantly newer (>15s), preventing snapshot position rollbacks.
        if (a != null && b != null) {
          if (!b.isAfter(a)) return existing;
          if (existing.status == VehicleStatus.moving &&
              b.difference(a).inSeconds < 15) {
            // Retain fresher socket location if REST coordinates are identical or older
            if (existing.hasLocation && incoming.hasLocation) {
              return existing;
            }
          }
        }
        return incoming;
      }).toList();

      // Deduplicate vehicles by registrationNumber & deviceId so ghost duplicates never appear
      final Map<String, Vehicle> deduplicated = <String, Vehicle>{};
      for (final Vehicle v in merged) {
        final String dedupKey = v.registrationNumber.trim().isNotEmpty
            ? v.registrationNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '')
            : (v.deviceId.trim().isNotEmpty ? 'dev_${v.deviceId.trim()}' : v.id);
        final Vehicle? prev = deduplicated[dedupKey];
        if (prev == null) {
          deduplicated[dedupKey] = v;
        } else {
          final DateTime? tPrev = prev.lastPacketAt;
          final DateTime? tCurr = v.lastPacketAt;
          if (tCurr != null && (tPrev == null || tCurr.isAfter(tPrev))) {
            deduplicated[dedupKey] = v;
          }
        }
      }
      final List<Vehicle> cleanMerged = deduplicated.values.toList();

      if (state.vehicles.isEmpty || !silent) {
        _sort(cleanMerged);
      } else {
        // Silent background sync: preserve the existing display order so cards don't jump
        final Map<String, int> existingOrder = <String, int>{
          for (int i = 0; i < state.vehicles.length; i++) state.vehicles[i].id: i,
        };
        cleanMerged.sort((Vehicle a, Vehicle b) {
          final int orderA = existingOrder[a.id] ?? 999999;
          final int orderB = existingOrder[b.id] ?? 999999;
          if (orderA != orderB) return orderA.compareTo(orderB);
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
      }
      // 1. Immediately index and render vehicles so the app opens instantly (< 1 second)
      _rebuildIndexes(cleanMerged);

      // Fetch authoritative groups assigned to the user from /api/admin/groups
      List<FleetGroup> userAssignedGroups = state.groups;
      try {
        final List<Map<String, dynamic>> rawGroups =
            await ref.read(vehicleRepositoryProvider).getAssignedGroups();
        if (rawGroups.isNotEmpty) {
          userAssignedGroups = rawGroups
              .map((Map<String, dynamic> m) {
                final String gId = (m['id'] ?? '').toString().trim();
                final String gName = (m['name'] ?? '').toString().trim();
                return FleetGroup(
                  id: gId,
                  name: gName,
                  vehicleCount: 0,
                );
              })
              .where((g) => g.id.isNotEmpty && g.name.isNotEmpty)
              .toList();
        }
      } catch (_) {}

      if (!_mounted) return;
      _safeSetState(state.copyWith(
        vehicles: cleanMerged,
        groups: userAssignedGroups,
        isLoading: false,
        isRefreshing: false,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      ));

      // 2. Perform consolidated fuel calibration in background so it never stalls startup
      unawaited(_asyncCalibrateFuel(cleanMerged));

      // For small fleets (<= 25), joining individual vehicle rooms is fine.
      // For large fleets (e.g. 568+), the org/user room already streams all telemetry
      // without flooding the WebSocket with hundreds of frame emissions.
      if (merged.length <= 25) {
        final SocketService socket = ref.read(socketServiceProvider);
        for (final Vehicle v in merged) {
          socket.joinVehicle(v.id);
        }
      }

      // Dynamically tune throttle based on fleet size to keep UI at 60 FPS
      if (_socketSub != null) {
        _flushTimer?.cancel();
        final Duration throttle = merged.length > 100
            ? const Duration(milliseconds: 1500)
            : (merged.length > 30
                ? const Duration(milliseconds: 800)
                : AppConfig.mapThrottle);
        _flushTimer = Timer.periodic(throttle, (_) => _flush());
      }

      _startStaleTimer();
    } on ApiException catch (e) {
      if (!_mounted) return;
      _safeSetState(state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.message,
      ));
    } catch (e) {
      if (!_mounted) return;
      _safeSetState(state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _asyncCalibrateFuel(List<Vehicle> list) async {
    try {
      final List<Vehicle> calibratedList = await _syncConsolidatedFuel(list);
      final List<Vehicle> manualSyncedList =
          await _syncManualFuelOverview(calibratedList);
      if (!_mounted) return;
      _rebuildIndexes(manualSyncedList);
      _safeSetState(state.copyWith(
        vehicles: manualSyncedList,
      ));
    } catch (e) {
      debugPrint('[FleetController] Background fuel calibration skipped: $e');
    }
  }

  Future<List<Vehicle>> _syncManualFuelOverview(List<Vehicle> list) async {
    try {
      final dynamic apiRes =
          await ref.read(apiClientProvider).get<dynamic>('/fuel/manual/overview');

      List<dynamic> rowsData = <dynamic>[];
      if (apiRes is List) {
        rowsData = apiRes;
      } else if (apiRes is Map) {
        final dynamic d = apiRes['data'] ?? apiRes['vehicles'];
        if (d is List) rowsData = d;
      }

      if (rowsData.isEmpty) return list;

      final Map<String, Map<String, dynamic>> overviewByKey =
          <String, Map<String, dynamic>>{};

      for (final dynamic item in rowsData) {
        if (item is! Map) continue;
        final Map<String, dynamic> m = Map<String, dynamic>.from(item);

        // STRICT: Only index this vehicle in the manual overview if the backend
        // EXPLICITLY marks it as a non-sensor / manual fuel vehicle via a flag field.
        // We must NEVER infer non-sensor status from the presence of fuel data alone —
        // sensor vehicles also appear in this endpoint with current_fuel / tank_capacity.
        final bool isExplicitlyManual =
            m['is_non_sensor_fuel'] == true ||
            m['is_manual_fuel'] == true ||
            m['isNonSensor'] == true ||
            m['is_non_sensor'] == true ||
            m['nonSensor'] == true ||
            m['non_sensor'] == true ||
            (m['fuel_type'] ?? '').toString().toLowerCase() == 'manual' ||
            (m['fuel_type'] ?? '').toString().toLowerCase() == 'non-sensor' ||
            (m['fuel_type'] ?? '').toString().toLowerCase() == 'non_sensor' ||
            (m['fuel_type'] ?? '').toString().toLowerCase() == 'nonsensor' ||
            (m['type'] ?? '').toString().toLowerCase() == 'manual' ||
            (m['type'] ?? '').toString().toLowerCase() == 'non-sensor';

        if (!isExplicitlyManual) {
          debugPrint('[ManualFuelSync] Skipping ${m['vehicle_name'] ?? m['vehicle_id']} — no explicit non-sensor flag from backend');
          continue;
        }

        final String? vid = m['vehicle_id']?.toString().trim();
        if (vid != null && vid.isNotEmpty) overviewByKey[vid] = m;

        final String? plate = m['plate']?.toString().trim();
        if (plate != null && plate.isNotEmpty) {
          overviewByKey[plate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')] = m;
        }

        final String? vName = m['vehicle_name']?.toString().trim();
        if (vName != null && vName.isNotEmpty) {
          overviewByKey[vName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')] = m;
        }
      }

      if (overviewByKey.isEmpty) return list;

      return list.map((Vehicle v) {
        // SENSOR VEHICLE IMMUNITY: Never overwrite or reclassify a vehicle that
        // already has a confirmed live sensor fuel level or hardware fuel sensor!
        if ((v.fuelLevel != null && v.fuelLevel! > 0 && !v.isNonSensorFuel) ||
            v.hasHardwareFuelSensor) {
          return v;
        }

        Map<String, dynamic>? ov = overviewByKey[v.id];
        if (ov == null && v.registrationNumber.isNotEmpty) {
          ov = overviewByKey[
              v.registrationNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')];
        }
        if (ov == null && v.name.isNotEmpty) {
          ov = overviewByKey[
              v.name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')];
        }

        if (ov == null) return v;

        // Only stamp as non-sensor if the backend overview EXPLICITLY says so
        final bool backendSaysManual =
            ov['is_non_sensor_fuel'] == true ||
            ov['is_manual_fuel'] == true ||
            ov['isNonSensor'] == true ||
            ov['is_non_sensor'] == true ||
            (ov['fuel_type'] ?? '').toString().toLowerCase() == 'manual' ||
            (ov['fuel_type'] ?? '').toString().toLowerCase() == 'non-sensor' ||
            (ov['fuel_type'] ?? '').toString().toLowerCase() == 'non_sensor';

        final double? curFuel = asDoubleOrNull(ov, const <String>['current_fuel', 'currentFuel']);
        final double? consumed = asDoubleOrNull(ov, const <String>['total_fuel_consumed', 'totalFuelConsumed']);
        final double? mileage = asDoubleOrNull(ov, const <String>['current_mileage', 'currentMileage', 'initial_mileage']);

        final Map<String, dynamic> mergedRaw = <String, dynamic>{
          ...v.raw,
          if (ov['tank_capacity'] != null) 'manual_tank_capacity': ov['tank_capacity'],
          if (ov['current_fuel'] != null) 'current_fuel': ov['current_fuel'],
          if (ov['total_fuel_consumed'] != null) 'manual_fuel_consumed': ov['total_fuel_consumed'],
          if (ov['current_mileage'] != null) 'manual_mileage': ov['current_mileage'],
          if (ov['estimated_range_km'] != null) 'manual_estimated_range': ov['estimated_range_km'],
          if (ov['fuel_status'] != null) 'fuel_status': ov['fuel_status'],
          if (ov['last_entry_date'] != null) 'last_entry_date': ov['last_entry_date'],
          if (ov['last_refill_date'] != null) 'last_refill_date': ov['last_refill_date'],
          if (backendSaysManual) 'is_non_sensor_fuel': true,
          if (backendSaysManual) 'is_manual_fuel': true,
          if (backendSaysManual) 'hasInitialFuel': true,
        };

        return v.copyWith(
          fuelLevel: curFuel ?? v.fuelLevel,
          fuelUsed: consumed ?? v.fuelUsed,
          estimatedMileage: mileage ?? v.estimatedMileage,
          raw: mergedRaw,
        );
      }).toList();
    } catch (e) {
      debugPrint('[FleetController] Manual fuel overview sync skipped: $e');
      return list;
    }
  }

  Future<List<Vehicle>> _syncConsolidatedFuel(List<Vehicle> list) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime start = DateTime(now.year, now.month, now.day);
      final ReportResult repRes = await ref.read(reportRepositoryProvider).run(
        type: ReportType.fuelConsolidated,
        start: start,
        end: now,
      );

      final Map<String, double> endFuelByVehicle = <String, double>{};

      double? parseCalibrated(Map<String, dynamic> raw) {
        final double? val = asDoubleOrNull(raw, <String>[
          'end_fuel_level',
          'endFuelLevel',
          'end_fuel',
          'endFuel',
          'endingFuel',
          'end_fuel_ltr',
          'end_fuel_litres',
          'end_fuel_liters',
          'current_fuel_level',
          'currentFuelLevel',
          'current_fuel',
          'currentFuel',
          'calibrated_fuel',
          'calibratedFuel',
          'normalized_fuel',
          'normalizedFuel',
          'fuel_litres',
          'fuel_liters',
          'fuel_qty',
          'fuelQty',
          'fuel',
          'fuelLevel',
          'fuel_level',
        ]);
        if (val != null && val > 0 && val <= 1500) return val;
        return null;
      }

      void indexRow(ReportRow row) {
        final double? ef = parseCalibrated(row.raw) ??
            (row.endFuel != null && row.endFuel! > 0 && row.endFuel! <= 1500
                ? row.endFuel
                : null);
        if (ef == null) return;

        final List<String?> idList = <String?>[
          row.vehicleId,
          row.raw['vehicle_id']?.toString(),
          row.raw['vehicleId']?.toString(),
          row.raw['id']?.toString(),
          row.raw['_id']?.toString(),
          row.raw['deviceId']?.toString(),
          row.raw['device_id']?.toString(),
          row.raw['imei']?.toString(),
          row.raw['IMEI']?.toString(),
        ];
        for (final String? id in idList) {
          if (id != null && id.trim().isNotEmpty) {
            endFuelByVehicle[id.trim()] = ef;
          }
        }

        final List<String?> plateList = <String?>[
          row.plate,
          row.raw['plate']?.toString(),
          row.raw['plateNumber']?.toString(),
          row.raw['registrationNumber']?.toString(),
          row.raw['reg_no']?.toString(),
          row.raw['regNo']?.toString(),
          row.raw['vehicle_number']?.toString(),
        ];
        for (final String? p in plateList) {
          if (p != null && p.trim().isNotEmpty) {
            final String clean =
                p.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
            if (clean.isNotEmpty) endFuelByVehicle[clean] = ef;
          }
        }

        final List<String?> nameList = <String?>[
          row.vehicleName,
          row.raw['vehicle_name']?.toString(),
          row.raw['vehicleName']?.toString(),
          row.raw['name']?.toString(),
        ];
        for (final String? n in nameList) {
          if (n != null && n.trim().isNotEmpty) {
            final String clean =
                n.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
            if (clean.isNotEmpty) endFuelByVehicle[clean] = ef;
          }
        }
      }

      for (final ReportRow row in repRes.rows) {
        indexRow(row);
      }

      double? findFuelForVehicle(Vehicle v) {
        if (endFuelByVehicle.containsKey(v.id)) return endFuelByVehicle[v.id];
        if (v.deviceId.isNotEmpty && endFuelByVehicle.containsKey(v.deviceId)) {
          return endFuelByVehicle[v.deviceId];
        }
        if (v.imei.isNotEmpty && endFuelByVehicle.containsKey(v.imei)) {
          return endFuelByVehicle[v.imei];
        }

        final String cleanReg =
            v.registrationNumber.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final String cleanName =
            v.name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (cleanReg.isNotEmpty && endFuelByVehicle.containsKey(cleanReg)) {
          return endFuelByVehicle[cleanReg];
        }
        if (cleanName.isNotEmpty && endFuelByVehicle.containsKey(cleanName)) {
          return endFuelByVehicle[cleanName];
        }

        for (final MapEntry<String, double> entry in endFuelByVehicle.entries) {
          final String k = entry.key;
          if (k.length >= 5) {
            if (cleanReg.isNotEmpty &&
                (cleanReg.contains(k) || k.contains(cleanReg))) {
              return entry.value;
            }
            if (cleanName.isNotEmpty &&
                (cleanName.contains(k) || k.contains(cleanName))) {
              return entry.value;
            }
          }
        }
        return null;
      }

      final List<Vehicle> updated = list.map((Vehicle v) {
        final double? f = findFuelForVehicle(v);
        if (f != null && f > 0 && f <= 1000) {
          return v.copyWith(fuelLevel: f);
        }
        return v;
      }).toList();

      return updated;
    } catch (e) {
      debugPrint('Consolidated fuel sync skipped: $e');
      return list;
    }
  }

  /// Called by the lifecycle observer on resume — REST first, socket after.
  Future<void> resyncAfterForeground() async {
    debugPrint('[fleet] foreground resync');
    await load(silent: true);
  }

  // ── Real-time ────────────────────────────────────────────────────

  void attachSocket() {
    _socketSub?.cancel();
    final SocketService socket = ref.read(socketServiceProvider);

    _socketSub = socket.events$.listen(_onSocketEvent);

    final AppUser? user = ref.read(authProvider).user;
    if (user?.orgId != null && user!.orgId.isNotEmpty) {
      socket.joinOrg(user.orgId);
    } else if (user?.id != null) {
      socket.joinUser(user!.id);
    }

    _flushTimer?.cancel();
    final Duration throttle = state.vehicles.length > 100
        ? const Duration(milliseconds: 1500)
        : (state.vehicles.length > 30
            ? const Duration(milliseconds: 800)
            : AppConfig.mapThrottle);
    _flushTimer = Timer.periodic(throttle, (_) => _flush());
  }

  void detachSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
  }

  void _onSocketEvent(SocketEvent event) {
    switch (event.name) {
      case 'fleet:update':
      case 'vehicle:update':
      case 'location:update':
      case 'position:update':
      case 'positions':
      case 'vehicle:status':
        _bufferUpdate(event.payload);
        break;
      case 'alert:new':
      case 'geofence:event':
        // FCM handles push notifications now. Socket is just for UI state.
        break;
      case 'vehicle:safety_park':
        final String? vId = event.payload['vehicleId']?.toString() ?? event.payload['id']?.toString();
        final String? sp = event.payload['safetyPark']?.toString();
        if (vId != null && sp != null) {
          final bool armed = sp == 'YES' || sp == 'true';
          final List<Vehicle> updated = state.vehicles.map((Vehicle v) {
            if (v.id == vId) return v.withSafetyPark(armed);
            return v;
          }).toList();
          _safeSetState(state.copyWith(vehicles: updated));
        }
        break;
      default:
        break;
    }
  }

  void _bufferUpdate(Map<String, dynamic> payload) {
    // A frame may be one vehicle or a batch.
    final Object? list = payload['vehicles'] ?? payload['data'];
    if (list is List) {
      for (final Object? item in list) {
        if (item is Map) _bufferOne(Map<String, dynamic>.from(item));
      }
      return;
    }
    _bufferOne(payload);
  }

  void _bufferOne(Map<String, dynamic> frame) {
    // 1. Check all identifier fields, prioritizing device/vehicle identifiers over packet ID
    final String? devId = frame['deviceId']?.toString() ??
        frame['device_id']?.toString() ??
        (frame['device'] is Map ? (frame['device'] as Map)['id']?.toString() : null);
    final String? imei = frame['imei']?.toString() ??
        frame['IMEI']?.toString() ??
        (frame['device'] is Map ? (frame['device'] as Map)['imei']?.toString() : null);
    final String? vehicleId = frame['vehicleId']?.toString() ?? frame['_id']?.toString();
    final String? regNo = frame['registrationNumber']?.toString() ??
        frame['regNo']?.toString() ??
        frame['plateNumber']?.toString();
    final String? name = frame['name']?.toString() ?? frame['vehicleName']?.toString();
    final String? rawId = frame['vehicle']?.toString() ?? frame['id']?.toString();

    // 2. Resolve matching vehicle from indexes in order of precision
    String? resolvedId;
    if (vehicleId != null && vehicleId.isNotEmpty) {
      resolvedId = _identifierToVehicleId[vehicleId] ?? (_vehiclesById.containsKey(vehicleId) ? vehicleId : null);
    }
    if (resolvedId == null && devId != null && devId.isNotEmpty) {
      resolvedId = _identifierToVehicleId[devId] ?? (_vehiclesById.containsKey(devId) ? devId : null);
    }
    if (resolvedId == null && imei != null && imei.isNotEmpty) {
      resolvedId = _identifierToVehicleId[imei] ?? (_vehiclesById.containsKey(imei) ? imei : null);
    }
    if (resolvedId == null && regNo != null && regNo.isNotEmpty) {
      final String cleanReg = regNo.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      resolvedId = _identifierToVehicleId[cleanReg] ?? _identifierToVehicleId[regNo];
    }
    if (resolvedId == null && name != null && name.isNotEmpty) {
      final String cleanName = name.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      resolvedId = _identifierToVehicleId[cleanName] ?? _identifierToVehicleId[name];
    }
    if (resolvedId == null && rawId != null && rawId.isNotEmpty) {
      resolvedId = _identifierToVehicleId[rawId] ?? (_vehiclesById.containsKey(rawId) ? rawId : null);
    }
    // Single-vehicle fleet fallback: if the fleet only has 1 vehicle, socket frames belong to it
    if (resolvedId == null && _vehiclesById.length == 1) {
      resolvedId = _vehiclesById.keys.first;
    }

    final Vehicle? existing = resolvedId != null
        ? (_pending[resolvedId] ?? _vehiclesById[resolvedId])
        : null;

    if (existing == null) {
      // If we cannot match an existing vehicle, do NOT inject an unverified ghost record.
      // Doing so creates a duplicate marker on the map!
      if (state.vehicles.isNotEmpty) {
        return;
      }
      final Vehicle fresh = Vehicle.fromJson(frame);
      if (fresh.id.isNotEmpty && fresh.displayName.isNotEmpty) {
        _pending[fresh.id] = fresh;
        _vehiclesById[fresh.id] = fresh;
        _identifierToVehicleId[fresh.id] = fresh.id;
        if (fresh.deviceId.isNotEmpty) _identifierToVehicleId[fresh.deviceId] = fresh.id;
        if (fresh.imei.isNotEmpty) _identifierToVehicleId[fresh.imei] = fresh.id;
      }
      return;
    }

    final Vehicle updated = existing.mergeLive(frame);
    _pending[existing.id] = updated;
    _vehiclesById[existing.id] = updated;
  }

  /// Updates provider state safely so state mutations never collide
  /// with widget unmounting or frame pipeline execution.
  void _safeSetState(FleetState nextState) {
    if (!_mounted) return;
    try {
      final WidgetsBinding binding = WidgetsBinding.instance;
      if (binding.buildOwner?.debugBuilding == true) {
        Future.microtask(() {
          if (_mounted) {
            try {
              state = nextState;
            } catch (_) {}
          }
        });
      } else {
        state = nextState;
      }
    } catch (_) {}
  }

  /// Manually update or add a vehicle (e.g. from a detailed single-vehicle fetch).
  void upsertVehicle(Vehicle vehicle) {
    if (!_mounted) return;
    _pending[vehicle.id] = vehicle;
    _vehiclesById[vehicle.id] = vehicle;
    _flush();
  }

  /// Flush buffered socket frames.
  /// Telemetry data updates the vehicle in-place at its exact position in the list
  /// without re-sorting, ensuring vehicle cards never jump or shift unexpectedly while
  /// the user is focusing on or viewing them. Real-time data sync remains instant.
  void _flush() {
    if (!_mounted || _pending.isEmpty) return;

    final Map<String, Vehicle> snapshot = Map<String, Vehicle>.from(_pending);
    _pending.clear();

    if (state.vehicles.isEmpty) {
      final List<Vehicle> initialList = snapshot.values.toList();
      _sort(initialList);
      _rebuildIndexes(initialList);
      _safeSetState(state.copyWith(vehicles: initialList));
      return;
    }

    // 1. In-place update preserving exact card order on screen.
    final Set<String> updatedVehicleIds = <String>{};
    final List<Vehicle> updatedList = <Vehicle>[];

    for (final Vehicle current in state.vehicles) {
      Vehicle? live = snapshot[current.id];
      if (live != null) {
        if (_customOverrides.containsKey(live.id)) {
          final Map<String, dynamic> o = _customOverrides[live.id]!;
          live = live.copyWith(
            name: o['name'] as String? ?? live.name,
            odometer: o['odometer'] as double? ?? live.odometer,
          );
        }
        updatedList.add(live);
        updatedVehicleIds.add(current.id);
      } else {
        updatedList.add(current);
      }
    }

    // 2. Append any genuinely new vehicles in snapshot that were not in state.vehicles yet
    for (final MapEntry<String, Vehicle> entry in snapshot.entries) {
      if (!updatedVehicleIds.contains(entry.key)) {
        final Vehicle newVeh = entry.value;
        final String newDedupKey = newVeh.registrationNumber.trim().isNotEmpty
            ? newVeh.registrationNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '')
            : (newVeh.deviceId.trim().isNotEmpty ? 'dev_${newVeh.deviceId.trim()}' : newVeh.id);

        final bool alreadyExists = updatedList.any((Vehicle v) {
          if (v.id == newVeh.id) return true;
          final String existingDedupKey = v.registrationNumber.trim().isNotEmpty
              ? v.registrationNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '')
              : (v.deviceId.trim().isNotEmpty ? 'dev_${v.deviceId.trim()}' : v.id);
          return existingDedupKey == newDedupKey;
        });

        if (!alreadyExists) {
          updatedList.add(newVeh);
        }
      }
    }

    _rebuildIndexes(updatedList);
    _safeSetState(state.copyWith(vehicles: updatedList));
  }

  /// Manually force a re-render so vehicles immediately evaluate against
  /// any newly updated No Data Rule threshold.
  void refreshVehicleStatuses() {
    if (!_mounted || state.vehicles.isEmpty) return;
    _safeSetState(
        state.copyWith(vehicles: List<Vehicle>.from(state.vehicles)));
  }

  /// Vehicles go stale silently (no packet = no event), so we re-render
  /// periodically to let `status` flip to offline on its own.
  void _startStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_mounted || state.vehicles.isEmpty) return;
      _safeSetState(
          state.copyWith(vehicles: List<Vehicle>.from(state.vehicles)));
    });
  }

  /// Moving first, then idle, stopped, offline — then alphabetical.
  /// Operators care most about what is currently in motion.
  void _sort(List<Vehicle> list) {
    int rank(VehicleStatus s) => switch (s) {
          VehicleStatus.moving => 0,
          VehicleStatus.idle => 1,
          VehicleStatus.stopped => 2,
          VehicleStatus.offline => 3,
          VehicleStatus.noData => 4,
        };

    list.sort((Vehicle a, Vehicle b) {
      final int r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  }

  Future<void> updateSettings(
    String vehicleId, {
    double? overSpeedLimit,
    double? overspeedDurationAlert,
    double? idleDurationAlert,
    double? stoppageThreshold,
    double? parkingDurationAlert,
    double? movingDurationAlert,
    Map<String, bool>? alertConfig,
    bool? safetyPark,
  }) async {
    try {
      if (safetyPark != null) {
        final String cleanTarget = vehicleId.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final List<Vehicle> updated = state.vehicles.map((Vehicle v) {
          final String vReg = v.registrationNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
          final String vName = v.name.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
          if (v.id == vehicleId || vReg == cleanTarget || vName == cleanTarget) {
            final Vehicle armed = v.withSafetyPark(safetyPark);
            if (_pending.containsKey(v.id)) {
              _pending[v.id] = _pending[v.id]!.withSafetyPark(safetyPark);
            }
            _vehiclesById[v.id] = armed;
            return armed;
          }
          return v;
        }).toList();
        _safeSetState(state.copyWith(vehicles: updated));
      }

      await ref.read(vehicleRepositoryProvider).updateSettings(
            vehicleId,
            overSpeedLimit: overSpeedLimit,
            overspeedDurationAlert: overspeedDurationAlert,
            idleDurationAlert: idleDurationAlert,
            stoppageThreshold: stoppageThreshold,
            parkingDurationAlert: parkingDurationAlert,
            movingDurationAlert: movingDurationAlert,
            alertConfig: alertConfig,
            safetyPark: safetyPark,
          );
      // Reload fleet so changes reflect instantly in UI
      await load(silent: true);
    } catch (e) {
      _safeSetState(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  /// Updates vehicle name and/or odometer reading immediately in state and persists to backend.
  Future<void> updateVehicleDetails(
    String vehicleId, {
    String? name,
    double? odometer,
  }) async {
    try {
      final Map<String, dynamic> override = Map<String, dynamic>.from(
        _customOverrides[vehicleId] ?? <String, dynamic>{},
      );
      if (name != null && name.trim().isNotEmpty) {
        override['name'] = name.trim();
      }
      if (odometer != null) {
        override['odometer'] = odometer;
      }
      _customOverrides[vehicleId] = override;

      final Vehicle? existing = _vehiclesById[vehicleId] ??
          state.vehicles.where((v) => v.id == vehicleId).firstOrNull;
      if (existing != null) {
        final Map<String, dynamic> rawCopy =
            Map<String, dynamic>.from(existing.raw);
        if (name != null && name.trim().isNotEmpty) {
          rawCopy['name'] = name.trim();
          rawCopy['vehicleName'] = name.trim();
        }
        if (odometer != null) {
          rawCopy['odometer'] = odometer;
          rawCopy['current_odometer'] = odometer;
          rawCopy['odometerReading'] = odometer;
        }

        final Vehicle updated = existing.copyWith(
          name: override['name'] as String? ?? existing.name,
          odometer: override['odometer'] as double? ?? existing.odometer,
        );
        upsertVehicle(updated);
      }

      await ref.read(vehicleRepositoryProvider).updateVehicleDetails(
            vehicleId,
            name: name,
            odometer: odometer,
          );
      await load(silent: true);
    } catch (e) {
      debugPrint('[FleetNotifier] updateVehicleDetails error: $e');
      rethrow;
    }
  }

  void clear() {
    detachSocket();
    _staleTimer?.cancel();
    _vehiclesById.clear();
    _identifierToVehicleId.clear();
    state = const FleetState();
  }
}

// ── Derived providers ──────────────────────────────────────────────

final Provider<FleetStats> fleetStatsProvider =
    Provider<FleetStats>((Ref ref) => ref.watch(fleetProvider).stats);

final ProviderFamily<Vehicle?, String> vehicleByIdProvider =
    Provider.family<Vehicle?, String>((Ref ref, String id) {
  final List<Vehicle> list = ref.watch(fleetProvider).vehicles;
  if (id.isEmpty) return null;
  final String cleanId = Uri.decodeComponent(id).trim().toLowerCase();
  for (final Vehicle v in list) {
    if (v.id == id ||
        v.id.toLowerCase() == cleanId ||
        v.registrationNumber.toLowerCase() == cleanId ||
        v.displayName.toLowerCase() == cleanId ||
        v.name.toLowerCase() == cleanId) {
      return v;
    }
  }
  return null;
});

/// Dashboard search + status filter.
final StateProvider<String> fleetSearchProvider =
    StateProvider<String>((Ref ref) => '');

enum FleetSortOption {
  statusDefault,
  speedDesc,
  nameAsc,
  batteryDesc,
}

final StateProvider<VehicleStatus?> fleetFilterProvider =
    StateProvider<VehicleStatus?>((Ref ref) => null);

/// Active fleet group filter. `null` or `'all'` means all groups.
final StateProvider<String?> fleetGroupFilterProvider =
    StateProvider<String?>((Ref ref) => null);

class FleetGroup {
  final String id;
  final String name;
  final int vehicleCount;
  final int onlineCount;

  const FleetGroup({
    required this.id,
    required this.name,
    required this.vehicleCount,
    this.onlineCount = 0,
  });
}

/// Authoritative groups assigned to the user from /api/admin/groups,
/// populated with real-time vehicle counts and online counts.
final Provider<List<FleetGroup>> availableFleetGroupsProvider =
    Provider<List<FleetGroup>>((Ref ref) {
  final FleetState fleet = ref.watch(fleetProvider);
  final List<Vehicle> vehicles = fleet.vehicles;
  final List<FleetGroup> userGroups = fleet.groups;

  // 1. Authoritative: strictly use the groups assigned to this user!
  if (userGroups.isNotEmpty) {
    final List<FleetGroup> list = userGroups.map((g) {
      final List<Vehicle> matching = vehicles.where((v) {
        return v.belongsToGroup(g.id) || v.belongsToGroup(g.name);
      }).toList();

      return FleetGroup(
        id: g.id,
        name: g.name,
        vehicleCount: matching.length,
        onlineCount: matching.where((v) => v.isOnline).length,
      );
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  // 2. Fallback: extract distinct groups assigned on vehicles
  if (vehicles.isNotEmpty) {
    final Map<String, FleetGroup> groupMap = <String, FleetGroup>{};
    for (final Vehicle v in vehicles) {
      for (final String gName in v.groupNames) {
        final String trimmed = gName.trim();
        if (trimmed.isEmpty) continue;
        final String key = trimmed.toLowerCase();
        final FleetGroup? existing = groupMap[key];
        final int vCount = (existing?.vehicleCount ?? 0) + 1;
        final int onCount = (existing?.onlineCount ?? 0) + (v.isOnline ? 1 : 0);
        groupMap[key] = FleetGroup(
          id: existing?.id ?? trimmed,
          name: existing?.name ?? trimmed,
          vehicleCount: vCount,
          onlineCount: onCount,
        );
      }
    }
    if (groupMap.isNotEmpty) {
      final List<FleetGroup> list = groupMap.values.toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }
  }

  return const <FleetGroup>[];
});

final StateProvider<String?> fleetTypeFilterProvider =
    StateProvider<String?>((Ref ref) => null);

final StateProvider<FleetSortOption> fleetSortProvider =
    StateProvider<FleetSortOption>((Ref ref) => FleetSortOption.statusDefault);

final StateProvider<bool> fleetAlertsOnlyProvider =
    StateProvider<bool>((Ref ref) => false);

final Provider<List<Vehicle>> filteredVehiclesProvider =
    Provider<List<Vehicle>>((Ref ref) {
  final List<Vehicle> all = ref.watch(fleetProvider).vehicles;
  final String query = ref.watch(fleetSearchProvider).trim().toLowerCase();
  final VehicleStatus? filter = ref.watch(fleetFilterProvider);
  final String? typeFilter = ref.watch(fleetTypeFilterProvider);
  final String? groupFilter = ref.watch(fleetGroupFilterProvider);
  final bool alertsOnly = ref.watch(fleetAlertsOnlyProvider);
  final FleetSortOption sortOption = ref.watch(fleetSortProvider);

  final List<Vehicle> list = all.where((Vehicle v) {
    if (groupFilter != null &&
        groupFilter.isNotEmpty &&
        groupFilter.toLowerCase() != 'all') {
      if (!v.belongsToGroup(groupFilter)) return false;
    }
    if (filter != null && v.status != filter) return false;
    if (typeFilter != null) {
      final String t = v.displayType.toLowerCase();
      if (typeFilter == 'other') {
        if (t == 'truck' || t == 'car' || t == 'bike') return false;
      } else if (!t.contains(typeFilter)) {
        return false;
      }
    }
    if (alertsOnly &&
        (!v.isOverspeeding ||
            v.status == VehicleStatus.offline ||
            v.status == VehicleStatus.noData)) {
      return false;
    }
    if (query.isEmpty) return true;
    return v.displayName.toLowerCase().contains(query) ||
        v.name.toLowerCase().contains(query) ||
        v.imei.toLowerCase().contains(query) ||
        (v.driverName ?? '').toLowerCase().contains(query);
  }).toList();

  switch (sortOption) {
    case FleetSortOption.speedDesc:
      list.sort((a, b) => b.speed.compareTo(a.speed));
    case FleetSortOption.nameAsc:
      list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    case FleetSortOption.batteryDesc:
      list.sort((a, b) => (b.batteryLevel ?? 0).compareTo(a.batteryLevel ?? 0));
    case FleetSortOption.statusDefault:
      break;
  }

  return list;
});
