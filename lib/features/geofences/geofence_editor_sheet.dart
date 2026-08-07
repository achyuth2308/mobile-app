import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/geofence.dart';
import '../../data/models/vehicle.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../live_map/widgets/map_tiles.dart';

/// Create a circular geofence by dragging the map and sizing the radius.
///
/// Scope note: customers get circle geofences only. Polygon drawing is an
/// admin-console job — it needs vertex editing, snapping and validation that
/// do not belong in a monitoring app.
class GeofenceEditorSheet extends ConsumerStatefulWidget {
  const GeofenceEditorSheet({super.key});

  @override
  ConsumerState<GeofenceEditorSheet> createState() =>
      _GeofenceEditorSheetState();
}

class _GeofenceEditorSheetState extends ConsumerState<GeofenceEditorSheet> {
  final TextEditingController _name = TextEditingController();
  final MapController _map = MapController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();

  GeofenceShape _shape = GeofenceShape.circle;
  LatLng _center = const LatLng(17.385, 78.4867);
  double _radius = 300;
  final List<LatLng> _polygonPoints = <LatLng>[];
  final List<String> _selectedVehicleIds = <String>[];
  bool _onEnter = true;
  bool _onExit = true;
  bool _saving = false;
  String _color = '#4F6BFF';

  static const List<String> _palette = <String>[
    '#4F6BFF', '#22D3EE', '#22C55E', '#F59E0B', '#FF4D6D', '#A78BFA',
  ];

  @override
  void initState() {
    super.initState();

    final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
    for (final Vehicle v in vehicles) {
      if (v.hasLocation) {
        _center = LatLng(v.latitude!, v.longitude!);
        break;
      }
    }

    _latController.text = _center.latitude.toStringAsFixed(6);
    _lngController.text = _center.longitude.toStringAsFixed(6);

    _latController.addListener(_onCoordinateInputChanged);
    _lngController.addListener(_onCoordinateInputChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _onCoordinateInputChanged() {
    final double? lat = double.tryParse(_latController.text);
    final double? lng = double.tryParse(_lngController.text);
    if (lat != null && lng != null) {
      final LatLng newCenter = LatLng(lat, lng);
      if (newCenter.latitude != _center.latitude ||
          newCenter.longitude != _center.longitude) {
        _center = newCenter;
        _map.move(_center, _map.camera.zoom);
      }
    }
  }

  void _updateCenter(LatLng newCenter, {bool moveMap = false}) {
    _center = newCenter;
    final String latStr = newCenter.latitude.toStringAsFixed(6);
    final String lngStr = newCenter.longitude.toStringAsFixed(6);
    
    _latController.removeListener(_onCoordinateInputChanged);
    _lngController.removeListener(_onCoordinateInputChanged);
    
    _latController.text = latStr;
    _lngController.text = lngStr;
    
    _latController.addListener(_onCoordinateInputChanged);
    _lngController.addListener(_onCoordinateInputChanged);

    if (moveMap) {
      _map.move(newCenter, _map.camera.zoom);
    }
    setState(() {});
  }

  void _useCurrentLocation() {
    final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
    LatLng? bestLoc;
    for (final Vehicle v in vehicles) {
      if (v.hasLocation) {
        bestLoc = LatLng(v.latitude!, v.longitude!);
        break;
      }
    }
    
    if (bestLoc != null) {
      _updateCenter(bestLoc, moveMap: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered map at vehicle location.'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active vehicle coordinates found.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the geofence a name.')),
      );
      return;
    }
    if (_shape == GeofenceShape.polygon && _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A polygon geofence must have at least 3 points.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(geofenceRepositoryProvider).create(
            Geofence(
              id: '',
              name: _name.text.trim(),
              shape: _shape,
              centerLat: _shape == GeofenceShape.circle ? _center.latitude : null,
              centerLng: _shape == GeofenceShape.circle ? _center.longitude : null,
              radiusMeters: _shape == GeofenceShape.circle ? _radius : 200,
              points: _shape == GeofenceShape.polygon ? _polygonPoints : const <LatLng>[],
              colorHex: _color,
              alertOnEnter: _onEnter,
              alertOnExit: _onExit,
              vehicleIds: _selectedVehicleIds,
            ),
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _hex(_color);
    final List<Vehicle> vehicles = ref.watch(fleetProvider).vehicles;

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      expand: false,
      builder: (BuildContext context, ScrollController scroll) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: Row(
              children: <Widget>[
                Text('New geofence', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
              children: <Widget>[
                // Shape Selection
                Text('Shape', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _shape == GeofenceShape.circle
                              ? theme.colorScheme.primaryContainer
                              : null,
                          side: BorderSide(
                            color: _shape == GeofenceShape.circle
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        onPressed: () => setState(() => _shape = GeofenceShape.circle),
                        icon: const Icon(Icons.circle_outlined),
                        label: const Text('Circle'),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _shape == GeofenceShape.polygon
                              ? theme.colorScheme.primaryContainer
                              : null,
                          side: BorderSide(
                            color: _shape == GeofenceShape.polygon
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        onPressed: () => setState(() => _shape = GeofenceShape.polygon),
                        icon: const Icon(Icons.hexagon_outlined),
                        label: const Text('Polygon'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: Gap.lg),

                // Map with live circle/polygon preview.
                ClipRRect(
                  borderRadius: Corners.rLg,
                  child: SizedBox(
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        FlutterMap(
                          mapController: _map,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: 14.5,
                            minZoom: 3,
                            maxZoom: 19,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all &
                                  ~InteractiveFlag.rotate,
                            ),
                            onTap: (TapPosition tapPosition, LatLng point) {
                              if (_shape == GeofenceShape.circle) {
                                _updateCenter(point, moveMap: true);
                              } else {
                                setState(() {
                                  _polygonPoints.add(point);
                                });
                              }
                            },
                            onPositionChanged:
                                (MapCamera camera, bool hasGesture) {
                              if (_shape == GeofenceShape.circle) {
                                _center = camera.center;
                                if (hasGesture) {
                                  _latController.removeListener(_onCoordinateInputChanged);
                                  _lngController.removeListener(_onCoordinateInputChanged);
                                  _latController.text = _center.latitude.toStringAsFixed(6);
                                  _lngController.text = _center.longitude.toStringAsFixed(6);
                                  _latController.addListener(_onCoordinateInputChanged);
                                  _lngController.addListener(_onCoordinateInputChanged);
                                }
                              }
                              if (hasGesture) setState(() {});
                            },
                          ),
                          children: <Widget>[
                            buildTileLayer(MapStyle.dark),
                            if (_shape == GeofenceShape.circle)
                              CircleLayer<Object>(
                                circles: <CircleMarker<Object>>[
                                  CircleMarker<Object>(
                                    point: _center,
                                    radius: _radius,
                                    useRadiusInMeter: true,
                                    color: color.withOpacity(0.18),
                                    borderColor: color,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            if (_shape == GeofenceShape.polygon && _polygonPoints.isNotEmpty) ...<Widget>[
                              PolygonLayer(
                                polygons: <Polygon>[
                                  Polygon(
                                    points: _polygonPoints,
                                    color: color.withOpacity(0.18),
                                    borderColor: color,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: _polygonPoints.asMap().entries.map((MapEntry<int, LatLng> entry) {
                                  return Marker(
                                    point: entry.value,
                                    width: 16,
                                    height: 16,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: OsmAttribution(
                                  style: MapStyle.dark, compact: true),
                            ),
                          ],
                        ),
                        // Fixed crosshair — only show for Circle mode
                        if (_shape == GeofenceShape.circle)
                          IgnorePointer(
                            child: Icon(
                              Icons.add_rounded,
                              size: 26,
                              color: color.withOpacity(0.9),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_shape == GeofenceShape.circle) ...<Widget>[
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Drag map or tap on it to position the centre.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_shape == GeofenceShape.polygon) ...<Widget>[
                  const SizedBox(height: Gap.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Tap the map to add polygon corners.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _polygonPoints.clear()),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                        label: const Text('Clear points'),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: Gap.lg),

                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Geofence name',
                    hintText: 'e.g. Main Depot',
                    prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
                  ),
                ),

                const SizedBox(height: Gap.lg),

                if (_shape == GeofenceShape.circle) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Text('Radius', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      Text(
                        _radius >= 1000
                            ? '${(_radius / 1000).toStringAsFixed(1)} km'
                            : '${_radius.round()} m',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 5000,
                    divisions: 99,
                    onChanged: (double v) => setState(() => _radius = v),
                  ),
                  const SizedBox(height: Gap.md),
                ],

                // Manual Coordinates & Location Button
                Text('Coordinates', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          contentPadding: EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: TextField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          contentPadding: EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    IconButton.filledTonal(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      tooltip: 'Use vehicle location',
                    ),
                  ],
                ),

                const SizedBox(height: Gap.lg),

                Text('Colour', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.md),
                Row(
                  children: _palette
                      .map(
                        (String hex) => Padding(
                          padding: const EdgeInsets.only(right: Gap.md),
                          child: GestureDetector(
                            onTap: () => setState(() => _color = hex),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _hex(hex),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _color == hex
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: _color == hex
                                  ? const Icon(Icons.check_rounded,
                                      size: 17, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: Gap.xl),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onEnter,
                  onChanged: (bool v) => setState(() => _onEnter = v),
                  title: const Text('Alert on entry'),
                  subtitle: const Text('Notify when a vehicle enters the zone'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onExit,
                  onChanged: (bool v) => setState(() => _onExit = v),
                  title: const Text('Alert on exit'),
                  subtitle: const Text('Notify when a vehicle leaves the zone'),
                ),

                const SizedBox(height: Gap.lg),

                // Applicable Vehicles List
                Text('Applicable Vehicles', style: theme.textTheme.titleSmall),
                const SizedBox(height: Gap.sm),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: Corners.rLg,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vehicles.length,
                    separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Vehicle vehicle = vehicles[index];
                      final bool isSelected = _selectedVehicleIds.contains(vehicle.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedVehicleIds.add(vehicle.id);
                            } else {
                              _selectedVehicleIds.remove(vehicle.id);
                            }
                          });
                        },
                        title: Text(vehicle.name),
                        subtitle: Text(
                          vehicle.registrationNumber.isNotEmpty
                              ? vehicle.registrationNumber
                              : 'No plate number',
                        ),
                        secondary: const Icon(Icons.directions_car_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md),
                      );
                    },
                  ),
                ),

                const SizedBox(height: Gap.xl),

                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Create geofence'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _hex(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.brand;
    }
  }
}
