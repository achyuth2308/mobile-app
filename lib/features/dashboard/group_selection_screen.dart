import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fleet_provider.dart';
import 'widgets/fleet_overview_card.dart';
import 'widgets/stat_tiles.dart';

/// Screen displayed after splash screen allowing user to choose an assigned group.
/// Features clean, tactile Neumorphic (Soft UI) styling on a matte canvas.
class GroupSelectionScreen extends ConsumerStatefulWidget {
  const GroupSelectionScreen({super.key});

  @override
  ConsumerState<GroupSelectionScreen> createState() =>
      _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends ConsumerState<GroupSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetProvider.notifier).load(silent: true);
    });
  }

  void _selectGroup(String? groupId) {
    debugPrint('[GroupSelectionScreen] Selecting group: $groupId');
    ref.read(fleetGroupFilterProvider.notifier).state = groupId;
    if (mounted) {
      context.go('/dashboard');
    }
  }

  String _timeGreeting() {
    final int hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final FleetState fleet = ref.watch(fleetProvider);
    final List<FleetGroup> allGroups = ref.watch(availableFleetGroupsProvider);
    final int alertCount = ref.watch(unreadAlertsCountProvider);
    final String? name = ref.watch(authProvider).user?.name;

    final Color canvasColor =
        isDark ? const Color(0xFF161C26) : const Color(0xFFE8EEF5);

    return Scaffold(
      backgroundColor: canvasColor,
      body: RefreshIndicator(
        onRefresh: () => ref.read(fleetProvider.notifier).load(),
        color: AppColors.brand,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header (Identical to 1st page Dashboard header) ────────
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 88,
              backgroundColor: canvasColor,
              elevation: 0,
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
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Color(0xFFEF4444),
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
                      onPressed: () => context.push('/alerts?groupId=all'),
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
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
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
                        color:
                            isDark ? const Color(0xFF818CF8) : AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top spacing below header
            const SliverToBoxAdapter(
              child: SizedBox(height: Gap.xs),
            ),

            // ── Fleet Overview Neumorphic Card ─────────────────────────────
            if (fleet.vehicles.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
                  child: FleetOverviewCard(),
                ),
              ),

            // Loading state
            if (fleet.isLoading && allGroups.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text(
                        'Loading vehicle groups...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (allGroups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          size: 48,
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No vehicle groups found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _selectGroup(null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('View All Vehicles'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // Assigned Groups List (Neumorphic Cards)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final FleetGroup group = allGroups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildNeumorphicGroupCard(
                          group: group,
                          isDark: isDark,
                          surfaceColor: canvasColor,
                          onTap: () => _selectGroup(group.id),
                        ),
                      );
                    },
                    childCount: allGroups.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Extruded Neumorphic Card with dual light/dark directional shadows
  Widget _buildNeumorphicGroupCard({
    required FleetGroup group,
    required bool isDark,
    required Color surfaceColor,
    required VoidCallback onTap,
  }) {
    const Color brandBlue = Color(0xFF2563EB);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? [
                    const BoxShadow(
                      color: Color(0xFF232D3D),
                      offset: Offset(-4, -4),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.60),
                      offset: const Offset(4, 4),
                      blurRadius: 10,
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-5, -5),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: const Color(0xFFA6B4C9).withOpacity(0.55),
                      offset: const Offset(5, 5),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // Embossed Brand Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3B82F6),
                            Color(0xFF2563EB),
                            Color(0xFF1D4ED8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: brandBlue.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(2, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Group Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Debossed Vehicle Count Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF11161F)
                                      : const Color(0xFFDCE3ED),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isDark
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.4),
                                            offset: const Offset(1, 1),
                                            blurRadius: 1.5,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFFA6B4C9)
                                                .withOpacity(0.35),
                                            offset: const Offset(1, 1),
                                            blurRadius: 1.5,
                                          ),
                                          const BoxShadow(
                                            color: Colors.white,
                                            offset: Offset(-0.8, -0.8),
                                            blurRadius: 1,
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_car_rounded,
                                      size: 12,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${group.vehicleCount} ${group.vehicleCount == 1 ? "Vehicle" : "Vehicles"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Neumorphic Soft Action Button
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        boxShadow: isDark
                            ? [
                                const BoxShadow(
                                  color: Color(0xFF242E3E),
                                  offset: Offset(-2.5, -2.5),
                                  blurRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.55),
                                  offset: const Offset(2.5, 2.5),
                                  blurRadius: 5,
                                ),
                              ]
                            : [
                                const BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-2.5, -2.5),
                                  blurRadius: 5,
                                ),
                                BoxShadow(
                                  color:
                                      const Color(0xFFA6B4C9).withOpacity(0.50),
                                  offset: const Offset(2.5, 2.5),
                                  blurRadius: 5,
                                ),
                              ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: brandBlue,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
