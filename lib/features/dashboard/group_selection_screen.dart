import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fleet_provider.dart';
import 'widgets/stat_tiles.dart';

/// Screen displayed after splash screen allowing user to choose an assigned group.
/// Matches the 1st page dashboard header (Good morning/afternoon/evening, User Name, Date, Alerts & Profile icons)
/// and displays the user's assigned vehicle groups below it.
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
      // Ensure latest fleet groups and vehicle telemetry are loaded
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF1F7),
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
              backgroundColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF1F7),
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
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Color(0xFFEF4444), // Vibrant Red Calendar Icon
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
                        color: isDark ? const Color(0xFF818CF8) : AppColors.brand,
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

            // ── Fleet Overview Pie Chart ─────────────────────────────
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
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
              // Assigned Groups List (One by one cards)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final FleetGroup group = allGroups[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGroupItemCard(
                          group: group,
                          isDark: isDark,
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

    Widget _buildGroupItemCard({
    required FleetGroup group,
    required bool isDark,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFFBFDFF),
                      const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              // Ambient soft 3D blur
              BoxShadow(
                color: const Color(0xFF0F172A)
                    .withValues(alpha: isDark ? 0.40 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              // Subtle directional color depth shadow
              BoxShadow(
                color: brandBlue
                    .withValues(alpha: isDark ? 0.20 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // Bevel rim shadow
              BoxShadow(
                color: const Color(0xFF1E293B)
                    .withValues(alpha: isDark ? 0.35 : 0.03),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    // Left 3D embossed leading icon
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
                            color: brandBlue.withValues(alpha: 0.38),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 25,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 3,
                              offset: Offset(0, 1.5),
                            ),
                          ],
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
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Vehicle Count Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF334155).withValues(alpha: 0.6)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF475569)
                                        : const Color(0xFFE2E8F0),
                                  ),
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

                              // Online Count Chip (Pulsing Emerald)
                              if (group.onlineCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B)
                                            .withValues(alpha: 0.45)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF059669)
                                              .withValues(alpha: 0.45)
                                          : const Color(0xFFA7F3D0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.7),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4.5),
                                      Text(
                                        '${group.onlineCount} online',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
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

                    // 3D Interactive Trailing Action Button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF334155),
                                  const Color(0xFF1E293B),
                                ]
                              : [
                                  const Color(0xFFEFF6FF),
                                  const Color(0xFFDBEAFE),
                                ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFBFDBFE),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: brandBlue
                                .withValues(alpha: isDark ? 0.3 : 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : brandBlue,
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
