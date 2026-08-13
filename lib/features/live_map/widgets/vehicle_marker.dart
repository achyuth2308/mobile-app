import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';

/// ─────────────────────────────────────────────────────────────────────
///  VEHICLE MARKER
/// ─────────────────────────────────────────────────────────────────────
///
/// With Google Maps a marker had to be rasterised to a PNG and memoised by
/// (status × heading bucket × selected). Moving to flutter_map means markers
/// are ordinary widgets, which is strictly better:
///
///  * heading is a real `Transform.rotate` — smooth, not snapped to 15°
///  * colours come from `AppColors` directly, so map and list can never drift
///  * the selected marker can animate and show a label with no extra bitmaps
///  * no canvas → PNG → texture upload per unique state
class VehicleMarkerPin extends StatelessWidget {
  const VehicleMarkerPin({
    required this.vehicle,
    this.selected = false,
    this.showLabel = false,
    this.useSprite = false,
    super.key,
  });

  final Vehicle vehicle;
  final bool selected;
  final bool showLabel;
  final bool useSprite;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forStatus(vehicle.status.key);
    final bool moving = vehicle.status == VehicleStatus.moving;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showLabel) _Label(text: vehicle.displayName, color: color),
        if (showLabel) const SizedBox(height: 3),
        SizedBox(
          width: selected ? 64 : 52,
          height: selected ? 64 : 52,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Soft halo — also the selection affordance.
              AnimatedContainer(
                duration: Motion.fast,
                width: selected ? 64 : 48,
                height: selected ? 64 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(selected ? 0.26 : 0.16),
                  border: selected
                      ? Border.all(color: color.withOpacity(0.6), width: 2)
                      : null,
                ),
              ),

              // Direction cone, only while actually moving.
              if (moving)
                Transform.rotate(
                  angle: vehicle.heading * math.pi / 180,
                  child: CustomPaint(
                    size: Size(selected ? 64 : 52, selected ? 64 : 52),
                    painter: _HeadingPainter(color: color),
                  ),
                ),

              // Body.
              useSprite
                  ? Transform.rotate(
                      angle: (vehicle.heading - 90) * 3.1415926535897932 / 180,
                      child: Container(
                        width: selected ? 52 : 42,
                        height: selected ? 52 : 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: color.withOpacity(0.6),
                              blurRadius: selected ? 15 : 10,
                              spreadRadius: selected ? 3 : 1,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          vehicle.displayType == 'scooter' || vehicle.displayType == 'bike'
                              ? 'assets/images/vehicles/bike.png'
                              : 'assets/images/vehicles/car.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : Container(
                      width: selected ? 42 : 34,
                      height: selected ? 42 : 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: color, width: 2.0),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: selected ? 15 : 10,
                            spreadRadius: selected ? 3 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        VehicleIcons.forType(vehicle.type),
                        color: color,
                        size: selected ? 24 : 18,
                      ),
                    ),

              // Overspeed badge.
              if (vehicle.isOverspeeding &&
                  vehicle.status != VehicleStatus.offline)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.6),
                    ),
                    child: const Icon(Icons.priority_high_rounded,
                        size: 8, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filled arc pointing along the vehicle's bearing (0° = north = up).
class _HeadingPainter extends CustomPainter {
  const _HeadingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    final Path path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - radius * 0.28, center.dy - radius * 0.58)
      ..lineTo(center.dx + radius * 0.28, center.dy - radius * 0.58)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _HeadingPainter old) => old.color != color;
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.95),
        borderRadius: Corners.rXs,
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Cluster bubble — size and tint scale with the number of vehicles.
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final double size = count < 10
        ? 40
        : count < 50
            ? 48
            : 56;

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
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.brand.withOpacity(0.4),
                blurRadius: 12,
              ),
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
