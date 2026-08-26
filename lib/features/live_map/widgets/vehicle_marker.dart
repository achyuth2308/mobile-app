import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VEHICLE MARKER — Classic Google Maps-style teardrop drop pin
//  Color matches vehicle status. Selected pin has outer ring + bigger size.
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
    with SingleTickerProviderStateMixin {
  // Pulse animation for selected pin
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.8)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    if (widget.selected) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(VehicleMarkerPin old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _pulseController.repeat();
    } else if (!widget.selected && old.selected) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static Color _pinColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF22C55E); // Green
      case VehicleStatus.idle:
        return const Color(0xFFF97316); // Orange
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444); // Red
      case VehicleStatus.offline:
      default:
        return const Color(0xFF94A3B8); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color pinColor = _pinColor(widget.vehicle.status);
    final bool selected = widget.selected;
    final double pinW = selected ? 38.0 : 32.0;
    final double pinH = selected ? 54.0 : 46.0;

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
              const SizedBox(height: 3),
            ],
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Outer pulsing ring for selected/followed vehicle
                if (selected)
                  Positioned(
                    top: pinW * 0.05,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _pulseScale.value,
                            child: Opacity(
                              opacity: _pulseOpacity.value,
                              child: Container(
                                width: pinW,
                                height: pinW,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: pinColor.withOpacity(0.25),
                                  border: Border.all(
                                    color: pinColor.withOpacity(0.7),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // The teardrop pin itself
                SizedBox(
                  width: pinW + 12,
                  height: pinH + 4,
                  child: Center(
                    child: CustomPaint(
                      size: Size(pinW, pinH),
                      painter: _TearDropPinPainter(
                        color: pinColor,
                        selected: selected,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Paints a classic teardrop map pin.
//  The circle (head) is at the top, the pointed tail is at the bottom.
//  Alignment.bottomCenter on the Marker ensures the tip sits exactly on the coord.
// ─────────────────────────────────────────────────────────────────────────────
class _TearDropPinPainter extends CustomPainter {
  const _TearDropPinPainter({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2; // radius of the circle head

    // The circle occupies the top portion; the tail comes from below the circle.
    final Offset center = Offset(w / 2, r);

    // ── Shadow ───────────────────────────────────────────────────────────
    final Path shadow = _buildPinPath(w, h, r);
    canvas.drawShadow(shadow, Colors.black.withOpacity(0.4), selected ? 8 : 5, true);

    // ── Main pin fill ────────────────────────────────────────────────────
    final Paint fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(_buildPinPath(w, h, r), fill);

    // ── Lighter inner circle (3D dome effect) ────────────────────────────
    final Paint innerFill = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r * 0.62, innerFill);

    // ── White gloss highlight ────────────────────────────────────────────
    final Paint gloss = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - r * 0.22, center.dy - r * 0.22),
      r * 0.28,
      gloss,
    );

    // ── White ring border ────────────────────────────────────────────────
    final Paint border = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..strokeWidth = selected ? 2.2 : 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(_buildPinPath(w, h, r), border);
  }

  /// Builds the teardrop path: circle at top, Bezier tail pointing down.
  Path _buildPinPath(double w, double h, double r) {
    final double cx = w / 2;
    final Offset circleCenter = Offset(cx, r);
    final Path path = Path();

    // Start at the bottom left tangent of the circle
    // Angle from center to tangent: approx atan(tail half-width / 0) = 90° offset
    // We sweep the circle from bottom-left (135°) clockwise around to bottom-right (45°)
    // then bezier curves to the sharp tip at the bottom.

    const double startAngle = 135 * math.pi / 180; // bottom-left of circle
    const double endAngle   = 45  * math.pi / 180; // bottom-right of circle
    const double sweepAngle = (360 - 90) * math.pi / 180; // 270° clockwise

    path.addArc(
      Rect.fromCircle(center: circleCenter, radius: r),
      startAngle,
      sweepAngle,
    );

    // From the end of the arc (bottom-right tangent) curve to the tip
    final double bRx = cx + r * math.cos(endAngle);
    final double bRy = r + r * math.sin(endAngle);

    // Bezier control points converge toward the tip
    path.quadraticBezierTo(cx + r * 0.55, h * 0.72, cx, h);
    path.quadraticBezierTo(cx - r * 0.55, h * 0.72, cx + r * math.cos(startAngle), r + r * math.sin(startAngle));

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_TearDropPinPainter old) =>
      old.color != color || old.selected != selected;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Label chip displayed above the marker
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
