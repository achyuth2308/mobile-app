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
  final reportRepo = ref.watch(reportRepositoryProvider);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

  final routeFuture = vehicleRepo.getRoute(
    vehicleId: vehicleId,
    start: start,
    end: end,
  );

  final stoppagesFuture = reportRepo.run(
    type: ReportType.stoppages,
    start: start,
    end: end,
    vehicleId: vehicleId,
  );

  final results = await Future.wait([routeFuture, stoppagesFuture]);
  final route = results[0] as List<TrackPoint>;
  final reportResult = results[1] as ReportResult;
  final stoppages = List<ReportRow>.from(reportResult.rows);
  stoppages.sort((a, b) {
    final aTime = a.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return aTime.compareTo(bTime);
  });

  return VehicleDailyData(
    route: route,
    stoppages: stoppages,
  );
});
