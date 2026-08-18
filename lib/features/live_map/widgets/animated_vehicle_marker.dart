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
    required this.speed,
    required this.builder,
    this.duration = const Duration(milliseconds: 1000),
    super.key,
  });

  final LatLng point;
  final double heading;
  final VehicleStatus status;
  final double speed;
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
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _targetHeading = widget.heading;
    _lastUpdateTime = DateTime.now();
    // Use a long duration (30 seconds) so the controller keeps ticking and rebuilding the marker
    // for drift/extrapolation after the first 1-second fast transition.
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30));
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
      if (widget.status == VehicleStatus.moving && distanceMeters > 5) {
        _targetHeading = dist.bearing(oldWidget.point, widget.point);
      } else if (distanceMeters <= 1) {
        // Tiny jitter — keep the last known heading so the arrow doesn't flicker
      } else {
        _targetHeading = widget.heading;
      }

      // Record where we were when the new coordinate arrived relative to the OLD target point
      _oldPoint = _getAnimatedPoint(oldWidget.point);
      _lastUpdateTime = DateTime.now();
      
      _controller.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading) {
      _targetHeading = widget.heading;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _getAnimatedPoint(LatLng targetPoint) {
    if (_snap || _oldPoint == null || _lastUpdateTime == null) return targetPoint;
    
    final double elapsedMs = DateTime.now().difference(_lastUpdateTime!).inMilliseconds.toDouble();
    final double fastDurationMs = widget.duration.inMilliseconds.toDouble();
    
    if (elapsedMs <= fastDurationMs) {
      // 1. Fast transition phase (first 1 second)
      final double t = elapsedMs / fastDurationMs;
      final double lat = _oldPoint!.latitude + (targetPoint.latitude - _oldPoint!.latitude) * t;
      final double lng = _oldPoint!.longitude + (targetPoint.longitude - _oldPoint!.longitude) * t;
      return LatLng(lat, lng);
    } else {
      // 2. Slow drift/creep phase (after 1 second)
      // Only drift if the vehicle status is moving
      if (widget.status == VehicleStatus.moving) {
        final double driftSeconds = (elapsedMs - fastDurationMs) / 1000.0;
        
        // Drift speed: exactly 0.5 km/h as requested!
        // 0.5 km/h in m/s = 0.5 / 3.6 = 0.1388 m/s.
        const double driftSpeed = 0.5 / 3.6;
        
        final double rad = _targetHeading * math.pi / 180.0;
        final double driftMeters = driftSpeed * driftSeconds;
        
        final double dLat = driftMeters * math.cos(rad) / 111111.0;
        final double dLng = driftMeters * math.sin(rad) / (111111.0 * math.cos(targetPoint.latitude * math.pi / 180.0));
        
        return LatLng(targetPoint.latitude + dLat, targetPoint.longitude + dLng);
      }
      return targetPoint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MapCamera camera = MapCamera.of(context);
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        final LatLng currentLatLng = _getAnimatedPoint(widget.point);
        
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
