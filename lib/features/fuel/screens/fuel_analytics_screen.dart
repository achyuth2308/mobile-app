import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../providers/fuel_analytics_provider.dart';
import '../services/fuel_service.dart';
import '../widgets/fuel_analytics_chart.dart';
import '../widgets/fuel_filter_sheet.dart';
import '../widgets/fuel_intelligence_card.dart';
import '../widgets/fuel_packet_table.dart';

class FuelAnalyticsScreen extends ConsumerWidget {
  const FuelAnalyticsScreen({
    this.vehicleId,
    super.key,
  });

  final String? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FuelAnalyticsState state =
        ref.watch(fuelAnalyticsProvider(vehicleId));
    final FuelAnalyticsNotifier notifier =
        ref.read(fuelAnalyticsProvider(vehicleId).notifier);
    final List<Vehicle> vehicles = ref.watch(fleetProvider).vehicles;

    final Vehicle? currentVehicle = vehicles
        .where((Vehicle v) => v.id == state.selectedVehicleId)
        .firstOrNull;

    final String vehicleLabel = currentVehicle != null
        ? '${currentVehicle.displayName} (${currentVehicle.registrationNumber})'
        : (state.selectedVehicleId ?? 'Select Vehicle');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Fuel Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          // Switch between Chart and Table Mode
          IconButton(
            tooltip: state.viewMode == FuelViewMode.chart
                ? 'Switch to Table View'
                : 'Switch to Chart View',
            icon: Icon(
              state.viewMode == FuelViewMode.chart
                  ? Icons.table_chart_rounded
                  : Icons.show_chart_rounded,
              color: Colors.white,
            ),
            onPressed: notifier.toggleViewMode,
          ),

          // Date & Time Filter Sheet
          IconButton(
            tooltip: 'Filter Date & Interval',
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              FuelFilterSheet.show(
                context,
                initialStart: state.startDate,
                initialEnd: state.endDate,
                initialInterval: state.interval,
                onApply: (DateTime s, DateTime e, FuelInterval i) {
                  notifier.updateDateRangeAndInterval(
                    start: s,
                    end: e,
                    interval: i,
                  );
                },
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Vehicle Selector Header Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedVehicleId,
                      isExpanded: true,
                      hint: Text(
                        vehicleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      items: vehicles.map((Vehicle v) {
                        return DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(
                            '${v.displayName} (${v.registrationNumber})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newId) {
                        if (newId != null) notifier.selectVehicle(newId);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 2. Active Date Range Pill Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat('dd/MM HH:mm').format(state.startDate)} → ${DateFormat('dd/MM HH:mm').format(state.endDate)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: state.interval == FuelInterval.filtered
                        ? const Color(0xFFE0F2FE)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: state.interval == FuelInterval.filtered
                          ? const Color(0xFFBAE6FD)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    state.interval.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: state.interval == FuelInterval.filtered
                          ? const Color(0xFF0369A1)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 3. Body Content
          Expanded(
            child: state.reportData.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF0284C7),
                ),
              ),
              error: (Object err, StackTrace? stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: Color(0xFFEF4444)),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load fuel report: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: notifier.fetchReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (FuelReportData data) {
                if (state.viewMode == FuelViewMode.table) {
                  return FuelPacketTable(points: data.points);
                }

                // Chart & Web App Dashboard View
                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool isDesktop = constraints.maxWidth >= 960;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A. Chart Card with Exact Web App Header and Toggles
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.tune_rounded,
                                                color: Color(0xFF10B981),
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Fuel vs. Speed vs. Distance Correlation',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Interactive time-series displaying fuel level drops during speed bursts and idle idling intervals',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 5 Web App Series Toggles
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // 1. All Fuel Data
                                      _webToggleChip(
                                        label: 'All Fuel Data',
                                        isSelected: state.showAllFuel,
                                        activeColor: const Color(0xFF475569),
                                        onTap: notifier.toggleAllFuel,
                                      ),
                                      const SizedBox(width: 8),

                                      // 2. Filtered Fuel Data (Default Active)
                                      _webToggleChip(
                                        label: 'Filtered Fuel Data',
                                        isSelected: state.showFilteredFuel,
                                        activeColor: const Color(0xFF0284C7),
                                        onTap: notifier.toggleFilteredFuel,
                                      ),
                                      const SizedBox(width: 8),

                                      // 3. Normalize (Default Active)
                                      _webToggleChip(
                                        label: 'Normalize',
                                        isSelected: state.showNormalize,
                                        activeColor: const Color(0xFFEF4444),
                                        onTap: notifier.toggleNormalize,
                                      ),
                                      const SizedBox(width: 8),

                                      // 4. Engine
                                      _webToggleChip(
                                        label: 'Engine',
                                        isSelected: state.showEngine,
                                        activeColor: const Color(0xFFEAB308),
                                        onTap: notifier.toggleEngine,
                                      ),
                                      const SizedBox(width: 8),

                                      // 5. Speed
                                      _webToggleChip(
                                        label: 'Speed',
                                        isSelected: state.showSpeed,
                                        activeColor: const Color(0xFF06B6D4),
                                        onTap: notifier.toggleSpeed,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Chart + Side Intelligence Layout
                                if (isDesktop) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 7,
                                        child: FuelAnalyticsChart(
                                          points: data.points,
                                          showAllFuel: state.showAllFuel,
                                          showFilteredFuel: state.showFilteredFuel,
                                          showNormalize: state.showNormalize,
                                          showSpeed: state.showSpeed,
                                          showEngine: state.showEngine,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 310,
                                        child: FuelIntelligencePanel(
                                          summary: data.summary,
                                          rawCount: data.rawCount,
                                          onTapRawData: () => notifier.setViewMode(FuelViewMode.table),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  FuelAnalyticsChart(
                                    points: data.points,
                                    showAllFuel: state.showAllFuel,
                                    showFilteredFuel: state.showFilteredFuel,
                                    showNormalize: state.showNormalize,
                                    showSpeed: state.showSpeed,
                                    showEngine: state.showEngine,
                                  ),
                                  const SizedBox(height: 14),
                                  FuelIntelligencePanel(
                                    summary: data.summary,
                                    rawCount: data.rawCount,
                                    onTapRawData: () => notifier.setViewMode(FuelViewMode.table),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // B. 5 Status Cards matching Web App Screenshot 2
                          FuelStatusCards(summary: data.summary),

                          const SizedBox(height: 16),

                          // C. Fuel Fill and Theft Details Table matching Web App Screenshot 2
                          FuelFillTheftTable(summary: data.summary),

                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _webToggleChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
