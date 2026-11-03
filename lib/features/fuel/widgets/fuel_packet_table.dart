import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/geocoder.dart';
import '../models/fuel_telemetry_point.dart';

class FuelPacketTable extends StatelessWidget {
  const FuelPacketTable({
    required this.points,
    super.key,
  });

  final List<FuelTelemetryPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No raw telemetry packets found for this period.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Header
        Container(
          color: const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Date & Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Fuel(ltr)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Address',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Speed(Kmph)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Odo',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.builder(
            itemCount: points.length,
            itemBuilder: (BuildContext context, int index) {
              final FuelTelemetryPoint pt = points[index];
              final bool isEven = index.isEven;
              final Color bgColor =
                  isEven ? Colors.white : const Color(0xFFF1F5F9);

              return Container(
                color: bgColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    // Date & Time
                    Expanded(
                      flex: 3,
                      child: Text(
                        DateFormat('yyyy-MM-dd\nHH:mm:ss').format(pt.timestamp),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    // Fuel(ltr) - normalized settled value
                    Expanded(
                      flex: 2,
                      child: Text(
                        pt.displayFuel.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    // Address Link
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: InkWell(
                          onTap: () => _showAddressDialog(context, pt),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Text(
                              'Link',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Speed(Kmph)
                    Expanded(
                      flex: 2,
                      child: Text(
                        pt.speed.round().toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pt.speed > 0
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    // Odo
                    Expanded(
                      flex: 2,
                      child: Text(
                        pt.odo.toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddressDialog(BuildContext context, FuelTelemetryPoint pt) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFF0284C7), size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Packet Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(pt.timestamp)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Coordinates: ${pt.latitude.toStringAsFixed(5)}, ${pt.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),
                      const Text(
                        'Address:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (pt.address != null && pt.address!.isNotEmpty)
                        Text(
                          pt.address!,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        )
                      else if (pt.latitude != 0 && pt.longitude != 0)
                        FutureBuilder<String>(
                          future: Geocoder.getAddress(pt.latitude, pt.longitude),
                          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Resolving address...',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              );
                            }
                            return Text(
                              snapshot.data ?? 'Location unavailable',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            );
                          },
                        )
                      else
                        const Text(
                          'No GPS fix coordinates for this packet.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
