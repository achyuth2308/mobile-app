import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VEHICLE MARKER — Teardrop map pin with white vehicle icon (as requested):
//  Compact status-colored pin with white vehicle icon in the circle head.
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
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.selected) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VehicleMarkerPin old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _pulseController.repeat(reverse: true);
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

  static Color statusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF00A651); // Green (Moving)
      case VehicleStatus.idle:
        return const Color(0xFFF59E0B); // Yellow (Idle)
      case VehicleStatus.stopped:
        return const Color(0xFF64748B); // Gray (Parking)
      case VehicleStatus.offline:
        return const Color(0xFFEF4444); // Red (Offline)
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color pinColor = statusColor(widget.vehicle.status);

    // Teardrop Marker dimensions — 24px width, 32px height
    const double pinWidth = 24.0;
    const double pinHeight = 32.0;

    final Widget pinWidget = SizedBox(
      width: pinWidth,
      height: pinHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Pulse effect when selected (pulsing ring around the head circle)
          if (widget.selected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final double scale = 1.0 + (_pulseController.value * 0.35);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: pinWidth + 6,
                        height: pinWidth + 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pinColor.withValues(alpha: 0.35),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Custom Teardrop Pin Shape (Tip at bottom center 14, 36) — ALWAYS UPRIGHT
          CustomPaint(
            size: const Size(pinWidth, pinHeight),
            painter: _TeardropPinPainter(color: pinColor),
          ),

          // White Vehicle Icon centered in top circular head
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pinWidth,
            child: Center(
              child: Icon(
                VehicleIcons.forType(widget.vehicle.type),
                color: Colors.white,
                size: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.showLabel) return pinWidget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(
          text: widget.vehicle.displayName,
          color: pinColor,
        ),
        const SizedBox(height: 2),
        pinWidget,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Teardrop Map Pin Painter (Matching Google Maps / standard GPS location pin)
// ─────────────────────────────────────────────────────────────────────────────
class _TeardropPinPainter extends CustomPainter {
  final Color color;

  const _TeardropPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    const double strokeWidth = 1.5;
    // Outer stroke edge lands at exactly y = 36.0 to align perfectly with Alignment.bottomCenter
    final double tipY = h - (strokeWidth / 2.0); // 35.25
    final double tipX = w / 2.0; // 14.0
    final double r = w / 2.0; // 14.0

    // Build the teardrop path — sharp tip at bottom center (14.0, 35.25)
    final Path path = Path();
    path.moveTo(tipX, tipY);
    path.cubicTo(w * 0.10, tipY * 0.72, 0.0, r * 1.4, 0.0, r);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);
    path.cubicTo(w, r * 1.4, w * 0.90, tipY * 0.72, tipX, tipY);
    path.close();

    // Subtle shadow behind pin
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawPath(path.shift(const Offset(0.0, 0.5)), shadowPaint);

    // Pin body fill
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // White border stroke
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_TeardropPinPainter oldDelegate) => oldDelegate.color != color;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
        borderRadius: Corners.rXs,
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 4)],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9.5,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
