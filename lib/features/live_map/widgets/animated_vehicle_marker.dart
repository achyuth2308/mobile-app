import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// Smoothly interpolates a vehicle marker between GPS updates.
/// NO extrapolation / drift — the marker stops exactly at the last known
/// position once the animation completes, which keeps it on the road.
class AnimatedVehicleMarker extends StatefulWidget {
  final LatLng point;
  final double heading;
  final VehicleStatus status;
  final double speed;
  final Widget Function(BuildContext context, double heading) builder;
  final Duration duration;
  final ValueNotifier<LatLng?>? visualPositionNotifier;

  const AnimatedVehicleMarker({
    required this.point,
    required this.heading,
    required this.status,
    required this.speed,
    required this.builder,
    this.duration = const Duration(milliseconds: 800),
    this.visualPositionNotifier,
    super.key,
  });

  @override
  State<AnimatedVehicleMarker> createState() => _AnimatedVehicleMarkerState();
}

class _AnimatedVehicleMarkerState extends State<AnimatedVehicleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curve;

  LatLng _fromPoint = const LatLng(0, 0);
  LatLng _toPoint = const LatLng(0, 0);
  double _targetHeading = 0.0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _fromPoint = widget.point;
    _toPoint = widget.point;
    _targetHeading = widget.heading;
    _initialized = true;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.linear);

    _controller.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    if (widget.visualPositionNotifier != null) {
      widget.visualPositionNotifier!.value = _interpolatedPoint;
    }
    // We only need the AnimatedBuilder below to rebuild — so no setState here.
    // The AnimatedBuilder listens to _controller directly.
  }

  @override
  void didUpdateWidget(AnimatedVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_initialized) return;

    if (oldWidget.point != widget.point) {
      const Distance dist = Distance();
      final double meters = dist(oldWidget.point, widget.point);

      // Snap for impossibly large jumps (teleport / bad data > 2 km)
      if (meters > 2000) {
        _fromPoint = widget.point;
        _toPoint = widget.point;
        _targetHeading = widget.heading;
        widget.visualPositionNotifier?.value = widget.point;
        _controller.stop();
        return;
      }

      // Start new interpolation from wherever we currently are visually
      _fromPoint = _interpolatedPoint;
      _toPoint = widget.point;

      // Derive heading from actual movement vector when vehicle is moving
      if (widget.status == VehicleStatus.moving && meters > 2) {
        _targetHeading = dist.bearing(_fromPoint, _toPoint);
      } else {
        _targetHeading = widget.heading;
      }

      // Calculate animation duration based on physical speed
      // Speed is in km/h. Convert to m/s.
      final double speedMs = (widget.speed > 0 ? widget.speed : 10.0) / 3.6;

      // Time = Distance / Speed.
      int ms = ((meters / speedMs) * 1000).toInt();

      // If we got a massive delay, clamp it so it doesn't take 5 minutes to animate a huge jump
      // Also ensure it's not super fast if points are close.
      ms = ms.clamp(1000, 15000);

      _controller.duration = Duration(milliseconds: ms);
      _controller.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading) {
      _targetHeading = widget.heading;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAnimationTick);
    _controller.dispose();
    super.dispose();
  }

  LatLng get _interpolatedPoint {
    final double t = _curve.value;
    final double lat =
        _fromPoint.latitude + (_toPoint.latitude - _fromPoint.latitude) * t;
    final double lng =
        _fromPoint.longitude + (_toPoint.longitude - _fromPoint.longitude) * t;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final LatLng current = _interpolatedPoint;

        final math.Point<double> targetPos =
            camera.latLngToScreenPoint(_toPoint);
        final math.Point<double> currentPos =
            camera.latLngToScreenPoint(current);

        final Offset offset = Offset(
          currentPos.x - targetPos.x,
          currentPos.y - targetPos.y,
        );

        return Transform.translate(
          offset: offset,
          child: widget.builder(context, _targetHeading),
        );
      },
    );
  }
}
