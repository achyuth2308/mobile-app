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
        return const Color(0xFFF97316);   // orange
      case VehicleStatus.stopped:
        return const Color(0xFFEF4444);   // red
      case VehicleStatus.offline:
      default:
        return const Color(0xFF94A3B8);   // gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(widget.vehicle.status);
    // Large glow circle (dominant) + small vehicle on top — matching web app
    const double glowSize = 56.0;
    const double vehicleSize = 26.0;

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
              width: glowSize + 20,
              height: glowSize + 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Outer pulsing ripple (selected/followed vehicle) ──
                  if (widget.selected)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity: _pulseOpacity.value,
                          child: Container(
                            width: glowSize + 8,
                            height: glowSize + 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor.withOpacity(0.30),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Large translucent glow circle (main visual) ────────
                  Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withOpacity(0.28),
                      border: Border.all(
                        color: statusColor.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // ── Small top-view vehicle icon (rotates with heading) ─
                  AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) => Transform.rotate(
                      // +180° corrects bearing so front faces direction of travel
                      angle: (_rotation.value + 180) * math.pi / 180,
                      child: SizedBox(
                        width: vehicleSize,
                        height: vehicleSize,
                        child: CustomPaint(
                          painter: _CompactVehiclePainter(
                            status: widget.vehicle.status,
                          ),
                        ),
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
//  Small compact top-view vehicle icon — clean and minimal
// ─────────────────────────────────────────────────────────────────────────────
class _CompactVehiclePainter extends CustomPainter {
  const _CompactVehiclePainter({required this.status});
  final VehicleStatus status;

  Color get _bodyColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF15803D);
      case VehicleStatus.idle:
        return const Color(0xFFC2410C);
      case VehicleStatus.stopped:
        return const Color(0xFFB91C1C);
      case VehicleStatus.offline:
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    // Vehicle body
    final Paint body = Paint()..color = _bodyColor;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - w * 0.32, h * 0.06, w * 0.64, h * 0.86),
        topLeft: Radius.circular(w * 0.22),
        topRight: Radius.circular(w * 0.22),
        bottomLeft: Radius.circular(w * 0.10),
        bottomRight: Radius.circular(w * 0.10),
      ),
      body,
    );

    // Windshield (white, front/top)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.20, h * 0.09, w * 0.40, h * 0.20),
        Radius.circular(w * 0.10),
      ),
      Paint()..color = Colors.white.withOpacity(0.60),
    );

    // Rear window (white, smaller, bottom)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.14, h * 0.66, w * 0.28, h * 0.14),
        Radius.circular(w * 0.06),
      ),
      Paint()..color = Colors.white.withOpacity(0.38),
    );

    // Wheels (dark, four corners)
    final Paint wh = Paint()..color = Colors.black.withOpacity(0.65);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.42, h * 0.14, w * 0.14, h * 0.22), Radius.circular(w * 0.04)), wh);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + w * 0.28, h * 0.14, w * 0.14, h * 0.22), Radius.circular(w * 0.04)), wh);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.42, h * 0.62, w * 0.14, h * 0.22), Radius.circular(w * 0.04)), wh);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx + w * 0.28, h * 0.62, w * 0.14, h * 0.22), Radius.circular(w * 0.04)), wh);

    // Gloss highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.26, h * 0.14, w * 0.12, h * 0.30),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withOpacity(0.20),
    );
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
