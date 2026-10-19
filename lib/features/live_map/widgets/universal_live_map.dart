import 'dart:math' as math;
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

// ── Widget ────────────────────────────────────────────────────────────────────

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

// ── State ─────────────────────────────────────────────────────────────────────

class _UniversalLiveMapState extends State<UniversalLiveMap> {
  // Current animated visual position of the focused vehicle.
  // Updated by _onVisualPosUpdate on every animation tick.
  LatLng? _activeVisualPos;

  // ── CONFIRMED TRAIL ARCHITECTURE ──────────────────────────────────────────
  //
  // _confirmedTrails[vehicleId] stores ONLY positions that the animated marker
  // has PHYSICALLY REACHED — i.e., the glide animation to that GPS point has
  // completed and onPositionConfirmed fired.
  //
  // This guarantees the trail can NEVER be drawn ahead of the marker.
  //
  // Trail rendered as:  [p0, p1, ..., p_confirmed_last] + [activeVisualPos]
  //  - [p0..p_last] = GPS positions the marker has already arrived at
  //  - [activeVisualPos] = current live position (glide interpolation or
  //    dead-reckoning coast — always at or behind the visual marker)
  final Map<String, List<LatLng>> _confirmedTrails = {};

  bool _isUserInteracting = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Seed each vehicle with its current GPS as the start of the confirmed trail.
    for (final v in widget.vehicles) {
      if (v.hasLocation) {
        _confirmedTrails[v.id] = <LatLng>[LatLng(v.latitude!, v.longitude!)];
      }
    }
  }

  @override
  void didUpdateWidget(UniversalLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ensure newly-visible vehicles get a seed position.
    for (final v in widget.vehicles) {
      if (v.hasLocation) {
        _confirmedTrails.putIfAbsent(
            v.id, () => <LatLng>[LatLng(v.latitude!, v.longitude!)]);
      }
    }
  }

  String? get _resolvedActiveId =>
      widget.selectedId ??
      widget.followingId ??
      widget.pendingFocusId ??
      (widget.vehicles.isNotEmpty ? widget.vehicles.first.id : null);

  // ── Callbacks from AnimatedVehicleMarker ───────────────────────────────────

  /// Called when the glide animation completes — marker physically reached [pos].
  /// Safe to call setState: animation status listeners fire in
  /// SchedulerPhase.animating (transient callbacks), before the build phase.
  void _onPositionConfirmed(LatLng pos) {
    final String? activeId = _resolvedActiveId;
    if (activeId == null) return;
    final List<LatLng> trail =
        _confirmedTrails.putIfAbsent(activeId, () => <LatLng>[pos]);
    const Distance d = Distance();
    if (trail.isEmpty || d(trail.last, pos) >= 1.5) {
      setState(() => trail.add(pos));
    }
  }

  /// Called every animation tick (glide + smooth line pouring).
  /// Animation ticks fire in SchedulerPhase.animating (before build) —
  /// setState is safe and keeps the trail tip in the same frame as the marker.
  void _onVisualPosUpdate(LatLng pos) {
    final String? activeId = _resolvedActiveId;
    if (activeId == null) return;

    // Debounce: skip rebuilds for micro-jitter (<0.25m)
    if (_activeVisualPos != null) {
      const Distance d = Distance();
      if (d(_activeVisualPos!, pos) < 0.25) return;
    }

    setState(() => _activeVisualPos = pos);
    if (widget.followingId != null && !_isUserInteracting) {
      if (widget.mapController.camera.rotation != 0) {
        widget.mapController.moveAndRotate(
          pos,
          widget.mapController.camera.zoom,
          0.0,
        );
      } else {
        widget.mapController.move(pos, widget.mapController.camera.zoom);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String? activeId = _resolvedActiveId;

    // Active vehicle lookup
    Vehicle? activeV;
    if (activeId != null && activeId.isNotEmpty) {
      activeV = widget.vehicles.cast<Vehicle?>().firstWhere(
            (v) => v?.id == activeId,
            orElse: () => null,
          );
    }

    // activeVisualPos: the animated position fed back from AnimatedVehicleMarker.
    // Falls back to latest GPS only until the first animation tick fires —
    // this is correct because the vehicle IS at its last GPS position initially.
    final LatLng? activeVisualPos = (activeV != null && activeV.hasLocation)
        ? (_activeVisualPos ?? LatLng(activeV.latitude!, activeV.longitude!))
        : null;

    // ── Trail polylines ──────────────────────────────────────────────────────
    final List<Polyline> allPolylines = [];

    if (widget.showTrail) {
      const Distance dist = Distance();

      if (widget.showFullTrail && activeV != null && widget.route.isNotEmpty) {
        // ── FULL TRAIL MODE (Vehicle clicked/selected) ──────────────────────
        // Displays today's complete recorded journey up to the current live marker.
        final List<LatLng> fullPoints = [];
        LatLng? lastPt;

        for (final TrackPoint tp in widget.route) {
          if (!tp.isValid) continue;
          if (lastPt != null && dist(lastPt, tp.latLng) > 2000) {
            // Flush segment before gap (>2km gap = offline / overnight)
            if (fullPoints.length >= 2) {
              allPolylines.addAll(_splitPolyline(
                points: List<LatLng>.from(fullPoints),
                color: const Color(0xFF10B981),
                strokeWidth: 4.5,
              ));
            }
            fullPoints.clear();
          }
          fullPoints.add(tp.latLng);
          lastPt = tp.latLng;
        }

        // Attach the live animated tip to the end of the route
        if (activeVisualPos != null && fullPoints.isNotEmpty) {
          // Truncate any points in widget.route that lie ahead of activeVisualPos
          // (which happens if history has points ahead or during a turnaround/retreat)
          int bestMatchIdx = fullPoints.length - 1;
          double minDist = dist(fullPoints.last, activeVisualPos);

          final int searchWindow = math.max(0, fullPoints.length - 80);
          for (int i = fullPoints.length - 1; i >= searchWindow; i--) {
            final double d = dist(fullPoints[i], activeVisualPos);
            if (d < minDist) {
              minDist = d;
              bestMatchIdx = i;
            }
          }

          if (bestMatchIdx < fullPoints.length - 1) {
            // Cut off all points that extend ahead of the live marker
            fullPoints.removeRange(bestMatchIdx + 1, fullPoints.length);
          }

          // Anti-overshoot: ensure no point extends ahead along heading vector
          if (activeV.heading > 0 && fullPoints.length >= 2) {
            final LatLng tip = fullPoints.last;
            final double rad = activeV.heading * (math.pi / 180.0);
            final double cosLat = math
                .cos(activeVisualPos.latitude * (math.pi / 180.0))
                .abs()
                .clamp(0.01, 1.0);
            final double dNorth =
                (tip.latitude - activeVisualPos.latitude) * 111320.0;
            final double dEast =
                (tip.longitude - activeVisualPos.longitude) * 111320.0 * cosLat;
            final double aheadMeters =
                (dEast * math.sin(rad)) + (dNorth * math.cos(rad));
            if (aheadMeters > 1.0) {
              fullPoints.removeLast();
            }
          }

          if (minDist < 12.0 && fullPoints.isNotEmpty) {
            fullPoints[fullPoints.length - 1] = activeVisualPos;
          } else if (minDist >= 2.0) {
            fullPoints.add(activeVisualPos);
          }
        }

        if (fullPoints.length >= 2) {
          allPolylines.addAll(_splitPolyline(
            points: fullPoints,
            color: const Color(0xFF10B981),
            strokeWidth: 4.5,
          ));
        }
      } else if (activeId != null && activeV != null) {
        // ── LIVE POURING TRAIL MODE (Default / Running mode) ────────────────
        // When vehicle is moving, trail pours smoothly out behind the marker.
        // Pure live trail: confirmed positions already passed + live visual tip.
        final List<LatLng> trail =
            List<LatLng>.from(_confirmedTrails[activeId] ?? const []);

        if (activeVisualPos != null) {
          if (trail.isEmpty) {
            trail.add(activeVisualPos);
          } else if (trail.last != activeVisualPos) {
            trail.add(activeVisualPos);
          }
        }

        if (trail.length >= 2) {
          allPolylines.addAll(_splitPolyline(
            points: trail,
            color: const Color(0xFF10B981),
            strokeWidth: 4.5,
          ));
        }
      }
    }

    // ── Stoppage markers ─────────────────────────────────────────────────────
    final List<Marker> pointMarkers = [];
    final Map<String, int> overlapCounts = {};
    for (int i = 0; i < widget.stoppages.length; i++) {
      final stop = widget.stoppages[i];
      final lat = stop.startLat ?? stop.endLat;
      final lng = stop.startLng ?? stop.endLng;
      if (lat == null || lng == null) continue;
      final String overlapKey =
          '${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
      overlapCounts[overlapKey] = (overlapCounts[overlapKey] ?? 0) + 1;
      pointMarkers.add(Marker(
        point: LatLng(lat, lng),
        width: 24,
        height: 30,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTapStoppage?.call(stop, i + 1),
          child: Center(
            child: CustomPaint(
              size: const Size(24, 30),
              painter: _MessageBubblePainter(
                  number: i + 1, color: const Color(0xFFFF6B6B)),
            ),
          ),
        ),
      ));
    }

    // ── Vehicle markers ──────────────────────────────────────────────────────
    final List<Marker> vehicleMarkers = [];
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
          width: 44,
          height: 48,
          alignment: const Alignment(0.0,
              -0.89), // Inverted y-axis: sharp needle tip rests directly on GPS road coordinate
          child: AnimatedVehicleMarker(
            point: LatLng(v.latitude!, v.longitude!),
            heading: v.heading,
            status: v.status,
            speed: v.speed,
            onVisualPositionUpdate: isActive ? _onVisualPosUpdate : null,
            onPositionConfirmed: isActive ? _onPositionConfirmed : null,
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

    // ── Resolve initial center directly on active vehicle on frame 0 ─────────
    LatLng resolvedCenter = widget.fallbackCenter;
    if (activeV != null && activeV.hasLocation) {
      resolvedCenter = LatLng(activeV.latitude!, activeV.longitude!);
    } else {
      for (final v in widget.vehicles) {
        if (v.hasLocation) {
          resolvedCenter = LatLng(v.latitude!, v.longitude!);
          break;
        }
      }
    }

    // ── Render ───────────────────────────────────────────────────────────────
    final Widget mapWidget = FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: resolvedCenter,
        initialZoom: 16.0,
        minZoom: 2,
        maxZoom: 22.0,
        backgroundColor: widget.style == MapStyle.satellite
            ? const Color(0xFF1D262B)
            : const Color(0xFFE5E9EC),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
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
        buildTileLayer(widget.style, apiKey: widget.apiKey, retina: false),
        if (allPolylines.isNotEmpty) PolylineLayer(polylines: allPolylines),
        if (widget.showTrail && widget.showFullTrail && pointMarkers.isNotEmpty)
          MarkerLayer(markers: pointMarkers),
        MarkerLayer(markers: vehicleMarkers),
      ],
    );

    return mapWidget;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helper: build a Polyline with round caps/joins
// ─────────────────────────────────────────────────────────────────────────────
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
//  Stoppage pin painter — teardrop with numbered inner circle
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

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final ui.Path path = ui.Path();
    final double radius = w / 2;
    path.moveTo(w / 2, h);
    path.quadraticBezierTo(0, h * 0.7, 0, radius);
    path.arcToPoint(Offset(w, radius),
        radius: Radius.circular(radius), clockwise: true);
    path.quadraticBezierTo(w, h * 0.7, w / 2, h);
    path.close();

    canvas.drawPath(path.shift(const Offset(0, 3)), shadowPaint);
    canvas.drawPath(path, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);

    final double cx = w / 2;
    final double cy = radius;
    canvas.drawCircle(
        Offset(cx, cy),
        radius * 0.75,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);

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
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2.2));
  }

  @override
  bool shouldRepaint(_MessageBubblePainter old) => old.number != number;
}
