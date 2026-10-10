import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/vehicle.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/report_models.dart';
import '../../../providers/fleet_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';
import '../providers/live_map_providers.dart';

abstract class TripSegment {
  final DateTime startTime;
  final DateTime endTime;
  TripSegment(this.startTime, this.endTime);
}

class DrivingSegment extends TripSegment {
  final double distanceKm;
  final double avgSpeedKmph;
  DrivingSegment(DateTime startTime, DateTime endTime, this.distanceKm, this.avgSpeedKmph) : super(startTime, endTime);
}

class StopSegment extends TripSegment {
  final double lat;
  final double lng;
  final int index;
  final String title;
  StopSegment(DateTime startTime, DateTime endTime, this.lat, this.lng, this.index, {this.title = ''}) : super(startTime, endTime);
}

List<TripSegment> _buildSegments(List<TrackPoint> route, List<ReportRow> stoppages, Vehicle vehicle) {
  final DateTime now = DateTime.now();
  final DateTime todayStart = DateTime(now.year, now.month, now.day);

  if (route.isEmpty) {
    // If no route points recorded today, construct a real segment from live vehicle state
    if (vehicle.speed <= 3) {
      return [
        StopSegment(
          vehicle.lastPacketAt ?? todayStart,
          now,
          vehicle.latitude ?? 0,
          vehicle.longitude ?? 0,
          1,
          title: 'Stopped',
        ),
      ];
    } else {
      return [
        DrivingSegment(
          vehicle.lastPacketAt ?? todayStart,
          now,
          vehicle.todayDistanceKm ?? 0.0,
          vehicle.speed,
        ),
      ];
    }
  }

  final List<TripSegment> segments = [];
  const Distance dist = Distance();

  DateTime currentStart = route.first.timestamp;
  int routeIndex = 0;

  for (int i = 0; i < stoppages.length; i++) {
    final ReportRow stop = stoppages[i];
    final DateTime stopStart = stop.raw['start_time'] as DateTime;
    final DateTime stopEnd = stop.raw['end_time'] as DateTime;

    // Driving segment before this stop
    if (stopStart.isAfter(currentStart)) {
      double distance = 0.0;
      double speedSum = 0.0;
      int count = 0;
      TrackPoint? prev;
      for (int j = routeIndex; j < route.length; j++) {
        final TrackPoint pt = route[j];
        if (pt.timestamp.isAfter(stopStart)) {
          routeIndex = j;
          break;
        }
        if (pt.timestamp.isAfter(currentStart) || pt.timestamp.isAtSameMomentAs(currentStart)) {
          if (prev != null) {
            distance += dist.distance(prev.latLng, pt.latLng) / 1000.0;
          }
          speedSum += pt.speed;
          count++;
          prev = pt;
        }
      }
      final double avgSpeed = count > 0 ? speedSum / count : 0.0;
      segments.add(DrivingSegment(currentStart, stopStart, distance, avgSpeed));
    }

    segments.add(StopSegment(
      stopStart,
      stopEnd,
      (stop.raw['start_lat'] as num).toDouble(),
      (stop.raw['start_lng'] as num).toDouble(),
      i + 1,
      title: 'Stop ${i + 1}',
    ));

    currentStart = stopEnd;
  }

  // Final driving segment
  final DateTime lastTime = route.last.timestamp;
  if (currentStart.isBefore(lastTime)) {
    double distance = 0.0;
    double speedSum = 0.0;
    int count = 0;
    TrackPoint? prev;
    for (int j = routeIndex; j < route.length; j++) {
      final TrackPoint pt = route[j];
      if (pt.timestamp.isAfter(currentStart) || pt.timestamp.isAtSameMomentAs(currentStart)) {
        if (prev != null) {
          distance += dist.distance(prev.latLng, pt.latLng) / 1000.0;
        }
        speedSum += pt.speed;
        count++;
        prev = pt;
      }
    }
    final double avgSpeed = count > 0 ? speedSum / count : 0.0;
    segments.add(DrivingSegment(currentStart, lastTime, distance, avgSpeed));
  }

  return segments;
}

class CoordinateAddress extends StatefulWidget {
  final double lat;
  final double lng;
  const CoordinateAddress({required this.lat, required this.lng, super.key});

  @override
  State<CoordinateAddress> createState() => _CoordinateAddressState();
}

class _CoordinateAddressState extends State<CoordinateAddress> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CoordinateAddress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _resolve();
    }
  }

  void _resolve() {
    Geocoder.getAddress(widget.lat, widget.lng).then((addr) {
      if (mounted && addr != 'Location unavailable') {
        setState(() => _address = addr);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _address != null ? Fmt.address(_address) : 'Locating address...',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF475569),
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class VehiclePeekSheet extends ConsumerWidget {
  const VehiclePeekSheet({
    required this.vehicleId,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onOpenDetails,
    this.scrollController,
    super.key,
  });

  final String vehicleId;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenDetails;
  final ScrollController? scrollController;

  static String _formatDurationShort(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}hrs ${mins}mins';
    } else {
      return '${mins}mins';
    }
  }

  static String _formatTimeRange(DateTime start, DateTime end) {
    return 'Today ${_formatTime(start)} - ${_formatTime(end)}';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleByIdProvider(vehicleId));
    if (vehicle == null) return const SizedBox.shrink();

    final asyncData = ref.watch(vehicleDailyHistoryProvider(vehicleId));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Segments
            asyncData.when(
                    data: (data) {
                      final segments = _buildSegments(data.route, data.stoppages, vehicle);

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: segments.length,
                        itemBuilder: (context, index) {
                          final seg = segments[index];
                          final bool isLast = index == segments.length - 1;

                          if (seg is DrivingSegment) {
                            final Duration dur = seg.endTime.difference(seg.startTime);
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Timeline Line & Icon Node
                                  SizedBox(
                                    width: 36,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.navigation_rounded, size: 16, color: Colors.white),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 3.5,
                                              color: const Color(0xFF2563EB),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Segment Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'Driving',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                              Text(
                                                ' — ${_formatDurationShort(dur)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTimeRange(seg.startTime, seg.endTime),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // 2 Card Boxes (Distance & Average Speed)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Distance',
                                                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.route_rounded, size: 18, color: Color(0xFF64748B)),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '${seg.distanceKm.toStringAsFixed(1)} km',
                                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'Average Speed',
                                                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.speed_rounded, size: 18, color: Color(0xFF64748B)),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '${seg.avgSpeedKmph.round()} kmph',
                                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (seg is StopSegment) {
                            final Duration dur = seg.endTime.difference(seg.startTime);
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Timeline Line & Icon Node
                                  SizedBox(
                                    width: 36,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFD97706), // Orange
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.local_gas_station_rounded, size: 16, color: Colors.white),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 3.5,
                                              color: const Color(0xFFD97706),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Segment Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${seg.title} — ${_formatDurationShort(dur)}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFD97706),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {},
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Text(
                                                      'Set up an alert',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF2563EB),
                                                      ),
                                                    ),
                                                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2563EB)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTimeRange(seg.startTime, seg.endTime),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          CoordinateAddress(lat: seg.lat, lng: seg.lng),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, stack) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Failed to load trip details', style: TextStyle(color: Colors.red))),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Trip Started - ${asyncData.valueOrNull?.route.firstOrNull != null ? Fmt.date(asyncData.valueOrNull!.route.first.timestamp) : 'Today'}, 12:00 AM',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }
}
