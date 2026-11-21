import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/report_models.dart';
import '../../../data/models/vehicle.dart';

enum ReportCategory {
  trips,
  activity,
  fuel,
  safety,
}

class ReportTabMeta {
  const ReportTabMeta({
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final ReportType type;
  final ReportCategory category;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bg;
}

const List<ReportTabMeta> kReportTabs = <ReportTabMeta>[
  // TRIPS CATEGORY
  ReportTabMeta(
    type: ReportType.trip,
    category: ReportCategory.trips,
    title: 'Trips',
    description: 'Start/end points, distance, duration & route replays',
    icon: Icons.alt_route_rounded,
    color: Color(0xFF2563EB),
    bg: Color(0xFFEFF6FF),
  ),
  ReportTabMeta(
    type: ReportType.dailyTrip,
    category: ReportCategory.trips,
    title: 'Full Day Trips',
    description: '24-hour operational cycle and daily journey breakdown',
    icon: Icons.route_rounded,
    color: Color(0xFF2563EB),
    bg: Color(0xFFEFF6FF),
  ),
  ReportTabMeta(
    type: ReportType.geofenceTransit,
    category: ReportCategory.trips,
    title: 'Geofence Trips',
    description: 'Entry, exit & dwell times across defined operational zones',
    icon: Icons.fence_rounded,
    color: Color(0xFF2563EB),
    bg: Color(0xFFEFF6FF),
  ),
  ReportTabMeta(
    type: ReportType.distance,
    category: ReportCategory.trips,
    title: 'Day Distance',
    description: 'Daily odometer accumulation and distance travelled',
    icon: Icons.trending_up_rounded,
    color: Color(0xFF2563EB),
    bg: Color(0xFFEFF6FF),
  ),

  // ACTIVITY & STOPS CATEGORY
  ReportTabMeta(
    type: ReportType.stoppages,
    category: ReportCategory.activity,
    title: 'Stoppages',
    description: 'Parking & standstill locations with exact halt durations',
    icon: Icons.pause_circle_rounded,
    color: Color(0xFFD97706),
    bg: Color(0xFFFEF3C7),
  ),
  ReportTabMeta(
    type: ReportType.idle,
    category: ReportCategory.activity,
    title: 'Idle Time',
    description: 'Engine active without movement (fuel waste analytics)',
    icon: Icons.access_time_rounded,
    color: Color(0xFFD97706),
    bg: Color(0xFFFEF3C7),
  ),
  ReportTabMeta(
    type: ReportType.ignition,
    category: ReportCategory.activity,
    title: 'Engine On / Off',
    description: 'Key ignition on/off events timeline and intervals',
    icon: Icons.power_settings_new_rounded,
    color: Color(0xFFD97706),
    bg: Color(0xFFFEF3C7),
  ),
  ReportTabMeta(
    type: ReportType.consolidated,
    category: ReportCategory.activity,
    title: 'Consolidated',
    description: 'High-level fleet-wide operational summary report',
    icon: Icons.group_work_rounded,
    color: Color(0xFFD97706),
    bg: Color(0xFFFEF3C7),
  ),

  // FUEL TELEMETRY CATEGORY
  ReportTabMeta(
    type: ReportType.fuelRefill,
    category: ReportCategory.fuel,
    title: 'Fuel Refill',
    description: 'Verified fuel intake events with volume & location stamps',
    icon: Icons.local_gas_station_rounded,
    color: Color(0xFF059669),
    bg: Color(0xFFECFDF5),
  ),
  ReportTabMeta(
    type: ReportType.fuelTheft,
    category: ReportCategory.fuel,
    title: 'Fuel Theft',
    description: 'Abrupt level drops, siphoning alerts & drain detection',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFDC2626),
    bg: Color(0xFFFEF2F2),
  ),
  ReportTabMeta(
    type: ReportType.fuelConsumption,
    category: ReportCategory.fuel,
    title: 'Consumption',
    description: 'Fuel volume burned across driving vs idle intervals',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF059669),
    bg: Color(0xFFECFDF5),
  ),
  ReportTabMeta(
    type: ReportType.fuelKmpl,
    category: ReportCategory.fuel,
    title: 'KMPL Economy',
    description: 'Kilometers per liter operational efficiency metric',
    icon: Icons.speed_rounded,
    color: Color(0xFF059669),
    bg: Color(0xFFECFDF5),
  ),
  ReportTabMeta(
    type: ReportType.fuelLph,
    category: ReportCategory.fuel,
    title: 'LPH Rate',
    description: 'Liters per hour consumption rate during operations',
    icon: Icons.timelapse_rounded,
    color: Color(0xFF059669),
    bg: Color(0xFFECFDF5),
  ),
  ReportTabMeta(
    type: ReportType.fuelConsolidated,
    category: ReportCategory.fuel,
    title: 'Fuel Consolidated',
    description: 'Fleet-wide fuel telemetry roll-up and audit summary',
    icon: Icons.summarize_rounded,
    color: Color(0xFF059669),
    bg: Color(0xFFECFDF5),
  ),

  // SAFETY & DRIVERS CATEGORY
  ReportTabMeta(
    type: ReportType.overspeeding,
    category: ReportCategory.safety,
    title: 'Overspeeding',
    description: 'Speed threshold breaches with peak speed & location',
    icon: Icons.speed_rounded,
    color: Color(0xFFE11D48),
    bg: Color(0xFFFFF1F2),
  ),
  ReportTabMeta(
    type: ReportType.individual,
    category: ReportCategory.safety,
    title: 'Driver / Individual',
    description: 'Driver-assigned trip logs and operational adherence',
    icon: Icons.person_rounded,
    color: Color(0xFFE11D48),
    bg: Color(0xFFFFF1F2),
  ),
];

class ReportTopTabs extends StatefulWidget {
  const ReportTopTabs({
    required this.selectedType,
    required this.onTabSelected,
    this.activeVehicle,
    super.key,
  });

  final ReportType selectedType;
  final ValueChanged<ReportType> onTabSelected;
  final Vehicle? activeVehicle;

  @override
  State<ReportTopTabs> createState() => _ReportTopTabsState();
}

class _ReportTopTabsState extends State<ReportTopTabs> {
  late ReportCategory _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = _categoryForType(widget.selectedType);
  }

  @override
  void didUpdateWidget(covariant ReportTopTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      final ReportCategory cat = _categoryForType(widget.selectedType);
      if (cat != _activeCategory) {
        setState(() {
          _activeCategory = cat;
        });
      }
    }
  }

  ReportCategory _categoryForType(ReportType type) {
    final ReportTabMeta? meta = kReportTabs.where((t) => t.type == type).firstOrNull;
    return meta?.category ?? ReportCategory.trips;
  }

  List<ReportTabMeta> _filteredTabs() {
    return kReportTabs.where((ReportTabMeta tab) {
      if (tab.type.isFuelReport) {
        if (widget.activeVehicle != null && !widget.activeVehicle!.hasFuel) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showAllReportsModal(BuildContext context, List<ReportTabMeta> availableTabs) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AllReportsBottomSheet(
        tabs: availableTabs,
        selectedType: widget.selectedType,
        onSelect: (ReportType type) {
          widget.onTabSelected(type);
          setState(() {
            _activeCategory = _categoryForType(type);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<ReportTabMeta> allTabs = _filteredTabs();

    // Group categories present in available tabs
    final bool hasFuel = allTabs.any((t) => t.category == ReportCategory.fuel);
    final List<_CategoryData> categories = <_CategoryData>[
      const _CategoryData(
        category: ReportCategory.trips,
        label: 'Trips',
        icon: Icons.alt_route_rounded,
        accentColor: Color(0xFF2563EB),
      ),
      const _CategoryData(
        category: ReportCategory.activity,
        label: 'Activity',
        icon: Icons.timer_outlined,
        accentColor: Color(0xFFD97706),
      ),
      if (hasFuel)
        const _CategoryData(
          category: ReportCategory.fuel,
          label: 'Fuel',
          icon: Icons.local_gas_station_rounded,
          accentColor: Color(0xFF059669),
        ),
      const _CategoryData(
        category: ReportCategory.safety,
        label: 'Safety',
        icon: Icons.shield_outlined,
        accentColor: Color(0xFFE11D48),
      ),
    ];

    // Sub-reports for the active category
    final List<ReportTabMeta> subTabs = allTabs
        .where((t) => t.category == _activeCategory)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // LEVEL 1: High-Level Category Segmented Bar + Quick Search Sheet Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: categories.map((_CategoryData cat) {
                        final bool isCatActive = cat.category == _activeCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _activeCategory = cat.category;
                              });
                              // Auto-select first report of category if current report is not in it
                              final List<ReportTabMeta> inCat = allTabs
                                  .where((t) => t.category == cat.category)
                                  .toList();
                              if (inCat.isNotEmpty && !inCat.any((t) => t.type == widget.selectedType)) {
                                widget.onTabSelected(inCat.first.type);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isCatActive
                                    ? (isDark ? cat.accentColor.withValues(alpha: 0.25) : cat.accentColor.withValues(alpha: 0.12))
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isCatActive
                                      ? cat.accentColor
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: isCatActive ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cat.icon,
                                    size: 15,
                                    color: isCatActive
                                        ? cat.accentColor
                                        : (isDark ? Colors.white60 : const Color(0xFF475569)),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCatActive ? FontWeight.w800 : FontWeight.w600,
                                      color: isCatActive
                                          ? (isDark ? Colors.white : cat.accentColor)
                                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Instant "All Reports" Sheet Action Pill
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showAllReportsModal(context, allTabs);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.dashboard_customize_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // LEVEL 2: Sub-Report Chips for the selected category
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: subTabs.map((ReportTabMeta tab) {
                final bool isSelected = tab.type == widget.selectedType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTabSelected(tab.type);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? tab.color.withValues(alpha: 0.22) : tab.bg)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? tab.color
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: tab.color.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.icon,
                            size: 15,
                            color: isSelected ? tab.color : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tab.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? Colors.white : tab.color)
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryData {
  const _CategoryData({
    required this.category,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  final ReportCategory category;
  final String label;
  final IconData icon;
  final Color accentColor;
}

/// All Reports Modal Bottom Sheet with live search & grouped categories
class AllReportsBottomSheet extends StatefulWidget {
  const AllReportsBottomSheet({
    required this.tabs,
    required this.selectedType,
    required this.onSelect,
    super.key,
  });

  final List<ReportTabMeta> tabs;
  final ReportType selectedType;
  final ValueChanged<ReportType> onSelect;

  static void show(
    BuildContext context, {
    required ReportType selectedType,
    required ValueChanged<ReportType> onSelect,
    Vehicle? activeVehicle,
  }) {
    final List<ReportTabMeta> availableTabs = kReportTabs.where((ReportTabMeta tab) {
      if (tab.type.isFuelReport) {
        if (activeVehicle != null && !activeVehicle.hasFuel) {
          return false;
        }
      }
      return true;
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AllReportsBottomSheet(
        tabs: availableTabs,
        selectedType: selectedType,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<AllReportsBottomSheet> createState() => _AllReportsBottomSheetState();
}

class _AllReportsBottomSheetState extends State<AllReportsBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String q = _query.trim().toLowerCase();

    final List<ReportTabMeta> filtered = q.isEmpty
        ? widget.tabs
        : widget.tabs.where((t) {
            return t.title.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q) ||
                t.category.name.toLowerCase().contains(q);
          }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    size: 20,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet Intelligence Reports',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select from all 15 operational reports',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (String val) {
                setState(() {
                  _query = val;
                });
              },
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search report by name or metric...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Report List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No reports match "$_query"',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (BuildContext context, int index) {
                      final ReportTabMeta item = filtered[index];
                      final bool isSelected = item.type == widget.selectedType;

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelect(item.type);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? item.color.withValues(alpha: 0.18) : item.bg)
                                : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? item.color
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(item.icon, size: 20, color: item.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: item.color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.category.name.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: item.color,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.description,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: item.color,
                                )
                              else
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
