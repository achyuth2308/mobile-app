import 'package:flutter/material.dart';

/// Maps a vehicle type string from the API to an icon.
class VehicleIcons {
  const VehicleIcons._();

  static IconData forType(String type) => switch (type.toLowerCase().trim()) {
        'truck' || 'lorry' || 'hgv' || 'trailer' => Icons.local_shipping_rounded,
        'bus' || 'coach' || 'van' => Icons.directions_bus_rounded,
        'bike' || 'motorcycle' || 'scooter' || 'two-wheeler' =>
          Icons.two_wheeler_rounded,
        'tractor' || 'harvester' || 'excavator' || 'jcb' =>
          Icons.agriculture_rounded,
        'generator' || 'genset' => Icons.electrical_services_rounded,
        'ambulance' => Icons.emergency_rounded,
        'taxi' || 'cab' => Icons.local_taxi_rounded,
        'tanker' => Icons.propane_tank_rounded,
        'boat' || 'ship' => Icons.directions_boat_rounded,
        'container' => Icons.inventory_2_rounded,
        _ => Icons.directions_car_rounded,
      };

  static IconData forAlert(String type) => switch (type.toLowerCase()) {
        'overspeed' || 'overspeeding' => Icons.speed_rounded,
        'geofence' || 'geofence_enter' || 'geofenceenter' => Icons.login_rounded,
        'geofence_exit' || 'geofenceexit' => Icons.logout_rounded,
        'ignition_on' => Icons.power_settings_new_rounded,
        'ignition_off' => Icons.power_off_rounded,
        'trip_started' || 'trip_start' || 'trip_begin' || 'start_trip' => Icons.navigation_rounded,
        'trip_ended' || 'trip_end' || 'trip_completed' => Icons.flag_rounded,
        'sos' || 'panic' => Icons.sos_rounded,
        'power_cut' => Icons.power_off_outlined,
        'low_battery' => Icons.battery_alert_rounded,
        'harsh_braking' => Icons.warning_amber_rounded,
        'harsh_acceleration' => Icons.rocket_launch_rounded,
        'idle' => Icons.hourglass_empty_rounded,
        'tow' => Icons.car_crash_rounded,
        'stoppage' => Icons.local_parking_rounded,
        'maintenance' => Icons.build_rounded,
        'moving' || 'start_moving' => Icons.moving_rounded,
        'stopped' => Icons.stop_rounded,
        'parking' => Icons.local_parking_rounded,
        'theft' || 'theft_alarm' => Icons.alarm_rounded,
        _ => Icons.notifications_active_rounded,
      };
}
