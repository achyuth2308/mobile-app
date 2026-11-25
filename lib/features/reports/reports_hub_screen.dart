import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/models/report_models.dart';
import '../../providers/fleet_provider.dart';
import 'report_detail_screen.dart';

/// Reports Hub: 4-category executive entry point
/// 1. Reports (General Fleet Telemetry: Idle, Stoppage, Distance, Overspeed, Engine On, Consolidated)
/// 2. Fuel Reports (Sensor: Fuel Graph, KMPL, LPH, Refill, Theft, Fuel Consolidated, Consumption)
/// 3. Trips (Automated Trips, Full Day Trips, Geofence Trips)
/// 4. Non-Sensor Fuel Report (Manual Fuel Ingestion & Mileage Analytics)
class ReportsHubScreen extends ConsumerStatefulWidget {
  final String? initialVehicleId;
  final ReportType? initialType;
  final String? initialFromGeofenceId;
  final String? initialToGeofenceId;
  final String? initialMode;

  const ReportsHubScreen({
    this.initialVehicleId,
    this.initialType,
    this.initialFromGeofenceId,
    this.initialToGeofenceId,
    this.initialMode,
    super.key,
  });

  @override
  ConsumerState<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends ConsumerState<ReportsHubScreen> {
  ReportType? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void didUpdateWidget(covariant ReportsHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialType != oldWidget.initialType) {
      setState(() {
        _selectedType = widget.initialType;
      });
    }
  }

  // ── 1. General Reports ──────────────────────────────────────────────────────
  static const List<_ReportItemDef> _generalReports = [
    _ReportItemDef(
      type: ReportType.idle,
      title: 'Idle Report',
      description: 'Engine idling duration without movement (fuel waste logs)',
      icon: Icons.access_time_rounded,
      color: Color(0xFFD97706),
      bg: Color(0xFFFEF3C7),
    ),
    _ReportItemDef(
      type: ReportType.stoppages,
      title: 'Stoppage Report',
      description: 'Standstill & parking locations with exact halt durations',
      icon: Icons.pause_circle_rounded,
      color: Color(0xFFEA580C),
      bg: Color(0xFFFFEDD5),
    ),
    _ReportItemDef(
      type: ReportType.distance,
      title: 'Distance Report',
      description: 'Daily odometer accumulation and total distance covered',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF2563EB),
      bg: Color(0xFFEFF6FF),
    ),
    _ReportItemDef(
      type: ReportType.overspeeding,
      title: 'Overspeed Report',
      description: 'Speed threshold breaches with peak speed & locations',
      icon: Icons.speed_rounded,
      color: Color(0xFFE11D48),
      bg: Color(0xFFFFF1F2),
    ),
    _ReportItemDef(
      type: ReportType.ignition,
      title: 'Engine On / Off',
      description: 'Key ignition on/off events timeline and operating hours',
      icon: Icons.power_settings_new_rounded,
      color: Color(0xFF059669),
      bg: Color(0xFFECFDF5),
    ),
    _ReportItemDef(
      type: ReportType.consolidated,
      title: 'Vehicle Consolidated',
      description: 'Fleet-wide operational roll-up and multi-vehicle summary',
      icon: Icons.group_work_rounded,
      color: Color(0xFF7C3AED),
      bg: Color(0xFFF5F3FF),
    ),
  ];

  // ── 2. Fuel Reports (Sensor) ────────────────────────────────────────────────
  static const List<_ReportItemDef> _fuelReports = [
    _ReportItemDef(
      type: null,
      title: 'Fuel Graph',
      description: 'Interactive dual-axis graph with 2-stage zoom telemetry',
      icon: Icons.show_chart_rounded,
      color: Color(0xFF0284C7),
      bg: Color(0xFFF0F9FF),
      isFuelGraph: true,
    ),
    _ReportItemDef(
      type: ReportType.fuelKmpl,
      title: 'KMPL Report',
      description: 'Kilometers per liter operational efficiency metric',
      icon: Icons.speed_rounded,
      color: Color(0xFF059669),
      bg: Color(0xFFECFDF5),
    ),
    _ReportItemDef(
      type: ReportType.fuelLph,
      title: 'LPH Report',
      description: 'Liters per hour consumption rate during operations',
      icon: Icons.timelapse_rounded,
      color: Color(0xFFD97706),
      bg: Color(0xFFFEF3C7),
    ),
    _ReportItemDef(
      type: ReportType.fuelRefill,
      title: 'Refill Report',
      description: 'Verified fuel intake events with volume & location stamps',
      icon: Icons.local_gas_station_rounded,
      color: Color(0xFF16A34A),
      bg: Color(0xFFDCFCE7),
    ),
    _ReportItemDef(
      type: ReportType.fuelTheft,
      title: 'Theft Report',
      description: 'Abrupt level drops, siphoning alerts & drain detection',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFDC2626),
      bg: Color(0xFFFEF2F2),
    ),
    _ReportItemDef(
      type: ReportType.fuelConsolidated,
      title: 'Fuel Consolidated',
      description: 'Fleet-wide fuel telemetry roll-up and audit summary',
      icon: Icons.summarize_rounded,
      color: Color(0xFF0D9488),
      bg: Color(0xFFF0FDFA),
    ),
    _ReportItemDef(
      type: ReportType.fuelConsumption,
      title: 'Fuel Consumption',
      description: 'Fuel volume burned across driving vs idle intervals',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF0891B2),
      bg: Color(0xFFECFEFF),
    ),
  ];

  // ── 3. Trips Reports ────────────────────────────────────────────────────────
  static const List<_ReportItemDef> _tripsReports = [
    _ReportItemDef(
      type: ReportType.trip,
      title: 'Automated Trips',
      description: 'Start/end points, distance, duration & route replays',
      icon: Icons.alt_route_rounded,
      color: Color(0xFF2563EB),
      bg: Color(0xFFEFF6FF),
    ),
    _ReportItemDef(
      type: ReportType.dailyTrip,
      title: 'Full Day Trips',
      description: '24-hour daily journey summary & day-by-day logs',
      icon: Icons.today_rounded,
      color: Color(0xFF4F46E5),
      bg: Color(0xFFEEF2FF),
    ),
    _ReportItemDef(
      type: ReportType.geofenceTransit,
      title: 'Geofence Trips',
      description: 'Entry, exit & dwell times across defined operational zones',
      icon: Icons.fence_rounded,
      color: Color(0xFF0D9488),
      bg: Color(0xFFF0FDFA),
    ),
  ];

  // ── 4. Non-Sensor Fuel Reports (Manual) ─────────────────────────────────────
  static const List<_ReportItemDef> _manualFuelReports = [
    _ReportItemDef(
      type: null,
      title: 'Manual Fuel Log',
      description: 'Non-sensor vehicle fuel purchase & manual intake entries',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF7C3AED),
      bg: Color(0xFFF5F3FF),
      isManualFuel: true,
    ),
    _ReportItemDef(
      type: null,
      title: 'Non-Sensor Mileage Summary',
      description: 'Calculated KM/L and consumption for manual fuel vehicles',
      icon: Icons.calculate_rounded,
      color: Color(0xFF9333EA),
      bg: Color(0xFFFAF5FF),
      isManualFuel: true,
    ),
  ];

  void _showFuelGraphVehiclePicker(BuildContext context) {
    final fleetState = ref.read(fleetProvider);
    final fuelVehicles = fleetState.vehicles.where((v) => v.hasFuel).toList();

    if (fuelVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No fuel-sensor equipped vehicles found in your fleet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.initialVehicleId != null &&
        fuelVehicles.any((v) => v.id == widget.initialVehicleId)) {
      context.push('/vehicle/${widget.initialVehicleId}/fuel-analytics');
      return;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E2238) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.show_chart_rounded,
                          color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Vehicle for Fuel Graph',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Choose a vehicle with fuel sensor telemetry',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? Colors.grey.shade400
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: fuelVehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext _, int index) {
                      final v = fuelVehicles[index];
                      return ListTile(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          context.push('/vehicle/${v.id}/fuel-analytics');
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        tileColor: isDark
                            ? const Color(0xFF262B45)
                            : const Color(0xFFF8FAFC),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping_rounded,
                              color: Color(0xFF0284C7), size: 18),
                        ),
                        title: Text(
                          v.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          'Plate: ${v.plate.isNotEmpty ? v.plate : "N/A"}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualFuelInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.edit_note_rounded,
              color: Color(0xFF7C3AED), size: 36),
        ),
        title: const Text(
          'Non-Sensor Fuel Report',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: const Text(
          'Non-sensor fuel monitoring allows logging manual fuel bills, pump receipts, and tracking odometer mileage for vehicles without hardware fuel level sensors.\n\nManual entries sync directly with the production database.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If an individual report table is selected, show ReportDetailScreen
    if (_selectedType != null) {
      return ReportDetailScreen(
        key: ValueKey<String>(
            '${widget.initialVehicleId}_${_selectedType!.name}'),
        type: _selectedType!,
        initialVehicleId: widget.initialVehicleId,
        initialFromGeofenceId: widget.initialFromGeofenceId,
        initialToGeofenceId: widget.initialToGeofenceId,
        initialMode: widget.initialMode,
        onBackToHub: () {
          setState(() {
            _selectedType = null;
          });
        },
      );
    }

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF162036) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 48),
        children: [
          _buildReportSection('Reports', _generalReports, isDark),
          _buildReportSection('Fuel & Sensors', _fuelReports, isDark),
          _buildReportSection('Trips', _tripsReports, isDark),
          _buildReportSection('Non-Sensor Fuel', _manualFuelReports, isDark),
        ],
      ),
    );
  }

  Widget _buildReportSection(
    String title,
    List<_ReportItemDef> items,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162036) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _buildReportRow(items[i], isDark),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      indent: 58,
                      endIndent: 0,
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportRow(_ReportItemDef item, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.isFuelGraph) {
            _showFuelGraphVehiclePicker(context);
          } else if (item.isManualFuel) {
            _showManualFuelInfoDialog(context);
          } else if (item.type != null) {
            setState(() {
              _selectedType = item.type;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? item.color.withOpacity(0.18)
                      : item.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color:
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportItemDef {
  final ReportType? type;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool isFuelGraph;
  final bool isManualFuel;

  const _ReportItemDef({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bg,
    this.isFuelGraph = false,
    this.isManualFuel = false,
  });
}
