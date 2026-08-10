import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A wrapper widget for flutter_map markers that animates smooth movement 
/// between coordinate updates.
///
/// Because flutter_map physically places the widget at the target `LatLng` 
/// immediately, this widget uses a reverse-translation trick. It interpolates 
/// the LatLng, projects both the target and the interpolated LatLng into screen 
/// space using the current map camera, and applies a Transform to seamlessly 
/// glide the marker into place. This allows perfectly smooth 60fps movement 
/// that accurately tracks the map even if the user zooms or pans during the animation.
class AnimatedVehicleMarker extends ImplicitlyAnimatedWidget {
  const AnimatedVehicleMarker({
    required this.point,
    required this.child,
    super.curve = Curves.easeInOut,
    super.duration = const Duration(milliseconds: 1500),
    super.key,
  });

  final LatLng point;
  final Widget child;

  @override
  AnimatedWidgetBaseState<AnimatedVehicleMarker> createState() => _AnimatedVehicleMarkerState();
}

class _AnimatedVehicleMarkerState extends AnimatedWidgetBaseState<AnimatedVehicleMarker> {
  LatLngTween? _latLngTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _latLngTween = visitor(
      _latLngTween,
      widget.point,
      (dynamic value) => LatLngTween(begin: value as LatLng),
    ) as LatLngTween?;
  }

  @override
  Widget build(BuildContext context) {
    // If there is no map camera context (shouldn't happen inside flutter_map), just return child.
    final MapCamera camera = MapCamera.of(context);
    
    // Evaluate the interpolated LatLng for the current animation frame
    final LatLng currentLatLng = _latLngTween!.evaluate(animation);
    
    // Project both coordinates to screen points using the real-time camera
    final math.Point<double> targetPos = camera.latLngToScreenPoint(widget.point);
    final math.Point<double> currentPos = camera.latLngToScreenPoint(currentLatLng);
    
    // Calculate the pixel offset needed to shift the widget from its physical 
    // anchor (targetPos) to its visual animated position (currentPos).
    final Offset offset = Offset(currentPos.x - targetPos.x, currentPos.y - targetPos.y);

    return Transform.translate(
      offset: offset,
      child: widget.child,
    );
  }
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({super.begin, super.end});

  @override
  LatLng lerp(double t) {
    final double lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final double lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}
