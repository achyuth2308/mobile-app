import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../models/fuel_telemetry_point.dart';
import '../providers/fuel_analytics_provider.dart';
import '../services/fuel_service.dart';
import '../widgets/fuel_analytics_chart.dart';
import '../widgets/fuel_filter_sheet.dart';

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
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F2042),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: InkWell(
          onTap: () {
            _showVehiclePickerSheet(
              context: context,
              vehicles: vehicles,
              selectedId: state.selectedVehicleId,
              onSelect: (String newId) => notifier.selectVehicle(newId),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fuel Graph',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 150,
                    ),
                    child: Text(
                      currentVehicle?.displayName ?? vehicleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF94A3B8),
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Log Fuel Entry',
            icon: const Icon(
              Icons.edit_note_rounded,
              color: Color(0xFFFDBA74), // Warm amber/orange
              size: 24,
            ),
            onPressed: () {
              final String? targetId = vehicleId ?? state.selectedVehicleId;
              if (targetId != null && targetId.isNotEmpty) {
                context.push('/vehicle/$targetId/manual-fuel-entry');
              } else {
                context.push('/manual-fuel-entry');
              }
            },
          ),
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
      body: state.reportData.when(
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
          final FuelReportSummary summary = data.summary;
          final double startOdo = summary.startOdo > 0
              ? summary.startOdo
              : (data.points.isNotEmpty ? data.points.first.odo : 0.0);
          final double endOdo = summary.endOdo > 0
              ? summary.endOdo
              : (data.points.isNotEmpty ? data.points.last.odo : 0.0);

          final double screenHeight = MediaQuery.of(context).size.height;
          // Allocate ~58-60% of viewport to graph height (clamped safely between 420 and 560px)
          final double heroGraphHeight =
              (screenHeight * 0.56).clamp(400.0, 540.0);

          final double currentFuel = data.points.isNotEmpty
              ? data.points.last.displayFuel
              : 0.0;
          final double tankPct = summary.tankSize > 0
              ? ((currentFuel / summary.tankSize) * 100.0).clamp(0.0, 100.0)
              : 0.0;
          final Color tankColor = tankPct > 30
              ? const Color(0xFF16A34A)
              : (tankPct > 15
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFDC2626));
          final bool isEngineOn =
              data.points.isNotEmpty && data.points.last.ignition;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick Date Range Filter Chips Bar (Today, Yesterday, Last 24h, 7 Days, Custom)
                _buildDatePresetBar(context, state, notifier),
                const SizedBox(height: 10),

                // 1. Hero Chart Card (Primary 60% viewport focus)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Vehicle Specs & Visual Fuel Tank Capacity Gauge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Tank capacity & current level with visual progress bar
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Tank: ${summary.tankSize.round()} L',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const Text('  •  ',
                                          style: TextStyle(
                                              color: Color(0xFFCBD5E1),
                                              fontSize: 11)),
                                      Text(
                                        'Current: ${currentFuel.toStringAsFixed(1)} L',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: tankColor.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${tankPct.round()}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: tankColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value:
                                          (tankPct / 100.0).clamp(0.0, 1.0),
                                      minHeight: 5,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              tankColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Engine Status Pill Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isEngineOn
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isEngineOn
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isEngineOn
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF94A3B8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isEngineOn ? 'Engine ON' : 'Engine OFF',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isEngineOn
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Interactive Series Toggles: Fuel, Speed, Engine
                      Row(
                        children: [
                          Expanded(
                            child: _seriesToggleChip(
                              label: 'Fuel',
                              color: const Color(0xFF0284C7),
                              isSelected: state.showFilteredFuel,
                              onTap: notifier.toggleFilteredFuel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _seriesToggleChip(
                              label: 'Speed',
                              color: const Color(0xFFEA580C),
                              isSelected: state.showSpeed,
                              onTap: notifier.toggleSpeed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _seriesToggleChip(
                              label: 'Engine',
                              color: const Color(0xFFEAB308),
                              isSelected: state.showEngine,
                              onTap: notifier.toggleEngine,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Zoom & Swipe hint indicator
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(Icons.pinch_rounded,
                              size: 14, color: Color(0xFF94A3B8)),
                          SizedBox(width: 4),
                          Text(
                            'Pinch to zoom • Drag timeline',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      FuelAnalyticsChart(
                        points: data.points,
                        height: heroGraphHeight,
                        showFilteredFuel: state.showFilteredFuel,
                        showSpeed: state.showSpeed,
                        showEngine: state.showEngine,
                        refuelEvents: data.refuelEvents,
                        theftEvents: data.theftEvents,
                        tankCapacity: summary.tankSize,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 2. 2x2 Primary KPI Summary Cards
                Row(
                  children: [
                    // KPI: Fuel Consumed
                    Expanded(
                      child: _kpiCard(
                        icon: Icons.water_drop_rounded,
                        iconColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        title: 'Fuel Consumed',
                        value:
                            '${summary.totalFuelConsumed.toStringAsFixed(1)} L',
                        subtitle: summary.mileageKmpl > 0
                            ? '${summary.mileageKmpl.toStringAsFixed(1)} km/L avg'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // KPI: Distance
                    Expanded(
                      child: _kpiCard(
                        icon: Icons.route_rounded,
                        iconColor: const Color(0xFFEA580C),
                        bgColor: const Color(0xFFFFF7ED),
                        title: 'Trip Distance',
                        value: '${summary.tripDistance.toStringAsFixed(1)} km',
                        subtitle: summary.totalFuelConsumed > 0
                            ? '${(summary.tripDistance / summary.totalFuelConsumed).toStringAsFixed(1)} km/L'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // KPI: Fuel Filled
                    Expanded(
                      child: _kpiCard(
                        icon: Icons.local_gas_station_rounded,
                        iconColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFF0FDF4),
                        title: 'Fuel Filled',
                        value:
                            '+${summary.totalFuelFill.toStringAsFixed(1)} L',
                        subtitle:
                            '${summary.refuelCount} refill${summary.refuelCount == 1 ? '' : 's'}',
                        valueColor: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // KPI: Theft / Drain
                    Expanded(
                      child: _kpiCard(
                        icon: Icons.warning_amber_rounded,
                        iconColor: summary.theftDrain > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                        bgColor: summary.theftDrain > 0
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF8FAFC),
                        title: 'Theft / Drain',
                        value: summary.theftDrain > 0
                            ? '-${summary.theftDrain.toStringAsFixed(1)} L'
                            : '0.0 L',
                        subtitle: summary.theftDrain > 0
                            ? '${summary.drainCount} drain${summary.drainCount == 1 ? '' : 's'} detected'
                            : 'No drain detected',
                        valueColor: summary.theftDrain > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Fuel Events Breakdown (Refills & Drains)
                if (data.refuelEvents.isNotEmpty ||
                    data.theftEvents.isNotEmpty) ...[
                  _buildEventsBreakdownCard(data),
                  const SizedBox(height: 12),
                ],

                // 4. Fuel Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            color: Color(0xFF1E293B),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Fuel Summary',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _summaryRow(
                        icon: Icons.local_gas_station_rounded,
                        iconColor: const Color(0xFF334155),
                        label: 'Start Fuel',
                        value: '${summary.startFuel.toStringAsFixed(1)} L',
                      ),
                      const SizedBox(height: 14),
                      _summaryRow(
                        icon: Icons.local_gas_station_rounded,
                        iconColor: const Color(0xFF334155),
                        label: 'End Fuel',
                        value: '${summary.endFuel.toStringAsFixed(1)} L',
                      ),
                      const SizedBox(height: 14),
                      _summaryRow(
                        icon: Icons.local_gas_station_rounded,
                        iconColor: const Color(0xFF16A34A),
                        label: 'Fuel Filled',
                        value:
                            '+${summary.totalFuelFill.toStringAsFixed(1)} L',
                        valueColor: const Color(0xFF16A34A),
                      ),
                      const SizedBox(height: 14),
                      _summaryRow(
                        icon: Icons.warning_amber_rounded,
                        iconColor: summary.theftDrain > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                        label: 'Theft / Drain',
                        value: summary.theftDrain > 0
                            ? '-${summary.theftDrain.toStringAsFixed(1)} L'
                            : '0.0 L',
                        valueColor: summary.theftDrain > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 14),
                      _summaryRow(
                        icon: Icons.water_drop_rounded,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Fuel Consumed',
                        value:
                            '${summary.totalFuelConsumed.toStringAsFixed(1)} L',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Distance & Odometer Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _summaryRow(
                        icon: Icons.add_road_rounded,
                        iconColor: const Color(0xFF334155),
                        label: 'Trip Distance',
                        value: '${summary.tripDistance.toStringAsFixed(1)} km',
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                color: Color(0xFF475569),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Odometer',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(
                              '${_formatOdo(startOdo)} → ${_formatOdo(endOdo)}',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _seriesToggleChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity( 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatOdo(double odo) {
    if (odo <= 0) return '-';
    final double val = odo > 10000000 ? odo / 1000.0 : odo;
    return '${val.toStringAsFixed(1)} km';
  }

  Widget _buildDatePresetBar(
    BuildContext context,
    FuelAnalyticsState state,
    FuelAnalyticsNotifier notifier,
  ) {
    final DateTime now = DateTime.now();
    final DateTime startOfToday =
        DateTime(now.year, now.month, now.day, 0, 0, 0);
    final DateTime startOfYesterday =
        startOfToday.subtract(const Duration(days: 1));
    final DateTime endOfYesterday = DateTime(startOfYesterday.year,
        startOfYesterday.month, startOfYesterday.day, 23, 59, 59);

    final bool isToday =
        (state.startDate.difference(startOfToday).inMinutes).abs() < 5 &&
            state.endDate.day == now.day;
    final bool isYesterday =
        (state.startDate.difference(startOfYesterday).inMinutes).abs() < 5 &&
            (state.endDate.difference(endOfYesterday).inMinutes).abs() < 5;
    final bool is24h = !isToday &&
        !isYesterday &&
        (state.endDate.difference(state.startDate).inHours).abs() == 24;
    final bool is7d =
        (state.endDate.difference(state.startDate).inDays).abs() == 7;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _datePresetChip(
            label: 'Today',
            isSelected: isToday,
            onTap: () {
              notifier.updateDateRangeAndInterval(
                start: startOfToday,
                end: DateTime.now(),
                interval: state.interval,
              );
            },
          ),
          const SizedBox(width: 8),
          _datePresetChip(
            label: 'Yesterday',
            isSelected: isYesterday,
            onTap: () {
              notifier.updateDateRangeAndInterval(
                start: startOfYesterday,
                end: endOfYesterday,
                interval: state.interval,
              );
            },
          ),
          const SizedBox(width: 8),
          _datePresetChip(
            label: 'Last 24h',
            isSelected: is24h,
            onTap: () {
              final DateTime current = DateTime.now();
              notifier.updateDateRangeAndInterval(
                start: current.subtract(const Duration(hours: 24)),
                end: current,
                interval: state.interval,
              );
            },
          ),
          const SizedBox(width: 8),
          _datePresetChip(
            label: 'Last 7 Days',
            isSelected: is7d,
            onTap: () {
              final DateTime current = DateTime.now();
              notifier.updateDateRangeAndInterval(
                start: current.subtract(const Duration(days: 7)),
                end: current,
                interval: state.interval,
              );
            },
          ),
          const SizedBox(width: 8),
          _datePresetChip(
            label: 'Custom 📅',
            isSelected: !isToday && !isYesterday && !is24h && !is7d,
            onTap: () {
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
        ],
      ),
    );
  }

  Widget _datePresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F2042) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F2042)
                : const Color(0xFFCBD5E1),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x180F2042),
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEventsBreakdownCard(FuelReportData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF0284C7), size: 20),
              SizedBox(width: 8),
              Text(
                'Detected Fuel Events',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final Map<String, dynamic> refuel in data.refuelEvents) ...[
            _eventTile(
              isRefuel: true,
              liters: (refuel['liters'] as num?)?.toDouble() ?? 0.0,
              time: refuel['timestamp'] as DateTime?,
              address: refuel['address'] as String?,
            ),
            const SizedBox(height: 8),
          ],
          for (final Map<String, dynamic> theft in data.theftEvents) ...[
            _eventTile(
              isRefuel: false,
              liters: (theft['liters'] as num?)?.toDouble() ?? 0.0,
              time: theft['timestamp'] as DateTime?,
              address: theft['address'] as String?,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _eventTile({
    required bool isRefuel,
    required double liters,
    required DateTime? time,
    String? address,
  }) {
    final Color themeColor =
        isRefuel ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final Color bgColor =
        isRefuel ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final String title =
        isRefuel ? 'Refuel Added' : 'Potential Drain / Theft';
    final String timeStr = time != null
        ? DateFormat('dd MMM, HH:mm').format(time)
        : 'Time recorded';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRefuel
                  ? Icons.local_gas_station_rounded
                  : Icons.warning_amber_rounded,
              color: themeColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address != null && address.isNotEmpty
                      ? '$timeStr • $address'
                      : timeStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isRefuel ? '+' : '-'}${liters.toStringAsFixed(1)} L',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: themeColor,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showVehiclePickerSheet({
    required BuildContext context,
    required List<Vehicle> vehicles,
    required String? selectedId,
    required ValueChanged<String> onSelect,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: const BoxConstraints(maxWidth: 580),
      builder: (BuildContext ctx) => _FuelVehicleSearchSheet(
        vehicles: vehicles,
        selectedId: selectedId,
        onSelect: onSelect,
      ),
    );
  }
}

class _FuelVehicleSearchSheet extends StatefulWidget {
  const _FuelVehicleSearchSheet({
    required this.vehicles,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Vehicle> vehicles;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_FuelVehicleSearchSheet> createState() => _FuelVehicleSearchSheetState();
}

class _FuelVehicleSearchSheetState extends State<_FuelVehicleSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String q = _query.trim().toLowerCase();
    final List<Vehicle> filtered = widget.vehicles.where((Vehicle v) {
      if (q.isEmpty) return true;
      final String name = v.displayName.toLowerCase();
      final String plate = v.registrationNumber.toLowerCase();
      final String rawName = v.name.toLowerCase();
      final String id = v.id.toLowerCase();
      return name.contains(q) ||
          plate.contains(q) ||
          rawName.contains(q) ||
          id.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) =>
          Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header & Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Vehicle',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${filtered.length} of ${widget.vehicles.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar with AutoFocus & Clear button
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by vehicle name or plate number...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF0284C7),
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            color: const Color(0xFF64748B),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF0284C7),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (String v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Vehicle List or Empty State
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_off_rounded,
                              size: 28,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No vehicles match "$_query"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Check the spelling or try searching by registration plate.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 64,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final Vehicle v = filtered[index];
                      final bool isSelected = v.id == widget.selectedId;

                      final String initials = v.displayName.isNotEmpty
                          ? v.displayName.characters
                              .take(2)
                              .toString()
                              .toUpperCase()
                          : 'VH';

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelect(v.id);
                        },
                        child: Container(
                          color: isSelected
                              ? const Color(0xFF0284C7).withOpacity( 0.06)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFFE2E8F0),
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (v.registrationNumber.isNotEmpty)
                                          Text(
                                            v.registrationNumber,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          )
                                        else
                                          const Text(
                                            'No Plate',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        if (v.type.isNotEmpty) ...[
                                          const Text(
                                            ' • ',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          Text(
                                            v.type.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 20,
                                )
                              else
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFFCBD5E1),
                                  size: 14,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
