import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/route.dart';
import '../../providers/route_provider.dart';
import 'route_editor_sheet.dart';

/// Lists all routes owned by the customer's organisation.
/// FAB opens [RouteEditorSheet] to draw a new route.
/// Tapping a route opens it for editing.
/// Swiping left reveals a delete action.
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  @override
  void initState() {
    super.initState();
    // Load routes after first frame so the provider is ready
    Future<void>.microtask(() {
      if (mounted) ref.read(routeProvider.notifier).load();
    });
  }

  Future<void> _openEditor({AppRoute? existing}) async {
    final Object? result = await Navigator.of(context).push<AppRoute>(
      MaterialPageRoute<AppRoute>(
        fullscreenDialog: true,
        builder: (_) => RouteEditorSheet(existing: existing),
      ),
    );
    if (result != null) {
      // Reload to reflect any changes
      if (mounted) ref.read(routeProvider.notifier).load();
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppRoute route) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text(
            'Delete "${route.name}"?\n\nVehicles assigned to this route will no longer be tracked for deviations.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(routeProvider.notifier).delete(route.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final RouteState state = ref.watch(routeProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Route Management'),
        actions: <Widget>[
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(routeProvider.notifier).load(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_route',
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('New Route',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(theme, scheme, state),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme scheme, RouteState state) {
    if (state.isLoading && state.routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded,
                size: 48, color: scheme.error),
            const SizedBox(height: Gap.sm),
            Text(state.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: Gap.md),
            FilledButton(
              onPressed: () => ref.read(routeProvider.notifier).load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.routes.isEmpty) {
      return _EmptyRoutesView(onCreateTap: () => _openEditor());
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          Gap.md, Gap.sm, Gap.md, 120 /* FAB clearance */),
      itemCount: state.routes.length,
      itemBuilder: (BuildContext ctx, int i) {
        final AppRoute route = state.routes[i];
        return Dismissible(
          key: ValueKey<String>(route.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _confirmDelete(ctx, route);
            return false; // we handle deletion manually
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: Gap.md),
            margin: const EdgeInsets.only(bottom: Gap.sm),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: Corners.rMd,
            ),
            child:
                Icon(Icons.delete_rounded, color: scheme.onErrorContainer),
          ),
          child: _RouteCard(
            route: route,
            onTap: () => _openEditor(existing: route),
            onToggleActive: () =>
                ref.read(routeProvider.notifier).toggleActive(route),
            theme: theme,
            scheme: scheme,
          ),
        );
      },
    );
  }
}

// ── Route card ─────────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onTap,
    required this.onToggleActive,
    required this.theme,
    required this.scheme,
  });

  final AppRoute route;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      shape: RoundedRectangleBorder(borderRadius: Corners.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.rMd,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: <Widget>[
              // Route icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: route.isActive
                      ? AppColors.brand.withOpacity(0.15)
                      : scheme.surfaceContainerHighest,
                  borderRadius: Corners.rSm,
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: route.isActive
                      ? AppColors.brand
                      : scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: Gap.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            route.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: route.isActive
                                  ? null
                                  : scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Active toggle
                        GestureDetector(
                          onTap: onToggleActive,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: route.isActive
                                  ? Colors.green.withOpacity(0.15)
                                  : scheme.surfaceContainerHighest,
                              borderRadius: Corners.rPill,
                            ),
                            child: Text(
                              route.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: route.isActive
                                    ? Colors.green
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        _chip(
                          icon: Icons.straighten_rounded,
                          label:
                              '${route.approxLengthKm.toStringAsFixed(1)} km',
                          scheme: scheme,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          icon: Icons.gps_fixed_rounded,
                          label: '±${route.toleranceMeters.round()} m',
                          scheme: scheme,
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          icon: Icons.directions_car_rounded,
                          label:
                              '${route.vehicleIds.length} vehicle${route.vehicleIds.length == 1 ? '' : 's'}',
                          scheme: scheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: Gap.sm),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
      {required IconData icon,
      required String label,
      required ColorScheme scheme}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: scheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyRoutesView extends StatelessWidget {
  const _EmptyRoutesView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_road_rounded,
                  size: 40, color: AppColors.brand),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'No Routes Yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Draw a route on the map and assign vehicles.\n'
              'You will get alerts when a trip starts, ends, or when a vehicle deviates from the route.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Create First Route',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
