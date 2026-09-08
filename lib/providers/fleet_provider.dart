import 'dart:async';
import 'dart:convert' as dart_convert;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as flutter_local_notifications;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../core/realtime/socket_service.dart';
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
    this.overspeeding = 0,
    this.expiringSoon = 0,
    this.totalDistanceToday = 0,
  });

  final int total;
  final int moving;
  final int idle;
  final int stopped;
  final int offline;
  final int overspeeding;
  final int expiringSoon;
  final double totalDistanceToday;

  int get online => total - offline;

  double get onlinePercent => total == 0 ? 0 : online / total;
  double get utilisation => total == 0 ? 0 : moving / total;

  factory FleetStats.from(List<Vehicle> vehicles) {
    int moving = 0, idle = 0, stopped = 0, offline = 0;
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
      }
      if (v.status != VehicleStatus.offline && v.isOverspeeding) over++;
      if (v.isExpiringSoon) expiring++;
      distance += v.todayDistanceKm ?? 0;
    }

    return FleetStats(
      total: vehicles.length,
      moving: moving,
      idle: idle,
      stopped: stopped,
      offline: offline,
      overspeeding: over,
      expiringSoon: expiring,
      totalDistanceToday: distance,
    );
  }
}

class FleetState {
  const FleetState({
    this.vehicles = const <Vehicle>[],
    this.isLoading = true,
    this.isRefreshing = false,
    this.error,
    this.lastSyncedAt,
  });

  final List<Vehicle> vehicles;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastSyncedAt;

  FleetStats get stats => FleetStats.from(vehicles);
  bool get isEmpty => vehicles.isEmpty && !isLoading;

  FleetState copyWith({
    List<Vehicle>? vehicles,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    DateTime? lastSyncedAt,
    bool clearError = false,
  }) =>
      FleetState(
        vehicles: vehicles ?? this.vehicles,
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
        final Vehicle? existing = current[incoming.id];
        if (existing == null) return incoming;
        final DateTime? a = existing.lastPacketAt;
        final DateTime? b = incoming.lastPacketAt;
        if (a != null && b != null && a.isAfter(b)) return existing;
        return incoming;
      }).toList();

      _sort(merged);

      if (!_mounted) return;
      _safeSetState(state.copyWith(
        vehicles: merged,
        isLoading: false,
        isRefreshing: false,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      ));

      final SocketService socket = ref.read(socketServiceProvider);
      for (final Vehicle v in merged) {
        socket.joinVehicle(v.id);
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
    _flushTimer = Timer.periodic(AppConfig.mapThrottle, (_) => _flush());
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
    // Attempt to extract any known identifier from the socket payload
    final String rawId = <String>['vehicleId', '_id', 'id', 'vehicle', 'deviceId', 'device_id', 'imei', 'IMEI']
            .map((String k) => frame[k])
            .firstWhere(
              (Object? v) => v != null && v.toString().isNotEmpty,
              orElse: () => null,
            )
            ?.toString() ??
        '';

    if (rawId.isEmpty) {
      // Also check nested device object (common in Traccar)
      if (frame['device'] is Map) {
        final Map<String, dynamic> dev = frame['device'] as Map<String, dynamic>;
        final String devId = dev['id']?.toString() ?? dev['imei']?.toString() ?? '';
        if (devId.isNotEmpty) {
          _bufferOne({...frame, 'deviceId': devId});
        }
      }
      return;
    }

    final Vehicle? existing = _pending[rawId] ??
        state.vehicles.cast<Vehicle?>().firstWhere(
              (Vehicle? v) => v?.id == rawId || v?.deviceId == rawId || v?.imei == rawId,
              orElse: () => null,
            );

    if (existing == null) {
      // Unknown vehicle — likely added server-side while we were connected.
      final Vehicle fresh = Vehicle.fromJson(frame);
      if (fresh.id.isNotEmpty) _pending[fresh.id] = fresh;
      return;
    }

    _pending[existing.id] = existing.mergeLive(frame);
  }

  /// Updates provider state safely post-frame so state mutations never collide
  /// with widget unmounting or frame pipeline execution.
  void _safeSetState(FleetState nextState) {
    if (!_mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        try {
          state = nextState;
        } on Object catch (_) {}
      }
    });
  }

  /// Flush buffered socket frames. Snapshots _pending immediately (so new
  /// events keep buffering), then merges onto the CURRENT state at
  /// write-time — not at call-time — so a concurrent load() result is
  /// never overwritten.
  void _flush() {
    if (!_mounted || _pending.isEmpty) return;

    final Map<String, Vehicle> snapshot = Map<String, Vehicle>.from(_pending);
    _pending.clear();

    final Map<String, Vehicle> next = <String, Vehicle>{
      for (final Vehicle v in state.vehicles) v.id: v,
      ...snapshot,
    };
    final List<Vehicle> list = next.values.toList();
    _sort(list);
    _safeSetState(state.copyWith(vehicles: list));
  }

  /// Vehicles go stale silently (no packet = no event), so we re-render
  /// periodically to let `status` flip to offline on its own.
  void _startStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_mounted || state.vehicles.isEmpty) return;
      _safeSetState(state.copyWith(vehicles: List<Vehicle>.from(state.vehicles)));
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
        };

    list.sort((Vehicle a, Vehicle b) {
      final int r = rank(a.status).compareTo(rank(b.status));
      if (r != 0) return r;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  }

  Future<void> updateSettings(String vehicleId, {
    double? overSpeedLimit,
    double? overspeedDurationAlert,
    double? idleDurationAlert,
  }) async {
    try {
      await ref.read(vehicleRepositoryProvider).updateSettings(
        vehicleId,
        overSpeedLimit: overSpeedLimit,
        overspeedDurationAlert: overspeedDurationAlert,
        idleDurationAlert: idleDurationAlert,
      );
      // Reload fleet so changes reflect instantly in UI
      await load(silent: true);
    } catch (e) {
      _safeSetState(state.copyWith(error: e.toString()));
      rethrow;
    }
  }

  void clear() {
    detachSocket();
    _staleTimer?.cancel();
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

final StateProvider<VehicleStatus?> fleetFilterProvider =
    StateProvider<VehicleStatus?>((Ref ref) => null);

final Provider<List<Vehicle>> filteredVehiclesProvider =
    Provider<List<Vehicle>>((Ref ref) {
  final List<Vehicle> all = ref.watch(fleetProvider).vehicles;
  final String query = ref.watch(fleetSearchProvider).trim().toLowerCase();
  final VehicleStatus? filter = ref.watch(fleetFilterProvider);

  return all.where((Vehicle v) {
    if (filter != null && v.status != filter) return false;
    if (query.isEmpty) return true;
    return v.displayName.toLowerCase().contains(query) ||
        v.name.toLowerCase().contains(query) ||
        v.imei.toLowerCase().contains(query) ||
        (v.driverName ?? '').toLowerCase().contains(query);
  }).toList(growable: false);
});
