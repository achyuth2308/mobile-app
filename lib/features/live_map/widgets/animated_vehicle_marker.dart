import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// Rapido / Uber-style Smooth Continuous Motion Marker.
///
/// Principles:
/// 1. Stays strictly on the road by interpolating between verified consecutive GPS points.
/// 2. Paces glide duration to the telemetry packet interval (4s – 7.5s) for slow,
///    fluid, non-stopping motion.
/// 3. Never moves backward or drives off-road into fields.
/// 4. Continuously emits visual updates to pour the live trail fluidly behind the marker.
class AnimatedVehicleMarker extends StatefulWidget {
  final LatLng point;
  final double heading;
  final VehicleStatus status;
  final double speed; // km/h

  final Widget Function(BuildContext context, double heading) builder;

  /// Fires every animation tick with the current interpolated map position.
  /// Parent uses this to move the Marker.point and pour the trail tip in sync.
  final void Function(LatLng pos)? onVisualPositionUpdate;

  /// Fires once when the marker arrives at [point].
  final void Function(LatLng confirmedPos)? onPositionConfirmed;

  const AnimatedVehicleMarker({
    required this.point,
    required this.heading,
    required this.status,
    required this.speed,
    required this.builder,
    this.onVisualPositionUpdate,
    this.onPositionConfirmed,
    super.key,
  });

  @override
  State<AnimatedVehicleMarker> createState() => _AnimatedVehicleMarkerState();
}

class _AnimatedVehicleMarkerState extends State<AnimatedVehicleMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glideController;

  LatLng _fromPoint = const LatLng(0, 0);
  LatLng _toPoint = const LatLng(0, 0);
  double _fromHeading = 0.0;
  double _toHeading = 0.0;

  DateTime _glideStartTime = DateTime.now();
  int _glideDurationMs = 5000;

  DateTime? _lastPacketTime;
  int _estimatedIntervalMs = 6000;
  bool _positionConfirmedFired = false;

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
    _glideStartTime = DateTime.now();
    _glideDurationMs = 4500;
    _initialized = true;

    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _glideController.addListener(_onGlideTick);

    // If vehicle is actively driving on mount, immediately start continuous motion
    if (widget.status == VehicleStatus.moving && widget.speed >= 1.5) {
      _glideController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedVehicleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) return;

    final bool isMoving =
        widget.status == VehicleStatus.moving && widget.speed >= 1.5;

    // ── New GPS Coordinate Arrived ──────────────────────────────────────────
    if (oldWidget.point != widget.point) {
      final double rawMeters = _dist(oldWidget.point, widget.point);

      // Filter GPS satellite drift / micro-jitter:
      // When parked/stopped/idle, GPS hardware drifts 3-15m from atmospheric satellite noise.
      // Strictly ignore any jitter < 15m when not confirmed moving.
      if (!isMoving && rawMeters < 15.0) return;
      if (rawMeters < 1.0) return;

      // Teleport / massive jump (> 1.5 km): snap instantly
      if (rawMeters > 1500) {
        _glideController.stop();
        _fromPoint = widget.point;
        _toPoint = widget.point;
        _fromHeading = widget.heading;
        _toHeading = widget.heading;
        _glideStartTime = DateTime.now();
        _glideDurationMs = 100;
        widget.onVisualPositionUpdate?.call(_toPoint);
        return;
      }

      final DateTime now = DateTime.now();
      if (_lastPacketTime != null) {
        final int elapsed = now.difference(_lastPacketTime!).inMilliseconds;
        if (elapsed >= 1500 && elapsed <= 25000) {
          _estimatedIntervalMs =
              ((_estimatedIntervalMs * 0.35) + (elapsed * 0.65)).round();
        }
      }
      _lastPacketTime = now;

      // Pick up smoothly from the current visual position on screen
      final LatLng currentVisual = _currentVisualPoint;
      _fromPoint = currentVisual;
      _toPoint = widget.point;

      // Heading: align along the road segment towards the target point
      _fromHeading = _currentVisualHeading;
      final double strideMeters = _dist(_fromPoint, _toPoint);
      if (isMoving && strideMeters > 1.5) {
        _toHeading = (_dist.bearing(_fromPoint, _toPoint) + 360.0) % 360.0;
      } else if (widget.heading > 0) {
        _toHeading = widget.heading;
      }

      _positionConfirmedFired = false;
      _glideStartTime = DateTime.now();

      if (isMoving) {
        // Continuous pacing: glide to target in durationMs, then keep coasting forward
        // so the vehicle never freezes dead in place while driving at speed between packets
        _glideDurationMs =
            max(3000, min(8000, (_estimatedIntervalMs * 0.95).round()));
        if (!_glideController.isAnimating) {
          _glideController.repeat();
        }
      } else {
        // Stopped/parked: settle cleanly in 400ms without coasting
        _glideDurationMs = 400;
        if (!_glideController.isAnimating) {
          _glideController.repeat();
        }
      }
    } else if (oldWidget.status != widget.status ||
        oldWidget.speed != widget.speed) {
      if (isMoving) {
        if (!_glideController.isAnimating) {
          _glideStartTime = DateTime.now();
          _glideDurationMs = 3000;
          _glideController.repeat();
        }
      } else {
        if (DateTime.now().difference(_glideStartTime).inMilliseconds >=
            _glideDurationMs) {
          _glideController.stop();
        }
      }
    } else if (oldWidget.heading != widget.heading &&
        widget.heading > 0 &&
        !_glideController.isAnimating) {
      _fromHeading = _currentVisualHeading;
      _toHeading = widget.heading;
      _glideStartTime = DateTime.now();
      _glideDurationMs = 400;
      _glideController.repeat();
    }
  }

  @override
  void dispose() {
    _glideController.removeListener(_onGlideTick);
    _glideController.dispose();
    super.dispose();
  }

  void _onGlideTick() {
    if (!mounted) return;
    final DateTime now = DateTime.now();
    final int elapsedMs = now.difference(_glideStartTime).inMilliseconds;

    if (!_positionConfirmedFired && elapsedMs >= _glideDurationMs) {
      _positionConfirmedFired = true;
      widget.onPositionConfirmed?.call(_toPoint);
      if (widget.status != VehicleStatus.moving || widget.speed < 1.5) {
        _glideController.stop();
      }
    }
    widget.onVisualPositionUpdate?.call(_currentVisualPoint);
  }

  // ── Position & Heading Interpolation ──────────────────────────────────────

  LatLng get _currentVisualPoint {
    final DateTime now = DateTime.now();
    final int elapsedMs = now.difference(_glideStartTime).inMilliseconds;

    // Phase 1: Gliding from _fromPoint to _toPoint
    if (elapsedMs < _glideDurationMs) {
      final double t = (elapsedMs / _glideDurationMs).clamp(0.0, 1.0);
      return LatLng(
        _fromPoint.latitude + (_toPoint.latitude - _fromPoint.latitude) * t,
        _fromPoint.longitude + (_toPoint.longitude - _fromPoint.longitude) * t,
      );
    }

    // Phase 2: Arrived at or passed _toPoint
    // If not moving or speed is low, stay firmly at _toPoint
    if (widget.status != VehicleStatus.moving || widget.speed < 1.5) {
      return _toPoint;
    }

    // ── Continuous True Dead-Reckoning Coasting (elapsedMs >= _glideDurationMs) ──
    // Moving vehicle covers (speed / 3.6) meters per second along current heading
    final double coastSeconds = (elapsedMs - _glideDurationMs) / 1000.0;
    // Cap coasting to 25 seconds or 350 meters to prevent unbounded drift if device goes offline
    final double cappedCoastSeconds = min(25.0, coastSeconds);
    final double metersPerSecond = widget.speed / 3.6;
    final double displacementMeters = min(350.0, metersPerSecond * cappedCoastSeconds);

    final double rad = _toHeading * (pi / 180.0);
    final double uEast = sin(rad);
    final double uNorth = cos(rad);

    final double cosLat = cos(_toPoint.latitude * (pi / 180.0)).abs().clamp(0.01, 1.0);
    final double deltaLat = (displacementMeters * uNorth) / 111320.0;
    final double deltaLng = (displacementMeters * uEast) / (111320.0 * cosLat);

    return LatLng(
      _toPoint.latitude + deltaLat,
      _toPoint.longitude + deltaLng,
    );
  }

  double get _currentVisualHeading {
    final DateTime now = DateTime.now();
    final int elapsedMs = now.difference(_glideStartTime).inMilliseconds;
    if (elapsedMs >= _glideDurationMs) {
      return _toHeading;
    }
    final double t = (elapsedMs / _glideDurationMs).clamp(0.0, 1.0);
    // Shortest-path angular interpolation
    final double diff = (_toHeading - _fromHeading) % 360.0;
    final double shortest = (2 * diff % 360.0) - diff;
    return (_fromHeading + shortest * t + 360.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glideController,
      builder: (BuildContext context, Widget? child) {
        return widget.builder(context, _currentVisualHeading);
      },
    );
  }
}
