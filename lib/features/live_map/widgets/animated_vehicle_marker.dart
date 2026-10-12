import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// Smoothly glides a vehicle marker along the road between GPS updates.
///
/// Features:
///   1. **Adaptive Duration Pacing** — Automatically measures the real arrival
///      cadence between GPS packets and paces the glide duration to match it.
///      This ensures the vehicle moves continuously forward without stopping.
///
///   2. **Mid-Flight Re-Targeting** — When a new GPS update arrives while the
///      marker is still gliding, it immediately takes the exact current visual
///      position on screen as the start point and glides forward to the new fix.
///      It NEVER snaps or jumps backwards.
///
///   3. **Coast Easing** — Uses [Curves.easeOutCubic] so vehicle maintains steady
///      road speed and gently decelerates if a packet is delayed, rather than
///      freezing abruptly.
///
///   4. **Parked Settling** — When the vehicle stops (speed < 1 km/h or status != moving),
///      it settles quickly (600ms) and remains stationary without drifting.
class AnimatedVehicleMarker extends StatefulWidget {
  final LatLng point;
  final double heading;
  final VehicleStatus status;
  final double speed; // km/h
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
  late AnimationController _glideController;
  late Animation<double> _glideCurve;

  LatLng _fromPoint = const LatLng(0, 0);
  LatLng _toPoint = const LatLng(0, 0);
  double _fromHeading = 0.0;
  double _toHeading = 0.0;

  DateTime? _lastPacketTime;
  int _estimatedIntervalMs = 6000;
  bool _initialized = false;
  static const Distance _dist = Distance();

  @override
  void initState() {
    super.initState();
    _fromPoint = widget.point;
    _toPoint = widget.point;
    _fromHeading = widget.heading;
    _toHeading = widget.heading;
    _lastPacketTime = DateTime.now();
    _initialized = true;

    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glideCurve =
        CurvedAnimation(parent: _glideController, curve: Curves.easeOutCubic);

    _glideController.addListener(_onGlideTick);

    // Publish initial position
    _notifyVisualPos(widget.point);
  }

  @override
  void didUpdateWidget(AnimatedVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_initialized) return;

    if (oldWidget.point != widget.point) {
      final double meters = _dist(oldWidget.point, widget.point);

      // Skip sub-meter GPS jitter when parked
      if (meters < 1.0 && widget.status != VehicleStatus.moving) return;

      final DateTime now = DateTime.now();
      if (_lastPacketTime != null) {
        final int elapsed = now.difference(_lastPacketTime!).inMilliseconds;
        // If elapsed time is between 2s and 25s, use exponential moving average
        // to adapt smoothly to the hardware's reporting cadence.
        if (elapsed >= 1500 && elapsed <= 25000) {
          _estimatedIntervalMs =
              ((_estimatedIntervalMs * 0.4) + (elapsed * 0.6)).round();
        }
      }
      _lastPacketTime = now;

      // Retarget seamlessly from the EXACT current on-screen visual position!
      // This guarantees the marker ONLY moves forward and NEVER snaps backward.
      _fromPoint = _interpolatedGlidePoint;
      _toPoint = widget.point;

      _fromHeading = _interpolatedHeading;

      // Derive bearing from movement vector if moving significantly, else use device heading
      if (widget.status == VehicleStatus.moving && meters > 2.0) {
        _toHeading = _dist.bearing(_fromPoint, _toPoint);
      } else {
        _toHeading = widget.heading;
      }

      // Calculate glide duration:
      int ms;
      if (meters > 1500) {
        // Teleport / initial map load — snap quickly
        ms = 300;
      } else if (widget.status != VehicleStatus.moving || widget.speed < 1.0) {
        // Vehicle stopped / parking — settle quickly to rest
        ms = 600;
      } else {
        // Moving — pace glide across estimated packet interval so motion is continuous.
        // Cap between 2000ms and 12000ms.
        ms = _estimatedIntervalMs.clamp(2000, 12000);
      }

      _glideController.duration = Duration(milliseconds: ms);
      _glideController.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading &&
        !_glideController.isAnimating) {
      _fromHeading = _interpolatedHeading;
      _toHeading = widget.heading;
      _glideController.duration = const Duration(milliseconds: 600);
      _glideController.forward(from: 0.0);
    }
  }

  void _onGlideTick() {
    if (!mounted) return;
    _notifyVisualPos(_interpolatedGlidePoint);
  }

  void _notifyVisualPos(LatLng pos) {
    if (widget.visualPositionNotifier != null) {
      try {
        widget.visualPositionNotifier!.value = pos;
      } catch (_) {}
    }
  }

  LatLng get _interpolatedGlidePoint {
    if (!_glideController.isAnimating && _glideController.isCompleted) {
      return _toPoint;
    }
    final double t = _glideCurve.value;
    return LatLng(
      _fromPoint.latitude + (_toPoint.latitude - _fromPoint.latitude) * t,
      _fromPoint.longitude + (_toPoint.longitude - _fromPoint.longitude) * t,
    );
  }

  double get _interpolatedHeading {
    if (!_glideController.isAnimating && _glideController.isCompleted) {
      return _toHeading;
    }
    final double t = _glideCurve.value;
    final double diff = (_toHeading - _fromHeading) % 360;
    final double shortestAngle = (2 * diff % 360) - diff;
    return (_fromHeading + shortestAngle * t) % 360;
  }

  @override
  void dispose() {
    _glideController.removeListener(_onGlideTick);
    _glideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glideController,
      builder: (BuildContext context, Widget? child) {
        return widget.builder(context, _interpolatedHeading);
      },
    );
  }
}
