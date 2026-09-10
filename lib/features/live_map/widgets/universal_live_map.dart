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
  final void Function(ReportRow, int)? onTapStoppage;

  @override
  State<UniversalLiveMap> createState() => _UniversalLiveMapState();
}

class _UniversalLiveMapState extends State<UniversalLiveMap> {
  final ValueNotifier<LatLng?> _activeVisualPosition = ValueNotifier(null);
  // Stores the confirmed trail history (points the marker has ACTUALLY visited).
  final Map<String, List<LatLng>> _sessionTrails = {};
  // Stores position of last GPS update for all non-active vehicles
  final Map<String, LatLng> _lastKnownPos = {};
  bool _isUserInteracting = false;
  bool _showLoadingOverlay = true;

  @override
  void didUpdateWidget(UniversalLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    const Distance dist = Distance();
    final String? activeId = widget.selectedId ?? widget.followingId;

    for (final v in widget.vehicles) {
      if (!v.hasLocation) continue;
      final LatLng currentPos = LatLng(v.latitude!, v.longitude!);

      // For NON-active vehicles, record trail directly since they don't animate
      if (v.id != activeId) {
        final List<LatLng> trail = _sessionTrails.putIfAbsent(v.id, () => <LatLng>[]);
        final LatLng? prev = _lastKnownPos[v.id];
        if (prev == null || dist(prev, currentPos) > 5.0) {
          trail.add(currentPos);
          _lastKnownPos[v.id] = currentPos;
        }
      } else {
        // For the ACTIVE vehicle, just initialize if needed.
        // Trail recording happens via the _activeVisualPosition listener.
        _sessionTrails.putIfAbsent(v.id, () => <LatLng>[currentPos]);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _activeVisualPosition.addListener(_onVisualPositionChanged);
    _activeVisualPosition.addListener(_recordActiveVehicleTrail);
    
    // Populate initial trail points immediately when map opens
    for (final v in widget.vehicles) {
      if (v.hasLocation) {
        final LatLng pos = LatLng(v.latitude!, v.longitude!);
        _sessionTrails[v.id] = <LatLng>[pos];
        _lastKnownPos[v.id] = pos;
      }
    }
    
    // Give tiles 2.5 seconds to load in the background before revealing the map
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showLoadingOverlay = false;
        });
      }
    });
  }

  /// Records the active vehicle's position as the marker actually animates.
  /// This ensures the trail tip is ALWAYS at the marker, never ahead of it.
  void _recordActiveVehicleTrail() {
    final LatLng? pos = _activeVisualPosition.value;
    if (pos == null) return;
    final String? activeId = widget.selectedId ?? widget.followingId;
    if (activeId == null) return;

    final List<LatLng> trail = _sessionTrails.putIfAbsent(activeId, () => <LatLng>[]);
    const Distance dist = Distance();
    if (trail.isEmpty || dist(trail.last, pos) > 3.0) {
      trail.add(pos);
    }
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
    _activeVisualPosition.removeListener(_recordActiveVehicleTrail);
    _activeVisualPosition.dispose();
    super.dispose();
  }

  List<Marker> _buildStaticMarkers(String? activeId) {
    final bool manyVehicles = widget.vehicles.length > 50;

    return widget.vehicles
        .where((Vehicle v) => v.hasLocation && v.id != activeId)
        .map(
          (Vehicle v) {
            final bool isSelected = v.id == widget.selectedId;

            Widget markerChild = VehicleMarkerPin(
              vehicle: v,
              selected: isSelected,
              showLabel: false,
              useSprite: true,
              headingOverride: v.heading,
            );

            if (!manyVehicles) {
              markerChild = AnimatedVehicleMarker(
                key: ValueKey<String>('anim_${v.id}'),
                point: LatLng(v.latitude!, v.longitude!),
                heading: v.heading,
                status: v.status,
                speed: v.speed,
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
              width: 28,
              height: 36,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectVehicle(v),
                child: markerChild,
              ),
            );
          },
        )
        .toList();
  }

  Widget _buildActiveMarkerLayer(Vehicle activeV, bool isSelected) {
    return ValueListenableBuilder<LatLng?>(
      valueListenable: _activeVisualPosition,
      builder: (BuildContext context, LatLng? visualPos, Widget? child) {
        final LatLng markerPos = visualPos ?? LatLng(activeV.latitude!, activeV.longitude!);

        return MarkerLayer(
          markers: [
            Marker(
              key: ValueKey<String>('active_${activeV.id}'),
              point: markerPos,
              width: 28,
              height: 36,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onSelectVehicle(activeV),
                child: AnimatedVehicleMarker(
                  key: ValueKey<String>('anim_${activeV.id}'),
                  point: LatLng(activeV.latitude!, activeV.longitude!),
                  heading: activeV.heading,
                  status: activeV.status,
                  speed: activeV.speed,
                  visualPositionNotifier: _activeVisualPosition,
                  builder: (BuildContext context, double animatedHeading) => VehicleMarkerPin(
                    vehicle: activeV,
                    selected: isSelected,
                    showLabel: false,
                    useSprite: true,
                    headingOverride: animatedHeading,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
      final String overlapKey = '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      final int count = overlapCounts[overlapKey] ?? 0;
      overlapCounts[overlapKey] = count + 1;

      pointMarkers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
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
              buildTileLayer(widget.style, apiKey: widget.apiKey),
              ValueListenableBuilder<LatLng?>(
                valueListenable: _activeVisualPosition,
                builder: (BuildContext context, LatLng? visualPos, Widget? child) {
                  final LatLng? activeVisualPos = (activeV != null && activeV.hasLocation)
                      ? (visualPos ?? LatLng(activeV.latitude!, activeV.longitude!))
                      : null;

                  final List<Polyline> allPolylines = [];

                  if (widget.showTrail) {
                    if (activeV != null && widget.route.isNotEmpty) {
                      final List<LatLng> trailPoints = [];
                      final LatLng currentPos = activeVisualPos!;
                      int cutIdx = -1;
                      double minDistance = double.infinity;
                      const Distance dist = Distance();

                      for (int i = 0; i < widget.route.length; i++) {
                        final TrackPoint tp = widget.route[i];
                        if (!tp.isValid) continue;

                        final double d = dist(tp.latLng, currentPos);
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
                      if (trailPoints.isEmpty) {
                        trailPoints.add(currentPos);
                      } else {
                        trailPoints.add(currentPos);
                      }
                      allPolylines.addAll(_splitPolyline(points: trailPoints, color: const Color(0xFF10B981), strokeWidth: 4.5));
                    } else if (widget.route.isNotEmpty) {
                      final List<LatLng> trailPoints = [];
                      for (final TrackPoint tp in widget.route) {
                        if (tp.isValid) trailPoints.add(tp.latLng);
                      }
                      allPolylines.addAll(_splitPolyline(points: trailPoints, color: const Color(0xFF10B981), strokeWidth: 4.5));
                    } else {
                      // Live session trails for all vehicles
                      for (final v in widget.vehicles) {
                        if (!v.hasLocation) continue;
                        
                        final List<LatLng> trail = _sessionTrails[v.id]?.toList() ?? [];
                        
                        // For the active vehicle, the trail is already being kept
                        // current by _recordActiveVehicleTrail listener. No appending needed.
                        // For non-active vehicles, make sure current pos is included.
                        if (v.id != activeId) {
                          final LatLng staticPos = LatLng(v.latitude!, v.longitude!);
                          if (trail.isEmpty || trail.last != staticPos) {
                            trail.add(staticPos);
                          }
                        }
                        
                        if (trail.length >= 2) {
                          allPolylines.addAll(_splitPolyline(
                            points: trail,
                            color: v.id == activeId ? const Color(0xFF10B981) : const Color(0xFF10B981).withOpacity(0.4),
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
                          builder: (BuildContext context, double heading) => GestureDetector(
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
                      MarkerLayer(markers: vehicleMarkers),
                    ],
                  );
                },
              ),
              if (widget.showTrail && pointMarkers.isNotEmpty)
                MarkerLayer(markers: pointMarkers),
            ],
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
          points: _smoothPoints(current),
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
      points: _smoothPoints(current),
      strokeWidth: strokeWidth,
      color: color,
    ));
  }

  return segments;
}

/// Catmull-Rom spline interpolation for smooth, natural road-aligned GPS polyline rendering.
List<LatLng> _smoothPoints(List<LatLng> pts) {
  if (pts.length < 3) return pts;
  final List<LatLng> smoothed = <LatLng>[pts.first];

  for (int i = 0; i < pts.length - 1; i++) {
    final LatLng p0 = i == 0 ? pts[i] : pts[i - 1];
    final LatLng p1 = pts[i];
    final LatLng p2 = pts[i + 1];
    final LatLng p3 = (i + 2 < pts.length) ? pts[i + 2] : pts[i + 1];

    const int steps = 4;
    for (int t = 1; t <= steps; t++) {
      final double u = t / steps;
      final double u2 = u * u;
      final double u3 = u2 * u;

      final double lat = 0.5 * (
        (2 * p1.latitude) +
        (-p0.latitude + p2.latitude) * u +
        (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * u2 +
        (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * u3
      );

      final double lng = 0.5 * (
        (2 * p1.longitude) +
        (-p0.longitude + p2.longitude) * u +
        (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * u2 +
        (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * u3
      );

      smoothed.add(LatLng(lat, lng));
    }
  }

  if (smoothed.isNotEmpty && pts.isNotEmpty) {
    smoothed[smoothed.length - 1] = pts.last;
  }
  return smoothed;
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
