import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VEHICLE MARKER — Premium 3D top-view, direction-correct, vibrant status colors
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
  late AnimationController _rotController;
  late Animation<double> _rotation;
  double _lastHeading = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    _lastHeading = widget.headingOverride ?? widget.vehicle.heading;

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
    _pulseScale = Tween<double>(begin: 1.0, end: 1.65)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.65, end: 0.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    if (widget.selected) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(VehicleMarkerPin old) {
    super.didUpdateWidget(old);

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

  static Color _statusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF22C55E);
      case VehicleStatus.idle:
        return const Color(0xFFF59E0B);
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444);
      case VehicleStatus.offline:
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(widget.vehicle.status);
    final bool selected = widget.selected;
    final double markerSize = selected ? 60.0 : 48.0;

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
              width: markerSize + 28,
              height: markerSize + 28,
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
                              width: markerSize + 14,
                              height: markerSize + 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF3B82F6),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ── Status glow halo ─────────────────────────────────
                  Container(
                    width: markerSize + 10,
                    height: markerSize + 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withOpacity(selected ? 0.22 : 0.14),
                    ),
                  ),

                  // ── Rotating 3D vehicle ──────────────────────────────
                  AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) {
                      // +180° corrects the reversed direction so the front
                      // faces the direction of travel (bearing convention).
                      return Transform.rotate(
                        angle: (_rotation.value + 180) * math.pi / 180,
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

                  // ── Small status dot at edge ─────────────────────────
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.55),
                            blurRadius: 5,
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAINTER — Vibrant colored top-view vehicle body
//  Front faces UP (north) when heading=0. Parent adds 180° offset so actual
//  bearing aligns correctly with map north.
// ─────────────────────────────────────────────────────────────────────────────
class _TopViewVehiclePainter extends CustomPainter {
  const _TopViewVehiclePainter({required this.status, required this.selected});

  final VehicleStatus status;
  final bool selected;

  // Primary body color matches vehicle status
  Color get _bodyColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF16A34A); // Rich green
      case VehicleStatus.idle:
        return const Color(0xFFD97706); // Amber
      case VehicleStatus.stopped:
        return const Color(0xFFDC2626); // Red
      case VehicleStatus.offline:
      default:
        return const Color(0xFF64748B); // Slate gray
    }
  }

  Color get _bodyLight {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF22C55E);
      case VehicleStatus.idle:
        return const Color(0xFFFBBF24);
      case VehicleStatus.stopped:
        return const Color(0xFFF87171);
      case VehicleStatus.offline:
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    // ── Drop shadow under the whole marker ──────────────────────────────
    final Path shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.30, h * 0.05, w * 0.60, h * 0.88),
        Radius.circular(w * 0.15),
      ));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.45), selected ? 10 : 6, true);

    // ── White puck background ────────────────────────────────────────────
    final Paint bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.32, h * 0.04, w * 0.64, h * 0.90),
        Radius.circular(w * 0.16),
      ),
      bgPaint,
    );

    // ── Main vehicle body ────────────────────────────────────────────────
    final Paint bodyPaint = Paint()
      ..color = _bodyColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - w * 0.26, h * 0.08, w * 0.52, h * 0.80),
        topLeft: Radius.circular(w * 0.18),
        topRight: Radius.circular(w * 0.18),
        bottomLeft: Radius.circular(w * 0.09),
        bottomRight: Radius.circular(w * 0.09),
      ),
      bodyPaint,
    );

    // ── Gloss highlight on body (3D effect) ─────────────────────────────
    final Paint glossPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.18, h * 0.12, w * 0.14, h * 0.38),
        Radius.circular(w * 0.06),
      ),
      glossPaint,
    );

    // ── Windshield (front, top of canvas) — white/light glass ───────────
    final Paint windshieldPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.17, h * 0.11, w * 0.34, h * 0.18),
        Radius.circular(w * 0.10),
      ),
      windshieldPaint,
    );

    // ── Headlights (front, bright accent color) ──────────────────────────
    final Paint headlightPaint = Paint()
      ..color = _bodyLight
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..style = PaintingStyle.fill;
    // Left headlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.24, h * 0.08, w * 0.10, h * 0.06),
        Radius.circular(w * 0.03),
      ),
      headlightPaint,
    );
    // Right headlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + w * 0.14, h * 0.08, w * 0.10, h * 0.06),
        Radius.circular(w * 0.03),
      ),
      headlightPaint,
    );

    // ── Rear window (smaller, bottom) ────────────────────────────────────
    final Paint rearWindowPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.14, h * 0.66, w * 0.28, h * 0.13),
        Radius.circular(w * 0.05),
      ),
      rearWindowPaint,
    );

    // ── Tail lights (red, bottom) ─────────────────────────────────────────
    final Paint tailPaint = Paint()
      ..color = const Color(0xFFFF2D2D).withOpacity(0.90)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.23, h * 0.80, w * 0.09, h * 0.05),
        Radius.circular(w * 0.025),
      ),
      tailPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + w * 0.14, h * 0.80, w * 0.09, h * 0.05),
        Radius.circular(w * 0.025),
      ),
      tailPaint,
    );

    // ── Wheels (four corners) ─────────────────────────────────────────────
    final Paint wheelPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    final Paint rimPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;

    _wheel(canvas, Offset(cx - w * 0.28, h * 0.21), w * 0.075, wheelPaint, rimPaint);
    _wheel(canvas, Offset(cx + w * 0.28, h * 0.21), w * 0.075, wheelPaint, rimPaint);
    _wheel(canvas, Offset(cx - w * 0.28, h * 0.72), w * 0.075, wheelPaint, rimPaint);
    _wheel(canvas, Offset(cx + w * 0.28, h * 0.72), w * 0.075, wheelPaint, rimPaint);
  }

  void _wheel(Canvas canvas, Offset center, double r, Paint tire, Paint rim) {
    canvas.drawCircle(center, r, tire);
    canvas.drawCircle(center, r * 0.48, rim);
  }

  @override
  bool shouldRepaint(_TopViewVehiclePainter old) =>
      old.status != status || old.selected != selected;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Label chip above the marker
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
