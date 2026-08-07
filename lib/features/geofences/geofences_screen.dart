import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/geofence.dart';
import '../../providers/core_providers.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/glass_card.dart';
import '../live_map/widgets/map_tiles.dart';
import 'geofence_editor_sheet.dart';

class GeofencesScreen extends ConsumerStatefulWidget {
  const GeofencesScreen({super.key});

  @override
  ConsumerState<GeofencesScreen> createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends ConsumerState<GeofencesScreen> {
  List<Geofence> _fences = <Geofence>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<Geofence> data =
          await ref.read(geofenceRepositoryProvider).getGeofences();
      if (!mounted) return;
      setState(() {
        _fences = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => const GeofenceEditorSheet(),
    );
    if (created == true) await _load();
  }

  Future<void> _delete(Geofence fence) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete geofence?'),
        content: Text(
          '"${fence.name}" will be removed and you will stop receiving '
          'entry and exit alerts for it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(geofenceRepositoryProvider).delete(fence.id);
      if (!mounted) return;
      setState(() => _fences.removeWhere((Geofence g) => g.id == fence.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${fence.name}" deleted')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofences'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('New geofence'),
      ),
      body: _loading
          ? const ListSkeleton(count: 4)
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _fences.isEmpty
                  ? EmptyState(
                      icon: Icons.fence_rounded,
                      title: 'No geofences yet',
                      message: 'Draw a zone around a depot, customer site or '
                          'restricted area and get alerted whenever a vehicle '
                          'enters or leaves it.',
                      actionLabel: 'Create your first geofence',
                      onAction: _create,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.lg, Gap.md, Gap.lg, 96),
                        itemCount: _fences.length,
                        itemBuilder: (BuildContext context, int i) =>
                            _GeofenceCard(
                          fence: _fences[i],
                          onDelete: () => _delete(_fences[i]),
                          onToggle: (bool active) =>
                              _toggle(_fences[i], active),
                        ),
                      ),
                    ),
    );
  }

  Future<void> _toggle(Geofence fence, bool active) async {
    setState(() {
      final int i = _fences.indexWhere((Geofence g) => g.id == fence.id);
      if (i != -1) _fences[i] = fence.copyWith(isActive: active);
    });

    try {
      await ref.read(geofenceRepositoryProvider).update(
        fence.id,
        <String, dynamic>{'isActive': active},
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Roll back the optimistic update.
      setState(() {
        final int i = _fences.indexWhere((Geofence g) => g.id == fence.id);
        if (i != -1) _fences[i] = fence;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _GeofenceCard extends StatelessWidget {
  const _GeofenceCard({
    required this.fence,
    required this.onDelete,
    required this.onToggle,
  });

  final Geofence fence;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _parseColor(fence.colorHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            // Mini map preview
            SizedBox(
              height: 128,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Corners.lg),
                ),
                child: fence.center == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(Icons.map_outlined, size: 26),
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: fence.center!,
                          initialZoom: _zoomFor(fence),
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: <Widget>[
                          buildTileLayer(MapStyle.dark),
                          if (fence.shape == GeofenceShape.circle)
                            CircleLayer<Object>(
                              circles: <CircleMarker<Object>>[
                                CircleMarker<Object>(
                                  point: fence.center!,
                                  radius: fence.radiusMeters,
                                  useRadiusInMeter: true,
                                  color: color.withOpacity(0.18),
                                  borderColor: color,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          if (fence.shape == GeofenceShape.polygon)
                            PolygonLayer<Object>(
                              polygons: <Polygon<Object>>[
                                Polygon<Object>(
                                  points: fence.points,
                                  color: color.withOpacity(0.18),
                                  borderColor: color,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),

            Padding(
              padding: Gap.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          fence.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: fence.isActive,
                        onChanged: onToggle,
                      ),
                    ],
                  ),
                  if (fence.description != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(fence.description!, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: Gap.md),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.sm,
                    children: <Widget>[
                      _tag(
                        theme,
                        fence.shape == GeofenceShape.circle
                            ? Icons.circle_outlined
                            : Icons.hexagon_outlined,
                        fence.shape == GeofenceShape.circle
                            ? '${fence.radiusMeters.round()} m radius'
                            : '${fence.points.length} points',
                      ),
                      _tag(
                        theme,
                        Icons.crop_free_rounded,
                        '${fence.areaKm2.toStringAsFixed(2)} km²',
                      ),
                      if (fence.alertOnEnter)
                        _tag(theme, Icons.login_rounded, 'Entry alert'),
                      if (fence.alertOnExit)
                        _tag(theme, Icons.logout_rounded, 'Exit alert'),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: <Widget>[
                      Text(
                        'Created ${Fmt.relative(fence.createdAt)}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(letterSpacing: 0),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger),
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(ThemeData theme, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: Corners.rXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      );

  static double _zoomFor(Geofence f) {
    if (f.shape == GeofenceShape.polygon) return 13;
    final double r = f.radiusMeters;
    if (r <= 200) return 15.5;
    if (r <= 500) return 14.5;
    if (r <= 1500) return 13;
    return 11.5;
  }

  static Color _parseColor(String hex) {
    try {
      final String clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.brand;
    }
  }
}
