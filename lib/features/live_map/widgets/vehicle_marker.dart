import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VEHICLE MARKER — Premium 3D top-view fleet tracker style
//  • Rotates to match bearing/heading
//  • Status accent glow (moving=green, idle=amber, stopped=red, offline=gray)
//  • Selected vehicle has a bright blue pulsing ring
// ─────────────────────────────────────────────────────────────────────────────
class VehicleMarkerPin extends StatefulWidget {
  const VehicleMarkerPin({
    required this.vehicle,
    this.selected = false,
    this.showLabel = false,
    this.useSprite = false,
    this.headingOverride,
    super.key,
  });

  final Vehicle vehicle;
  final bool selected;
  final bool showLabel;
  final bool useSprite;
  final double? headingOverride;

  @override
  State<VehicleMarkerPin> createState() => _VehicleMarkerPinState();
}

class _VehicleMarkerPinState extends State<VehicleMarkerPin>
    with TickerProviderStateMixin {
  // Smooth rotation
  late AnimationController _rotController;
  late Animation<double> _rotation;
  double _lastHeading = 0;

  // Pulsing ring for selected vehicle
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _lastHeading = (widget.headingOverride ?? widget.vehicle.heading);
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rotation = Tween<double>(begin: _lastHeading, end: _lastHeading)
        .animate(CurvedAnimation(parent: _rotController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    if (widget.selected) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(VehicleMarkerPin old) {
    super.didUpdateWidget(old);

    // Heading rotation
    final double newHeading = widget.headingOverride ?? widget.vehicle.heading;
    if ((newHeading - _lastHeading).abs() > 1.0) {
      double delta = newHeading - _lastHeading;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      final double target = _lastHeading + delta;
      _rotation = Tween<double>(begin: _lastHeading, end: target)
          .animate(CurvedAnimation(parent: _rotController, curve: Curves.easeOut));
      _rotController.forward(from: 0);
      _lastHeading = target;
    }

    // Pulse animation on/off
    if (widget.selected && !old.selected) {
      _pulseController.repeat();
    } else if (!widget.selected && old.selected) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _rotController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(widget.vehicle.status);
    final bool selected = widget.selected;
    final double markerSize = selected ? 58.0 : 46.0;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showLabel) ...[
              _Label(
                text: widget.vehicle.displayName,
                color: AppColors.forStatus(widget.vehicle.status.key),
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: markerSize + 24,
              height: markerSize + 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Outer pulsing ring (selected only) ──────────────
                  if (selected)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _pulseScale.value,
                          child: Opacity(
                            opacity: _pulseOpacity.value,
                            child: Container(
                              width: markerSize + 12,
                              height: markerSize + 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF2563EB).withOpacity(0.25),
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ── Status glow shadow ring ──────────────────────────
                  Container(
                    width: markerSize + 8,
                    height: markerSize + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withOpacity(selected ? 0.20 : 0.12),
                    ),
                  ),

                  // ── Rotating vehicle icon ────────────────────────────
                  AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) {
                      return Transform.rotate(
                        angle: _rotation.value * math.pi / 180,
                        child: SizedBox(
                          width: markerSize,
                          height: markerSize,
                          child: CustomPaint(
                            painter: _TopViewVehiclePainter(
                              status: widget.vehicle.status,
                              selected: selected,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // ── Status dot at bottom ─────────────────────────────
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF22C55E); // Green
      case VehicleStatus.idle:
        return const Color(0xFFF59E0B); // Amber
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444); // Red
      case VehicleStatus.offline:
      default:
        return const Color(0xFF9CA3AF); // Gray
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAINTER — 3D top-view vehicle (SUV/truck silhouette)
//  Points UP (north) when heading=0. Rotated by the parent Transform.rotate.
// ─────────────────────────────────────────────────────────────────────────────
class _TopViewVehiclePainter extends CustomPainter {
  const _TopViewVehiclePainter({required this.status, required this.selected});

  final VehicleStatus status;
  final bool selected;

  Color get _bodyColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF1E293B);
      case VehicleStatus.idle:
        return const Color(0xFF1E293B);
      case VehicleStatus.stopped:
        return const Color(0xFF1E293B);
      case VehicleStatus.offline:
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get _accentColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF22C55E);
      case VehicleStatus.idle:
        return const Color(0xFFF59E0B);
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444);
      case VehicleStatus.offline:
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    // ── Drop shadow ─────────────────────────────────────────────────────
    final Path shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.32, h * 0.04, w * 0.64, h * 0.9),
        Radius.circular(w * 0.14),
      ));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.5), selected ? 10 : 6, true);

    // ── White background puck ────────────────────────────────────────────
    final Paint bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.34, h * 0.03, w * 0.68, h * 0.92),
        Radius.circular(w * 0.16),
      ),
      bgPaint,
    );

    // ── Vehicle body ─────────────────────────────────────────────────────
    final Paint bodyPaint = Paint()
      ..color = _bodyColor
      ..style = PaintingStyle.fill;

    // Main body shape - rounded rect representing the car body
    final Rect bodyRect = Rect.fromLTWH(cx - w * 0.28, h * 0.10, w * 0.56, h * 0.78);
    final RRect bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(w * 0.20),
      topRight: Radius.circular(w * 0.20),
      bottomLeft: Radius.circular(w * 0.10),
      bottomRight: Radius.circular(w * 0.10),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    // ── Windshield (front, lighter) ──────────────────────────────────────
    final Paint windshieldPaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.20, h * 0.12, w * 0.40, h * 0.20),
        Radius.circular(w * 0.10),
      ),
      windshieldPaint,
    );

    // ── Rear window (smaller) ────────────────────────────────────────────
    final Paint rearPaint = Paint()
      ..color = const Color(0xFF94A3B8).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.16, h * 0.65, w * 0.32, h * 0.14),
        Radius.circular(w * 0.06),
      ),
      rearPaint,
    );

    // ── Accent / headlights strip ────────────────────────────────────────
    final Paint accentPaint = Paint()
      ..color = _accentColor
      ..style = PaintingStyle.fill;

    // Front accent line (headlights band)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.25, h * 0.08, w * 0.50, h * 0.05),
        Radius.circular(w * 0.05),
      ),
      accentPaint,
    );

    // Left headlight
    canvas.drawCircle(
      Offset(cx - w * 0.17, h * 0.12),
      w * 0.06,
      accentPaint..color = _accentColor.withOpacity(0.9),
    );
    // Right headlight
    canvas.drawCircle(
      Offset(cx + w * 0.17, h * 0.12),
      w * 0.06,
      accentPaint,
    );

    // ── Body highlight (3D gloss effect) ────────────────────────────────
    final Paint highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.22, h * 0.18, w * 0.16, h * 0.35),
        Radius.circular(w * 0.06),
      ),
      highlightPaint,
    );

    // ── Left & right wheels ──────────────────────────────────────────────
    final Paint wheelPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    final Paint wheelRimPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    // Front-left wheel
    _drawWheel(canvas, Offset(cx - w * 0.30, h * 0.22), w * 0.08, wheelPaint, wheelRimPaint);
    // Front-right wheel
    _drawWheel(canvas, Offset(cx + w * 0.30, h * 0.22), w * 0.08, wheelPaint, wheelRimPaint);
    // Rear-left wheel
    _drawWheel(canvas, Offset(cx - w * 0.30, h * 0.72), w * 0.08, wheelPaint, wheelRimPaint);
    // Rear-right wheel
    _drawWheel(canvas, Offset(cx + w * 0.30, h * 0.72), w * 0.08, wheelPaint, wheelRimPaint);

    // ── Rear tail-lights ─────────────────────────────────────────────────
    final Paint tailPaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.85)
      ..style = PaintingStyle.fill;
    // Left tail
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.24, h * 0.82, w * 0.10, h * 0.05),
        Radius.circular(w * 0.03),
      ),
      tailPaint,
    );
    // Right tail
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + w * 0.14, h * 0.82, w * 0.10, h * 0.05),
        Radius.circular(w * 0.03),
      ),
      tailPaint,
    );

    // ── Center stripe / roof detail ──────────────────────────────────────
    final Paint roofPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.05, h * 0.35, w * 0.10, h * 0.28),
        Radius.circular(w * 0.03),
      ),
      roofPaint,
    );
  }

  void _drawWheel(Canvas canvas, Offset center, double radius,
      Paint wheelPaint, Paint rimPaint) {
    canvas.drawCircle(center, radius, wheelPaint);
    canvas.drawCircle(center, radius * 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(_TopViewVehiclePainter old) =>
      old.status != status || old.selected != selected;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Label chip displayed above the marker when showLabel=true
// ─────────────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  const _Label({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.90),
        borderRadius: Corners.rXs,
        border: Border.all(color: color.withOpacity(0.65), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 6),
        ],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
