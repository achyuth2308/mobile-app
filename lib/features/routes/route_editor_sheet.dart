import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/route.dart';
import '../../data/models/vehicle.dart';
import '../../features/live_map/widgets/map_tiles.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/route_provider.dart';

/// Full-screen sheet for drawing a route on the map and assigning it
/// to one or more vehicles. Opened from [RoutesScreen].
class RouteEditorSheet extends ConsumerStatefulWidget {
  const RouteEditorSheet({this.existing, super.key});

  /// When non-null, the editor pre-loads this route for editing.
  final AppRoute? existing;

  @override
  ConsumerState<RouteEditorSheet> createState() => _RouteEditorSheetState();
}

class _RouteEditorSheetState extends ConsumerState<RouteEditorSheet> {
  final MapController _mapCtrl = MapController();
  final TextEditingController _nameCtrl = TextEditingController();

  final List<LatLng> _waypoints = <LatLng>[];
  double _tolerance = 150; // metres
  final Set<String> _selectedVehicleIds = <String>{};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final AppRoute? ex = widget.existing;
    if (ex != null) {
      _nameCtrl.text = ex.name;
      _waypoints.addAll(ex.coordinates);
      _tolerance = ex.toleranceMeters;
      _selectedVehicleIds.addAll(ex.vehicleIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter a route name.');
      return;
    }
    if (_waypoints.length < 2) {
      _showSnack('Tap the map to add at least 2 waypoints.');
      return;
    }
    setState(() => _saving = true);

    final AppRoute route = AppRoute(
      id: widget.existing?.id ?? '',
      name: name,
      coordinates: List<LatLng>.from(_waypoints),
      toleranceMeters: _tolerance,
    );

    final RouteController ctrl = ref.read(routeProvider.notifier);
    AppRoute? saved;
    if (widget.existing == null) {
      saved = await ctrl.create(route);
    } else {
      // Update existing
      try {
        saved = await ref.read(routeRepositoryProvider).updateRoute(
              route.id,
              name: route.name,
              coordinates: route.coordinates
                  .map((LatLng p) =>
                      <String, double>{'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
              tolerance: route.toleranceMeters,
            );
        // Refresh list
        await ctrl.load();
      } catch (e) {
        setState(() => _saving = false);
        _showSnack('Failed to update: $e');
        return;
      }
    }

    if (saved == null) {
      setState(() => _saving = false);
      _showSnack(ref.read(routeProvider).error ?? 'Failed to save route.');
      return;
    }

    // Assign vehicles
    if (_selectedVehicleIds.isNotEmpty) {
      await ctrl.assign(saved.id, _selectedVehicleIds.toList());
    }

    if (mounted) Navigator.of(context).pop(saved);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Map tap → add waypoint ─────────────────────────────────────────────────

  void _onTap(TapPosition _, LatLng latlng) {
    setState(() => _waypoints.add(latlng));
  }

  void _removeWaypoint(int index) {
    setState(() => _waypoints.removeAt(index));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<Vehicle> vehicles = ref.watch(fleetProvider).vehicles;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(
          widget.existing == null ? 'Draw Route' : 'Edit Route',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // ── Map ────────────────────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _waypoints.isNotEmpty
                        ? _waypoints.first
                        : const LatLng(17.385, 78.4867),
                    initialZoom: 13,
                    onTap: _onTap,
                  ),
                  children: <Widget>[
                    buildTileLayer(MapStyle.standard),
                    // Route polyline
                    if (_waypoints.length >= 2)
                      PolylineLayer(
                        polylines: <Polyline>[
                          Polyline(
                            points: _waypoints,
                            color: AppColors.brand,
                            strokeWidth: 4,
                            borderColor: Colors.white.withOpacity(0.5),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    // Waypoint markers
                    MarkerLayer(
                      markers: <Marker>[
                        for (int i = 0; i < _waypoints.length; i++)
                          Marker(
                            point: _waypoints[i],
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onLongPress: () => _removeWaypoint(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == 0
                                      ? Colors.green
                                      : i == _waypoints.length - 1
                                          ? Colors.red
                                          : AppColors.brand,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Hint overlay
                if (_waypoints.isEmpty)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: Corners.rPill,
                        ),
                        child: const Text(
                          'Tap the map to add waypoints • Long press to remove',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                // Undo last point
                if (_waypoints.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'undo',
                      onPressed: () =>
                          setState(() => _waypoints.removeLast()),
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                      child: const Icon(Icons.undo_rounded, size: 18),
                    ),
                  ),
              ],
            ),
          ),

          // ── Settings panel ─────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.md, Gap.sm, Gap.md, Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: Gap.sm),
                  // Name field
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Route Name',
                      hintText: 'e.g. Hyderabad–Warangal Highway',
                      prefixIcon: const Icon(Icons.route_rounded),
                      border: OutlineInputBorder(
                          borderRadius: Corners.rMd),
                    ),
                  ),
                  const SizedBox(height: Gap.md),

                  // Tolerance slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Deviation Tolerance',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_tolerance.round()} m',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _tolerance,
                    min: 50,
                    max: 2000,
                    divisions: 39,
                    label: '${_tolerance.round()} m',
                    activeColor: AppColors.brand,
                    onChanged: (double v) =>
                        setState(() => _tolerance = v),
                  ),
                  Text(
                    'Alert will fire when vehicle moves more than '
                    '${_tolerance.round()} m from the route.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),

                  const SizedBox(height: Gap.md),

                  // Vehicle assignment
                  Text(
                    'Assign to Vehicles',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Gap.xs),
                  if (vehicles.isEmpty)
                    Text(
                      'No vehicles found in your fleet.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: vehicles.map((Vehicle v) {
                        final bool selected =
                            _selectedVehicleIds.contains(v.id);
                        return FilterChip(
                          label: Text(v.displayName),
                          selected: selected,
                          selectedColor: AppColors.brand.withOpacity(0.2),
                          checkmarkColor: AppColors.brand,
                          onSelected: (bool val) => setState(() {
                            if (val) {
                              _selectedVehicleIds.add(v.id);
                            } else {
                              _selectedVehicleIds.remove(v.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
