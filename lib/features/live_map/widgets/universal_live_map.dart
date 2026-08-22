import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/report_models.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import 'animated_vehicle_marker.dart';
import 'map_tiles.dart';
import 'vehicle_marker.dart';

class UniversalLiveMap extends StatelessWidget {
  const UniversalLiveMap({
    super.key,
    required this.mapController,
    required this.vehicles,
    required this.style,
    required this.fallbackCenter,
    required this.selectedId,
    required this.followingId,
    required this.onMapReady,
    required this.onUserInteracting,
    required this.onTapMap,
    required this.onSelectVehicle,
    this.pendingFocusId,
    this.route = const [],
    this.stoppages = const [],
    this.onTapStoppage,
  });

  final MapController mapController;
  final List<Vehicle> vehicles;
  final MapStyle style;
  final LatLng fallbackCenter;
  final String? selectedId;
  final String? followingId;
  final String? pendingFocusId;
  final VoidCallback onMapReady;
  final ValueChanged<bool> onUserInteracting;
  final VoidCallback onTapMap;
  final ValueChanged<Vehicle> onSelectVehicle;
  final List<TrackPoint> route;
  final List<ReportRow> stoppages;
  final void Function(ReportRow, int)? onTapStoppage;

  List<Marker> _buildMarkers() {
    return vehicles
        .where((Vehicle v) => v.hasLocation)
        .map(
          (Vehicle v) => Marker(
            key: ValueKey<String>(v.id),
            point: LatLng(v.latitude!, v.longitude!),
            width: 120,
            height: 120,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => onSelectVehicle(v),
              child: AnimatedVehicleMarker(
                key: ValueKey<String>('anim_${v.id}'),
                point: LatLng(v.latitude!, v.longitude!),
                heading: v.heading ?? 0.0,
                status: v.status,
                speed: v.speed ?? 0.0,
                builder: (BuildContext context, double animatedHeading) => VehicleMarkerPin(
                  vehicle: v,
                  selected: v.id == selectedId,
                  showLabel: false,
                  useSprite: true,
                  headingOverride: animatedHeading,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Marker> markers = _buildMarkers();
    
    final String? activeId = selectedId ?? followingId;
    final Vehicle? activeVehicle = activeId != null
        ? vehicles.cast<Vehicle?>().firstWhere((v) => v?.id == activeId, orElse: () => null)
        : null;

    final List<LatLng> polylinePoints = route
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) => LatLng(p.latitude!, p.longitude!))
        .toList();

    // Connect the historical trail to the vehicle's current live location
    if (activeVehicle != null && activeVehicle.hasLocation && polylinePoints.isNotEmpty) {
      polylinePoints.add(LatLng(activeVehicle.latitude!, activeVehicle.longitude!));
    }

    return Stack(
      children: <Widget>[
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: fallbackCenter,
              initialZoom: 10.5,
              minZoom: 2,
              maxZoom: style.maxZoom,
              backgroundColor: theme.colorScheme.surface,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: onMapReady,
              onPointerDown: (_, __) => onUserInteracting(true),
              onPointerUp: (_, __) => onUserInteracting(false),
              onTap: (_, __) => onTapMap(),
            ),
            children: <Widget>[
              buildTileLayer(style),
              if (route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      color: Colors.blue.withOpacity(0.8),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              if (stoppages.isNotEmpty)
                MarkerLayer(
                  markers: List.generate(stoppages.length, (index) {
                    final stop = stoppages[index];
                    final lat = stop.startLat ?? stop.endLat;
                    final lng = stop.startLng ?? stop.endLng;
                    if (lat == null || lng == null) return null;
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () {
                          if (onTapStoppage != null) {
                            onTapStoppage!(stop, index + 1);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
              if (markers.isNotEmpty)
                MarkerLayer(markers: markers),
            ],
          ),
      ],
    );
  }
}
