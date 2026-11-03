import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../models/fuel_telemetry_point.dart';
import '../services/fuel_service.dart';

enum FuelViewMode {
  chart,
  table,
}

class FuelAnalyticsState {
  const FuelAnalyticsState({
    required this.selectedVehicleId,
    required this.startDate,
    required this.endDate,
    this.interval = FuelInterval.filtered,
    this.viewMode = FuelViewMode.chart,
    this.showAllFuel = false,
    this.showFilteredFuel = true,
    this.showNormalize = true,
    this.showSpeed = true,
    this.showEngine = true,
    this.reportData = const AsyncValue.loading(),
  });

  final String? selectedVehicleId;
  final DateTime startDate;
  final DateTime endDate;
  final FuelInterval interval;
  final FuelViewMode viewMode;
  final bool showAllFuel;
  final bool showFilteredFuel;
  final bool showNormalize;
  final bool showSpeed;
  final bool showEngine;
  final AsyncValue<FuelReportData> reportData;

  FuelAnalyticsState copyWith({
    String? selectedVehicleId,
    DateTime? startDate,
    DateTime? endDate,
    FuelInterval? interval,
    FuelViewMode? viewMode,
    bool? showAllFuel,
    bool? showFilteredFuel,
    bool? showNormalize,
    bool? showSpeed,
    bool? showEngine,
    AsyncValue<FuelReportData>? reportData,
  }) {
    return FuelAnalyticsState(
      selectedVehicleId: selectedVehicleId ?? this.selectedVehicleId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      interval: interval ?? this.interval,
      viewMode: viewMode ?? this.viewMode,
      showAllFuel: showAllFuel ?? this.showAllFuel,
      showFilteredFuel: showFilteredFuel ?? this.showFilteredFuel,
      showNormalize: showNormalize ?? this.showNormalize,
      showSpeed: showSpeed ?? this.showSpeed,
      showEngine: showEngine ?? this.showEngine,
      reportData: reportData ?? this.reportData,
    );
  }
}

class FuelAnalyticsNotifier extends StateNotifier<FuelAnalyticsState> {
  FuelAnalyticsNotifier(this._ref, {String? initialVehicleId})
      : super(_buildInitialState(initialVehicleId)) {
    _initVehicleAndFetch();
  }

  final Ref _ref;

  static FuelAnalyticsState _buildInitialState(String? initialVehicleId) {
    final DateTime now = DateTime.now();
    // Default to start of today 00:00:00 to now
    final DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

    return FuelAnalyticsState(
      selectedVehicleId: initialVehicleId,
      startDate: startOfDay,
      endDate: now,
    );
  }

  void _initVehicleAndFetch() {
    final List<Vehicle> vehicles = _ref.read(fleetProvider).vehicles;
    if (state.selectedVehicleId == null || state.selectedVehicleId!.isEmpty) {
      if (vehicles.isNotEmpty) {
        state = state.copyWith(selectedVehicleId: vehicles.first.id);
      }
    }
    fetchReport();
  }

  Future<void> fetchReport() async {
    final String? vId = state.selectedVehicleId;
    if (vId == null || vId.isEmpty) {
      state = state.copyWith(
        reportData: const AsyncValue.data(
          FuelReportData(
            points: <FuelTelemetryPoint>[],
            summary: FuelReportSummary(),
          ),
        ),
      );
      return;
    }

    state = state.copyWith(reportData: const AsyncValue.loading());

    try {
      final Vehicle? vehicle = _ref
          .read(fleetProvider)
          .vehicles
          .where((Vehicle v) => v.id == vId)
          .firstOrNull;

      final FuelService service = _ref.read(fuelServiceProvider);
      final FuelReportData data = await service.getFuelReport(
        vehicleId: vId,
        start: state.startDate,
        end: state.endDate,
        interval: state.interval,
        vehicle: vehicle,
      );

      if (mounted) {
        state = state.copyWith(reportData: AsyncValue.data(data));
      }
    } catch (err, stack) {
      if (mounted) {
        state = state.copyWith(reportData: AsyncValue.error(err, stack));
      }
    }
  }

  void selectVehicle(String vehicleId) {
    if (state.selectedVehicleId == vehicleId) return;
    state = state.copyWith(selectedVehicleId: vehicleId);
    fetchReport();
  }

  void updateDateRangeAndInterval({
    required DateTime start,
    required DateTime end,
    required FuelInterval interval,
  }) {
    state = state.copyWith(
      startDate: start,
      endDate: end,
      interval: interval,
    );
    fetchReport();
  }

  void toggleViewMode() {
    state = state.copyWith(
      viewMode: state.viewMode == FuelViewMode.chart
          ? FuelViewMode.table
          : FuelViewMode.chart,
    );
  }

  void setViewMode(FuelViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void toggleAllFuel() =>
      state = state.copyWith(showAllFuel: !state.showAllFuel);

  void toggleFilteredFuel() =>
      state = state.copyWith(showFilteredFuel: !state.showFilteredFuel);

  void toggleNormalize() =>
      state = state.copyWith(showNormalize: !state.showNormalize);

  void toggleSpeed() => state = state.copyWith(showSpeed: !state.showSpeed);

  void toggleEngine() => state = state.copyWith(showEngine: !state.showEngine);
}

final StateNotifierProviderFamily<FuelAnalyticsNotifier, FuelAnalyticsState, String?>
    fuelAnalyticsProvider = StateNotifierProvider.family<
        FuelAnalyticsNotifier, FuelAnalyticsState, String?>(
  (Ref ref, String? vehicleId) =>
      FuelAnalyticsNotifier(ref, initialVehicleId: vehicleId),
);
