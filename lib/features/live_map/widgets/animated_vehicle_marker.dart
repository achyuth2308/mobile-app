import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// A wrapper widget for flutter_map markers that animates smooth movement 
/// between coordinate updates using an explicit AnimationController.
class AnimatedVehicleMarker extends StatefulWidget {
  const AnimatedVehicleMarker({
    required this.point,
    required this.heading,
    required this.status,
    required this.builder,
    this.duration = const Duration(milliseconds: 1000),
    super.key,
  });

  final LatLng point;
  final double heading;
  final VehicleStatus status;
  final Widget Function(BuildContext context, double heading) builder;
  final Duration duration;

  @override
  State<AnimatedVehicleMarker> createState() => _AnimatedVehicleMarkerState();
}

class _AnimatedVehicleMarkerState extends State<AnimatedVehicleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  LatLng? _oldPoint;
  double _targetHeading = 0.0;
  bool _snap = false;

  @override
  void initState() {
    super.initState();
    _targetHeading = widget.heading;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void didUpdateWidget(AnimatedVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.point != widget.point) {
      _snap = false;
      
      const Distance dist = Distance();
      final double distanceMeters = dist(oldWidget.point, widget.point);
      
      // Calculate realistic heading from the road trajectory.
      // The hardware heading byte from the GPS device is frequently stale (stays 0° for
      // several packets after a direction change). Always derive from the GPS movement
      // vector when the vehicle is moving and has moved a meaningful distance.
      if (widget.status == VehicleStatus.moving && distanceMeters > 5) {
        // Trajectory bearing = direction from previous GPS point to current GPS point.
        // This is always correct because it is derived from real coordinate movement.
        _targetHeading = dist.bearing(oldWidget.point, widget.point);
      } else if (distanceMeters <= 1) {
        // Tiny jitter — keep the last known heading so the arrow doesn't flicker
        // _targetHeading unchanged intentionally
      } else {
        _targetHeading = widget.heading;
      }

      // Record where we were when the new coordinate arrived
      // If animation was already running, capture the current interpolated position!
      _oldPoint = _getCurrentInterpolatedPoint(oldWidget.point);
      
      // Restart the animation for the new segment
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading) {
      _targetHeading = widget.heading;
      _controller.duration = widget.duration;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _getCurrentInterpolatedPoint(LatLng previousTarget) {
    if (_oldPoint == null || !_controller.isAnimating) return previousTarget;
    final double t = _animation.value;
    final double lat = _oldPoint!.latitude + (previousTarget.latitude - _oldPoint!.latitude) * t;
    final double lng = _oldPoint!.longitude + (previousTarget.longitude - _oldPoint!.longitude) * t;
    return LatLng(lat, lng);
  }

  LatLng _getAnimatedPoint() {
    if (_snap || _oldPoint == null) return widget.point;
    final double t = _animation.value;
    final double lat = _oldPoint!.latitude + (widget.point.latitude - _oldPoint!.latitude) * t;
    final double lng = _oldPoint!.longitude + (widget.point.longitude - _oldPoint!.longitude) * t;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        final LatLng currentLatLng = _getAnimatedPoint();
        
        final math.Point<double> targetPos = camera.latLngToScreenPoint(widget.point);
        final math.Point<double> currentPos = camera.latLngToScreenPoint(currentLatLng);
        
        final Offset offset = Offset(currentPos.x - targetPos.x, currentPos.y - targetPos.y);

        return Transform.translate(
          offset: offset,
          child: widget.builder(context, _targetHeading),
        );
      },
    );
  }
}
