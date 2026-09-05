import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// Smoothly glides a vehicle marker between GPS updates.
/// It does NOT extrapolate forward (Dead Reckoning) to prevent the marker
/// from driving off the road or disconnecting from the historical trail.
class AnimatedVehicleMarker extends StatefulWidget {
  final LatLng point;
  final double heading;
  final VehicleStatus status;
  final double speed;
  final Widget Function(BuildContext context, double heading) builder;
  final ValueNotifier<LatLng?>? visualPositionNotifier;

  const AnimatedVehicleMarker({
    required this.point,
    required this.heading,
    required this.status,
    required this.speed,
    required this.builder,
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
  
  double _fromHeading = 0.0;
  double _toHeading = 0.0;
  
  bool _initialized = false;
  static const Distance _dist = Distance();

  @override
  void initState() {
    super.initState();
    _fromPoint = widget.point;
    _toPoint = widget.point;
    _fromHeading = widget.heading;
    _toHeading = widget.heading;
    _initialized = true;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Standard glide time
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.addListener(_onAnimationTick);
    
    // Set initial visual position
    if (widget.visualPositionNotifier != null) {
      widget.visualPositionNotifier!.value = widget.point;
    }
  }

  void _onAnimationTick() {
    if (widget.visualPositionNotifier != null) {
      widget.visualPositionNotifier!.value = _interpolatedPoint;
    }
    // AnimatedBuilder will rebuild the widget below based on _controller
  }

  @override
  void didUpdateWidget(AnimatedVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_initialized) return;

    if (oldWidget.point != widget.point) {
      final double meters = _dist(oldWidget.point, widget.point);

      // Start new interpolation from wherever we currently are visually
      _fromPoint = _interpolatedPoint;
      _toPoint = widget.point;

      _fromHeading = _interpolatedHeading;
      
      // Derive heading from actual movement vector when vehicle is moving
      if (widget.status == VehicleStatus.moving && meters > 2) {
        _toHeading = _dist.bearing(_fromPoint, _toPoint);
      } else {
        _toHeading = widget.heading;
      }

      // Calculate animation duration based on distance. 
      // We cap it so teleports don't take forever, but it glides smoothly.
      int ms = 1500;
      if (meters > 5000) {
        // Massive teleport, snap almost instantly
        ms = 300;
      } else if (meters > 100) {
        // Long distance jump, glide slightly longer so it looks smooth
        ms = 2500;
      }

      _controller.duration = Duration(milliseconds: ms);
      _controller.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading) {
      _fromHeading = _interpolatedHeading;
      _toHeading = widget.heading;
      _controller.forward(from: 0.0);
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
  
  double get _interpolatedHeading {
    final double t = _curve.value;
    // Shortest path angle interpolation
    final double diff = (_toHeading - _fromHeading) % 360;
    final double shortestAngle = (2 * diff % 360) - diff;
    return (_fromHeading + shortestAngle * t) % 360;
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
          child: widget.builder(context, _interpolatedHeading),
        );
      },
    );
  }
}
