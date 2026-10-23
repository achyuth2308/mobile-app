import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final FleetState fleet = ref.watch(fleetProvider);
    final int alertCount = ref.watch(unreadAlertsCountProvider);
    final List<Vehicle> vehicles = ref.watch(filteredVehiclesProvider);
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
              expandedHeight: 90 + MediaQuery.paddingOf(context).top,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              titleSpacing: Gap.lg,
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, 100.0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _greeting(name),
                          maxLines: 2,
                          softWrap: true,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            fontSize: 18,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Fmt.date(DateTime.now()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Alerts',
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
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  onPressed: () => context.push('/alerts'),
                ),
                const SizedBox(width: Gap.xs),
                IconButton(
                  tooltip: 'Profile & Settings',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => context.push('/profile-settings'),
                ),
                const SizedBox(width: Gap.xs),
              ],
            ),

            // ── Overview ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const OfflineNotice(),
                    // ── Search Bar directly above Total Fleet card ───────
                    Container(
                      margin: const EdgeInsets.only(top: Gap.xs, bottom: Gap.md),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerHigh
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.4)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Search plate, name, driver or IMEI',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Gap.md,
                            vertical: 12,
                          ),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
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
                    const FleetOverviewCard()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.08),
                    const AttentionStrip(),
                  ],
                ),
              ),
            ),

            // ── List header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xs),
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

  String _greeting(String? name) {
    final int hour = DateTime.now().hour;
    final String part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final String clean = (name ?? '').trim();
    return clean.isEmpty ? part : '$part,\n$clean';
  }
}
