import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/vehicle.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/connectivity_banner.dart';
import 'widgets/stat_tiles.dart';
import 'widgets/vehicle_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() => ref.read(fleetProvider.notifier).load();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final FleetState fleet = ref.watch(fleetProvider);
    final int alertCount = ref.watch(unreadAlertsCountProvider);
    final List<Vehicle> vehicles = ref.watch(filteredVehiclesProvider);
    final List<FleetGroup> groups = ref.watch(availableFleetGroupsProvider);
    final String? activeGroupId = ref.watch(fleetGroupFilterProvider);
    final String? name = ref.watch(authProvider).user?.name;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 100,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            // ── Header ─────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 88,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              titleSpacing: Gap.md,
              title: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeGreeting(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text('👋', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (name ?? '').trim().isNotEmpty
                                ? (name ?? '').trim()
                                : 'Operator',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                Fmt.date(DateTime.now()),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      tooltip: 'Alerts',
                      onPressed: () => context.push('/alerts'),
                      icon: Badge(
                        isLabelVisible: alertCount > 0,
                        backgroundColor: const Color(0xFFEF4444),
                        textColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text(alertCount > 99 ? '99+' : '$alertCount'),
                        child: Icon(
                          alertCount > 0
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_rounded,
                          size: 24,
                          color: isDark
                              ? const Color(0xFFFBBF24) // Radiant Gold
                              : const Color(0xFFD97706), // Rich Metallic Gold
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton(
                      tooltip: 'Profile',
                      onPressed: () => context.push('/profile-settings'),
                      icon: Icon(
                        Icons.person_rounded,
                        size: 26,
                        color: isDark ? const Color(0xFF818CF8) : AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Overview ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const OfflineNotice(),
                    const FleetOverviewCard()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.08),
                    // ── Search Bar directly after Fleet Overview card ────
                    Container(
                      margin: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
                      padding: const EdgeInsets.fromLTRB(7, 5, 14, 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF162036) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.brand.withValues(alpha: 0.38)
                              : AppColors.brand.withValues(alpha: 0.28),
                          width: 1.5,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: isDark ? 0.25 : 0.08),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.035),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left Highlighted Search Icon Badge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: isDark ? 0.24 : 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Search Text Field
                          Expanded(
                            child: TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search plate, name, driver or IMEI...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        onPressed: () {
                                          _search.clear();
                                          ref.read(fleetSearchProvider.notifier).state = '';
                                          setState(() {});
                                        },
                                      ),
                              ),
                              onChanged: (String v) {
                                ref.read(fleetSearchProvider.notifier).state = v;
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AttentionStrip(),
                  ],
                ),
              ),
            ),

            // ── Group Dropdown Selector ─────────────────────────────
            if (groups.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: _buildGroupDropdown(
                    isDark: isDark,
                    groups: groups,
                    activeGroupId: activeGroupId,
                    totalCount: fleet.vehicles.length,
                  ),
                ),
              ),

            // ── List header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xs),
                child: Row(
                  children: <Widget>[
                    Text('Vehicles', style: theme.textTheme.titleLarge),
                    const SizedBox(width: Gap.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: Corners.rPill,
                      ),
                      child: Text(
                        '${vehicles.length}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    const Spacer(),
                    if (activeGroupId != null && activeGroupId != 'all')
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(fleetGroupFilterProvider.notifier).state = null,
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('All groups'),
                      ),
                    if (_search.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          _search.clear();
                          ref.read(fleetSearchProvider.notifier).state = '';
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear search'),
                      ),
                    if (ref.watch(fleetFilterProvider) != null)
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(fleetFilterProvider.notifier).state = null,
                        icon:
                            const Icon(Icons.filter_alt_off_rounded, size: 16),
                        label: const Text('Clear filter'),
                      ),
                  ],
                ),
              ),
            ),

            // ── Refresh indicator (after resume from background) ─────
            if (fleet.isRefreshing && fleet.vehicles.isNotEmpty)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),

            // ── Body ─────────────────────────────────────────────────
            if (fleet.isLoading && fleet.vehicles.isEmpty)
              const SliverToBoxAdapter(child: ListSkeleton())
            else if (fleet.error != null && fleet.vehicles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(message: fleet.error!, onRetry: _refresh),
              )
            else if (vehicles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: fleet.vehicles.isEmpty
                      ? Icons.no_transfer_rounded
                      : Icons.search_off_rounded,
                  title:
                      fleet.vehicles.isEmpty ? 'No vehicles yet' : 'No matches',
                  message: fleet.vehicles.isEmpty
                      ? 'Vehicles added to your account by your provider will '
                          'appear here automatically.'
                      : 'Try a different search term or clear the active filter.',
                  actionLabel: fleet.vehicles.isEmpty ? null : 'Clear filters',
                  onAction: fleet.vehicles.isEmpty
                      ? null
                      : () {
                          _search.clear();
                          ref.read(fleetSearchProvider.notifier).state = '';
                          ref.read(fleetFilterProvider.notifier).state = null;
                          ref.read(fleetGroupFilterProvider.notifier).state = null;
                          setState(() {});
                        },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.lg, 0, Gap.lg, Gap.navClearance),
                sliver: SliverList.builder(
                  itemCount: vehicles.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Vehicle v = vehicles[index];
                    return VehicleCard(
                      key: ValueKey<String>(v.id.isNotEmpty ? v.id : 'veh_$index'),
                      vehicle: v,
                      onTap: () => context.push('/vehicle/${v.id}'),
                      onTrack: () {
                        if (v.hasLocation) {
                          context.push('/vehicle-map?focus=${v.id}');
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown({
    required bool isDark,
    required List<FleetGroup> groups,
    required String? activeGroupId,
    required int totalCount,
  }) {
    final FleetGroup? selectedGroup = groups.cast<FleetGroup?>().firstWhere(
          (g) => g?.id == activeGroupId || g?.name == activeGroupId,
          orElse: () => null,
        );
    final String currentLabel = selectedGroup?.name ?? 'All Groups';
    final int currentCount = selectedGroup?.vehicleCount ?? totalCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162036) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.brand.withValues(alpha: 0.35)
              : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String?>(
        tooltip: 'Select Vehicle Group',
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        color: isDark ? const Color(0xFF162036) : Colors.white,
        onSelected: (String? val) {
          ref.read(fleetGroupFilterProvider.notifier).state = val;
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
          PopupMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  size: 18,
                  color: (activeGroupId == null || activeGroupId == 'all')
                      ? AppColors.brand
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Groups',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          (activeGroupId == null || activeGroupId == 'all')
                              ? FontWeight.w700
                              : FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          ...groups.map(
            (FleetGroup g) => PopupMenuItem<String?>(
              value: g.id,
              child: Row(
                children: [
                  Icon(
                    Icons.folder_shared_rounded,
                    size: 18,
                    color: (activeGroupId == g.id || activeGroupId == g.name)
                        ? AppColors.brand
                        : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            (activeGroupId == g.id || activeGroupId == g.name)
                                ? FontWeight.w700
                                : FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${g.vehicleCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brand
                      .withValues(alpha: isDark ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_shared_rounded,
                  size: 18,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VEHICLE GROUP',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      currentLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$currentCount vehs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 26,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final int hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
  }

  String _greeting(String? name) {
    final String part = _timeGreeting();
    final String clean = (name ?? '').trim();
    return clean.isEmpty ? part : '$part,\n$clean';
  }
}
