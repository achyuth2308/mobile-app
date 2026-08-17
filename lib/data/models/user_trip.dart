import 'package:equatable/equatable.dart';
import 'json_utils.dart';

/// A user-defined trip created and managed through the Trips screen.
/// Distinct from the auto-detected [Trip] class used in history playback.
class UserTrip extends Equatable {
  const UserTrip({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.status,
    this.routeId,
    this.routeName,
    this.vehicleName,
    this.plate,
    this.origin,
    this.destination,
    this.notes,
    this.startTime,
    this.endTime,
    this.distanceKm = 0.0,
    this.maxSpeed = 0,
    this.avgSpeed = 0.0,
    this.durationSecs,
    this.createdAt,
  });

  final String id;
  final String vehicleId;
  final String name;
  final String status; // planned | in_progress | completed | cancelled
  final String? routeId;
  final String? routeName;
  final String? vehicleName;
  final String? plate;
  final String? origin;
  final String? destination;
  final String? notes;
  final DateTime? startTime;
  final DateTime? endTime;
  final double distanceKm;
  final int maxSpeed;
  final double avgSpeed;
  final int? durationSecs;
  final DateTime? createdAt;

  bool get isActive    => status == 'in_progress';
  bool get isPlanned   => status == 'planned';
  bool get isCompleted => status == 'completed';

  String get durationLabel {
    final s = durationSecs ?? 0;
    if (s == 0) return '–';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';

  factory UserTrip.fromJson(Map<String, dynamic> json) => UserTrip(
        id:           asString(json, ['id']),
        vehicleId:    asString(json, ['vehicle_id']),
        name:         asString(json, ['name'], fallback: 'Unnamed Trip'),
        status:       asString(json, ['status'], fallback: 'planned'),
        routeId:      asStringOrNull(json, ['route_id']),
        routeName:    asStringOrNull(json, ['route_name']),
        vehicleName:  asStringOrNull(json, ['vehicle_name']),
        plate:        asStringOrNull(json, ['plate']),
        origin:       asStringOrNull(json, ['origin']),
        destination:  asStringOrNull(json, ['destination']),
        notes:        asStringOrNull(json, ['notes']),
        startTime:    asDate(json, ['start_time']),
        endTime:      asDate(json, ['end_time']),
        distanceKm:   asDouble(json, ['distance_km'], fallback: 0.0),
        maxSpeed:     asInt(json, ['max_speed'], fallback: 0),
        avgSpeed:     asDouble(json, ['avg_speed'], fallback: 0.0),
        durationSecs: json['duration_secs'] is num
            ? (json['duration_secs'] as num).toInt()
            : null,
        createdAt:    asDate(json, ['created_at']),
      );

  Map<String, dynamic> toCreateJson() => <String, dynamic>{
        'vehicleId':    vehicleId,
        'name':         name,
        if (routeId != null)      'routeId':     routeId,
        if (origin != null)       'origin':      origin,
        if (destination != null)  'destination': destination,
        if (notes != null)        'notes':       notes,
      };

  @override
  List<Object?> get props => [id, status, distanceKm];
}
