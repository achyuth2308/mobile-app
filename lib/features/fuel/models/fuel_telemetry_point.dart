import 'dart:math';
import '../../../data/models/json_utils.dart';

/// A single telemetry packet used in the Fuel Analytics & Fuel Report.
class FuelTelemetryPoint {
  FuelTelemetryPoint({
    required this.timestamp,
    required this.fuel,
    required this.filteredFuel,
    double? normalizedFuel,
    required this.speed,
    required this.odo,
    required this.ignition,
    required this.latitude,
    required this.longitude,
    this.address,
    this.raw = const <String, dynamic>{},
  }) : normalizedFuel = normalizedFuel ?? filteredFuel;

  final DateTime timestamp;
  final double fuel; // in Liters (raw)
  final double filteredFuel; // smoothed Liters
  final double normalizedFuel; // settled / calibrated Liters
  final double speed; // in km/h
  final double odo; // in km
  final bool ignition;
  final double latitude;
  final double longitude;
  final String? address;
  final Map<String, dynamic> raw;

  /// The official settled/filtered value shown to the customer
  double get displayFuel {
    if (filteredFuel > 0) return filteredFuel;
    if (normalizedFuel > 0) return normalizedFuel;
    return fuel;
  }

  factory FuelTelemetryPoint.fromJson(
    Map<String, dynamic> json, {
    double? lastKnownFuel,
    double? lastKnownOdo,
  }) {
    // 1. Timestamp
    final DateTime time = asDate(json, <String>[
          'device_time',
          'deviceTime',
          'server_time',
          'serverTime',
          'timestamp',
          'time',
          'gpsTime',
          'fixTime',
          'createdAt',
        ]) ??
        DateTime.now();

    // 2. Fuel in Liters (prioritize calibrated liters over raw ADC/millivolts)
    double? rawFuel = asDoubleOrNull(json, <String>[
      'fuel_litres',
      'fuelLitres',
      'fuel_liters',
      'fuelLiters',
      'fuel_qty',
      'fuelQty',
      'current_fuel_level',
      'currentFuelLevel',
      'current_fuel',
      'currentFuel',
      'fuelLevel',
      'fuel_level',
      'litres',
      'liters',
      'fuel',
    ]);

    // Check nested attributes if fuel is not at root
    if (rawFuel == null && json['attributes'] is Map) {
      final Map<String, dynamic> attrs =
          Map<String, dynamic>.from(json['attributes'] as Map);
      rawFuel = asDoubleOrNull(attrs, <String>[
        'fuel_litres',
        'fuelLitres',
        'fuel_liters',
        'fuelLiters',
        'fuel_qty',
        'fuelQty',
        'current_fuel_level',
        'current_fuel',
        'fuel_level',
        'fuelLevel',
        'litres',
        'fuel',
      ]);
    }

    // If rawFuel is 0.0 or null, hold lastKnownFuel to eliminate sensor dropouts/glitches
    double resolvedFuel;
    if (rawFuel != null && rawFuel > 0.0) {
      resolvedFuel = rawFuel;
    } else if (lastKnownFuel != null && lastKnownFuel > 0.0) {
      resolvedFuel = lastKnownFuel;
    } else {
      resolvedFuel = rawFuel ?? 0.0;
    }

    // If fuel reading is > 1000 (e.g. 3398), it represents deci-liters (339.8 L) or raw mV
    if (resolvedFuel > 1000 && resolvedFuel < 10000) {
      resolvedFuel = resolvedFuel / 10.0;
    }

    // 3. Speed
    final double resolvedSpeed = asDouble(json, <String>[
      'speed',
      'spd',
      'speed_kmph',
      'speedKmph',
    ]);

    // 4. Odometer
    double? rawOdo = asDoubleOrNull(json, <String>[
      'odometer',
      'odo',
      'device_odo',
      'deviceOdo',
      'totalDistance',
      'total_distance',
      'distance',
    ]);
    if (rawOdo == null && json['attributes'] is Map) {
      final Map<String, dynamic> attrs =
          Map<String, dynamic>.from(json['attributes'] as Map);
      rawOdo = asDoubleOrNull(attrs, <String>[
        'odometer',
        'totalDistance',
        'device_odo',
      ]);
    }
    // If odometer comes in meters, convert to kilometers
    if (rawOdo != null && rawOdo > 10000000) {
      rawOdo = rawOdo / 1000.0;
    }
    final double resolvedOdo = rawOdo ?? lastKnownOdo ?? 0.0;

    // 5. Ignition
    bool resolvedIgnition = asBool(json, <String>[
      'ignition',
      'ign',
      'acc',
      'engine',
    ]);
    if (!resolvedIgnition && json['attributes'] is Map) {
      final Map<String, dynamic> attrs =
          Map<String, dynamic>.from(json['attributes'] as Map);
      resolvedIgnition = asBool(attrs, <String>['ignition', 'acc']);
    }

    // 6. Coordinates & address
    final double lat = asDouble(json, <String>['latitude', 'lat', 'y']);
    final double lng = asDouble(json, <String>['longitude', 'lng', 'lon', 'x']);
    final String? addr = asStringOrNull(json, <String>[
      'address',
      'location',
      'formatted_address',
    ]);

    // 7. Filtered / Smoothed fuel directly from backend
    const List<String> filteredKeys = <String>[
      'filtered_fuel',
      'filteredFuel',
      'filter_fuel',
      'filterFuel',
      'fuel_filtered',
      'fuelFiltered',
      'smooth_fuel',
      'smoothed_fuel',
      'smoothFuel',
      'smoothedFuel',
      'fuel_smooth',
      'settled_fuel',
      'settledFuel',
      'calibrated_fuel',
      'calibratedFuel',
      'normalized_fuel',
      'normalizedFuel',
    ];

    double? backendFiltered = asDoubleOrNull(json, filteredKeys);
    if (backendFiltered == null && json['attributes'] is Map) {
      final Map<String, dynamic> attrs =
          Map<String, dynamic>.from(json['attributes'] as Map);
      backendFiltered = asDoubleOrNull(attrs, filteredKeys);
    }
    if (backendFiltered != null && backendFiltered > 1000 && backendFiltered < 10000) {
      backendFiltered = backendFiltered / 10.0;
    }

    // Normalized / Calibrated fuel
    double? normVal = asDoubleOrNull(json, <String>[
      'normalized_fuel',
      'normalizedFuel',
      'normalize',
      'normalized',
      'fuel_normalized',
      'fuelNormalized',
      'calibrated_fuel',
      'calibratedFuel',
    ]);
    if (normVal == null && json['attributes'] is Map) {
      final Map<String, dynamic> attrs =
          Map<String, dynamic>.from(json['attributes'] as Map);
      normVal = asDoubleOrNull(attrs, <String>[
        'normalized_fuel',
        'normalizedFuel',
        'normalize',
        'normalized',
        'fuel_normalized',
      ]);
    }
    if (normVal != null && normVal > 1000 && normVal < 10000) {
      normVal = normVal / 10.0;
    }

    final double resolvedFiltered = (backendFiltered != null && backendFiltered > 0.0)
        ? backendFiltered
        : ((normVal != null && normVal > 0.0) ? normVal : resolvedFuel);
    final double resolvedNormalized = (normVal != null && normVal > 0.0)
        ? normVal
        : resolvedFiltered;

    return FuelTelemetryPoint(
      timestamp: time,
      fuel: resolvedFuel,
      filteredFuel: resolvedFiltered,
      normalizedFuel: resolvedNormalized,
      speed: max(0.0, resolvedSpeed),
      odo: resolvedOdo,
      ignition: resolvedIgnition,
      latitude: lat,
      longitude: lng,
      address: addr,
      raw: json,
    );
  }

  FuelTelemetryPoint copyWith({
    DateTime? timestamp,
    double? fuel,
    double? filteredFuel,
    double? normalizedFuel,
    double? speed,
    double? odo,
    bool? ignition,
    double? latitude,
    double? longitude,
    String? address,
    Map<String, dynamic>? raw,
  }) {
    return FuelTelemetryPoint(
      timestamp: timestamp ?? this.timestamp,
      fuel: fuel ?? this.fuel,
      filteredFuel: filteredFuel ?? this.filteredFuel,
      normalizedFuel: normalizedFuel ?? this.normalizedFuel,
      speed: speed ?? this.speed,
      odo: odo ?? this.odo,
      ignition: ignition ?? this.ignition,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      raw: raw ?? this.raw,
    );
  }
}

/// Aggregate summary matching the Fuel Report and Web App Intelligence cards.
class FuelReportSummary {
  const FuelReportSummary({
    this.startDate,
    this.endDate,
    this.totalFuelConsumed = 0.0,
    this.tripDistance = 0.0,
    this.totalFuelFill = 0.0,
    this.theftDrain = 0.0,
    this.startFuel = 0.0,
    this.endFuel = 0.0,
    this.startOdo = 0.0,
    this.endOdo = 0.0,
    this.refuelCount = 0,
    this.drainCount = 0,
    this.kmpl,
    this.movingHours = 0.0,
    this.idleHours = 0.0,
    this.maxSpeed = 0.0,
    this.avgSpeed = 0.0,
    this.tankSize = 300.0,
    this.fuelPercent = 0.0,
    this.currentStatus = 'OFF',
    this.currentSpeed = 0.0,
    this.vehicleGroup = 'All Groups',
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final double totalFuelConsumed;
  final double tripDistance;
  final double totalFuelFill;
  final double theftDrain;
  final double startFuel;
  final double endFuel;
  final double startOdo;
  final double endOdo;
  final int refuelCount;
  final int drainCount;
  final double? kmpl;
  final double movingHours;
  final double idleHours;
  final double maxSpeed;
  final double avgSpeed;
  final double tankSize;
  final double fuelPercent;
  final String currentStatus;
  final double currentSpeed;
  final String vehicleGroup;

  double get mileageKmpl =>
      kmpl ??
      ((totalFuelConsumed > 0 && tripDistance > 0)
          ? (tripDistance / totalFuelConsumed)
          : 0.0);

  factory FuelReportSummary.calculateFromPoints(
    List<FuelTelemetryPoint> points, {
    DateTime? startDate,
    DateTime? endDate,
    double? backendStartFuel,
    double? backendEndFuel,
    double? backendConsumed,
    double? backendFill,
    double? backendTheft,
    double? backendDistance,
    double? backendKmpl,
    double movingHours = 0.0,
    double idleHours = 0.0,
    double maxSpeed = 0.0,
    double avgSpeed = 0.0,
    double tankSize = 300.0,
    String currentStatus = 'OFF',
    double currentSpeed = 0.0,
    String vehicleGroup = 'All Groups',
  }) {
    if (points.isEmpty) {
      return FuelReportSummary(
        startDate: startDate,
        endDate: endDate,
        totalFuelConsumed: backendConsumed ?? 0.0,
        totalFuelFill: backendFill ?? 0.0,
        theftDrain: backendTheft ?? 0.0,
        tripDistance: backendDistance ?? 0.0,
        startFuel: backendStartFuel ?? 0.0,
        endFuel: backendEndFuel ?? 0.0,
        kmpl: backendKmpl,
        drainCount: (backendTheft != null && backendTheft > 0) ? 1 : 0,
        refuelCount: (backendFill != null && backendFill > 0) ? 1 : 0,
        movingHours: movingHours,
        idleHours: idleHours,
        maxSpeed: maxSpeed,
        avgSpeed: avgSpeed,
        tankSize: tankSize,
        currentStatus: currentStatus,
        currentSpeed: currentSpeed,
        vehicleGroup: vehicleGroup,
      );
    }

    final FuelTelemetryPoint firstPoint = points.first;
    final FuelTelemetryPoint lastPoint = points.last;

    final double sFuel = backendStartFuel ?? firstPoint.displayFuel;
    final double eFuel = backendEndFuel ?? lastPoint.displayFuel;
    final double sOdo = firstPoint.odo;
    final double eOdo = lastPoint.odo;

    // Strict Backend Source of Truth: Never fabricate theft or refills client-side
    final double calculatedFill = backendFill ?? 0.0;
    final double calculatedTheft = backendTheft ?? 0.0;
    final double dist = backendDistance ??
        (eOdo >= sOdo && sOdo > 0 ? (eOdo - sOdo) : 0.0);

    // If backend gave consumption, use it directly (e.g. 7.2 L). Otherwise fallback to start - end
    final double consumed = backendConsumed ??
        max(0.0, (sFuel > eFuel ? (sFuel - eFuel + calculatedFill - calculatedTheft) : 0.0));

    final double pct = tankSize > 0
        ? ((eFuel / tankSize) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    return FuelReportSummary(
      startDate: startDate ?? firstPoint.timestamp,
      endDate: endDate ?? lastPoint.timestamp,
      totalFuelConsumed: consumed,
      tripDistance: dist,
      totalFuelFill: calculatedFill,
      theftDrain: calculatedTheft,
      startFuel: sFuel,
      endFuel: eFuel,
      startOdo: sOdo,
      endOdo: eOdo,
      refuelCount: (calculatedFill > 0) ? 1 : 0,
      drainCount: (calculatedTheft > 0) ? 1 : 0,
      kmpl: backendKmpl,
      movingHours: movingHours,
      idleHours: idleHours,
      maxSpeed: maxSpeed,
      avgSpeed: avgSpeed,
      tankSize: tankSize,
      fuelPercent: pct,
      currentStatus: currentStatus,
      currentSpeed: currentSpeed,
      vehicleGroup: vehicleGroup,
    );
  }
}
