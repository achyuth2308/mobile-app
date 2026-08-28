import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/report_models.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/core_providers.dart';

final activeFollowingVehicleIdProvider = StateProvider<String?>((ref) => null);

class VehicleDailyData {
  const VehicleDailyData({
    required this.route,
    required this.stoppages,
  });

  final List<TrackPoint> route;
  final List<ReportRow> stoppages;
}

final vehicleDailyHistoryProvider =
    FutureProvider.family<VehicleDailyData, String>((ref, vehicleId) async {
  if (vehicleId.isEmpty) {
    return const VehicleDailyData(route: [], stoppages: []);
  }

  final vehicleRepo = ref.watch(vehicleRepositoryProvider);

  final now = DateTime.now();
  final startLocal = DateTime(now.year, now.month, now.day);
  final endLocal = now;

  // Apply Traccar UTC/IST offset bug workaround (same as vehicle_playback_tab)
  final DateTime startIstUtc = DateTime.utc(
    startLocal.year, startLocal.month, startLocal.day,
    startLocal.hour, startLocal.minute, startLocal.second,
  );
  final DateTime endIstUtc = DateTime.utc(
    endLocal.year, endLocal.month, endLocal.day,
    endLocal.hour, endLocal.minute, endLocal.second,
  );

  final DateTime startQuery = startIstUtc.subtract(const Duration(hours: 5, minutes: 30));
  final DateTime endQuery = endIstUtc.subtract(const Duration(hours: 5, minutes: 30));

  final List<TrackPoint> pts = await vehicleRepo.getHistory(
    vehicleId: vehicleId,
    start: startQuery,
    end: endQuery,
  );

  // Compute stoppages from the points
  final List<ReportRow> stoppages = [];
  TrackPoint? stopStart;
  TrackPoint? stopEnd;

  for (int i = 0; i < pts.length; i++) {
    final TrackPoint pt = pts[i];
    final bool isIdle = pt.speed <= 3;
    
    if (isIdle) {
      stopStart ??= pt;
      stopEnd = pt;
    } else {
      if (stopStart != null && stopEnd != null) {
        final Duration diff = stopEnd.timestamp.difference(stopStart.timestamp);
        if (diff.inMinutes >= 5) {
          stoppages.add(ReportRow(
            cells: const {},
            raw: {
              'start_lat': stopStart.latitude,
              'start_lng': stopStart.longitude,
              'end_lat': stopEnd.latitude,
              'end_lng': stopEnd.longitude,
              'start_time': stopStart.timestamp.toIso8601String(),
              'end_time': stopEnd.timestamp.toIso8601String(),
              'duration_seconds': diff.inSeconds.toDouble(),
            },
          ));
        }
      }
      stopStart = null;
      stopEnd = null;
    }
  }

  // Handle an ongoing stoppage at the end of the data
  if (stopStart != null && stopEnd != null) {
    final Duration diff = stopEnd.timestamp.difference(stopStart.timestamp);
    if (diff.inMinutes >= 5) {
      stoppages.add(ReportRow(
        cells: const {},
        raw: {
          'start_lat': stopStart.latitude,
          'start_lng': stopStart.longitude,
          'end_lat': stopEnd.latitude,
          'end_lng': stopEnd.longitude,
          'start_time': stopStart.timestamp.toIso8601String(),
          'end_time': stopEnd.timestamp.toIso8601String(),
          'duration_seconds': diff.inSeconds.toDouble(),
        },
      ));
    }
  }

  return VehicleDailyData(
    route: pts,
    stoppages: stoppages,
  );
});
