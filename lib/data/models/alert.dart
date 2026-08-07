import 'package:equatable/equatable.dart';

import 'json_utils.dart';

enum AlertSeverity { critical, warning, info }

class FleetAlert extends Equatable {
  const FleetAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.vehicleId,
    this.vehicleName,
    this.latitude,
    this.longitude,
    this.address,
    this.speed,
    this.createdAt,
    this.isRead = false,
  });

  final String id;

  /// overspeed | geofence_enter | geofence_exit | ignition_on | ignition_off |
  /// sos | power_cut | low_battery | harsh_braking | idle | tow …
  final String type;
  final String title;
  final String message;
  final String? vehicleId;
  final String? vehicleName;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? speed;
  final DateTime? createdAt;
  final bool isRead;

  bool get hasLocation => latitude != null && longitude != null;

  AlertSeverity get severity => switch (type.toLowerCase()) {
        'sos' ||
        'panic' ||
        'crash' ||
        'accident' ||
        'tow' ||
        'power_cut' ||
        'theft' ||
        'theft_alarm' =>
          AlertSeverity.critical,
        'overspeed' ||
        'overspeeding' ||
        'harsh_braking' ||
        'harsh_acceleration' ||
        'geofence' ||
        'geofence_enter' ||
        'geofenceenter' ||
        'geofence_exit' ||
        'geofenceexit' ||
        'low_battery' =>
          AlertSeverity.warning,
        _ => AlertSeverity.info,
      };

  factory FleetAlert.fromJson(Map<String, dynamic> json) {
    final String rawType =
        asString(json, <String>['type', 'alertType', 'alert_type', 'event', 'eventType', 'event_type'],
            fallback: 'info');
    final Map<String, dynamic> veh =
        asMap(json, <String>['vehicle', 'vehicleData']);

    return FleetAlert(
      id: asString(json, <String>['_id', 'id', 'alertId', 'alert_id']),
      type: rawType.toLowerCase(),
      title: asString(json, <String>['title', 'name', 'heading', 'alert_title', 'alertTitle'],
          fallback: _titleFor(rawType)),
      message: asString(json, <String>['message', 'description', 'body', 'text', 'alert_message', 'alertMessage', 'alertText', 'alert_text'],
          fallback: _titleFor(rawType)),
      vehicleId: asStringOrNull(json, <String>['vehicleId', 'vehicle_id']) ??
          asStringOrNull(veh, <String>['_id', 'id']),
      vehicleName:
          asStringOrNull(json, <String>['vehicleName', 'vehicle_name', 'vehicleNumber', 'regNo', 'plate']) ??
              asStringOrNull(veh, <String>['registrationNumber', 'name', 'vehicleName']),
      latitude: asDoubleOrNull(json, <String>['latitude', 'lat']),
      longitude: asDoubleOrNull(json, <String>['longitude', 'lng', 'lon']),
      address: asStringOrNull(json, <String>['address', 'location', 'place']),
      speed: asDoubleOrNull(json, <String>['speed']),
      createdAt: asDate(json,
          <String>['createdAt', 'created_at', 'timestamp', 'time', 'occurredAt', 'occurred_at', 'date', 'locTime', 'loc_time', 'deviceTime', 'device_time', 'serverTime', 'server_time']),
      isRead: asBool(json, <String>['isRead', 'is_read', 'read', 'seen']),
    );
  }

  static String _titleFor(String type) => switch (type.toLowerCase()) {
        'overspeed' || 'overspeeding' => 'Overspeeding',
        'geofence' => 'Geofence Alert',
        'geofence_enter' || 'geofenceenter' => 'Geofence Entry',
        'geofence_exit' || 'geofenceexit' => 'Geofence Exit',
        'ignition_on' => 'Ignition On',
        'ignition_off' => 'Ignition Off',
        'trip_started' || 'trip_start' || 'trip_begin' || 'start_trip' => 'Trip Started',
        'trip_ended' || 'trip_end' || 'trip_completed' => 'Trip Ended',
        'sos' || 'panic' => 'SOS Emergency',
        'power_cut' => 'Power Disconnected',
        'low_battery' => 'Low Battery',
        'harsh_braking' => 'Harsh Braking',
        'harsh_acceleration' => 'Harsh Acceleration',
        'idle' || 'excessive_idle' || 'excessive_idling' => 'Excessive Idling',
        'tow' => 'Tow Detected',
        'stoppage' => 'Long Stoppage',
        'moving' || 'start_moving' => 'Vehicle Moving',
        'stopped' => 'Vehicle Stopped',
        'parking' => 'Parking Alert',
        'theft' || 'theft_alarm' => 'Theft Alarm',
        _ => 'Fleet Alert',
      };

  FleetAlert copyWith({
    bool? isRead,
    String? vehicleId,
    String? vehicleName,
  }) => FleetAlert(
        id: id,
        type: type,
        title: title,
        message: message,
        vehicleId: vehicleId ?? this.vehicleId,
        vehicleName: vehicleName ?? this.vehicleName,
        latitude: latitude,
        longitude: longitude,
        address: address,
        speed: speed,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, type, title, message, vehicleId, createdAt, isRead];
}
