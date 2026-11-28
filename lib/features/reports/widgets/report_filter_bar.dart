import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/geofence.dart';
import '../../../data/models/report_models.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import 'report_top_tabs.dart';

class ReportFilterBar extends ConsumerWidget {
  const ReportFilterBar({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.vehicleId,
    required this.onVehicleChanged,
    required this.onGenerate,
    required this.isLoading,
    this.requiresVehicle = false,
    this.onTypeChanged,
    this.transitMode,
    this.onTransitModeChanged,
    this.fromGeofenceId,
    this.onFromGeofenceChanged,
    this.toGeofenceId,
    this.onToGeofenceChanged,
    this.singleGeofenceId,
    this.onSingleGeofenceChanged,
    this.geofences = const <Geofence>[],
    this.speedLimit,
    this.onSpeedLimitChanged,
    super.key,
  });

  final ReportType type;
  final DateTime startDate;
  final DateTime endDate;
  final void Function(DateTime start, DateTime end) onDateRangeChanged;
  final String? vehicleId;
  final ValueChanged<String?> onVehicleChanged;
  final VoidCallback onGenerate;
  final bool isLoading;
  final bool requiresVehicle;
  final ValueChanged<ReportType>? onTypeChanged;
  final String? transitMode;
  final ValueChanged<String>? onTransitModeChanged;
  final String? fromGeofenceId;
  final ValueChanged<String?>? onFromGeofenceChanged;
  final String? toGeofenceId;
  final ValueChanged<String?>? onToGeofenceChanged;
  final String? singleGeofenceId;
  final ValueChanged<String?>? onSingleGeofenceChanged;
  final List<Geofence> geofences;
  final int? speedLimit;
  final ValueChanged<int>? onSpeedLimitChanged;

  String _shortReportTitle(ReportType t) {
    switch (t) {
      case ReportType.trip:
        return 'Trips';
      case ReportType.dailyTrip:
        return 'Full Day';
      case ReportType.stoppages:
        return 'Stoppages';
      case ReportType.idle:
        return 'Idle Time';
      case ReportType.ignition:
        return 'Engine';
      case ReportType.overspeeding:
        return 'Overspeed';
      case ReportType.distance:
        return 'Distance';
      case ReportType.geofenceTransit:
        return 'Geofence';
      case ReportType.consolidated:
        return 'Summary';
      case ReportType.individual:
        return 'Driver';
      case ReportType.fuelRefill:
        return 'Fuel Refill';
      case ReportType.fuelTheft:
        return 'Fuel Theft';
      case ReportType.fuelConsumption:
        return 'Consumption';
      case ReportType.fuelKmpl:
        return 'KMPL';
      case ReportType.fuelLph:
        return 'LPH';
      case ReportType.fuelConsolidated:
        return 'Fuel Total';
      default:
        return t.label;
    }
  }

  LinearGradient _getGradient(ReportType type) {
    switch (type) {
      case ReportType.trip:
        return const LinearGradient(
          colors: <Color>[Color(0xFFA855F7), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.distance:
        return const LinearGradient(
          colors: <Color>[Color(0xFF0EA5E9), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.overspeeding:
        return const LinearGradient(
          colors: <Color>[Color(0xFFF43F5E), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.stoppages:
        return const LinearGradient(
          colors: <Color>[Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.idle:
        return const LinearGradient(
          colors: <Color>[Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.consolidated:
        return const LinearGradient(
          colors: <Color>[Color(0xFF22C55E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.fuelConsolidated:
        return const LinearGradient(
          colors: <Color>[Color(0xFFFB923C), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.fuelRefill:
        return const LinearGradient(
          colors: <Color>[Color(0xFF4ADE80), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.fuelTheft:
        return const LinearGradient(
          colors: <Color>[Color(0xFFFB7185), Color(0xFFE11D48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.fuelConsumption:
      case ReportType.fuelKmpl:
        return const LinearGradient(
          colors: <Color>[Color(0xFF38BDF8), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.fuelLph:
        return const LinearGradient(
          colors: <Color>[Color(0xFFFBBF24), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.geofenceTransit:
        return const LinearGradient(
          colors: <Color>[Color(0xFF14B8A6), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.geofenceSinglePlace:
        return const LinearGradient(
          colors: <Color>[Color(0xFF818CF8), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.dailyTrip:
        return const LinearGradient(
          colors: <Color>[Color(0xFF34D399), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.ignition:
        return const LinearGradient(
          colors: <Color>[Color(0xFFFBBF24), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ReportType.individual:
      default:
        return const LinearGradient(
          colors: <Color>[Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getAccentColor(ReportType type) {
    switch (type) {
      case ReportType.trip:
        return const Color(0xFF9333EA);
      case ReportType.distance:
        return const Color(0xFF0284C7);
      case ReportType.overspeeding:
        return const Color(0xFFE11D48);
      case ReportType.stoppages:
        return const Color(0xFFEA580C);
      case ReportType.idle:
        return const Color(0xFFD97706);
      case ReportType.consolidated:
        return const Color(0xFF16A34A);
      case ReportType.fuelConsolidated:
        return const Color(0xFFEA580C);
      case ReportType.geofenceTransit:
        return const Color(0xFF0D9488);
      case ReportType.geofenceSinglePlace:
        return const Color(0xFF6366F1);
      case ReportType.dailyTrip:
        return const Color(0xFF10B981);
      case ReportType.ignition:
        return const Color(0xFFD97706);
      case ReportType.individual:
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? activeColor,
  }) {
    final Color effectiveActiveColor = activeColor ?? _getAccentColor(type);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? effectiveActiveColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? effectiveActiveColor : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: effectiveActiveColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 12, color: selected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 4),
            ] else if (selected) ...<Widget>[
              const Icon(Icons.check_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Vehicle> allVehicles = ref.watch(groupScopedVehiclesProvider);
    final List<Vehicle> vehicles = type == ReportType.nonSensorFuel
        ? (allVehicles.where((Vehicle v) => v.isNonSensorFuel).isNotEmpty
            ? allVehicles.where((Vehicle v) => v.isNonSensorFuel).toList()
            : allVehicles)
        : (type.isFuelReport
            ? allVehicles.where((Vehicle v) => v.hasFuel).toList()
            : allVehicles);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // CATEGORY & REPORT DROPDOWN SELECTOR
          if (onTypeChanged != null) ...<Widget>[
            () {
              final bool isFuel = type.isFuelReport;
              final bool hasFuelVehicles = allVehicles.any((Vehicle v) => v.hasFuel);

              // Standard reports list
              const List<ReportType> standardTypes = <ReportType>[
                ReportType.trip,
                ReportType.dailyTrip,
                ReportType.stoppages,
                ReportType.idle,
                ReportType.ignition,
                ReportType.overspeeding,
                ReportType.distance,
                ReportType.geofenceTransit,
                ReportType.consolidated,
                ReportType.individual,
              ];

              // Fuel reports list
              const List<ReportType> fuelTypes = <ReportType>[
                ReportType.fuelRefill,
                ReportType.fuelTheft,
                ReportType.fuelConsumption,
                ReportType.fuelKmpl,
                ReportType.fuelLph,
                ReportType.fuelConsolidated,
              ];

              final List<ReportType> activeTypeList = isFuel ? fuelTypes : standardTypes;

              final ReportTabMeta currentMeta = kReportTabs.where((t) => t.type == type).firstOrNull ??
                  ReportTabMeta(
                    type: type,
                    category: isFuel ? ReportCategory.fuel : ReportCategory.trips,
                    title: type.label,
                    description: '',
                    icon: isFuel ? Icons.local_gas_station_rounded : Icons.alt_route_rounded,
                    color: const Color(0xFF2563EB),
                    bg: const Color(0xFFEFF6FF),
                  );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'REPORT TYPE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Direct Dropdown Category Buttons (Single Row, No second box)
                  Row(
                    children: <Widget>[
                      // Standard Reports Dropdown Button
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            popupMenuTheme: PopupMenuThemeData(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 6,
                            ),
                          ),
                          child: PopupMenuButton<ReportType>(
                            tooltip: 'Select Standard Report',
                            initialValue: !isFuel ? type : null,
                            onSelected: (ReportType selected) {
                              onTypeChanged!(selected);
                            },
                            itemBuilder: (BuildContext context) => standardTypes.map((ReportType rType) {
                              final ReportTabMeta itemMeta = kReportTabs.where((t) => t.type == rType).firstOrNull ??
                                  ReportTabMeta(
                                    type: rType,
                                    category: ReportCategory.trips,
                                    title: rType.label,
                                    description: '',
                                    icon: Icons.alt_route_rounded,
                                    color: const Color(0xFF2563EB),
                                    bg: const Color(0xFFEFF6FF),
                                  );
                              final bool isSelected = !isFuel && type == rType;

                              return PopupMenuItem<ReportType>(
                                value: rType,
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: itemMeta.color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(itemMeta.icon, size: 16, color: itemMeta.color),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        itemMeta.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                        ),

                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2563EB)),
                                  ],
                                ),
                              );
                            }).toList(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: !isFuel ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !isFuel ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                  width: !isFuel ? 1.5 : 1.0,
                                ),
                                boxShadow: !isFuel
                                    ? const <BoxShadow>[
                                        BoxShadow(
                                          color: Color(0x18000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    !isFuel ? currentMeta.icon : Icons.alt_route_rounded,
                                    size: 16,
                                    color: !isFuel ? Colors.white : const Color(0xFF475569),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      !isFuel ? _shortReportTitle(type) : 'Standard',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: !isFuel ? FontWeight.w800 : FontWeight.w600,
                                        color: !isFuel ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 20,
                                    color: !isFuel ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasFuelVehicles) ...<Widget>[
                        const SizedBox(width: 8),
                        // Fuel Reports Dropdown Button
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              popupMenuTheme: PopupMenuThemeData(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 6,
                              ),
                            ),
                            child: PopupMenuButton<ReportType>(
                              tooltip: 'Select Fuel Report',
                              initialValue: isFuel ? type : null,
                              onSelected: (ReportType selected) {
                                onTypeChanged!(selected);
                              },
                              itemBuilder: (BuildContext context) => fuelTypes.map((ReportType rType) {
                                final ReportTabMeta itemMeta = kReportTabs.where((t) => t.type == rType).firstOrNull ??
                                    ReportTabMeta(
                                      type: rType,
                                      category: ReportCategory.fuel,
                                      title: rType.label,
                                      description: '',
                                      icon: Icons.local_gas_station_rounded,
                                      color: const Color(0xFF059669),
                                      bg: const Color(0xFFECFDF5),
                                    );
                                final bool isSelected = isFuel && type == rType;

                                return PopupMenuItem<ReportType>(
                                  value: rType,
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: itemMeta.color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(itemMeta.icon, size: 16, color: itemMeta.color),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          itemMeta.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                          ),
  
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_rounded, size: 16, color: Color(0xFF059669)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isFuel ? const Color(0xFF059669) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isFuel ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                    width: isFuel ? 1.5 : 1.0,
                                  ),
                                  boxShadow: isFuel
                                      ? const <BoxShadow>[
                                          BoxShadow(
                                            color: Color(0x18000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(
                                      isFuel ? currentMeta.icon : Icons.local_gas_station_rounded,
                                      size: 16,
                                      color: isFuel ? Colors.white : const Color(0xFF475569),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isFuel ? _shortReportTitle(type) : 'Fuel',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isFuel ? FontWeight.w800 : FontWeight.w600,
                                          color: isFuel ? Colors.white : const Color(0xFF334155),
                                        ),

                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 20,
                                      color: isFuel ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              );
            }(),
          ],
          // Geofence Transit Mode Selector (All | One-Way | Two-Way | Round Trip)
          if (type == ReportType.geofenceTransit) ...<Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.sync_alt_rounded, size: 14, color: Color(0xFF0D9488)),
                    SizedBox(width: 6),
                    Text(
                      'CORRIDOR TRANSIT MODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: <Widget>[
                      _buildChip(
                        context: context,
                        label: 'All Trips',
                        selected: (transitMode ?? 'all') == 'all',
                        onTap: () => onTransitModeChanged?.call('all'),
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        context: context,
                        label: 'One-Way (A ➔ B)',
                        selected: transitMode == 'single_way',
                        onTap: () => onTransitModeChanged?.call('single_way'),
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        context: context,
                        label: 'Two-Way (A ⇄ B)',
                        selected: transitMode == 'two_way',
                        onTap: () => onTransitModeChanged?.call('two_way'),
                      ),
                      const SizedBox(width: 8),
                      _buildChip(
                        context: context,
                        label: 'Round Trip (A ➔ A)',
                        selected: transitMode == 'same_location',
                        onTap: () => onTransitModeChanged?.call('same_location'),
                      ),
                    ],
                  ),
                ),
                if (geofences.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      // From Geofence
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'ORIGIN (FROM)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: fromGeofenceId,
                                  hint: const Text('All Places', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  items: <DropdownMenuItem<String?>>[
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Places', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                    ...geofences.map((g) => DropdownMenuItem<String?>(
                                      value: g.id,
                                      child: Text(g.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                    )),
                                  ],
                                  onChanged: onFromGeofenceChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // To Geofence
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'DESTINATION (TO)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: toGeofenceId,
                                  hint: const Text('All Places', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  items: <DropdownMenuItem<String?>>[
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Places', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ),
                                    ...geofences.map((g) => DropdownMenuItem<String?>(
                                      value: g.id,
                                      child: Text(g.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                    )),
                                  ],
                                  onChanged: onToGeofenceChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
              ],
            ),
          ],

          // Single Place Activity Selector
          if (type == ReportType.geofenceSinglePlace && geofences.isNotEmpty) ...<Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.fmd_good_rounded, size: 14, color: Color(0xFF6366F1)),
                    SizedBox(width: 6),
                    Text(
                      'SELECT GEOFENCE / PLACE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: singleGeofenceId,
                      hint: const Text('All Geofences & Places', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Geofences & Places', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        ...geofences.map((g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: onSingleGeofenceChanged,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ],


          // Overspeeding Speed Limit Input Field
          if (type == ReportType.overspeeding) ...<Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Icon(Icons.speed_rounded, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 6),
                    Text(
                      'SPEED LIMIT (KM/H)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.speed_rounded, size: 18, color: Color(0xFFDC2626)),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: (speedLimit ?? 60).toString(),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter speed limit (e.g. 60)',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (String val) {
                            final int? limit = int.tryParse(val.trim());
                            if (limit != null && limit > 0) {
                              onSpeedLimitChanged?.call(limit);
                            }
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Text(
                          'km/h',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ],

          // Vehicle Selection Dropdown
          () {
            final String? selectedValue = (vehicleId != null &&
                    (vehicleId == '__all__' ||
                        vehicleId == 'all' ||
                        vehicles.any((Vehicle v) => v.id == vehicleId)))
                ? (vehicleId == 'all' ? '__all__' : vehicleId)
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'VEHICLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.35),
                      width: 1.1,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedValue,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded,
                          size: 24, color: Color(0xFF64748B)),
                      hint: const Row(
                        children: [
                          Icon(Icons.directions_car_outlined,
                              size: 18, color: Color(0xFF94A3B8)),
                          SizedBox(width: 8),
                          Text(
                            'Select Vehicle...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: '__all__',
                          child: Row(
                            children: [
                              Icon(Icons.grid_view_rounded,
                                  size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text(
                                'All Vehicles',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...vehicles.asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final Vehicle v = entry.value;
                          final Color vehicleIconColor = <Color>[
                            const Color(0xFF10B981), // Emerald Green
                            const Color(0xFFEA580C), // Vibrant Orange
                            const Color(0xFF2563EB), // Royal Blue
                            const Color(0xFF9333EA), // Purple
                            const Color(0xFFDB2777), // Pink
                            const Color(0xFF06B6D4), // Cyan
                            const Color(0xFFD97706), // Amber
                          ][idx % 7];

                          return DropdownMenuItem<String?>(
                            value: v.id,
                            child: Row(
                              children: [
                                Icon(Icons.directions_car_rounded,
                                    size: 18, color: vehicleIconColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    v.registrationNumber.isNotEmpty &&
                                            v.registrationNumber !=
                                                v.displayName
                                        ? '${v.displayName} (${v.registrationNumber})'
                                        : v.displayName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? val) {
                        onVehicleChanged(val);
                      },
                    ),
                  ),
                ),
              ],
            );
          }(),
          const SizedBox(height: 16),

          // Generate Button with Web Gradient
          SizedBox(
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _getGradient(type),
                borderRadius: BorderRadius.circular(8),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _getAccentColor(type).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : onGenerate,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Generate Report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
