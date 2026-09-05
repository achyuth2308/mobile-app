import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/report_models.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import 'animated_vehicle_marker.dart';
import 'map_tiles.dart';
import 'vehicle_marker.dart';

// ── Widget ───────────────────────────────────────────────────────────────────

class UniversalLiveMap extends StatefulWidget {
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

  @override
  State<UniversalLiveMap> createState() => _UniversalLiveMapState();
}

class _UniversalLiveMapState extends State<UniversalLiveMap> {
  final ValueNotifier<LatLng?> _activeVisualPosition = ValueNotifier(null);
  bool _isUserInteracting = false;

  final Map<String, GlobalKey> _markerKeys = <String, GlobalKey>{};

  GlobalKey _getMarkerKey(String id) {
    return _markerKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'marker_$id'));
  }

  @override
  void initState() {
    super.initState();
    _activeVisualPosition.addListener(_onVisualPositionChanged);
  }

  void _onVisualPositionChanged() {
    final pos = _activeVisualPosition.value;
    final String? activeId = widget.selectedId ?? widget.followingId;
    if (pos != null && activeId != null && widget.followingId != null && !_isUserInteracting) {
      widget.mapController.move(pos, widget.mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _activeVisualPosition.removeListener(_onVisualPositionChanged);
    _activeVisualPosition.dispose();
    super.dispose();
  }

  List<Marker> _buildMarkers(String? activeId) {
    return widget.vehicles
        .where((Vehicle v) => v.hasLocation)
        .map(
          (Vehicle v) => Marker(
            key: ValueKey<String>(v.id),
            point: LatLng(v.latitude!, v.longitude!),
            width: 120,
            height: 120,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => widget.onSelectVehicle(v),
              child: Center(
                child: AnimatedVehicleMarker(
                  key: _getMarkerKey(v.id),
                  point: LatLng(v.latitude!, v.longitude!),
                  heading: v.heading ?? 0.0,
                  status: v.status,
                  speed: v.speed ?? 0.0,
                  visualPositionNotifier: (v.id == activeId) ? _activeVisualPosition : null,
                  builder: (BuildContext context, double animatedHeading) => VehicleMarkerPin(
                    vehicle: v,
                    selected: v.id == widget.selectedId,
                    showLabel: false,
                    useSprite: true,
                    headingOverride: animatedHeading,
                  ),
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

    final String? activeId = widget.selectedId ?? widget.followingId;

    final List<Marker> markers = _buildMarkers(activeId);
    final List<ReportRow> filteredStoppages = widget.stoppages.toList();

    // Collect special point markers (Stoppages)
    final List<Marker> pointMarkers = [];
    final Map<String, int> overlapCounts = {};

    // Stoppage Markers (Red, Numbered 1, 2, ...)
    for (int i = 0; i < filteredStoppages.length; i++) {
      final stop = filteredStoppages[i];
      final lat = stop.startLat ?? stop.endLat;
      final lng = stop.startLng ?? stop.endLng;
      if (lat == null || lng == null) continue;

      // Group markers that are at the exact same location (within ~11 meters / 4 decimal places)
      final String overlapKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      final int count = overlapCounts[overlapKey] ?? 0;
      overlapCounts[overlapKey] = count + 1;

      // Visual offset so they fan out diagonally instead of perfectly eclipsing each other
      final double offsetLat = lat + (count * 0.0004); // ~40m North
      final double offsetLng = lng + (count * 0.0004); // ~40m East

      pointMarkers.add(
        Marker(
          point: LatLng(offsetLat, offsetLng),
          width: 44,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.onTapStoppage != null) {
                widget.onTapStoppage!(stop, i + 1);
              }
            },
            child: Center(
              child: CustomPaint(
                size: const Size(26, 30),
                painter: _MessageBubblePainter(number: i + 1, color: const Color(0xFFFF6B6B)), // Red
              ),
            ),
          ),
        )
      );
    }

    return Stack(
      children: <Widget>[
          FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: widget.fallbackCenter,
              initialZoom: 10.5,
              minZoom: 2,
              maxZoom: 22.0, // Allow zooming in deeply (tiles will be scaled up by TileLayer)
              backgroundColor: theme.colorScheme.surface,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: widget.onMapReady,
              onPointerDown: (_, __) {
                _isUserInteracting = true;
                widget.onUserInteracting(true);
              },
              onPointerUp: (_, __) {
                _isUserInteracting = false;
                widget.onUserInteracting(false);
              },
              onTap: (_, __) => widget.onTapMap(),
            ),
            children: <Widget>[
              buildTileLayer(widget.style),
              // The polyline trails were removed based on user request to only show numbered stoppage points
              if (markers.isNotEmpty)
                MarkerLayer(markers: markers),
              if (pointMarkers.isNotEmpty)
                MarkerLayer(markers: pointMarkers),
            ],
          ),
      ],
    );
  }
}

class _MapPinClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    final ui.Path path = ui.Path();

    // Circle centered at (w/2, w/2) with radius w/2
    final double r = w / 2;

    // Start at bottom tip
    path.moveTo(w / 2, h);
    // Draw left side tangent line to the circle
    path.quadraticBezierTo(w * 0.1, h * 0.6, 0, r);
    // Draw top circle arc
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Draw right side tangent line back to bottom tip
    path.quadraticBezierTo(w * 0.9, h * 0.6, w / 2, h);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPEECH / MESSAGE BUBBLE PAINTER — for stoppage markers
//  Light red rounded bubble with a small tail at bottom-left, number inside.
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubblePainter extends CustomPainter {
  final int number;
  final Color color;
  const _MessageBubblePainter({required this.number, this.color = const Color(0xFFFF6B6B)});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double bubbleH = h * 0.72;
    final double r = bubbleH * 0.28;

    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, bubbleH),
      Radius.circular(r),
    );

    final ui.Path tail = ui.Path()
      ..moveTo(w * 0.28, bubbleH - 1)
      ..lineTo(w * 0.16, h)
      ..lineTo(w * 0.50, bubbleH - 1)
      ..close();

    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(body, fill);
    canvas.drawPath(tail, fill);

    final Paint border = Paint()
      ..color = Colors.white.withOpacity(0.80)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(body, border);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: number > 9 ? 8.0 : 9.5,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, (bubbleH - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_MessageBubblePainter old) => old.number != number;
}
