import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// Smoothly glides a vehicle marker along the road between GPS updates.
///
/// Features:
///   1. **Steady Road Glide** — Paces the glide across the measured reporting
///      cadence so the vehicle moves smoothly forward along the road without stopping.
///
///   2. **Zero Overshoot (No Backward Retreats)** — Strictly clamps progression to [0.0, 1.0],
///      guaranteeing the marker never overshoots into imaginary coordinates ahead.
///      When the next GPS update arrives, the vehicle only advances forward.
///
///   3. **GPS Coordinate Bearing** — Derives the road heading directly from the
///      two coordinates (_fromPoint -> _toPoint) whenever moving, ensuring the
///      marker always points along the road even if device heading is 0 or noisy.
///
///   4. **Clean Parked Settling** — When the vehicle stops, it settles immediately
///      into rest in 400ms without drifting.
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
  int _estimatedIntervalMs = 5000;
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
      duration: const Duration(milliseconds: 3000),
    );
    _glideCurve =
        CurvedAnimation(parent: _glideController, curve: Curves.linear);

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
      if (meters < 0.8 && widget.status != VehicleStatus.moving) return;

      final DateTime now = DateTime.now();
      if (_lastPacketTime != null) {
        final int elapsed = now.difference(_lastPacketTime!).inMilliseconds;
        if (elapsed >= 1500 && elapsed <= 25000) {
          _estimatedIntervalMs =
              ((_estimatedIntervalMs * 0.35) + (elapsed * 0.65)).round();
        }
      }
      _lastPacketTime = now;

      // Start the new forward stride smoothly from the current on-screen visual position
      _fromPoint = _interpolatedGlidePoint;
      _toPoint = widget.point;

      _fromHeading = _interpolatedHeading;

      // When vehicle is moving and distance > 2m, calculate true road bearing directly from the coordinates
      final double strideMeters = _dist(_fromPoint, _toPoint);
      if (widget.status == VehicleStatus.moving && strideMeters > 2.0) {
        final double rawBearing = _dist.bearing(_fromPoint, _toPoint);
        _toHeading = (rawBearing + 360.0) % 360.0;
      } else if (widget.heading > 0) {
        _toHeading = widget.heading;
      }

      // Calculate stride duration matching real vehicle speed & interval
      int durationMs;
      if (meters > 1500) {
        // Initial load / massive reposition
        durationMs = 300;
      } else if (widget.status != VehicleStatus.moving || widget.speed < 1.0) {
        // Vehicle stopped — settle directly into parking spot in 400ms
        durationMs = 400;
      } else {
        // Moving — pace stride to match reporting interval so motion is steady
        final double speedMps = (widget.speed * 1000.0) / 3600.0;
        if (speedMps > 1.0 && strideMeters > 2.0) {
          final int travelMs = ((strideMeters / speedMps) * 1000.0).round();
          durationMs = travelMs.clamp(2500, 10000);
        } else {
          durationMs = _estimatedIntervalMs.clamp(2500, 10000);
        }
      }

      _glideController.duration = Duration(milliseconds: durationMs);
      _glideController.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading &&
        !_glideController.isAnimating) {
      _fromHeading = _interpolatedHeading;
      _toHeading = widget.heading;
      _glideController.duration = const Duration(milliseconds: 400);
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
    // Strictly clamped to 0.0..1.0 — zero overshoot, zero backward retreat
    final double t = _glideCurve.value.clamp(0.0, 1.0);
    return LatLng(
      _fromPoint.latitude + (_toPoint.latitude - _fromPoint.latitude) * t,
      _fromPoint.longitude + (_toPoint.longitude - _fromPoint.longitude) * t,
    );
  }

  double get _interpolatedHeading {
    if (!_glideController.isAnimating && _glideController.isCompleted) {
      return _toHeading;
    }
    final double t = _glideCurve.value.clamp(0.0, 1.0);
    final double diff = (_toHeading - _fromHeading) % 360.0;
    final double shortestAngle = (2 * diff % 360.0) - diff;
    return (_fromHeading + shortestAngle * t) % 360.0;
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


