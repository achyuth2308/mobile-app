import 'package:equatable/equatable.dart';

import 'json_utils.dart';

/// Every customer-facing report type, wired to its `/api/reports/*` path.
enum ReportType {
  trip,
  distance,
  activity,
  routeHistory,
  ignition,
  overspeeding,
  stoppages,
  idle,
  consolidated,
  individual,
  manualTrip,
}

extension ReportTypeX on ReportType {
  String get path => switch (this) {
        ReportType.trip => '/reports/trip',
        ReportType.distance => '/reports/distance',
        ReportType.activity => '/reports/activity',
        ReportType.routeHistory => '/reports/route-history',
        ReportType.ignition => '/reports/ignition',
        ReportType.overspeeding => '/reports/overspeeding',
        ReportType.stoppages => '/reports/stoppages',
        ReportType.idle => '/reports/stoppages',
        ReportType.consolidated => '/reports/consolidated',
        ReportType.individual => '/reports/individual',
        ReportType.manualTrip => '/trips',
      };

  String get label => switch (this) {
        ReportType.trip => 'Automated Trips',
        ReportType.distance => 'Distance Report',
        ReportType.activity => 'Activity Report',
        ReportType.routeHistory => 'Route History',
        ReportType.ignition => 'Ignition Report',
        ReportType.overspeeding => 'Overspeeding',
        ReportType.stoppages => 'Stoppage Report',
        ReportType.idle => 'Idle Report',
        ReportType.consolidated => 'Consolidated',
        ReportType.individual => 'Individual Summary',
        ReportType.manualTrip => 'Manual Trips',
      };

  String get blurb => switch (this) {
        ReportType.trip => 'Every journey with start, end, distance and duration',
        ReportType.distance => 'Distance travelled per day and per vehicle',
        ReportType.activity => 'Movement, idling and parking timeline',
        ReportType.routeHistory => 'Full GPS breadcrumb trail on a map',
        ReportType.ignition => 'Engine on and off events with locations',
        ReportType.overspeeding => 'Every breach of the configured speed limit',
        ReportType.stoppages => 'Where and how long vehicles stayed parked',
        ReportType.idle => 'Engine running while stationary — wasted fuel',
        ReportType.consolidated => 'Whole-fleet totals in a single sheet',
        ReportType.individual => 'Deep-dive summary for one vehicle',
        ReportType.manualTrip => 'Pre-planned and manually tracked trips',
      };

  /// A single vehicle must be chosen before running these.
  bool get requiresVehicle => switch (this) {
        ReportType.routeHistory || ReportType.individual => true,
        _ => false,
      };
}

/// Generic tabular report row. Reports across the platform differ wildly in
/// shape, so we normalise to ordered key/value cells plus a few well-known
/// hoisted fields the UI can style specially.
class ReportRow extends Equatable {
  const ReportRow({
    required this.cells,
    this.vehicleName,
    this.timestamp,
    this.distanceKm,
    this.durationSeconds,
    this.speed,
    this.address,
    this.latitude,
    this.longitude,
    this.raw = const <String, dynamic>{},
  });

  final Map<String, String> cells;
  final String? vehicleName;
  final DateTime? timestamp;
  final double? distanceKm;
  final int? durationSeconds;
  final double? speed;
  final String? address;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> raw;

  bool get hasLocation => latitude != null && longitude != null;

  // Safe typed accessors for specific tabular reports
  String? get vehicleId => asStringOrNull(raw, <String>['vehicle_id', 'vehicleId', 'id']);
  String? get plate => asStringOrNull(raw, <String>['plate', 'vehicleNumber', 'registrationNumber']);
  String? get orgName => asStringOrNull(raw, <String>['org_name', 'orgName', 'organization']);
  String? get driverName => asStringOrNull(raw, <String>['driver_name', 'driverName', 'driver']);
  String? get driverPhone => asStringOrNull(raw, <String>['driver_phone', 'driverPhone', 'driverMobileNumber', 'mobile']);
  String? get status => asStringOrNull(raw, <String>['status', 'state']);
  
  DateTime? get startTime => asDate(raw, <String>['start_time', 'startTime', 'device_time', 'timestamp']) ?? timestamp;
  DateTime? get endTime => asDate(raw, <String>['end_time', 'endTime']);
  DateTime? get date => asDate(raw, <String>['date', 'start_time', 'startTime']) ?? timestamp;

  double? get startLat => asDoubleOrNull(raw, <String>['start_lat', 'startLat', 'lat', 'latitude']) ?? latitude;
  double? get startLng => asDoubleOrNull(raw, <String>['start_lng', 'startLng', 'lng', 'lon', 'longitude']) ?? longitude;
  double? get endLat => asDoubleOrNull(raw, <String>['end_lat', 'endLat']);
  double? get endLng => asDoubleOrNull(raw, <String>['end_lng', 'endLng']);

  double? get startOdometer => asDoubleOrNull(raw, <String>['start_odometer', 'startOdometer']);
  double? get endOdometer => asDoubleOrNull(raw, <String>['end_odometer', 'endOdometer']);
  double? get distanceTravelled => asDoubleOrNull(raw, <String>['distance_travelled', 'distanceTravelled', 'distance', 'distanceKm']) ?? distanceKm;
  int get pointCount => asInt(raw, <String>['point_count', 'pointCount', 'pointsLogged']);

  double? get maxSpeedVal => asDoubleOrNull(raw, <String>['max_speed', 'maxSpeed', 'speed']) ?? speed;
  double? get avgSpeedVal => asDoubleOrNull(raw, <String>['avg_speed', 'avgSpeed']);
  int? get durationSecVal => asDoubleOrNull(raw, <String>['duration_seconds', 'durationSeconds', 'duration'])?.round() ?? durationSeconds;

  int? get runningSeconds => asDoubleOrNull(raw, <String>['running_seconds', 'runningSeconds', 'runningTime'])?.round();
  int? get idleSeconds => asDoubleOrNull(raw, <String>['idle_seconds', 'idleSeconds', 'idleTime'])?.round();
  int? get stoppedSeconds => asDoubleOrNull(raw, <String>['stopped_seconds', 'stoppedSeconds', 'stoppedTime'])?.round();

  int get runningMins => runningSeconds != null ? (runningSeconds! / 60).floor() : 0;
  int get idleMins => idleSeconds != null ? (idleSeconds! / 60).floor() : 0;
  int get stoppedMins => stoppedSeconds != null ? (stoppedSeconds! / 60).floor() : 0;

  int get tripCount => asInt(raw, <String>['trip_count', 'tripCount', 'trips', 'totalTrips']);
  int get stoppageCount => asInt(raw, <String>['stoppage_count', 'stoppageCount', 'stoppages', 'totalStops']);
  int get overspeedingCount => asInt(raw, <String>['overspeeding_count', 'overspeedingCount', 'overspeeding', 'overspeedCount', 'violations']);

  factory ReportRow.fromJson(Map<String, dynamic> json) {
    final Map<String, String> cells = <String, String>{};

    json.forEach((String key, dynamic value) {
      if (value == null) return;
      if (value is Map || value is List) return;
      if (<String>['_id', 'id', '__v', 'orgId', 'organizationId', 'userId']
          .contains(key)) {
        return;
      }
      cells[_humanise(key)] = _format(key, value);
    });

    return ReportRow(
      cells: cells,
      raw: Map<String, dynamic>.unmodifiable(json),
      vehicleName: asStringOrNull(json, <String>[
        'vehicle_name', 'vehicleName', 'vehicleNumber', 'registrationNumber', 'vehicle', 'name',
      ]),
      timestamp: asDate(json, <String>[
        'timestamp', 'date', 'time', 'start_time', 'startTime', 'createdAt', 'eventTime',
      ]),
      distanceKm:
          asDoubleOrNull(json, <String>['distance', 'distance_travelled', 'distanceKm', 'totalDistance']),
      durationSeconds:
          asDoubleOrNull(json, <String>['duration_seconds', 'duration', 'durationSeconds', 'totalDuration'])
              ?.round(),
      speed: asDoubleOrNull(json, <String>['speed', 'max_speed', 'maxSpeed', 'avgSpeed']),
      address: asStringOrNull(json, <String>['address', 'location', 'place', 'startAddress']),
      latitude: asDoubleOrNull(json, <String>['latitude', 'lat', 'start_lat', 'startLat']),
      longitude: asDoubleOrNull(json, <String>['longitude', 'lng', 'lon', 'start_lng', 'startLng']),
    );
  }

  static String _humanise(String key) {
    final String spaced = key
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'),
            (Match m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _format(String key, dynamic value) {
    final String k = key.toLowerCase();
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) {
      if (k.contains('distance')) return '${value.toStringAsFixed(2)} km';
      if (k.contains('speed')) return '${value.toStringAsFixed(0)} km/h';
      if (k.contains('duration') || k.contains('time') && value > 1000) {
        final int s = value.round();
        final int h = s ~/ 3600;
        final int m = (s % 3600) ~/ 60;
        return h > 0 ? '${h}h ${m}m' : '${m}m';
      }
      if (value is double) return value.toStringAsFixed(2);
      return value.toString();
    }
    final String s = value.toString();
    final DateTime? d = DateTime.tryParse(s);
    if (d != null && s.contains('-') && s.length > 9) {
      final DateTime l = d.toLocal();
      return '${l.day.toString().padLeft(2, '0')}/'
          '${l.month.toString().padLeft(2, '0')}/${l.year} '
          '${l.hour.toString().padLeft(2, '0')}:'
          '${l.minute.toString().padLeft(2, '0')}';
    }
    return s;
  }

  @override
  List<Object?> get props => <Object?>[cells, vehicleName, timestamp, raw];
}

/// Headline figures rendered as stat tiles above a report table.
class ReportSummary extends Equatable {
  const ReportSummary({
    this.totalDistanceKm = 0,
    this.totalTrips = 0,
    this.totalDurationSeconds = 0,
    this.idleSeconds = 0,
    this.stoppageCount = 0,
    this.overspeedCount = 0,
    this.maxSpeed = 0,
    this.avgSpeed = 0,
  });

  final double totalDistanceKm;
  final int totalTrips;
  final int totalDurationSeconds;
  final int idleSeconds;
  final int stoppageCount;
  final int overspeedCount;
  final double maxSpeed;
  final double avgSpeed;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
        totalDistanceKm: asDouble(
            json, <String>['totalDistance', 'distance', 'totalDistanceKm']),
        totalTrips: asInt(json, <String>['totalTrips', 'trips', 'tripCount']),
        totalDurationSeconds:
            asInt(json, <String>['totalDuration', 'duration', 'runningTime']),
        idleSeconds: asInt(json, <String>['idleDuration', 'idleTime', 'totalIdle']),
        stoppageCount: asInt(json, <String>['stoppages', 'stopCount', 'totalStops']),
        overspeedCount:
            asInt(json, <String>['overspeedCount', 'overspeeding', 'violations']),
        maxSpeed: asDouble(json, <String>['maxSpeed', 'topSpeed']),
        avgSpeed: asDouble(json, <String>['avgSpeed', 'averageSpeed']),
      );

  /// Fallback: derive totals client-side when the API returns only rows.
  factory ReportSummary.fromRows(List<ReportRow> rows) {
    double distance = 0;
    int duration = 0;
    double maxSpeed = 0;
    for (final ReportRow r in rows) {
      distance += r.distanceKm ?? 0;
      duration += r.durationSeconds ?? 0;
      if ((r.speed ?? 0) > maxSpeed) maxSpeed = r.speed ?? 0;
    }
    return ReportSummary(
      totalDistanceKm: distance,
      totalTrips: rows.length,
      totalDurationSeconds: duration,
      maxSpeed: maxSpeed,
      avgSpeed: duration > 0 ? distance / (duration / 3600) : 0,
    );
  }

  bool get isEmpty =>
      totalDistanceKm == 0 && totalTrips == 0 && totalDurationSeconds == 0;

  @override
  List<Object?> get props =>
      <Object?>[totalDistanceKm, totalTrips, totalDurationSeconds, maxSpeed];
}

class ReportResult extends Equatable {
  const ReportResult({
    required this.rows,
    required this.summary,
    this.columns = const <String>[],
  });

  final List<ReportRow> rows;
  final ReportSummary summary;
  final List<String> columns;

  bool get isEmpty => rows.isEmpty;

  factory ReportResult.parse(dynamic payload) {
    List<Map<String, dynamic>> raw = <Map<String, dynamic>>[];
    ReportSummary summary = const ReportSummary();

    if (payload is Map<String, dynamic>) {
      final dynamic dataObj = payload['data'] ??
          payload['rows'] ??
          payload['results'] ??
          payload['records'] ??
          payload['trips'] ??
          payload['items'] ??
          payload;

      if (dataObj is List) {
        raw = asMapList(dataObj);
      } else if (dataObj is Map<String, dynamic>) {
        // Check for Individual report payload with nested vehicle, activity, summary
        if (dataObj.containsKey('vehicle') ||
            dataObj.containsKey('activity') ||
            dataObj.containsKey('summary')) {
          final Map<String, dynamic> v = asMap(dataObj, <String>['vehicle']);
          final Map<String, dynamic> a = asMap(dataObj, <String>['activity']);
          final Map<String, dynamic> s = asMap(dataObj, <String>['summary']);
          final dynamic trips = dataObj['trips'];
          final dynamic stoppages = dataObj['stoppages'];
          final dynamic overspeeding = dataObj['overspeeding'];

          final Map<String, dynamic> singleRow = <String, dynamic>{
            'vehicle_name': v['name'] ?? v['registrationNumber'] ?? '-',
            'plate': v['plate'] ?? v['registrationNumber'] ?? '-',
            'distance_travelled': a['distance_travelled'] ?? a['distance'] ?? 0,
            'running_seconds': a['running_seconds'] ?? 0,
            'idle_seconds': a['idle_seconds'] ?? 0,
            'stopped_seconds': a['stopped_seconds'] ?? 0,
            'trip_count': s['trip_count'] ?? (trips is List ? trips.length : 0),
            'stoppage_count': s['stoppage_count'] ?? (stoppages is List ? stoppages.length : 0),
            'overspeeding_count': s['overspeeding_count'] ?? (overspeeding is List ? overspeeding.length : 0),
          };
          raw = <Map<String, dynamic>>[singleRow];
        } else {
          raw = asMapList(dataObj);
        }
      } else {
        raw = asMapList(payload);
      }

      final Map<String, dynamic> s =
          asMap(payload, <String>['summary', 'totals', 'aggregate', 'stats']);
      summary = s.isNotEmpty ? ReportSummary.fromJson(s) : ReportSummary.fromJson(payload);
    } else if (payload is List) {
      raw = asMapList(payload);
    }

    final List<ReportRow> rows =
        raw.map(ReportRow.fromJson).toList(growable: false);

    if (summary.isEmpty && rows.isNotEmpty) {
      summary = ReportSummary.fromRows(rows);
    }

    final List<String> columns =
        rows.isEmpty ? <String>[] : rows.first.cells.keys.toList();

    return ReportResult(rows: rows, summary: summary, columns: columns);
  }

  @override
  List<Object?> get props => <Object?>[rows, summary];
}
