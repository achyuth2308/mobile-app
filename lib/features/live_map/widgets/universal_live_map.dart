import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/vehicle.dart';
import 'map_tiles.dart';
import 'animated_vehicle_marker.dart';
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
              if (markers.isNotEmpty)
                MarkerLayer(markers: markers),
            ],
          ),
      ],
    );
  }
}
