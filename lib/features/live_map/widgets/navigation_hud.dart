import 'package:flutter/material.dart';
import '../../../../data/models/vehicle.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:math' as math;

class NavigationHUD extends StatelessWidget {
  const NavigationHUD({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      top: 100, // Below the top blue pill
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SpeedometerWidget(vehicle: vehicle),
          const SizedBox(height: 16),
          _NavigationStatsWidget(vehicle: vehicle),
        ],
      ),
    );
  }
}

class _SpeedometerWidget extends StatelessWidget {
  const _SpeedometerWidget({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.forStatus(vehicle.status.key);
    final String statusLabel = vehicle.status.key[0].toUpperCase() +
        vehicle.status.key.substring(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF0E1020),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gauge arcs + ticks
              CustomPaint(
                size: const Size(130, 130),
                painter: _SpeedGaugePainter(speed: vehicle.speed),
              ),
              // Speed text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    '${vehicle.speed.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Status pill — below the circle like in the screenshot
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1020),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedGaugePainter extends CustomPainter {
  _SpeedGaugePainter({required this.speed});
  final double speed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Arc spans from 135° (bottom-left) sweeping 270° to bottom-right
    const double startDeg = 135;
    const double sweepDeg = 270;
    final double startRad = startDeg * math.pi / 180;
    final double sweepRad = sweepDeg * math.pi / 180;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Background track ──────────────────────────────────────────
    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );

    final double maxSpeed = 200;
    final double normalised = (speed.clamp(0.0, maxSpeed) / maxSpeed);
    final double activeSweep = sweepRad * normalised;

    // ── Red segment (above 120 km/h, i.e. 60%+) ──────────────────
    // First draw full blue arc, then overpaint red portion if needed.
    if (activeSweep > 0) {
      // Blue arc (0–100%)
      final double blueEnd = activeSweep.clamp(0, sweepRad * 0.6);
      if (blueEnd > 0) {
        canvas.drawArc(
          rect,
          startRad,
          blueEnd,
          false,
          Paint()
            ..color = const Color(0xFF5C8DFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11
            ..strokeCap = StrokeCap.round,
        );
      }
      // Red arc (60–100% of gauge = 120–200 km/h)
      if (normalised > 0.6) {
        final double redStart = startRad + sweepRad * 0.6;
        final double redSweep = activeSweep - sweepRad * 0.6;
        canvas.drawArc(
          rect,
          redStart,
          redSweep,
          false,
          Paint()
            ..color = const Color(0xFFFF3B30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Tick marks + labels ───────────────────────────────────────
    const List<double> labelSpeeds = [0, 40, 80, 120, 160, 200];
    final double shortTickRadius = radius - 12;
    final double labelRadius = radius - 22;

    for (double s = 0; s <= maxSpeed; s += 20) {
      final double angle =
          startRad + (s / maxSpeed) * sweepRad;
      final bool isMajor = labelSpeeds.contains(s);
      final double innerR = isMajor ? shortTickRadius - 4 : shortTickRadius;

      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * (radius + 3),
            center.dy + math.sin(angle) * (radius + 3)),
        Offset(center.dx + math.cos(angle) * innerR,
            center.dy + math.sin(angle) * innerR),
        Paint()
          ..color = Colors.white.withOpacity(isMajor ? 0.7 : 0.3)
          ..strokeWidth = isMajor ? 1.8 : 1.0
          ..strokeCap = StrokeCap.round,
      );

      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.toInt().toString(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 7.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = center.dx + math.cos(angle) * labelRadius - tp.width / 2;
        final dy = center.dy + math.sin(angle) * labelRadius - tp.height / 2;
        tp.paint(canvas, Offset(dx, dy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedGaugePainter old) => old.speed != speed;
}

class _NavigationStatsWidget extends StatelessWidget {
  const _NavigationStatsWidget({required this.vehicle});
  
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    // Determine direction from heading
    String direction = 'N';
    final h = vehicle.heading % 360;
    if (h >= 337.5 || h < 22.5) direction = 'N';
    else if (h >= 22.5 && h < 67.5) direction = 'NE';
    else if (h >= 67.5 && h < 112.5) direction = 'E';
    else if (h >= 112.5 && h < 157.5) direction = 'SE';
    else if (h >= 157.5 && h < 202.5) direction = 'S';
    else if (h >= 202.5 && h < 247.5) direction = 'SW';
    else if (h >= 247.5 && h < 292.5) direction = 'W';
    else if (h >= 292.5 && h < 337.5) direction = 'NW';

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1020),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatRow(
            icon: Icons.route_outlined,
            value: '${(vehicle.todayDistanceKm ?? 0).toStringAsFixed(1)} km',
            label: 'Distance',
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.timer_outlined,
            value: _formatDuration(0),
            label: 'Duration',
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.speed_rounded,
            value: '72 km/h',
            label: 'Max Speed',
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.satellite_alt_outlined,
            value: '${vehicle.satellites ?? 16}',
            label: 'Satellites',
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.navigation_outlined,
            value: direction,
            label: 'Direction',
          ),
        ],
      ),
    );
  }

  String _formatDuration(double engineHours) {
    final int hours = engineHours.floor();
    final int minutes = ((engineHours - hours) * 60).floor();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
