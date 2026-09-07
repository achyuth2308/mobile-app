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

  bool _showLoadingOverlay = true;

  @override
  void initState() {
    super.initState();
    _activeVisualPosition.addListener(_onVisualPositionChanged);
    
    // Give tiles 2.5 seconds to load in the background before revealing the map
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showLoadingOverlay = false;
        });
      }
    });
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
    final bool manyVehicles = widget.vehicles.length > 50;

    return widget.vehicles
        .where((Vehicle v) => v.hasLocation)
        .map(
          (Vehicle v) {
            final bool isSelected = v.id == widget.selectedId;
            final bool isActive = v.id == activeId;
            final bool useAnimation = isActive || !manyVehicles;

            Widget markerChild = VehicleMarkerPin(
              vehicle: v,
              selected: isSelected,
              showLabel: false,
              useSprite: true,
              headingOverride: v.heading,
            );

            if (useAnimation) {
              markerChild = AnimatedVehicleMarker(
                key: ValueKey<String>('anim_${v.id}'),
                point: LatLng(v.latitude!, v.longitude!),
                heading: v.heading,
                status: v.status,
                speed: v.speed,
                visualPositionNotifier: isActive ? _activeVisualPosition : null,
                builder: (BuildContext context, double animatedHeading) => VehicleMarkerPin(
                  vehicle: v,
                  selected: isSelected,
                  showLabel: false,
                  useSprite: true,
                  headingOverride: animatedHeading,
                ),
              );
            }

            return Marker(
              key: ValueKey<String>(v.id),
              point: LatLng(v.latitude!, v.longitude!),
              width: 40,
              height: 50,
              child: GestureDetector(
                onTap: () => widget.onSelectVehicle(v),
                // Shift the marker UP by half its height (25px) so the bottom tip (y=50) 
                // anchors exactly on the GPS coordinate.
                child: Transform.translate(
                  offset: const Offset(0, -25),
                  child: markerChild,
                ),
              ),
            );
          },
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

      pointMarkers.add(
        Marker(
          point: LatLng(lat, lng),
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
              ValueListenableBuilder<LatLng?>(
                valueListenable: _activeVisualPosition,
                builder: (BuildContext context, LatLng? visualPos, Widget? child) {
                  final List<LatLng> trailPoints = [];
                  
                  if (activeV != null && activeV.hasLocation) {
                    final LatLng finalBackendPos = LatLng(activeV.latitude!, activeV.longitude!);
                    final LatLng targetPos = visualPos ?? finalBackendPos;

                    if (widget.route.isNotEmpty) {
                      int cutIdx = -1;
                      double minDistance = double.infinity;
                      const Distance dist = Distance();

                      for (int i = 0; i < widget.route.length; i++) {
                        final TrackPoint tp = widget.route[i];
                        if (!tp.isValid) continue;

                        final double d = dist(tp.latLng, targetPos);
                        if (d < minDistance) {
                          minDistance = d;
                          cutIdx = i;
                        }
                      }

                      if (cutIdx != -1 && minDistance < 1000) {
                        for (int i = 0; i <= cutIdx; i++) {
                          if (widget.route[i].isValid) {
                            trailPoints.add(widget.route[i].latLng);
                          }
                        }
                      } else {
                        for (final TrackPoint tp in widget.route) {
                          if (tp.isValid) {
                            if (activeV.lastPacketAt != null && tp.timestamp.isAfter(activeV.lastPacketAt!)) {
                              break;
                            }
                            trailPoints.add(tp.latLng);
                          }
                        }
                      }
                    }
                    if (trailPoints.isEmpty || trailPoints.last != targetPos) {
                      trailPoints.add(targetPos);
                    }
                  } else if (widget.route.isNotEmpty) {
                    for (final TrackPoint tp in widget.route) {
                      if (tp.isValid) trailPoints.add(tp.latLng);
                    }
                  }

                  if (trailPoints.length < 2) return const SizedBox.shrink();

                  return PolylineLayer(
                    polylines: _splitPolyline(
                      points: trailPoints,
                      color: const Color(0xFF10B981),
                      strokeWidth: 4.5,
                    ),
                  );
                },
              ),
              if (markers.isNotEmpty)
                MarkerLayer(markers: markers),
              if (pointMarkers.isNotEmpty)
                MarkerLayer(markers: pointMarkers),
            ],
          ),
          
          // Loading overlay that hides the map while tiles are being downloaded
          if (_showLoadingOverlay)
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surface,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
      ],
    );
  }
}

/// Splits a list of GPS points into multiple [Polyline] segments, breaking
/// the line wherever two consecutive points are more than [gapThresholdMeters]
/// apart. This eliminates the long "crow-fly" drift lines that appear when
/// the GPS tracker loses signal for a while.
List<Polyline> _splitPolyline({
  required List<LatLng> points,
  required Color color,
  double strokeWidth = 4.5,
  double gapThresholdMeters = 1000,
}) {
  if (points.length < 2) return const <Polyline>[];

  const Distance _dist = Distance();
  final List<Polyline> segments = <Polyline>[];
  List<LatLng> current = <LatLng>[points.first];

  for (int i = 1; i < points.length; i++) {
    final double d = _dist(points[i - 1], points[i]);
    if (d > gapThresholdMeters) {
      if (current.length >= 2) {
        segments.add(Polyline(
          points: List<LatLng>.of(current),
          strokeWidth: strokeWidth,
          color: color,
        ));
      }
      current = <LatLng>[points[i]];
    } else {
      current.add(points[i]);
    }
  }

  if (current.length >= 2) {
    segments.add(Polyline(
      points: current,
      strokeWidth: strokeWidth,
      color: color,
    ));
  }

  return segments;
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
      ..color = Colors.white.withValues(alpha: 0.80)
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
