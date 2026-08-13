import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/vehicle.dart';
import 'map_tiles.dart';
import 'map3d_view.dart';
import 'animated_vehicle_marker.dart';
import 'vehicle_marker.dart';
import 'vehicle_3d_marker.dart';

class UniversalLiveMap extends StatelessWidget {
  const UniversalLiveMap({
    super.key,
    required this.mapController,
    required this.vehicles,
    required this.style,
    required this.is3dEverMounted,
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
  final bool is3dEverMounted;
  final LatLng fallbackCenter;
  final String? selectedId;
  final String? followingId;
  final String? pendingFocusId;
  final VoidCallback onMapReady;
  final ValueChanged<bool> onUserInteracting;
  final VoidCallback onTapMap;
  final ValueChanged<Vehicle> onSelectVehicle;

  bool get _is3D => style == MapStyle.isometric3D;

  List<Marker> _buildMarkers() {
    return vehicles
        .where((Vehicle v) => v.hasLocation)
        .map(
          (Vehicle v) => Marker(
            key: ValueKey<String>(v.id),
            point: LatLng(v.latitude!, v.longitude!),
            width: v.id == selectedId ? 90 : 60,
            height: v.id == selectedId ? 76 : 52,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => onSelectVehicle(v),
              child: AnimatedVehicleMarker(
                key: ValueKey<String>('anim_${v.id}'),
                point: LatLng(v.latitude!, v.longitude!),
                child: VehicleMarkerPin(
                  vehicle: v,
                  selected: v.id == selectedId,
                  showLabel: false,
                  useSprite: true,
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

    final Vehicle? following = followingId == null
        ? null
        : vehicles.cast<Vehicle?>().firstWhere(
              (Vehicle? v) => v?.id == followingId,
              orElse: () => null,
            );

    return Stack(
      children: <Widget>[
        if (is3dEverMounted || _is3D)
          Opacity(
            opacity: _is3D ? 1.0 : 0.0,
            child: Map3DView(
              vehicles: vehicles,
              mapCenter: fallbackCenter,
              selectedVehicle: following,
            ),
          ),
        if (!_is3D)
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
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: markers,
                    maxClusterRadius: 55,
                    disableClusteringAtZoom: 14,
                    size: const Size(48, 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(50),
                    maxZoom: 15,
                    zoomToBoundsOnClick: true,
                    spiderfyCluster: false,
                    builder: (BuildContext context, List<Marker> cluster) =>
                        ClusterBubble(count: cluster.length),
                  ),
                ),
            ],
          ),

      ],
    );
  }
}
