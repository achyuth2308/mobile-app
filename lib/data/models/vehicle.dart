import 'dart:math' as math;
import 'package:equatable/equatable.dart';

import '../../core/config/app_config.dart';
import 'json_utils.dart';

/// Derived operational state. Computed client-side from telemetry so the
/// list, map and detail screens never disagree about what a vehicle is doing.
enum VehicleStatus { moving, idle, stopped, offline, noData }

extension VehicleStatusX on VehicleStatus {
  String get key => name;

  String get label => switch (this) {
        VehicleStatus.moving => 'Moving',
        VehicleStatus.idle => 'Idle',
        VehicleStatus.stopped => 'Stopped',
        VehicleStatus.offline => 'No Data',
        VehicleStatus.noData => 'Offline',
      };

  String get sinceLabel => switch (this) {
        VehicleStatus.moving => 'Moving',
        VehicleStatus.idle => 'Idle',
        VehicleStatus.stopped => 'Stopped',
        VehicleStatus.offline => 'No Data',
        VehicleStatus.noData => 'Unreachable',
      };

  String get description => switch (this) {
        VehicleStatus.moving => 'Ignition on and in motion',
        VehicleStatus.idle => 'Ignition on, not moving',
        VehicleStatus.stopped => 'Parked, ignition off',
        VehicleStatus.offline => 'No recent data received',
        VehicleStatus.noData => 'Location unavailable and no data received',
      };
}

class Vehicle extends Equatable {
  const Vehicle({
    required this.id,
    required this.name,
    this.registrationNumber = '',
    this.imei = '',
    this.deviceId = '',
    this.orgId = '',
    this.type = 'car',
    this.driverName,
    this.driverPhone,
    this.latitude,
    this.longitude,
    this.speed = 0,
    this.heading = 0,
    this.ignition = false,
    this.isMoving = false,
    this.odometer,
    this.fuelLevel,
    this.batteryLevel,
    this.gsmSignal,
    this.satellites,
    this.address,
    this.lastPacketAt,
    this.statusChangedAt,
    this.expiryDate,
    this.speedLimit,
    this.overspeedDurationAlert,
    this.idleDurationAlert,
    this.todayDistanceKm,
    this.isActive = true,
    this.rawStatus,
    this.raw = const <String, dynamic>{},
    this.isImmobilized = false,
    this.isAcOff = false,
    this.isOnline = true,
  });

  final Map<String, dynamic> raw;
  final String id;
  final String name;
  final String registrationNumber;
  final String imei;
  final String deviceId;
  final String orgId;

  /// car | truck | bus | bike | tractor | generator …
  final String type;

  final String? driverName;
  final String? driverPhone;

  // ── Live telemetry ───────────────────────────────────────────────
  final double? latitude;
  final double? longitude;
  final double speed; // km/h
  final double heading; // degrees, 0 = north
  final bool ignition;
  final bool isMoving;
  final double? odometer; // km
  final double? fuelLevel; // %
  final double? batteryLevel; // %
  final int? gsmSignal; // 0-5
  final int? satellites;
  final String? address;
  final DateTime? lastPacketAt;
  final DateTime? statusChangedAt;

  // ── Commercial ───────────────────────────────────────────────────
  final DateTime? expiryDate;
  final double? speedLimit;
  final double? overspeedDurationAlert;
  final double? idleDurationAlert;
  final double? todayDistanceKm;
  final bool isActive;

  /// Whatever the server called it, kept for debugging/telemetry parity.
  final String? rawStatus;

  /// Whether the engine is currently cut via relay command.
  final bool isImmobilized;

  /// Whether the AC relay is currently cut/disabled.
  final bool isAcOff;

  /// Whether the vehicle is currently online according to the server.
  final bool isOnline;

  String get displayType {
    final String lowerType = type.toLowerCase().trim();
    final String lowerName = name.toLowerCase();

    // 1. Explicitly check type field first and map to available assets
    if (lowerType == 'car' || lowerType == 'taxi' || lowerType == 'cab') {
      return 'car';
    }
    if (lowerType == 'generator' ||
        lowerType == 'genset' ||
        lowerType == 'dg_set' ||
        lowerType == 'dgset') {
      return 'generator';
    }
    if (lowerType == 'ambulance') {
      return 'ambulance';
    }
    if (lowerType == 'auto' ||
        lowerType == 'rickshaw' ||
        lowerType == 'autorickshaw' ||
        lowerType == 'tuk-tuk' ||
        lowerType == 'tuktuk' ||
        lowerType == 'three-wheeler' ||
        lowerType == '3-wheeler') {
      return 'auto';
    }
    if (lowerType == 'borewell' ||
        lowerType == 'drilling' ||
        lowerType == 'drilling_rig' ||
        lowerType == 'rig') {
      return 'borewell';
    }
    if (lowerType == 'crane' ||
        lowerType == 'crawler_crane' ||
        lowerType == 'mobile_crane') {
      return 'crane';
    }
    if (lowerType == 'tipper' || lowerType == 'dumper') {
      return 'tipper';
    }
    if (lowerType == 'hitachi' ||
        lowerType == 'excavator' ||
        lowerType == 'poclain') {
      return 'hitachi';
    }
    if (lowerType == 'jcb' || lowerType == 'backhoe') {
      return 'jcb';
    }
    if (lowerType == 'tractor' || lowerType == 'harvester') {
      return 'tractor';
    }
    if (lowerType == 'scooter' ||
        lowerType == 'scooty' ||
        lowerType == 'vespa' ||
        lowerType == 'activa') {
      return 'scooter';
    }
    if (lowerType == 'bike' ||
        lowerType == 'motorcycle' ||
        lowerType == 'two-wheeler') {
      return 'bike';
    }
    if (lowerType == 'lorry' ||
        lowerType == 'cargo_lorry' ||
        lowerType == 'indian_lorry' ||
        lowerType == 'indian_truck' ||
        lowerType == 'multiaxle' ||
        lowerType == 'multi-axle' ||
        lowerType == '12_wheeler' ||
        lowerType == '10_wheeler' ||
        lowerType == '14_wheeler' ||
        lowerType == '16_wheeler') {
      return 'lorry';
    }
    if (lowerType == 'truck' ||
        lowerType == 'trailer' ||
        lowerType == 'container' ||
        lowerType == 'cargo_truck' ||
        lowerType == 'heavy_truck') {
      return 'truck';
    }

    // 2. Next, check name clues if type is generic/empty
    if (lowerName.contains('generator') ||
        lowerName.contains('genset') ||
        lowerName.contains('dg set') ||
        lowerName.contains('dgset') ||
        lowerName.contains('dg_set')) {
      return 'generator';
    }
    if (lowerName.contains('ambulance')) return 'ambulance';
    if (lowerName.contains('rickshaw') ||
        lowerName.contains('auto ') ||
        lowerName.contains(' auto') ||
        lowerName.startsWith('auto') ||
        lowerName.endsWith('auto') ||
        lowerName.contains('tuktuk') ||
        lowerName.contains('tuk-tuk') ||
        lowerName.contains('three-wheeler') ||
        lowerName.contains('3-wheeler')) {
      return 'auto';
    }
    if (lowerName.contains('borewell') ||
        lowerName.contains('drilling') ||
        lowerName.contains(' rig')) {
      return 'borewell';
    }
    if (lowerName.contains('crane')) return 'crane';
    if (lowerName.contains('tipper')) return 'tipper';
    if (lowerName.contains('hitachi') ||
        lowerName.contains('excavator') ||
        lowerName.contains('poclain')) {
      return 'hitachi';
    }
    if (lowerName.contains('jcb') || lowerName.contains('backhoe')) {
      return 'jcb';
    }
    if (lowerName.contains('tractor')) return 'tractor';
    if (lowerName.contains('car')) return 'car';
    if (lowerName.contains('scooter') ||
        lowerName.contains('scooty') ||
        lowerName.contains('vespa') ||
        lowerName.contains('activa') ||
        lowerName.contains('scoot')) {
      return 'scooter';
    }
    if (lowerName.contains('bike') ||
        lowerName.contains('motorcycle') ||
        lowerName.contains('motor')) {
      return 'bike';
    }
    if (lowerName.contains('lorry')) return 'lorry';
    if (lowerName.contains('truck') ||
        lowerName.contains('dumper')) {
      return 'truck';
    }

    // 3. Fallback to truck if type is completely unknown or empty
    return 'truck';
  }

  /// Resolves the state-specific asset image path (e.g. truck_moving.png, truck_idle.png,
  /// truck_stopped.png), matching the vehicle's live operating state.
  String get statusAssetPath {
    final String base = displayType;
    switch (status) {
      case VehicleStatus.moving:
        return 'assets/images/vehicles/${base}_moving.png';
      case VehicleStatus.idle:
        return 'assets/images/vehicles/${base}_idle.png';
      case VehicleStatus.stopped:
        return 'assets/images/vehicles/${base}_stopped.png';
      case VehicleStatus.offline:
        return 'assets/images/vehicles/${base}_offline.png';
      case VehicleStatus.noData:
        return 'assets/images/vehicles/${base}_unreachable.png';
    }
  }

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  /// True only if this vehicle has calibrated fuel telemetry from its device/sensor.
  bool get hasFuel {
    if (fuelLevel != null && fuelLevel! > 0 && fuelLevel! <= 1000) return true;
    final dynamic meta = raw['metadata'];
    if (meta is Map) {
      if (meta['hasFuelSensor'] == true || meta['hasFuelSensor'] == 'YES') return true;
      if (meta['fuelSensor'] == true || meta['fuelSensor'] == 'YES') return true;
      if (meta['fuelConfig'] != null) return true;
      final dynamic ts = meta['tankSize'] ?? meta['tank_size'];
      if (ts != null && ts.toString() != '0' && ts.toString().isNotEmpty) return true;
    }
    if (raw['hasFuelSensor'] == true || raw['fuelSensor'] == true) return true;
    return false;
  }

  /// True if this asset is a stationary Diesel Generator / Genset.
  bool get isGenerator =>
      displayType == 'generator' ||
      type.toLowerCase().trim() == 'generator' ||
      type.toLowerCase().trim() == 'genset';

  /// Human-friendly operating status label (e.g. "Running" / "Standby" for generators, "Moving" / "Stopped" for vehicles).
  String get effectiveStatusLabel {
    if (isGenerator) {
      switch (status) {
        case VehicleStatus.moving:
          return 'Running';
        case VehicleStatus.idle:
          return 'Idle';
        case VehicleStatus.stopped:
          return 'Standby';
        case VehicleStatus.offline:
          return 'No Data';
        case VehicleStatus.noData:
          return 'Offline';
      }
    }
    return status.label;
  }

  /// True if Safety Parking (Theft Alarm) is armed for this vehicle.
  bool get isSafetyParkActive {
    final dynamic meta = raw['metadata'];
    if (meta is Map) {
      final dynamic sp = meta['safetyPark'] ?? meta['safety_park'];
      return sp == 'YES' || sp == true;
    }
    final dynamic sp = raw['safetyPark'] ?? raw['safety_park'];
    return sp == 'YES' || sp == true;
  }

  /// True only if this vehicle is registered or operating in Tamil Nadu (e.g. TN plate).
  /// Fitment certificates are strictly reserved for Tamil Nadu vehicles.
  bool get isTamilNadu {
    // 1. Direct registration number check (e.g. TN38AB1234, TN-01-1234)
    final String reg = registrationNumber.trim().toUpperCase();
    if (reg.isNotEmpty) {
      final String cleanReg = reg.replaceAll(RegExp(r'[\s\-_]+'), '');
      if (cleanReg.startsWith('TN')) return true;
      if (RegExp(r'\bTN[\s\-_]*[0-9]{1,2}', caseSensitive: false).hasMatch(reg)) return true;
    }

    // 2. Name / Display label check (e.g. "TN 38 BK 1234" or "DURGESH_TN01AD9169")
    final String n = name.trim().toUpperCase();
    if (n.isNotEmpty) {
      final String cleanName = n.replaceAll(RegExp(r'[\s\-_]+'), '');
      if (cleanName.startsWith('TN')) return true;
      if (RegExp(r'TN[0-9]{1,2}', caseSensitive: false).hasMatch(cleanName)) return true;
    }

    // 3. Metadata attributes check (state, districtState, certFormat)
    final dynamic meta = raw['metadata'];
    if (meta is Map) {
      final String state = (meta['state'] ??
              meta['districtState'] ??
              meta['stateName'] ??
              meta['rtoState'] ??
              meta['rto_state'] ??
              '')
          .toString()
          .toLowerCase()
          .trim();
      if (state.contains('tamil') || state.contains('tamilnadu') || state == 'tn') {
        return true;
      }
      if (meta['certFormat'] == 'tamilnadu_mining') {
        return true;
      }
    }

    final dynamic rawState = raw['state'] ?? raw['districtState'] ?? raw['stateName'];
    if (rawState != null) {
      final String s = rawState.toString().toLowerCase().trim();
      if (s.contains('tamil') || s.contains('tamilnadu') || s == 'tn') return true;
    }

    return false;
  }

  /// Returns a copy of this vehicle with Safety Parking updated.
  Vehicle withSafetyPark(bool armed) {
    final Map<String, dynamic> newRaw = Map<String, dynamic>.from(raw);
    final Map<String, dynamic> newMeta = (newRaw['metadata'] is Map)
        ? Map<String, dynamic>.from(newRaw['metadata'] as Map)
        : <String, dynamic>{};
    newMeta['safetyPark'] = armed ? 'YES' : 'NO';
    newRaw['metadata'] = newMeta;
    newRaw['safetyPark'] = armed ? 'YES' : 'NO';

    return Vehicle(
      id: id,
      name: name,
      registrationNumber: registrationNumber,
      imei: imei,
      deviceId: deviceId,
      orgId: orgId,
      type: type,
      driverName: driverName,
      driverPhone: driverPhone,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      heading: heading,
      ignition: ignition,
      isMoving: isMoving,
      odometer: odometer,
      fuelLevel: fuelLevel,
      batteryLevel: batteryLevel,
      gsmSignal: gsmSignal,
      satellites: satellites,
      address: address,
      lastPacketAt: lastPacketAt,
      statusChangedAt: statusChangedAt,
      expiryDate: expiryDate,
      speedLimit: speedLimit,
      overspeedDurationAlert: overspeedDurationAlert,
      idleDurationAlert: idleDurationAlert,
      todayDistanceKm: todayDistanceKm,
      isActive: isActive,
      rawStatus: rawStatus,
      raw: newRaw,
      isImmobilized: isImmobilized,
      isOnline: isOnline,
    );
  }

  /// True for bike / scooter / motorcycle type vehicles.
  /// Two-wheelers typically power their GPS tracker off the bike battery,
  /// so when the bike stops the device goes offline immediately. We treat
  /// them as Parked (stopped) rather than Offline when the last known
  /// data shows a standstill.
  bool get isTwoWheeler {
    final String t = type.toLowerCase().trim();
    return t == 'bike' ||
        t == 'motorcycle' ||
        t == 'scooter' ||
        t == 'scooty' ||
        t == 'two-wheeler' ||
        t == 'two_wheeler' ||
        t == 'moped' ||
        t == 'ebike' ||
        t == 'e-bike';
  }

  Duration? get sinceLastPacket =>
      lastPacketAt == null ? null : DateTime.now().difference(lastPacketAt!);

  /// Single source of truth for status across the app.
  VehicleStatus get status {
    // 0. Vehicles with no packet or unavailable location are classified as No Data.
    if (lastPacketAt == null || !hasLocation) {
      return VehicleStatus.noData;
    }

    final Duration? age = sinceLastPacket;

    // ── NO DATA RULE ─────────────────────────────────────────────
    // When telemetry is NOT coming from the device, keep the vehicle
    // in its exact SAME STATE (Moving, Idle, Parked) until the elapsed
    // time exceeds the user's selected threshold (default: 30 min, or 1h/3h/6h/12h/24h).
    //
    // Only after the threshold duration has fully elapsed without any
    // packets arriving from the device, transition to 'offline' (No Data).
    if (age != null && age > AppConfig.offlineThreshold) {
      return VehicleStatus.offline;
    }

    // 2. If the server explicitly provided a status and it's NOT stale, trust it
    // so the mobile app stays in perfect sync with the web dashboard.
    if (rawStatus != null) {
      final String rs = rawStatus!.toLowerCase().trim();
      if (rs == 'moving' ||
          rs == 'running' ||
          rs == 'driving' ||
          rs == 'active' ||
          rs == 'run' ||
          rs == 'in transit' ||
          rs == 'in_transit' ||
          rs == 'on trip' ||
          rs == 'on_trip' ||
          rs == 'trip' ||
          rs == 'motion') {
        return VehicleStatus.moving;
      }
      if (rs == 'idle' ||
          rs == 'idling' ||
          rs == 'stop_idle' ||
          rs == 'parked_idle') {
        return VehicleStatus.idle;
      }
      if (rs == 'stopped' || rs == 'parked' || rs == 'stop') {
        return VehicleStatus.stopped;
      }
      if (rs == 'offline' || rs == 'disconnected' || rs == 'inactive') {
        return VehicleStatus.offline;
      }
    }

    // 1. If vehicle is in motion (speed > 2.0 km/h), it is MOVING / RUNNING.
    // This perfectly matches the logic in CustomerDashboard.jsx on the web app.
    if (speed > 2.0) return VehicleStatus.moving;

    // 2. If stationary (speed <= 2.0 km/h) and ignition is ON, it is IDLE.
    if (ignition) return VehicleStatus.idle;

    // 3. Stationary and ignition OFF:
    return VehicleStatus.stopped;
  }

  bool get isOverspeeding {
    final double limit = speedLimit ?? AppConfig.overspeedDefaultKph;
    return speed > limit;
  }

  DateTime? get resolvedExpiryDate {
    if (expiryDate != null) return expiryDate;
    // Dynamic scan in raw map for any field containing 'expir', 'valid', or 'renew'
    for (final MapEntry<String, dynamic> e in raw.entries) {
      final String k = e.key.toLowerCase();
      if (k.contains('expir') || k.contains('valid') || k.contains('renew')) {
        final DateTime? d = asDate(<String, dynamic>{'d': e.value}, <String>['d']);
        if (d != null) return d;
      }
    }
    if (raw['attributes'] is Map) {
      final Map<String, dynamic> attrs =
          Map<String, dynamic>.from(raw['attributes'] as Map);
      for (final MapEntry<String, dynamic> e in attrs.entries) {
        final String k = e.key.toLowerCase();
        if (k.contains('expir') || k.contains('valid') || k.contains('renew')) {
          final DateTime? d = asDate(<String, dynamic>{'d': e.value}, <String>['d']);
          if (d != null) return d;
        }
      }
    }
    if (raw['device'] is Map) {
      final Map<String, dynamic> dev =
          Map<String, dynamic>.from(raw['device'] as Map);
      for (final MapEntry<String, dynamic> e in dev.entries) {
        final String k = e.key.toLowerCase();
        if (k.contains('expir') || k.contains('valid') || k.contains('renew')) {
          final DateTime? d = asDate(<String, dynamic>{'d': e.value}, <String>['d']);
          if (d != null) return d;
        }
      }
    }
    return null;
  }

  int? get daysToExpiry {
    final DateTime? expDate = resolvedExpiryDate;
    if (expDate == null) return null;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime exp =
        DateTime(expDate.year, expDate.month, expDate.day);
    return exp.difference(today).inDays;
  }

  bool get isExpiringSoon {
    final int? d = daysToExpiry;
    return d != null && d <= 30;
  }

  bool get isExpired {
    final int? d = daysToExpiry;
    return d != null && d < 0;
  }

  /// Best human label — plate first, it is what drivers/owners say out loud.
  String get displayName {
    if (registrationNumber.trim().isNotEmpty) return registrationNumber.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return 'Vehicle ${id.length > 6 ? id.substring(0, 6) : id}';
  }

  String get plateNumber => registrationNumber;
  String get plate => registrationNumber;

  String get secondaryLabel {
    if (registrationNumber.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        name.trim() != registrationNumber.trim()) {
      return name.trim();
    }
    if (driverName != null && driverName!.trim().isNotEmpty) {
      return driverName!.trim();
    }
    return imei.isNotEmpty ? 'IMEI $imei' : type.toUpperCase();
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Position may be nested under several shapes.
    final Map<String, dynamic> pos = <String, dynamic>{
      ...asMap(json, <String>[
        'lastLocation',
        'location',
        'position',
        'lastPosition',
        'latestLocation',
        'gps',
      ]),
    };
    final Map<String, dynamic> src = pos.isEmpty ? json : pos;

    // GeoJSON: { type: 'Point', coordinates: [lng, lat] }
    double? lat = asDoubleOrNull(src, <String>['latitude', 'lat', 'Lat', 'y']);
    double? lng =
        asDoubleOrNull(src, <String>['longitude', 'lng', 'lon', 'Lng', 'x']);

    if ((lat == null || lng == null) && src['coordinates'] is List) {
      final List<dynamic> c = src['coordinates'] as List<dynamic>;
      if (c.length >= 2) {
        lng = toDouble(c[0]);
        lat = toDouble(c[1]);
      }
    }
    if (lat == null || lng == null) {
      lat ??= asDoubleOrNull(json, <String>['latitude', 'lat']);
      lng ??= asDoubleOrNull(json, <String>['longitude', 'lng', 'lon']);
    }

    final Map<String, dynamic> srcAttrs =
        asMap(src, <String>['attributes', 'params', 'attr', 'io']);
    final Map<String, dynamic> jsonAttrs =
        asMap(json, <String>['attributes', 'params', 'attr', 'io', 'metadata', 'state', 'latest_state', 'latestState', 'vehicle_latest_state']);
    final Map<String, dynamic> device =
        asMap(json, <String>['device', 'tracker', 'gpsDevice']);
    final Map<String, dynamic> deviceAttrs =
        asMap(device, <String>['attributes', 'params', 'attr']);

    const List<String> speedKeys = <String>[
      'speed',
      'currentSpeed',
      'current_speed',
      'spd',
      'velocity',
      'gpsSpeed',
      'gps_speed',
      'lastSpeed',
      'last_speed',
      'speed_kph',
      'speedKph',
      'speed_kmh',
      'speedKmh',
      'spd_kph',
    ];

    const List<String> ignKeys = <String>[
      'ignition',
      'current_ignition',
      'ign',
      'acc',
      'ACC',
      'engineOn',
      'engine_on',
      'engine',
      'ignitionStatus',
      'ignition_status',
      'Ignition',
      'accStatus',
      'acc_status',
      'isIgnition',
      'is_ignition',
      'engineState',
      'engine_state',
    ];

    const List<String> motionKeys = <String>[
      'motion',
      'isMotion',
      'is_motion',
      'moving',
      'isMoving',
      'is_moving',
      'running',
      'isRunning',
      'is_running',
      'driving',
      'isDriving',
      'is_driving',
      'inTransit',
      'in_transit',
    ];

    const List<String> statusKeys = <String>[
      'status',
      'state',
      'vehicleStatus',
      'vehicle_status',
      'device_status',
      'deviceStatus',
      'currentStatus',
      'current_status',
      'activity',
      'motionStatus',
      'motion_status',
      'vehicle_state',
      'deviceState',
      'motion_state',
    ];

    final double parsedSpeed = asDoubleOrNull(src, speedKeys) ??
        asDoubleOrNull(json, speedKeys) ??
        asDoubleOrNull(srcAttrs, speedKeys) ??
        asDoubleOrNull(jsonAttrs, speedKeys) ??
        asDoubleOrNull(device, speedKeys) ??
        asDoubleOrNull(deviceAttrs, speedKeys) ??
        0.0;

    final bool isIgnition = asBool(src, ignKeys) ||
        asBool(json, ignKeys) ||
        asBool(srcAttrs, ignKeys) ||
        asBool(jsonAttrs, ignKeys) ||
        asBool(device, ignKeys) ||
        asBool(deviceAttrs, ignKeys) ||
        parsedSpeed > 2.0;

    final bool isMotion = asBool(src, motionKeys) ||
        asBool(json, motionKeys) ||
        asBool(srcAttrs, motionKeys) ||
        asBool(jsonAttrs, motionKeys) ||
        asBool(device, motionKeys) ||
        asBool(deviceAttrs, motionKeys);

    final bool isImmobilized = asBool(srcAttrs, <String>['blocked', 'out1', 'cut']) ||
        asBool(deviceAttrs, <String>['blocked', 'out1', 'cut']) ||
        asBool(json, <String>['blocked', 'out1', 'cut']);

    final bool isAcOff = asBool(srcAttrs, <String>['acOff', 'ac_off', 'cutAc', 'isAcCut', 'out2', 'relay2']) ||
        asBool(deviceAttrs, <String>['acOff', 'ac_off', 'cutAc', 'isAcCut', 'out2', 'relay2']) ||
        asBool(json, <String>['acOff', 'ac_off', 'cutAc', 'isAcCut', 'out2', 'relay2']);

    final String? parsedStatus = asStringOrNull(json, statusKeys) ??
        asStringOrNull(src, statusKeys) ??
        asStringOrNull(srcAttrs, statusKeys) ??
        asStringOrNull(jsonAttrs, statusKeys) ??
        asStringOrNull(device, statusKeys) ??
        asStringOrNull(deviceAttrs, statusKeys);

    return Vehicle(
      id: asString(json, <String>['_id', 'id', 'vehicleId', 'uuid']),
      name: asString(json, <String>['name', 'vehicleName', 'title', 'label']),
      registrationNumber: asString(json, <String>[
        'registrationNumber',
        'regNo',
        'registration',
        'plateNumber',
        'vehicleNumber',
        'number',
        'licensePlate',
      ]),
      imei: asString(json, <String>['imei', 'IMEI', 'deviceImei']).isNotEmpty
          ? asString(json, <String>['imei', 'IMEI', 'deviceImei'])
          : asString(device, <String>['imei', 'IMEI']),
      deviceId: asString(json, <String>['deviceId', 'device_id']).isNotEmpty
          ? asString(json, <String>['deviceId', 'device_id'])
          : asString(device, <String>['_id', 'id']),
      orgId: asString(json, <String>[
        'orgId',
        'organizationId',
        'organisationId',
        'org',
        'tenantId',
      ]),
      type: asString(json, <String>['type', 'model', 'vehicleType', 'category'],
              fallback: 'car')
          .toLowerCase(),
      driverName: asStringOrNull(json, <String>[
        'driverName',
        'driver',
        'assignedDriver',
        'driverFullName',
      ]),
      driverPhone: asStringOrNull(json, <String>[
        'driverPhone',
        'driverMobile',
        'driverContact',
      ]),
      latitude: lat,
      longitude: lng,
      speed: parsedSpeed,
      heading: asDouble(
          src, <String>['heading', 'current_direction', 'course', 'bearing', 'direction', 'angle']),
      ignition: isIgnition,
      isMoving: isMotion,
      isImmobilized: isImmobilized,
      isAcOff: isAcOff,
      isOnline: asBool(json, <String>['is_online', 'isOnline', 'online'], fallback: true) &&
                asBool(src, <String>['is_online', 'isOnline', 'online'], fallback: true),
      odometer: () {
        double? val = asDoubleOrNull(
                src, <String>['odometer', 'current_odometer', 'display_odometer', 'totalDistance', 'mileage', 'odo', 'total_distance', 'odokms', 'odometerReading', 'odometer_reading']) ??
            asDoubleOrNull(srcAttrs,
                <String>['odometer', 'current_odometer', 'display_odometer', 'totalDistance', 'mileage', 'odo', 'total_distance', 'odokms', 'odometerReading', 'odometer_reading']) ??
            asDoubleOrNull(json,
                <String>['odometer', 'current_odometer', 'display_odometer', 'totalDistance', 'mileage', 'odo', 'total_distance', 'odokms', 'odometerReading', 'odometer_reading']) ??
            asDoubleOrNull(jsonAttrs,
                <String>['odometer', 'current_odometer', 'display_odometer', 'totalDistance', 'mileage', 'odo', 'total_distance', 'odokms', 'odometerReading', 'odometer_reading']) ??
            asDoubleOrNull(device,
                <String>['odometer', 'current_odometer', 'display_odometer', 'totalDistance', 'mileage', 'odo', 'total_distance', 'odokms', 'odometerReading', 'odometer_reading']) ??
            asDoubleOrNull(deviceAttrs,
                <String>['odometer', 'current_odometer', 'display_odometer', 'totalDistance', 'mileage', 'odo', 'total_distance', 'odokms', 'odometerReading', 'odometer_reading']);
        if (val != null && val > 500000) {
          val = val / 1000.0;
        }
        return val;
      }(),
      fuelLevel: () {
        const List<String> calibratedKeys = <String>[
          'calibrated_fuel',
          'calibratedFuel',
          'normalized_fuel',
          'normalizedFuel',
          'end_fuel',
          'endFuel',
          'current_fuel_level',
          'currentFuelLevel',
          'fuel_litres',
          'fuelLitres',
          'fuel_liters',
          'fuelLiters',
          'fuel_qty',
          'fuelQty',
          'litres',
          'liters',
        ];
        const List<String> fallbackKeys = <String>[
          'current_fuel',
          'currentFuel',
          'fuel',
          'fuelLevel',
          'fuel_level',
          'fuelPercent',
          'fuel_percent',
        ];
        double? val = asDoubleOrNull(src, calibratedKeys) ??
            asDoubleOrNull(srcAttrs, calibratedKeys) ??
            asDoubleOrNull(json, calibratedKeys) ??
            asDoubleOrNull(jsonAttrs, calibratedKeys) ??
            asDoubleOrNull(device, calibratedKeys) ??
            asDoubleOrNull(deviceAttrs, calibratedKeys);

        val ??= asDoubleOrNull(src, fallbackKeys) ??
            asDoubleOrNull(srcAttrs, fallbackKeys) ??
            asDoubleOrNull(json, fallbackKeys) ??
            asDoubleOrNull(jsonAttrs, fallbackKeys) ??
            asDoubleOrNull(device, fallbackKeys) ??
            asDoubleOrNull(deviceAttrs, fallbackKeys);

        // Reject raw ADC values (e.g. 2803, 819). Calibrated fuel only!
        if (val != null && val > 400) {
          return null;
        }

        return val;
      }(),
      batteryLevel:
          asDoubleOrNull(src, <String>['current_voltage', 'voltage', 'external_voltage']) ??
              asDoubleOrNull(
                  srcAttrs, <String>['current_voltage', 'voltage', 'external_voltage']) ??
              asDoubleOrNull(json, <String>['current_voltage', 'voltage', 'external_voltage']) ??
              asDoubleOrNull(jsonAttrs, <String>['current_voltage', 'voltage', 'external_voltage']),
      gsmSignal: asDoubleOrNull(src, <String>['gsm', 'gsmSignal', 'signal'])
              ?.round() ??
          asDoubleOrNull(srcAttrs, <String>['gsm', 'gsmSignal', 'signal'])
              ?.round(),
      satellites: () {
        const List<String> satKeys = <String>[
          'satellites',
          'sats',
          'gpsSatellites',
          'sat',
          'sat_count',
          'satcount',
          'satellite',
          'satelliteCount',
          'satellite_count',
          'satsCount',
          'gps_satellites',
        ];
        return asDoubleOrNull(src, satKeys)?.round() ??
            asDoubleOrNull(srcAttrs, satKeys)?.round() ??
            asDoubleOrNull(json, satKeys)?.round() ??
            asDoubleOrNull(jsonAttrs, satKeys)?.round() ??
            asDoubleOrNull(device, satKeys)?.round() ??
            asDoubleOrNull(deviceAttrs, satKeys)?.round();
      }(),
      address: asStringOrNull(src, <String>['address', 'location', 'place']) ??
          asStringOrNull(json, <String>['address', 'lastAddress']),
      lastPacketAt: asDate(src, <String>[
            'last_seen',
            'lastSeen',
            'lastPacketAt',
            'device_time',
            'deviceTime',
            'server_time',
            'serverTime',
            'timestamp',
            'lastUpdate',
            'time',
            'gpsTime',
            'fixTime',
            'updatedAt',
            'locTime',
            'loc_time',
            'commTime',
            'comm_time',
            'Loc Time',
            'Comm Time',
            'date',
            'device_date',
            'server_date'
          ]) ??
          asDate(srcAttrs, <String>[
            'last_seen',
            'lastSeen',
            'timestamp',
            'time',
            'gpsTime',
            'fixTime'
          ]) ??
          asDate(json, <String>[
            'lastPacketAt',
            'lastUpdate',
            'lastSeen',
            'last_seen',
            'updatedAt',
            'timestamp',
            'locTime',
            'loc_time',
            'commTime',
            'comm_time',
            'Loc Time',
            'Comm Time',
            'date'
          ]),
      statusChangedAt: asDate(src, <String>[
            'statusChangedAt',
            'status_changed_at',
            'stateChangedAt',
            'state_changed_at',
            'statusTime',
            'status_time',
            'stateTime',
            'state_time',
            'motionTime',
            'motion_time',
            'movingSince',
            'moving_since',
            'statusSince',
            'status_since',
            'startTime',
            'start_time',
          ]) ??
          asDate(json, <String>[
            'statusChangedAt',
            'status_changed_at',
            'stateChangedAt',
            'state_changed_at',
            'statusTime',
            'status_time',
            'stateTime',
            'state_time',
            'motionTime',
            'motion_time',
            'movingSince',
            'moving_since',
            'statusSince',
            'status_since',
            'startTime',
            'start_time',
          ]),
      expiryDate: () {
        const List<String> expKeys = <String>[
          'expiryDate',
          'expiry_date',
          'expirationTime',
          'expiration_time',
          'expiration',
          'expiresAt',
          'expires_at',
          'expireDate',
          'expire_date',
          'expireTime',
          'expire_time',
          'expiry',
          'expires',
          'validTill',
          'valid_till',
          'validUntil',
          'valid_until',
          'validTo',
          'valid_to',
          'validity',
          'validityDate',
          'validity_date',
          'subscriptionExpiry',
          'subscription_expiry',
          'subscriptionEndDate',
          'subscription_end_date',
          'subscriptionEnd',
          'subscription_end',
          'renewalDate',
          'renewal_date',
          'renewal',
          'licenseExpiry',
          'license_expiry',
          'contractExpiry',
          'contract_expiry',
          'contractEndDate',
          'contract_end_date',
          'dueDate',
          'due_date',
          'endDate',
          'end_date',
          'simExpiry',
          'sim_expiry',
          'deviceExpiry',
          'device_expiry',
          'deviceExpiration',
          'device_expiration',
          'rechargeExpiry',
          'recharge_expiry',
          'rechargeDate',
          'recharge_date',
        ];
        final Map<String, dynamic> sub =
            asMap(json, <String>['subscription', 'sub', 'contract', 'renewal', 'plan']);
        return asDate(json, expKeys) ??
            asDate(jsonAttrs, expKeys) ??
            asDate(sub, expKeys) ??
            asDate(device, expKeys) ??
            asDate(deviceAttrs, expKeys) ??
            asDate(src, expKeys) ??
            asDate(srcAttrs, expKeys);
      }(),
      speedLimit: asDoubleOrNull(jsonAttrs, <String>[
        'speedLimit',
        'maxSpeed',
        'overspeedLimit',
        'overSpeedLimit',
        'speedThreshold',
      ]) ?? asDoubleOrNull(json, <String>[
        'speedLimit',
        'maxSpeed',
        'overspeedLimit',
        'overSpeedLimit',
        'speedThreshold',
      ]),
      overspeedDurationAlert: asDoubleOrNull(jsonAttrs, <String>[
        'overspeedDurationAlert',
      ]) ?? asDoubleOrNull(json, <String>[
        'overspeedDurationAlert',
      ]),
      idleDurationAlert: asDoubleOrNull(jsonAttrs, <String>[
        'idleDurationAlert',
      ]) ?? asDoubleOrNull(json, <String>[
        'idleDurationAlert',
      ]),
      todayDistanceKm: () {
        const List<String> keys = <String>['todayDistance', 'distanceToday', 'dayDistance', 'today_distance', 'today_km', 'distance_today'];
        double? val = asDoubleOrNull(src, keys) ??
            asDoubleOrNull(srcAttrs, keys) ??
            asDoubleOrNull(json, keys) ??
            asDoubleOrNull(jsonAttrs, keys) ??
            asDoubleOrNull(device, keys) ??
            asDoubleOrNull(deviceAttrs, keys);
        // Traccar often reports distances in meters. If today's distance is e.g. 5000 (which is 5km),
        // we might want to convert. But if it's huge, definitely divide.
        // Usually, if it's > 500, it's likely meters. 500km in a day is rare but possible, 500m is common.
        if (val != null && val > 10000) {
          val = val / 1000.0;
        }
        return val;
      }(),
      isActive: asBool(json, <String>['isActive', 'active', 'enabled'],
          fallback: true),
      rawStatus: parsedStatus,
      raw: json,
    );
  }

  /// Merges a partial `fleet:update` frame onto the existing vehicle.
  /// Socket frames often carry only lat/lng/speed — everything else is kept.
  Vehicle mergeLive(Map<String, dynamic> frame) {
    final Vehicle incoming = Vehicle.fromJson(<String, dynamic>{
      '_id': id,
      'name': name,
      ...frame,
    });

    final bool hasExplicitSpeed = frame.containsKey('speed') ||
        frame.containsKey('currentSpeed') ||
        frame.containsKey('spd') ||
        (frame['attributes'] is Map &&
            ((frame['attributes'] as Map).containsKey('speed') ||
                (frame['attributes'] as Map).containsKey('spd')));

    final bool hasExplicitIgnition = frame.containsKey('ignition') ||
        frame.containsKey('ign') ||
        frame.containsKey('acc') ||
        frame.containsKey('engineOn') ||
        (frame['attributes'] is Map &&
            ((frame['attributes'] as Map).containsKey('ignition') ||
                (frame['attributes'] as Map).containsKey('acc') ||
                (frame['attributes'] as Map).containsKey('ign')));

    final bool hasExplicitMotion = frame.containsKey('motion') ||
        frame.containsKey('isMoving') ||
        frame.containsKey('moving') ||
        frame.containsKey('running') ||
        frame.containsKey('isRunning') ||
        (frame['attributes'] is Map &&
            ((frame['attributes'] as Map).containsKey('motion') ||
                (frame['attributes'] as Map).containsKey('moving')));

    bool acceptLocation = true;

    if (frame['attributes'] is Map) {
      final Map<String, dynamic> attrs = Map<String, dynamic>.from(frame['attributes'] as Map);
      if (attrs['valid'] == false || attrs['outdated'] == true) {
        acceptLocation = false;
      }
      
      final num? accuracy = asDoubleOrNull(attrs, <String>['accuracy', 'hdop']);
      if (accuracy != null && accuracy > 100) {
        acceptLocation = false;
      }
    }

    if (incoming.satellites != null && incoming.satellites! < 3 && incoming.satellites! > 0) {
      acceptLocation = false;
    }

    // Guard against coordinates outside India bounding box (6-38°N, 65-100°E) or 0,0
    if (incoming.latitude != null && incoming.longitude != null) {
      final double inLat = incoming.latitude!;
      final double inLng = incoming.longitude!;
      if (inLat == 0 && inLng == 0) {
        acceptLocation = false;
      } else if (inLat < 6.0 || inLat > 38.0 || inLng < 65.0 || inLng > 100.0) {
        acceptLocation = false;
      }
    }

    double? nextOdometer = incoming.odometer;
    double? nextTodayDistanceKm = incoming.todayDistanceKm;

    if (acceptLocation && latitude != null && longitude != null && incoming.latitude != null && incoming.longitude != null && lastPacketAt != null) {
      final double lat1 = latitude! * math.pi / 180;
      final double lon1 = longitude! * math.pi / 180;
      final double lat2 = incoming.latitude! * math.pi / 180;
      final double lon2 = incoming.longitude! * math.pi / 180;

      final double dLat = lat2 - lat1;
      final double dLon = lon2 - lon1;

      final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
      final double c = 2 * math.asin(math.sqrt(a));
      final double distanceMeters = 6371000 * c;

      final DateTime newPacketTime = incoming.lastPacketAt ?? DateTime.now();
      final double timeDiffSecs = newPacketTime.difference(lastPacketAt!).inMilliseconds.toDouble() / 1000.0;

      // ── MONOTONIC TIMESTAMP GUARD ─────────────────────────────────
      // If the incoming packet's deviceTime is OLDER than our current lastPacketAt
      // (by more than a 2-second clock jitter tolerance), reject the location.
      // This prevents out-of-order / buffered GPS packets from moving the marker
      // BACKWARD along the road, which is the root cause of the trail dragging line.
      // Without this, a delayed packet from 30s ago at 200m behind passes the
      // 220 km/h teleport guard (200m/30s = 24 km/h) and moves the pin backward.
      if (timeDiffSecs < -2.0) {
        acceptLocation = false;
      }

      // ── GPS DRIFT FILTER ──
      // If vehicle is stationary (speed <= 2 and not moving and ignition off),
      // ignore jitter movements < 12 meters so the parked pin stays locked in place!
      final bool isMovingPacket = (hasExplicitSpeed ? incoming.speed > 3 : (incoming.speed != 0 ? incoming.speed > 3 : speed > 3)) ||
          (hasExplicitMotion && incoming.isMoving) ||
          (hasExplicitIgnition && incoming.ignition);

      if (!isMovingPacket && distanceMeters < 12.0) {
        // Stationary jitter — keep locked to previous coordinates to prevent visual drift
        acceptLocation = false;
      } else if (acceptLocation && timeDiffSecs.abs() > 1.0) {
        // Teleport jump filter: commercial vehicles cannot exceed 220 km/h over > 150m
        final double speedKmph = (distanceMeters / timeDiffSecs.abs()) * 3.6;
        if (speedKmph > 220 && distanceMeters > 150) {
          acceptLocation = false;
        }
      } else if (distanceMeters > 500) {
        // Sub-second jump > 500m is an impossible teleport
        acceptLocation = false;
      }

      if (acceptLocation && distanceMeters > 0 && incoming.odometer == null) {
        final double currentSpeed = hasExplicitSpeed ? incoming.speed : (incoming.speed != 0 ? incoming.speed : speed);
        if (currentSpeed > 2.0) {
          final double distKm = distanceMeters / 1000.0;
          if (odometer != null) {
            nextOdometer = odometer! + distKm;
          }
          if (todayDistanceKm != null && incoming.todayDistanceKm == null) {
            nextTodayDistanceKm = todayDistanceKm! + distKm;
          }
        }
      }
    }

    final bool hasExplicitOnline = frame.containsKey('is_online') ||
        frame.containsKey('isOnline') ||
        frame.containsKey('online');

    final bool nextIsOnline = hasExplicitOnline
        ? incoming.isOnline
        : isOnline;

    final double effectiveSpeed = hasExplicitSpeed ? incoming.speed : (incoming.speed != 0 ? incoming.speed : speed);

    final Vehicle mergedDraft = copyWith(
      latitude: acceptLocation ? (incoming.latitude ?? latitude) : latitude,
      longitude: acceptLocation ? (incoming.longitude ?? longitude) : longitude,
      speed: effectiveSpeed,
      heading: incoming.heading != 0 ? incoming.heading : heading,
      ignition: effectiveSpeed > 2.0 ? true : (hasExplicitIgnition ? incoming.ignition : ignition),
      isMoving: hasExplicitMotion ? incoming.isMoving : isMoving,
      isOnline: nextIsOnline,
      odometer: nextOdometer ?? odometer,
      fuelLevel: (incoming.fuelLevel != null &&
              incoming.fuelLevel! >= 0 &&
              incoming.fuelLevel! <= 400)
          ? incoming.fuelLevel
          : fuelLevel,
      batteryLevel: incoming.batteryLevel ?? batteryLevel,
      gsmSignal: incoming.gsmSignal ?? gsmSignal,
      satellites: incoming.satellites ?? satellites,
      address: incoming.address ?? address,
      lastPacketAt: incoming.lastPacketAt ?? (hasExplicitSpeed || hasExplicitMotion || incoming.latitude != null ? DateTime.now() : lastPacketAt),
      todayDistanceKm: nextTodayDistanceKm ?? todayDistanceKm,
      expiryDate: incoming.expiryDate ?? expiryDate,
      rawStatus: incoming.rawStatus ?? rawStatus,
      raw: <String, dynamic>{...raw, ...frame},
    );

    final VehicleStatus oldStatus = status;
    final VehicleStatus newStatus = mergedDraft.status;

    // ── STATUS-CHANGE GUARD ───────────────────────────────────────────────
    // If the server sent an authoritative statusSince timestamp (via the
    // backend fix), prefer it unconditionally. This is always accurate.
    //
    // If no server timestamp is available, we compute the transition locally.
    // IMPORTANT: Speed often oscillates around the 2 km/h threshold (e.g.
    // a vehicle does 1.8 → 2.1 → 1.9 → 2.3 km/h in a 30-second window).
    // Without a guard, every oscillation would reset statusChangedAt to now(),
    // showing "Moving Since (0s)" on every packet.
    //
    // Hysteresis dead-band:
    //   - Already MOVING → only stop being moving below 1.0 km/h  (not at 2.0)
    //   - Already STOPPED/IDLE → only start moving above 3.0 km/h (not at 2.0)
    // This prevents micro-transitions while preserving correct macroscopic state.
    DateTime? finalStatusChangedAt;
    if (incoming.statusChangedAt != null) {
      // Server supplied an authoritative timestamp — use it when status matches
      if (oldStatus != newStatus) {
        // Genuine transition: use the server's since-timestamp
        finalStatusChangedAt = incoming.statusChangedAt;
      } else {
        // Same status: preserve the earlier timestamp (don't move it forward)
        final DateTime? serverTs = incoming.statusChangedAt;
        if (statusChangedAt == null) {
          finalStatusChangedAt = serverTs;
        } else if (serverTs != null && serverTs.isBefore(statusChangedAt!)) {
          // Prefer the earlier (older) timestamp — it's the real start of the state
          finalStatusChangedAt = serverTs;
        } else {
          finalStatusChangedAt = statusChangedAt;
        }
      }
    } else if (oldStatus != newStatus) {
      // No server timestamp — genuine transition detected locally.
      // Apply hysteresis: only commit the transition when speed has crossed
      // clearly past the boundary, not just oscillating around it.
      final double currentSpd = mergedDraft.speed;
      bool committedTransition = true;

      if (oldStatus == VehicleStatus.moving && newStatus != VehicleStatus.moving) {
        // Was moving → now not moving: only commit if speed < 1.0 km/h
        if (currentSpd >= 1.0) committedTransition = false;
      } else if (oldStatus != VehicleStatus.moving && newStatus == VehicleStatus.moving) {
        // Was stopped/idle → now moving: only commit if speed > 3.0 km/h
        if (currentSpd <= 3.0) committedTransition = false;
      }

      if (committedTransition) {
        finalStatusChangedAt = DateTime.now();
      } else {
        // Oscillation — treat as same status, preserve existing timestamp
        finalStatusChangedAt = statusChangedAt;
      }
    } else {
      // Same status: preserve the existing timestamp always
      finalStatusChangedAt = statusChangedAt;
    }

    return mergedDraft.copyWith(statusChangedAt: finalStatusChangedAt);
  }

  Vehicle copyWith({
    String? name,
    String? registrationNumber,
    String? driverName,
    String? driverPhone,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    bool? ignition,
    bool? isMoving,
    double? odometer,
    double? fuelLevel,
    double? batteryLevel,
    int? gsmSignal,
    int? satellites,
    String? address,
    DateTime? lastPacketAt,
    DateTime? statusChangedAt,
    DateTime? expiryDate,
    double? speedLimit,
    double? overspeedDurationAlert,
    double? idleDurationAlert,
    double? todayDistanceKm,
    bool? isActive,
    String? rawStatus,
    Map<String, dynamic>? raw,
    bool? isImmobilized,
    bool? isAcOff,
    bool? isOnline,
  }) =>
      Vehicle(
        id: id,
        name: name ?? this.name,
        registrationNumber: registrationNumber ?? this.registrationNumber,
        imei: imei,
        deviceId: deviceId,
        orgId: orgId,
        type: type,
        driverName: driverName ?? this.driverName,
        driverPhone: driverPhone ?? this.driverPhone,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
        ignition: ignition ?? this.ignition,
        isMoving: isMoving ?? this.isMoving,
        odometer: odometer ?? this.odometer,
        fuelLevel: fuelLevel ?? this.fuelLevel,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        gsmSignal: gsmSignal ?? this.gsmSignal,
        satellites: satellites ?? this.satellites,
        address: address ?? this.address,
        lastPacketAt: lastPacketAt ?? this.lastPacketAt,
        statusChangedAt: statusChangedAt ?? this.statusChangedAt,
        expiryDate: expiryDate ?? this.expiryDate,
        speedLimit: speedLimit ?? this.speedLimit,
        overspeedDurationAlert: overspeedDurationAlert ?? this.overspeedDurationAlert,
        idleDurationAlert: idleDurationAlert ?? this.idleDurationAlert,
        todayDistanceKm: todayDistanceKm ?? this.todayDistanceKm,
        isActive: isActive ?? this.isActive,
        rawStatus: rawStatus ?? this.rawStatus,
        raw: raw ?? this.raw,
        isImmobilized: isImmobilized ?? this.isImmobilized,
        isAcOff: isAcOff ?? this.isAcOff,
        isOnline: isOnline ?? this.isOnline,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        registrationNumber,
        latitude,
        longitude,
        speed,
        heading,
        ignition,
        isMoving,
        isOnline,
        lastPacketAt,
        fuelLevel,
        batteryLevel,
        address,
        expiryDate,
        rawStatus,
        isImmobilized,
        isAcOff,
        todayDistanceKm,
        odometer,
        satellites,
        gsmSignal,
        speedLimit,
        isActive,
        type,
        driverName,
      ];
}
