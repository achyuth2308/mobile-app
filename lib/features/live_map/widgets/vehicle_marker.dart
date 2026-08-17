import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';

/// ─────────────────────────────────────────────────────────────────────
///  VEHICLE MARKER — bold arrowhead, premium Google Maps style
/// ─────────────────────────────────────────────────────────────────────
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
  // Smooth rotation via animation
  late AnimationController _rotController;
  late Animation<double> _rotation;
  double _lastHeading = 0;

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
  }

  @override
  void didUpdateWidget(VehicleMarkerPin old) {
    super.didUpdateWidget(old);
    final double newHeading = widget.headingOverride ?? widget.vehicle.heading;
    if ((newHeading - _lastHeading).abs() > 1.0) {
      // Always take the shortest rotation arc
      double delta = newHeading - _lastHeading;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      final double target = _lastHeading + delta;
      _rotation = Tween<double>(begin: _lastHeading, end: target)
          .animate(CurvedAnimation(parent: _rotController, curve: Curves.easeOut));
      _rotController.forward(from: 0);
      _lastHeading = target;
    }
  }

  @override
  void dispose() {
    _rotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool offline = widget.vehicle.status == VehicleStatus.offline;
    final bool selected = widget.selected;

    // Arrow size: big and bold
    final double size = selected ? 64.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          _Label(
            text: widget.vehicle.displayName,
            color: AppColors.forStatus(widget.vehicle.status.key),
          ),
          const SizedBox(height: 4),
        ],

        AnimatedBuilder(
          animation: _rotation,
          builder: (context, _) {
            return Transform.rotate(
              angle: _rotation.value * math.pi / 180,
              child: CustomPaint(
                size: Size(size, size),
                painter: _ArrowHeadPainter(
                  offline: offline,
                  selected: selected,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Draws a thick, bold, premium navigation arrowhead — clean, no extras.
///
/// Shape concept (points UP = north when heading=0):
///
///          ▲  ← sharp tip at top center
///         ▲ ▲
///        █████
///        █   █  ← concave notch at the bottom
///         ▼ ▼
///
class _ArrowHeadPainter extends CustomPainter {
  const _ArrowHeadPainter({required this.offline, required this.selected});

  final bool offline;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    // ── 1. White Puck Background & Shadow ────────────────────────────
    final Path puck = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: cx));
    
    // Soft drop shadow
    canvas.drawShadow(puck, Colors.black.withOpacity(0.4), selected ? 12 : 6, true);
    
    // Solid white fill
    final Paint puckPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(puck, puckPaint);

    // ── 2. 3D Arrow ──────────────────────────────────────────────────
    // The arrow is drawn in two halves (left and right) with different
    // shades of blue to create a 3D lighting effect.
    final double aw = w * 0.45; // arrow total width
    final double ah = h * 0.60; // arrow total height
    
    // Left half (lighter side facing the "sun")
    final Path leftArrow = Path();
    leftArrow.moveTo(cx, cy - ah * 0.6); // sharp tip
    leftArrow.lineTo(cx - aw / 2, cy + ah * 0.4); // left shoulder
    leftArrow.lineTo(cx, cy + ah * 0.15); // center notch
    leftArrow.close();

    // Right half (darker side in shadow)
    final Path rightArrow = Path();
    rightArrow.moveTo(cx, cy - ah * 0.6); // sharp tip
    rightArrow.lineTo(cx + aw / 2, cy + ah * 0.4); // right shoulder
    rightArrow.lineTo(cx, cy + ah * 0.15); // center notch
    rightArrow.close();

    final Color leftColor = offline 
        ? const Color(0xFFBDBDBD) 
        : const Color(0xFF4285F4); // Google Blue Light
    final Color rightColor = offline 
        ? const Color(0xFF757575) 
        : const Color(0xFF1967D2); // Google Blue Dark

    final Paint leftPaint = Paint()
      ..color = leftColor
      ..style = PaintingStyle.fill;

    final Paint rightPaint = Paint()
      ..color = rightColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(leftArrow, leftPaint);
    canvas.drawPath(rightArrow, rightPaint);
  }

  @override
  bool shouldRepaint(_ArrowHeadPainter old) =>
      old.offline != offline || old.selected != selected;
}

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
        color: const Color(0xFF111827).withOpacity(0.88),
        borderRadius: Corners.rXs,
        border: Border.all(color: color.withOpacity(0.6), width: 1.2),
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

/// Cluster bubble
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final double size = count < 10 ? 40 : count < 50 ? 48 : 56;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brand.withOpacity(0.22),
      ),
      child: Center(
        child: Container(
          width: size * 0.74,
          height: size * 0.74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
            border: Border.all(color: Colors.white.withOpacity(0.92), width: 2.2),
            boxShadow: [
              BoxShadow(color: AppColors.brand.withOpacity(0.4), blurRadius: 12),
            ],
          ),
          child: Center(
            child: Text(
              count > 999 ? '999+' : '$count',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w700,
                fontSize: count < 100 ? 15 : 12.5,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
