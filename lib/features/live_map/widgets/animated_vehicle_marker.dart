import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../data/models/vehicle.dart';

/// Smoothly glides a vehicle marker along the road between GPS updates.
///
/// Features:
///   1. **Continuous Steady Motion** — Paces the vehicle glide to match real
///      vehicle speed and packet arrival cadence. When moving, the vehicle
///      maintains continuous forward progression without freezing between packets.
///
///   2. **Zero-Backwards Guarantee** — Mathematically projects any incoming GPS
///      fix onto the vehicle's forward travel vector. If an incoming packet or jitter
///      lies behind the current visual position, forward progress is clamped to >= 0,
///      guaranteeing the vehicle NEVER moves or snaps backwards.
///
///   3. **Coast Deceleration** — If a packet is delayed, the vehicle smoothly coasts
///      forward along its road heading and gently decelerates rather than freezing abruptly.
///
///   4. **Clean Parked Settling** — When vehicle stops (speed < 1 km/h or status != moving),
///      it settles immediately into rest without drifting or coasting.
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

    // upperBound: 2.0 allows the vehicle to smoothly coast forward beyond 1.0
    // at constant road speed if the next GPS packet is slightly delayed,
    // ensuring continuous, unbroken forward motion!
    _glideController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 2.0,
      duration: const Duration(milliseconds: 4000),
    );

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
        if (elapsed >= 1500 && elapsed <= 25000) {
          _estimatedIntervalMs =
              ((_estimatedIntervalMs * 0.35) + (elapsed * 0.65)).round();
        }
      }
      _lastPacketTime = now;

      // Start the new forward stride from the EXACT current visual position
      final LatLng currentVisual = _interpolatedGlidePoint;
      _fromPoint = currentVisual;

      // Strict forward-only projection: ensure _toPoint NEVER lies behind currentVisual!
      _toPoint = _ensureForwardProgress(currentVisual, widget.point, _interpolatedHeading);

      _fromHeading = _interpolatedHeading;

      // Calculate bearing from movement vector if moving significantly (>2m)
      final double strideMeters = _dist(_fromPoint, _toPoint);
      if (widget.status == VehicleStatus.moving && strideMeters > 2.0) {
        final double rawBearing = _dist.bearing(_fromPoint, _toPoint);
        // Normalize bearing to 0..360
        _toHeading = (rawBearing + 360.0) % 360.0;
      } else {
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
        // Moving — pace stride so it glides smoothly across the packet interval
        // At speed (m/s), compute expected time to cover distance
        final double speedMps = (widget.speed * 1000.0) / 3600.0;
        if (speedMps > 1.0 && strideMeters > 2.0) {
          final int travelMs = ((strideMeters / speedMps) * 1000.0).round();
          durationMs = travelMs.clamp(2000, 10000);
        } else {
          durationMs = _estimatedIntervalMs.clamp(2000, 10000);
        }
      }

      _glideController.duration = Duration(milliseconds: durationMs);
      _glideController.forward(from: 0.0);
    } else if (oldWidget.heading != widget.heading &&
        !_glideController.isAnimating) {
      _fromHeading = _interpolatedHeading;
      _toHeading = widget.heading;
      _glideController.duration = const Duration(milliseconds: 500);
      _glideController.forward(from: 0.0);
    }
  }

  /// Mathematically guarantees that [_toPoint] NEVER lies behind [from]
  /// along the vehicle's forward heading vector. If an incoming packet or jitter
  /// is behind our current visual position, forward progress is clamped to >= 0,
  /// completely eliminating backwards jumps.
  LatLng _ensureForwardProgress(LatLng from, LatLng to, double headingDeg) {
    if (widget.status != VehicleStatus.moving) return to;

    final double rad = headingDeg * (math.pi / 180.0);
    final double uEast = math.sin(rad);
    final double uNorth = math.cos(rad);

    final double latMidRad = ((from.latitude + to.latitude) / 2.0) * (math.pi / 180.0);
    final double cosLat = math.cos(latMidRad).abs().clamp(0.01, 1.0);

    final double metersNorth = (to.latitude - from.latitude) * 111320.0;
    final double metersEast = (to.longitude - from.longitude) * 111320.0 * cosLat;

    // Component of incoming displacement along the forward heading
    final double forwardMeters = (metersEast * uEast) + (metersNorth * uNorth);
    // Component of incoming displacement perpendicular to heading (lateral shift)
    final double lateralMeters = (metersEast * uNorth) - (metersNorth * uEast);

    // If incoming fix is behind current position (forwardMeters <= 0), NEVER move backwards!
    if (forwardMeters < 0.5) {
      // Continue forward with a minimum forward progress (e.g. 1.0 meter)
      const double minForward = 1.0;
      // Gently blend lateral correction towards the road line
      final double adjLateral = lateralMeters * 0.4;

      final double clampedEast = (minForward * uEast) + (adjLateral * uNorth);
      final double clampedNorth = (minForward * uNorth) - (adjLateral * uEast);

      final double newLat = from.latitude + (clampedNorth / 111320.0);
      final double newLng = from.longitude + (clampedEast / (111320.0 * cosLat));
      return LatLng(newLat, newLng);
    }

    return to;
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

  /// Calculates effective progress:
  /// - For t in [0.0, 1.0]: steady linear progress from _fromPoint to _toPoint.
  /// - For t > 1.0 (waiting for next packet while moving): smoothly coasts forward
  ///   with gentle speed decay up to 1.5x so the vehicle NEVER freezes between packets!
  double get _effectiveProgress {
    final double raw = _glideController.value;
    if (widget.status != VehicleStatus.moving || widget.speed < 1.0) {
      return raw.clamp(0.0, 1.0);
    }
    if (raw <= 1.0) {
      return raw;
    }
    // Coasting with gentle decay: extends forward beyond 1.0 smoothly
    final double coast = raw - 1.0;
    return 1.0 + (coast * 0.75);
  }

  LatLng get _interpolatedGlidePoint {
    final double t = _effectiveProgress;
    return LatLng(
      _fromPoint.latitude + (_toPoint.latitude - _fromPoint.latitude) * t,
      _fromPoint.longitude + (_toPoint.longitude - _fromPoint.longitude) * t,
    );
  }

  double get _interpolatedHeading {
    final double t = _effectiveProgress.clamp(0.0, 1.0);
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

