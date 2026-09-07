import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
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
        return const Color(0xFF00A651); // Vibrant green matching screenshot
      case VehicleStatus.idle:
        return const Color(0xFFF59E0B); // Amber / Yellow
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444); // Red
      case VehicleStatus.offline:
        return const Color(0xFF64748B); // Slate grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color pinColor = statusColor(widget.vehicle.status);

    // Marker dimensions
    const double pinWidth = 40.0;
    const double pinHeight = 50.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          _Label(
            text: widget.vehicle.displayName,
            color: pinColor,
          ),
          const SizedBox(height: 2),
        ],
        SizedBox(
          width: pinWidth,
          height: pinHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Pulse effect when selected
              if (widget.selected)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final double scale = 1.0 + (_pulseController.value * 0.20);
                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
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

              // Main Teardrop Pin Shape
              CustomPaint(
                size: const Size(pinWidth, pinHeight),
                painter: _TeardropPinPainter(color: pinColor),
              ),

              // White Vehicle Icon in center of the pin circle
              const Positioned(
                top: 4.5,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Center(
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final double r = w / 2;

    final Path path = Path();
    // Start at bottom tip
    path.moveTo(w / 2, h);
    // Left curve up to left edge of top circle
    path.cubicTo(w * 0.08, h * 0.65, 0, r * 1.35, 0, r);
    // Top circle arc
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Right curve back down to bottom tip
    path.cubicTo(w, r * 1.35, w * 0.92, h * 0.65, w / 2, h);
    path.close();

    // Soft drop shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    // Main pin body fill
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Subtle crisp white border stroke
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
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
