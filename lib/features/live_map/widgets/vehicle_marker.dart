import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VEHICLE MARKER — Matches web app style:
//  Large translucent status-colored glow circle + small top-view vehicle icon
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
      duration: const Duration(milliseconds: 1800),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    if (widget.selected) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(VehicleMarkerPin old) {
    super.didUpdateWidget(old);
    final double newH = widget.headingOverride ?? widget.vehicle.heading;
    if ((newH - _lastHeading).abs() > 1.0) {
      double delta = newH - _lastHeading;
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
        return const Color(0xFF22C55E);   // green
      case VehicleStatus.idle:
        return const Color(0xFFEAB308);   // yellow
      case VehicleStatus.stopped:
        return const Color(0xFFF97316);   // orange (parked)
      case VehicleStatus.offline:
      default:
        return const Color(0xFFEF4444);   // red
    }
  }

  @override
  Widget build(BuildContext context) {
    // Competitor style: Long truck/vehicle marker.
    // Taller than it is wide.
    const double vehicleWidth = 28.0;
    const double vehicleHeight = 64.0;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxHeight: double.infinity,
        maxWidth: double.infinity,
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
              width: vehicleWidth,
              height: vehicleHeight,
              child: AnimatedBuilder(
                animation: _rotation,
                builder: (context, _) => Transform.rotate(
                  // Face the direction of travel (North = 0)
                  angle: _rotation.value * math.pi / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: CustomPaint(
                      painter: _CompactVehiclePainter(
                        status: widget.vehicle.status,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Realistic top-view Truck/Heavy Vehicle icon (Competitor style)
// ─────────────────────────────────────────────────────────────────────────────
class _CompactVehiclePainter extends CustomPainter {
  const _CompactVehiclePainter({required this.status});
  final VehicleStatus status;

  Color get _bodyColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF22C55E);   // green
      case VehicleStatus.idle:
        return const Color(0xFFEAB308);   // yellow
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444);   // red (matching competitor screenshot)
      case VehicleStatus.offline:
      default:
        return const Color(0xFF94A3B8);   // grey
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    
    // Truck body (Long rectangle)
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
    final RRect bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w, h),
      topLeft: Radius.circular(w * 0.15),
      topRight: Radius.circular(w * 0.15),
      bottomLeft: Radius.circular(w * 0.10),
      bottomRight: Radius.circular(w * 0.10),
    );
    
    // Draw shadow
    canvas.drawRRect(bodyRect.shift(const Offset(2, 4)), shadowPaint);

    // Draw main colored trailer/body
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _bodyColor,
          _bodyColor.withOpacity(0.8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(bodyRect, bodyPaint);

    // Draw front cabin (White block at the top)
    final double cabinHeight = h * 0.22;
    final RRect cabinRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.05, 0, w * 0.9, cabinHeight),
      topLeft: Radius.circular(w * 0.15),
      topRight: Radius.circular(w * 0.15),
      bottomLeft: Radius.circular(w * 0.05),
      bottomRight: Radius.circular(w * 0.05),
    );
    canvas.drawRRect(cabinRect, Paint()..color = Colors.white);

    // Draw small detail on the white cabin (e.g. blue/red logo dot like competitor)
    canvas.drawCircle(
      Offset(w * 0.5, cabinHeight * 0.45),
      w * 0.15,
      Paint()..color = _bodyColor,
    );
    canvas.drawCircle(
      Offset(w * 0.5, cabinHeight * 0.45),
      w * 0.05,
      Paint()..color = Colors.white,
    );

    // Draw connecting joint between cabin and trailer
    canvas.drawRect(
      Rect.fromLTWH(w * 0.2, cabinHeight, w * 0.6, h * 0.02),
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    // Draw subtle trailer roof lines
    final Paint linePaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.25, cabinHeight + h * 0.1), Offset(w * 0.25, h * 0.9), linePaint);
    canvas.drawLine(Offset(w * 0.75, cabinHeight + h * 0.1), Offset(w * 0.75, h * 0.9), linePaint);
  }

  @override
  bool shouldRepaint(_CompactVehiclePainter old) => old.status != status;
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.90),
        borderRadius: Corners.rXs,
        border: Border.all(color: color.withOpacity(0.65), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 6)],
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
