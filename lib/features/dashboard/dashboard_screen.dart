import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/realtime/socket_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/brand_mark.dart';
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

  bool _searchOpen = false;

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
    final List<Vehicle> vehicles = ref.watch(filteredVehiclesProvider);
    final String? name = ref.watch(authProvider).user?.name;
    final AsyncValue<SocketStatus> socket = ref.watch(socketStatusProvider);

    final bool isLive = socket.valueOrNull == SocketStatus.connected;

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
              expandedHeight: 120,
              collapsedHeight: 62,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              titleSpacing: Gap.lg,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, 12),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const BrandMark(size: 26),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'FuelTracks',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
                expandedTitleScale: 1.0,
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, Gap.md, Gap.lg, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _greeting(name),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                const SizedBox(width: Gap.sm),
                IconButton(
                  tooltip: 'Search fleet',
                  icon: Icon(_searchOpen
                      ? Icons.close_rounded
                      : Icons.search_rounded),
                  onPressed: () {
                    setState(() => _searchOpen = !_searchOpen);
                    if (!_searchOpen) {
                      _search.clear();
                      ref.read(fleetSearchProvider.notifier).state = '';
                    }
                  },
                ),
                const SizedBox(width: Gap.xs),
              ],
            ),

            // ── Search field ─────────────────────────────────────────
            if (_searchOpen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search plate, name, driver or IMEI',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Gap.lg,
                        vertical: Gap.md,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _search.clear();
                                ref.read(fleetSearchProvider.notifier).state =
                                    '';
                                setState(() {});
                              },
                            ),
                    ),
                    onChanged: (String v) {
                      ref.read(fleetSearchProvider.notifier).state = v;
                      setState(() {});
                    },
                  ),
                ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2),
              ),

            // ── Overview ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const OfflineNotice(),
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
                    const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
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
                      key: ValueKey<String>(v.id),
                      vehicle: v,
                      onTap: () => context.push('/vehicle/${v.id}'),
                      onTrack: v.hasLocation
                          ? () => context.go('/map?focus=${v.id}')
                          : null,
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
    final String first = (name ?? '').split(' ').first;
    return first.isEmpty ? part : '$part, $first';
  }
}
