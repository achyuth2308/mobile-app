import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VEHICLE MARKER — Top-view vehicle icon (matches web app style)
//  Vibrant status colors, pulsing ring for selected vehicle.
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
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.7)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(begin: 0.60, end: 0.0)
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
        return const Color(0xFF22C55E);
      case VehicleStatus.idle:
        return const Color(0xFFF97316);
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
              width: markerSize + 28,
              height: markerSize + 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing ring for selected/followed vehicle
                  if (selected)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _pulseScale.value,
                          child: Opacity(
                            opacity: _pulseOpacity.value,
                            child: Container(
                              width: markerSize + 16,
                              height: markerSize + 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withOpacity(0.20),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.8),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Status glow halo
                  Container(
                    width: markerSize + 8,
                    height: markerSize + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor.withOpacity(selected ? 0.18 : 0.10),
                    ),
                  ),

                  // Rotating top-view vehicle — +180 deg corrects bearing direction
                  AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) {
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

                  // Small status dot at bottom edge
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
//  Top-view vehicle painter — vibrant status-colored body
// ─────────────────────────────────────────────────────────────────────────────
class _TopViewVehiclePainter extends CustomPainter {
  const _TopViewVehiclePainter({required this.status, required this.selected});

  final VehicleStatus status;
  final bool selected;

  Color get _bodyColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF16A34A);
      case VehicleStatus.idle:
        return const Color(0xFFEA580C);
      case VehicleStatus.stopped:
        return const Color(0xFFDC2626);
      case VehicleStatus.offline:
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get _accentColor {
    switch (status) {
      case VehicleStatus.moving:
        return const Color(0xFF4ADE80);
      case VehicleStatus.idle:
        return const Color(0xFFFB923C);
      case VehicleStatus.stopped:
        return const Color(0xFFF87171);
      case VehicleStatus.offline:
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    // Shadow
    final Path shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.30, h * 0.05, w * 0.60, h * 0.88),
        Radius.circular(w * 0.14),
      ));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.40), selected ? 10 : 6, true);

    // White puck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.32, h * 0.04, w * 0.64, h * 0.90),
        Radius.circular(w * 0.16),
      ),
      Paint()..color = Colors.white,
    );

    // Vehicle body
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - w * 0.25, h * 0.08, w * 0.50, h * 0.80),
        topLeft: Radius.circular(w * 0.18),
        topRight: Radius.circular(w * 0.18),
        bottomLeft: Radius.circular(w * 0.09),
        bottomRight: Radius.circular(w * 0.09),
      ),
      Paint()..color = _bodyColor,
    );

    // Gloss highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.17, h * 0.12, w * 0.12, h * 0.36),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withOpacity(0.18),
    );

    // Windshield (top/front)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.16, h * 0.11, w * 0.32, h * 0.17),
        Radius.circular(w * 0.09),
      ),
      Paint()..color = Colors.white.withOpacity(0.50),
    );

    // Headlights (bright accent)
    final Paint hl = Paint()..color = _accentColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.23, h * 0.08, w * 0.09, h * 0.055),
        Radius.circular(w * 0.025),
      ),
      hl,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + w * 0.14, h * 0.08, w * 0.09, h * 0.055),
        Radius.circular(w * 0.025),
      ),
      hl,
    );

    // Rear window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.13, h * 0.66, w * 0.26, h * 0.12),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withOpacity(0.32),
    );

    // Tail lights
    final Paint tl = Paint()..color = const Color(0xFFFF3B30).withOpacity(0.88);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.22, h * 0.80, w * 0.08, h * 0.048),
        Radius.circular(w * 0.022),
      ),
      tl,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + w * 0.14, h * 0.80, w * 0.08, h * 0.048),
        Radius.circular(w * 0.022),
      ),
      tl,
    );

    // Wheels
    final Paint wh = Paint()..color = const Color(0xFF1E293B);
    final Paint rim = Paint()..color = const Color(0xFFCBD5E1);
    _wheel(canvas, Offset(cx - w * 0.28, h * 0.21), w * 0.074, wh, rim);
    _wheel(canvas, Offset(cx + w * 0.28, h * 0.21), w * 0.074, wh, rim);
    _wheel(canvas, Offset(cx - w * 0.28, h * 0.72), w * 0.074, wh, rim);
    _wheel(canvas, Offset(cx + w * 0.28, h * 0.72), w * 0.074, wh, rim);
  }

  void _wheel(Canvas canvas, Offset c, double r, Paint tire, Paint rim) {
    canvas.drawCircle(c, r, tire);
    canvas.drawCircle(c, r * 0.46, rim);
  }

  @override
  bool shouldRepaint(_TopViewVehiclePainter old) =>
      old.status != status || old.selected != selected;
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
