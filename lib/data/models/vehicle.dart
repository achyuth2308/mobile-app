import 'package:equatable/equatable.dart';

import '../../core/config/app_config.dart';
import 'json_utils.dart';

/// Derived operational state. Computed client-side from telemetry so the
/// list, map and detail screens never disagree about what a vehicle is doing.
enum VehicleStatus { moving, idle, stopped, offline }

extension VehicleStatusX on VehicleStatus {
  String get key => name;

  String get label => switch (this) {
        VehicleStatus.moving => 'Running',
        VehicleStatus.idle => 'Idle',
        VehicleStatus.stopped => 'Parking',
        VehicleStatus.offline => 'Offline',
      };

  String get description => switch (this) {
        VehicleStatus.moving => 'Ignition on and in motion',
        VehicleStatus.idle => 'Ignition on, not moving',
        VehicleStatus.stopped => 'Parked, ignition off',
        VehicleStatus.offline => 'No recent data received',
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
    this.expiryDate,
    this.speedLimit,
    this.todayDistanceKm,
    this.isActive = true,
    this.rawStatus,
    this.isImmobilized = false,
  });

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

  // ── Commercial ───────────────────────────────────────────────────
  final DateTime? expiryDate;
  final double? speedLimit;
  final double? todayDistanceKm;
  final bool isActive;

  /// Whatever the server called it, kept for debugging/telemetry parity.
  final String? rawStatus;

  /// Whether the engine is currently cut via relay command.
  final bool isImmobilized;

  /// Infers the correct type for images based on common vehicle names if the backend defaults to 'car'.
  String get displayType {
    final String lowerName = name.toLowerCase();
    if (type == 'car' || type.isEmpty) {
      if (lowerName.contains('activa') || lowerName.contains('scoot') || lowerName.contains('bike') || lowerName.contains('motor')) {
        return 'bike';
      }
      if (lowerName.contains('truck') || lowerName.contains('lorry') || lowerName.contains('eicher')) {
        return 'truck';
      }
      if (lowerName.contains('tipper')) {
        return 'tipper';
      }
      if (lowerName.contains('bus')) {
        return 'bus';
      }
    }
    // Map backend types to our available assets if needed
    if (type == 'scooter' || type == 'motorcycle' || type == 'scooty') return 'bike';
    return type;
  }

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0 && longitude == 0);

  Duration? get sinceLastPacket =>
      lastPacketAt == null ? null : DateTime.now().difference(lastPacketAt!);

  /// Single source of truth for status across the app.
  VehicleStatus get status {
    // If the server explicitly provided a status, trust it so the mobile app
    // stays in perfect sync with the web dashboard.
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

    final Duration? age = sinceLastPacket;
    if (age == null || age > AppConfig.offlineThreshold) {
      return VehicleStatus.offline;
    }

    // 1. If vehicle is in motion (speed > 2 km/h or motion flag is true), it is MOVING / RUNNING.
    if (speed > 2 || isMoving) return VehicleStatus.moving;

    // 2. If stationary (speed <= 2 km/h) and ignition is ON, it is IDLE.
    if (ignition) return VehicleStatus.idle;

    // 3. Stationary and ignition OFF:
    return VehicleStatus.stopped;
  }

  bool get isOverspeeding {
    final double limit = speedLimit ?? AppConfig.overspeedDefaultKph;
    return speed > limit;
  }

  int? get daysToExpiry {
    if (expiryDate == null) return null;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime exp =
        DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
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
        lng = (c[0] as num?)?.toDouble();
        lat = (c[1] as num?)?.toDouble();
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
        asBool(deviceAttrs, ignKeys);

    final bool isMotion = asBool(src, motionKeys) ||
        asBool(json, motionKeys) ||
        asBool(srcAttrs, motionKeys) ||
        asBool(jsonAttrs, motionKeys) ||
        asBool(device, motionKeys) ||
        asBool(deviceAttrs, motionKeys);

    final bool isImmobilized = asBool(srcAttrs, <String>['blocked', 'out1', 'cut']) ||
        asBool(deviceAttrs, <String>['blocked', 'out1', 'cut']) ||
        asBool(json, <String>['blocked', 'out1', 'cut']);

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
      type: asString(json, <String>['type', 'vehicleType', 'category'],
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
        if (val != null && val > 50000) {
          val = val / 1000.0;
        }
        return val;
      }(),
      fuelLevel:
          asDoubleOrNull(src, <String>['fuel', 'fuelLevel', 'fuelPercent']) ??
              asDoubleOrNull(
                  srcAttrs, <String>['fuel', 'fuelLevel', 'fuelPercent']) ??
              asDoubleOrNull(json, <String>['fuel', 'fuelLevel']) ??
              asDoubleOrNull(jsonAttrs, <String>['fuel', 'fuelLevel']),
      batteryLevel:
          asDoubleOrNull(src, <String>['battery', 'current_voltage', 'device_battery', 'power', 'batteryLevel', 'bat', 'vehicle_battery', 'vehicleBattery', 'battery_voltage', 'batteryVoltage', 'voltage', 'vehicle_voltage', 'external_voltage', 'main_voltage', 'ext_power', 'main_power', 'external_battery', 'ext_batt', 'car_battery', 'vbatt']) ??
              asDoubleOrNull(
                  srcAttrs, <String>['battery', 'current_voltage', 'device_battery', 'power', 'batteryLevel', 'bat', 'vehicle_battery', 'vehicleBattery', 'battery_voltage', 'batteryVoltage', 'voltage', 'vehicle_voltage', 'external_voltage', 'main_voltage', 'ext_power', 'main_power', 'external_battery', 'ext_batt', 'car_battery', 'vbatt']) ??
              asDoubleOrNull(json, <String>['battery', 'current_voltage', 'device_battery', 'power', 'batteryLevel', 'bat', 'vehicle_battery', 'vehicleBattery', 'battery_voltage', 'batteryVoltage', 'voltage', 'vehicle_voltage', 'external_voltage', 'main_voltage', 'ext_power', 'main_power', 'external_battery', 'ext_batt', 'car_battery', 'vbatt']) ??
              asDoubleOrNull(jsonAttrs, <String>['battery', 'current_voltage', 'device_battery', 'power', 'batteryLevel', 'bat', 'vehicle_battery', 'vehicleBattery', 'battery_voltage', 'batteryVoltage', 'voltage', 'vehicle_voltage', 'external_voltage', 'main_voltage', 'ext_power', 'main_power', 'external_battery', 'ext_batt', 'car_battery', 'vbatt']),
      gsmSignal: asDoubleOrNull(src, <String>['gsm', 'gsmSignal', 'signal'])
              ?.round() ??
          asDoubleOrNull(srcAttrs, <String>['gsm', 'gsmSignal', 'signal'])
              ?.round(),
      satellites:
          asDoubleOrNull(src, <String>['satellites', 'sats', 'gpsSatellites'])
                  ?.round() ??
              asDoubleOrNull(
                      srcAttrs, <String>['satellites', 'sats', 'gpsSatellites'])
                  ?.round(),
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
      expiryDate: asDate(json, <String>[
        'expiryDate',
        'expiresAt',
        'licenseExpiry',
        'validTill',
        'subscriptionExpiry',
        'renewalDate',
      ]),
      speedLimit: asDoubleOrNull(json, <String>[
        'speedLimit',
        'maxSpeed',
        'overspeedLimit',
        'speedThreshold',
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
        if (val != null && val > 2000) {
          val = val / 1000.0;
        }
        return val;
      }(),
      isActive: asBool(json, <String>['isActive', 'active', 'enabled'],
          fallback: true),
      rawStatus: parsedStatus,
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

    return copyWith(
      latitude: incoming.latitude ?? latitude,
      longitude: incoming.longitude ?? longitude,
      speed: hasExplicitSpeed ? incoming.speed : (incoming.speed != 0 ? incoming.speed : speed),
      heading: incoming.heading != 0 ? incoming.heading : heading,
      ignition: hasExplicitIgnition ? incoming.ignition : ignition,
      isMoving: hasExplicitMotion ? incoming.isMoving : isMoving,
      odometer: incoming.odometer ?? odometer,
      fuelLevel: incoming.fuelLevel ?? fuelLevel,
      batteryLevel: incoming.batteryLevel ?? batteryLevel,
      gsmSignal: incoming.gsmSignal ?? gsmSignal,
      satellites: incoming.satellites ?? satellites,
      address: incoming.address ?? address,
      lastPacketAt: incoming.lastPacketAt ?? DateTime.now(),
      todayDistanceKm: incoming.todayDistanceKm ?? todayDistanceKm,
      rawStatus: incoming.rawStatus ?? rawStatus,
    );
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
    DateTime? expiryDate,
    double? speedLimit,
    double? todayDistanceKm,
    bool? isActive,
    String? rawStatus,
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
        expiryDate: expiryDate ?? this.expiryDate,
        speedLimit: speedLimit ?? this.speedLimit,
        todayDistanceKm: todayDistanceKm ?? this.todayDistanceKm,
        isActive: isActive ?? this.isActive,
        rawStatus: rawStatus ?? this.rawStatus,
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
        lastPacketAt,
        fuelLevel,
        batteryLevel,
        address,
        expiryDate,
      ];
}
