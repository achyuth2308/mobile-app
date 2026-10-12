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
    this.apiKey,
    required this.fallbackCenter,
    required this.selectedId,
    required this.followingId,
    required this.onMapReady,
    required this.onUserInteracting,
    required this.onTapMap,
    required this.onSelectVehicle,
    this.pendingFocusId,
    this.route = const <TrackPoint>[],
    this.stoppages = const <ReportRow>[],
    this.showTrail = false,
    this.showFullTrail = false,
    this.onTapStoppage,
  });

  final MapController mapController;
  final List<Vehicle> vehicles;
  final MapStyle style;
  final String? apiKey;
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
  final bool showTrail;
  final bool showFullTrail;
  final void Function(ReportRow, int)? onTapStoppage;

  @override
  State<UniversalLiveMap> createState() => _UniversalLiveMapState();
}

class _UniversalLiveMapState extends State<UniversalLiveMap> {
  final ValueNotifier<LatLng?> _activeVisualPosition = ValueNotifier(null);
  // Stores confirmed GPS waypoints the vehicle has ALREADY completed.
  final Map<String, List<LatLng>> _sessionTrails = {};
  // Stores the pending target position that the vehicle is currently animating towards.
  // The pending target is held here until the glide finishes and the next packet arrives,
  // guaranteeing the trail is NEVER drawn in front of the vehicle or folded backwards!
  final Map<String, LatLng> _pendingTargetPos = {};
  bool _isUserInteracting = false;

  @override
  void didUpdateWidget(UniversalLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    const Distance dist = Distance();

    for (final v in widget.vehicles) {
      if (!v.hasLocation) continue;
      final LatLng currentPos = LatLng(v.latitude!, v.longitude!);
      final List<LatLng> trail =
          _sessionTrails.putIfAbsent(v.id, () => <LatLng>[currentPos]);
      final LatLng? prevTarget = _pendingTargetPos[v.id];

      if (prevTarget == null) {
        _pendingTargetPos[v.id] = currentPos;
      } else if (dist(prevTarget, currentPos) >= 4.0) {
        // Commit the previous target that the vehicle has completed into the confirmed past trail!
        if (trail.isEmpty || dist(trail.last, prevTarget) >= 3.0) {
          trail.add(prevTarget);
        }
        // currentPos becomes the new destination target the marker is currently animating towards
        _pendingTargetPos[v.id] = currentPos;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _activeVisualPosition.addListener(_onVisualPositionChanged);

    // Populate initial starting position immediately when map session begins
    for (final v in widget.vehicles) {
      if (v.hasLocation) {
        final LatLng pos = LatLng(v.latitude!, v.longitude!);
        _sessionTrails[v.id] = <LatLng>[pos];
        _pendingTargetPos[v.id] = pos;
      }
    }
  }

  void _onVisualPositionChanged() {
    final pos = _activeVisualPosition.value;
    final String? activeId = widget.selectedId ?? widget.followingId;
    if (pos != null &&
        activeId != null &&
        widget.followingId != null &&
        !_isUserInteracting) {
      widget.mapController.move(pos, widget.mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _activeVisualPosition.removeListener(_onVisualPositionChanged);
    _activeVisualPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? activeId = widget.selectedId ?? widget.followingId;

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
      final String overlapKey =
          '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      final int count = overlapCounts[overlapKey] ?? 0;
      overlapCounts[overlapKey] = count + 1;

      pointMarkers.add(Marker(
        point: LatLng(lat, lng),
        width: 20,
        height: 24,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (widget.onTapStoppage != null) {
              widget.onTapStoppage!(stop, i + 1);
            }
          },
          child: Center(
            child: CustomPaint(
              size: const Size(20, 24),
              painter: _MessageBubblePainter(
                  number: i + 1, color: const Color(0xFFFF6B6B)), // Red
            ),
          ),
        ),
      ));
    }

    // Extract active vehicle info for the trail builder
    Vehicle? activeV;
    if (activeId != null && activeId.isNotEmpty) {
      activeV = widget.vehicles.cast<Vehicle?>().firstWhere(
            (v) => v?.id == activeId,
            orElse: () => null,
          );
    }

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.fallbackCenter,
            initialZoom: 16.8,
            minZoom: 2,
            maxZoom:
                22.0, // Allow zooming in deeply (tiles will be scaled up by TileLayer)
            backgroundColor: widget.style == MapStyle.satellite
                ? const Color(0xFF1D262B)
                : const Color(0xFFE5E9EC),
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
            buildTileLayer(
              widget.style,
              apiKey: widget.apiKey,
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: _activeVisualPosition,
              builder:
                  (BuildContext context, LatLng? visualPos, Widget? child) {
                final LatLng? activeVisualPos =
                    (activeV != null && activeV.hasLocation)
                        ? (visualPos ??
                            LatLng(activeV.latitude!, activeV.longitude!))
                        : null;

                final List<Polyline> allPolylines = [];

                if (widget.showTrail) {
                  const Distance dist = Distance();

                  if (widget.showFullTrail && activeV != null && widget.route.isNotEmpty) {
                    // ── FULL TRAIL MODE (Shown ONLY when marker is clicked) ──
                    final List<LatLng> fullPoints = [];
                    for (final TrackPoint tp in widget.route) {
                      if (tp.isValid) fullPoints.add(tp.latLng);
                    }

                    // Seamlessly append confirmed session points that arrived after history
                    final List<LatLng> sessionPts = _sessionTrails[activeV.id] ?? const [];
                    for (final LatLng sPt in sessionPts) {
                      if (fullPoints.isEmpty) {
                        fullPoints.add(sPt);
                      } else {
                        final double d = dist(fullPoints.last, sPt);
                        if (d > 4.0) {
                          fullPoints.add(sPt);
                        }
                      }
                    }

                    // Strict anti-overshoot guard: If fullPoints.last happens to be at or near
                    // the pending future target, pop it so the polyline strictly terminates AT activeVisualPos!
                    if (activeVisualPos != null) {
                      final LatLng? pending = _pendingTargetPos[activeV.id];
                      if (pending != null && fullPoints.isNotEmpty) {
                        final double distLastToPending = dist(fullPoints.last, pending);
                        final double distVisualToPending = dist(activeVisualPos, pending);
                        if (distLastToPending < 5.0 && distVisualToPending > 4.0) {
                          fullPoints.removeLast();
                        }
                      }

                      if (fullPoints.isEmpty || dist(fullPoints.last, activeVisualPos) > 1.5) {
                        fullPoints.add(activeVisualPos);
                      }
                    }

                    allPolylines.addAll(_splitPolyline(
                      points: fullPoints,
                      color: const Color(0xFF10B981),
                      strokeWidth: 4.5,
                    ));
                  } else {
                    // ── SESSION TRAIL MODE (Default from where page opened) ──
                    for (final v in widget.vehicles) {
                      if (!v.hasLocation) continue;

                      final List<LatLng> trail =
                          List<LatLng>.from(_sessionTrails[v.id] ?? <LatLng>[]);

                      // For the active vehicle, activeVisualPos is currently gliding
                      // between trail.last and _pendingTargetPos.
                      // Appending activeVisualPos smoothly extends the trail to the truck tip!
                      // Because _pendingTargetPos is NOT in trail, the line NEVER overshoots
                      // and NEVER folds backwards!
                      if (v.id == activeId && activeVisualPos != null) {
                        if (trail.isEmpty || dist(trail.last, activeVisualPos) > 1.5) {
                          trail.add(activeVisualPos);
                        }
                      } else {
                        // For non-active vehicles (static), connect to pending target
                        final LatLng? target = _pendingTargetPos[v.id];
                        if (target != null && (trail.isEmpty || dist(trail.last, target) > 1.5)) {
                          trail.add(target);
                        }
                      }

                      if (trail.length >= 2) {
                        allPolylines.addAll(_splitPolyline(
                          points: trail,
                          color: v.id == activeId
                              ? const Color(0xFF10B981)
                              : const Color(0xFF10B981).withOpacity(0.4),
                          strokeWidth: v.id == activeId ? 4.5 : 3.0,
                        ));
                      }
                    }
                  }
                }

                final List<Marker> vehicleMarkers = <Marker>[];
                for (final Vehicle v in widget.vehicles) {
                  if (!v.hasLocation) continue;
                  final bool isActive = (v.id == activeId);
                  final LatLng markerPos = isActive
                      ? (activeVisualPos ?? LatLng(v.latitude!, v.longitude!))
                      : LatLng(v.latitude!, v.longitude!);

                  vehicleMarkers.add(
                    Marker(
                      key: ValueKey<String>('marker_${v.id}'),
                      point: markerPos,
                      width: 28,
                      height: 36,
                      alignment: Alignment.topCenter,
                      child: AnimatedVehicleMarker(
                        point: LatLng(v.latitude!, v.longitude!),
                        heading: v.heading,
                        status: v.status,
                        speed: v.speed,
                        visualPositionNotifier:
                            isActive ? _activeVisualPosition : null,
                        builder: (BuildContext context, double heading) =>
                            GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onSelectVehicle(v),
                          child: VehicleMarkerPin(
                            vehicle: v,
                            selected: v.id == widget.selectedId,
                            showLabel: false,
                            useSprite: true,
                            headingOverride: heading,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  children: <Widget>[
                    if (allPolylines.isNotEmpty)
                      PolylineLayer(polylines: allPolylines),
                    // Stoppage markers shown ONLY when full trail mode is active (marker clicked)
                    if (widget.showTrail && widget.showFullTrail && pointMarkers.isNotEmpty)
                      MarkerLayer(markers: pointMarkers),
                    MarkerLayer(markers: vehicleMarkers),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Renders GPS points as a continuous, unbroken [Polyline] connecting all
/// consecutive points with rounded joints and caps so there are no visual cuts.
List<Polyline> _splitPolyline({
  required List<LatLng> points,
  required Color color,
  double strokeWidth = 4.5,
}) {
  if (points.length < 2) return const <Polyline>[];

  return <Polyline>[
    Polyline(
      points: points,
      strokeWidth: strokeWidth,
      color: color,
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
//  BEAUTIFUL PIN PAINTER — for stoppage markers
//  A beautiful teardrop map pin with an inner white circle containing the number.
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubblePainter extends CustomPainter {
  final int number;
  final Color color;
  const _MessageBubblePainter(
      {required this.number, this.color = const Color(0xFFE53935)});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw a beautiful teardrop map pin
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final ui.Path path = ui.Path();
    final double radius = w / 2;

    path.moveTo(w / 2, h);
    path.quadraticBezierTo(0, h * 0.7, 0, radius);
    path.arcToPoint(Offset(w, radius),
        radius: Radius.circular(radius), clockwise: true);
    path.quadraticBezierTo(w, h * 0.7, w / 2, h);
    path.close();

    // Draw shadow
    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);

    // Draw main pin
    canvas.drawPath(path, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    // Inner white circle for the number
    final double cx = w / 2;
    final double cy = radius;
    final Paint innerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius * 0.75, innerCirclePaint);

    // Number text
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: number > 9 ? w * 0.40 : w * 0.50,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
        canvas,
        Offset(cx - tp.width / 2,
            cy - tp.height / 2.2)); // Adjusted Y for better vertical centering
  }

  @override
  bool shouldRepaint(_MessageBubblePainter old) => old.number != number;
}
