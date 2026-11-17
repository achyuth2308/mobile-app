import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        elevation: 0,
        title: const Text(
          'Fuel Report',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          // Date & Time Filter Sheet
          IconButton(
            tooltip: 'Filter Date & Interval',
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF0F172A),
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
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Vehicle Selector Header Bar with Search
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: () {
                _showVehiclePickerSheet(
                  context: context,
                  vehicles: vehicles,
                  selectedId: state.selectedVehicleId,
                  onSelect: (String newId) {
                    notifier.selectVehicle(newId);
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACTIVE VEHICLE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            vehicleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 14,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Isolated Fuel Graph Card with Web App Header and Toggles
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
                            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
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
                                              Expanded(
                                                 child: Expanded(
                                                 child: Expanded(
                                                 child: Text(
                                                   'Fuel vs. Speed vs. Distance Correlation',
                                                   style: TextStyle(
                                                     fontSize: 13,
                                                     fontWeight: FontWeight.w800,
                                                     color: Color(0xFF0F172A),
                                                   ),
                                                 ),
                                               ),
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

                                // Series Toggles (Filtered Fuel, Engine, Speed)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      // 1. Filtered Fuel Data (Default Active)
                                      _webToggleChip(
                                        label: 'Filtered Fuel Data',
                                        isSelected: state.showFilteredFuel,
                                        activeColor: const Color(0xFF0284C7),
                                        onTap: notifier.toggleFilteredFuel,
                                      ),
                                      const SizedBox(width: 8),

                                      // 2. Engine
                                      _webToggleChip(
                                        label: 'Engine',
                                        isSelected: state.showEngine,
                                        activeColor: const Color(0xFFEAB308),
                                        onTap: notifier.toggleEngine,
                                      ),
                                      const SizedBox(width: 8),

                                      // 3. Speed
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

                                // Dedicated Fuel Analytics Chart
                                FuelAnalyticsChart(
                                  points: data.points,
                                  showAllFuel: state.showAllFuel,
                                  showFilteredFuel: state.showFilteredFuel,
                                  showNormalize: state.showNormalize,
                                  showSpeed: state.showSpeed,
                                  showEngine: state.showEngine,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
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
                              ? const Color(0xFF0284C7).withOpacity(0.06)
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
