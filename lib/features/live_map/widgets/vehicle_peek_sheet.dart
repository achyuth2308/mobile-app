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
  StopSegment(DateTime startTime, DateTime endTime, this.lat, this.lng, this.index) : super(startTime, endTime);
}

List<TripSegment> _buildSegments(List<TrackPoint> route, List<ReportRow> stoppages) {
  if (route.isEmpty) return [];
  
  final List<TripSegment> segments = [];
  final Distance dist = const Distance();
  
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
    Geocoder.getAddress(widget.lat, widget.lng).then((addr) {
      if (mounted) setState(() => _address = addr);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Text(
      _address != null ? Fmt.address(_address) : '...',
      style: const TextStyle(fontSize: 12, color: Colors.black87),
    );
  }
}

class _TimelineSegmentWidget extends StatelessWidget {
  final TripSegment segment;
  final bool isLast;
  
  const _TimelineSegmentWidget({required this.segment, this.isLast = false});
  
  Widget _buildDriveContent(DrivingSegment seg) {
    final dur = seg.endTime.difference(seg.startTime);
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    final durStr = '${hours}hrs ${mins}mins';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Driving', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(' — $durStr', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Today ${Fmt.time(seg.startTime)} - ${Fmt.time(seg.endTime)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Distance', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.route, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${seg.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
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
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Average Speed', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${seg.avgSpeedKmph.toStringAsFixed(0)} kmph', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStopContent(StopSegment seg) {
    final dur = seg.endTime.difference(seg.startTime);
    final hours = dur.inHours;
    final mins = dur.inMinutes.remainder(60);
    final durStr = '${hours}hrs ${mins}mins';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Stop ${seg.index}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(' — $durStr', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Today ${Fmt.time(seg.startTime)} - ${Fmt.time(seg.endTime)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),
        CoordinateAddress(lat: seg.lat, lng: seg.lng),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDrive = segment is DrivingSegment;
    final color = isDrive ? Colors.blue : Colors.orange;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDrive ? Icons.navigation : Icons.remove,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 4,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 8),
              child: isDrive ? _buildDriveContent(segment as DrivingSegment) : _buildStopContent(segment as StopSegment),
            ),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleByIdProvider(vehicleId));
    if (vehicle == null) return const SizedBox.shrink();

    final asyncData = ref.watch(vehicleDailyHistoryProvider(vehicleId));

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xFF2F1A45)),
                  const SizedBox(width: 8),
                  Text(
                    'Today 12 AM - ${Fmt.time(DateTime.now())}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2F1A45)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Header
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Trip Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F1A45)),
            ),
          ),
          const SizedBox(height: 24),
          // Timeline
          asyncData.when(
            data: (data) {
              final segments = _buildSegments(data.route, data.stoppages);
              if (segments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No trip data available for today.')),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: segments.length,
                itemBuilder: (ctx, i) {
                  return _TimelineSegmentWidget(segment: segments[i], isLast: i == segments.length - 1);
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Error loading trip details')),
            ),
          ),
        ],
      ),
    ),
  );
}
}
