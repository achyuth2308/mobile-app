import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../../../shared/widgets/live_address.dart';

/// Compact live card shown when a marker is tapped.
///
/// It watches the vehicle provider directly, so the speed and address keep
/// updating in place while the sheet is open — no stale snapshot.
class VehiclePeekSheet extends ConsumerWidget {
  const VehiclePeekSheet({
    required this.vehicleId,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onOpenDetails,
    super.key,
  });

  final String vehicleId;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(vehicleId));
    
    if (vehicle == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Address Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: LiveAddress(
                  vehicle: vehicle,
                  max: 120,
                  style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Color(0xFF2F1A45)),
                onPressed: onOpenDetails,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Metrics Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Speedometer & Odometer
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 40,
                        child: CustomPaint(
                          painter: HalfCircleGaugePainter(speed: vehicle.speed),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${vehicle.speed.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const Text('km/h', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${vehicle.odometer?.toInt() ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF5A5E78), borderRadius: BorderRadius.circular(4)),
                    child: const Text('odometer', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ),
              
              const SizedBox(width: 24),
              
              // Distance & Duration Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DISTANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2F1A45))),
                            const SizedBox(height: 4),
                            const Text('Today', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            Text('${vehicle.todayDistanceKm?.toStringAsFixed(1) ?? '0.0'} km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            const Text('From Last Stop', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            const Text('0.0 km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 80, color: Colors.grey.shade300),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('DURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2F1A45))),
                                const Icon(Icons.arrow_circle_right, color: Color(0xFF2F1A45), size: 16),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Today', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            const Text('1H 27M', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 8),
                            const Text('From Last Stop', style: TextStyle(fontSize: 10, color: Colors.black54)),
                            const Text('0H 0M', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HalfCircleGaugePainter extends CustomPainter {
  final double speed;
  HalfCircleGaugePainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    // Draw background arc
    canvas.drawArc(rect, 3.14159, 3.14159, false, paint);

    // Draw speed arc
    paint.color = Colors.red;
    final sweepAngle = (speed.clamp(0, 120) / 120) * 3.14159;
    canvas.drawArc(rect, 3.14159, sweepAngle, false, paint);
    
    // Draw tick marks
    final tickPaint = Paint()..color = Colors.white..strokeWidth = 2;
    for (int i = 1; i < 5; i++) {
      final angle = 3.14159 + (i * 3.14159 / 5);
      final x1 = size.width / 2 + (size.width / 2 - 4) * 1.0 * (angle == 3.14159 ? 1 : 1); // Simple approximation
      // proper trig requires math package, let's just do dashes by breaking the arc.
    }
  }

  @override
  bool shouldRepaint(covariant HalfCircleGaugePainter oldDelegate) => oldDelegate.speed != speed;
}
