import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'widgets/map_tiles.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/report_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/glass_card.dart';
import 'providers/live_map_providers.dart';
import 'widgets/stoppage_detail_card.dart';
import 'widgets/vehicle_peek_sheet.dart';
import 'widgets/universal_live_map.dart';
import 'widgets/navigation_hud.dart';

/// Full-screen live fleet map, rendered with OpenStreetMap tiles via
/// flutter_map (the Flutter port of Leaflet).
///
/// Why this beats the previous Google Maps implementation:
///  * no API key, no billing account, no per-map-load quota
///  * markers are Flutter widgets → real rotation, themed colours, and
///    animation without rasterising a bitmap per unique state
///  * clustering is handled by a maintained package rather than my own
///    hand-rolled grid, and it animates on zoom
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({this.focusVehicleId, super.key});

  final String? focusVehicleId;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen>
    with TickerProviderStateMixin {
  final MapController _map = MapController();

  String? _selectedId;
  String? _followingId;
  String? _pendingFocusId;
  MapStyle _style = MapStyle.standard;
  bool _mapReady = false;
  bool _userInteracting = false;

  /// India-centred default until the first fix arrives.
  static const LatLng _fallbackCenter = LatLng(17.385, 78.4867);

  @override
  void initState() {
    super.initState();
    _selectedId = widget.focusVehicleId;
    _followingId = widget.focusVehicleId;
    _pendingFocusId = widget.focusVehicleId;
    _style = MapStyleX.fromKey(ref.read(secureStoreProvider).mapType);
  }

  @override
  void didUpdateWidget(LiveMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusVehicleId != null &&
        (widget.focusVehicleId != oldWidget.focusVehicleId ||
            _followingId != widget.focusVehicleId)) {
      _focusVehicle(widget.focusVehicleId);
    }
  }

  // ── Camera ───────────────────────────────────────────────────────

  void _move(LatLng target, {double? zoom}) {
    if (!_mapReady) return;
    _map.move(target, zoom ?? _map.camera.zoom);
  }

  void _focusVehicle(String? vehicleId, {double zoom = 17.0}) {
    if (vehicleId == null || vehicleId.isEmpty) return;
    _pendingFocusId = vehicleId;

    final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
    final Vehicle? target = vehicles.cast<Vehicle?>().firstWhere(
          (Vehicle? v) => v?.id == vehicleId,
          orElse: () => null,
        );

    if (target != null) {
      _pendingFocusId = null;
      setState(() {
        _followingId = target.id;
        _selectedId = target.id;
      });

      if (target.hasLocation && _mapReady) {
        _move(LatLng(target.latitude!, target.longitude!), zoom: zoom);
      }
    }
  }

  void _fitAll(List<Vehicle> vehicles) {
    final List<Vehicle> located =
        vehicles.where((Vehicle v) => v.hasLocation).toList();
    if (located.isEmpty || !_mapReady) return;

    setState(() => _followingId = null);

    if (located.length == 1) {
      _move(
        LatLng(located.first.latitude!, located.first.longitude!),
        zoom: 17,
      );
      return;
    }

    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          located
              .map((Vehicle v) => LatLng(v.latitude!, v.longitude!))
              .toList(),
        ),
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 200),
        maxZoom: 16,
      ),
    );
  }

  void _selectVehicle(Vehicle v) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _selectedId = v.id);
    _move(LatLng(v.latitude!, v.longitude!));
    _showPeek(v);
  }

  void _showPeek(Vehicle v) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => VehiclePeekSheet(
        vehicleId: v.id,
        isFollowing: _followingId == v.id,
        onToggleFollow: () {
          setState(() => _followingId = _followingId == v.id ? null : v.id);
          Navigator.pop(ctx);
          if (_followingId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Following ${v.displayName}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onOpenDetails: () {
          Navigator.pop(ctx);
          context.push('/vehicle/${v.id}');
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedId = null);
    });
  }

  void _showStoppageCard(ReportRow stoppage, int stopNumber) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => Padding(
        padding: const EdgeInsets.only(top: kToolbarHeight),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: StoppageDetailCard(
            stoppage: stoppage,
            stopNumber: stopNumber,
          ),
        ),
      ),
    );
  }

  void _showMapStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Map Type',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                ...MapStyle.values.map((MapStyle s) {
                  final bool isSelected = s == _style;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(
                      s.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      s.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() {
                        _style = s;
                      });
                      await ref.read(secureStoreProvider).setMapType(s.name);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FleetState fleet = ref.watch(fleetProvider);
    final List<Vehicle> vehicles = fleet.vehicles;

    // Follow mode — recentre as new frames arrive, unless the user is panning.
    ref.listen<FleetState>(fleetProvider, (FleetState? _, FleetState next) {
      if (_pendingFocusId != null) {
        _focusVehicle(_pendingFocusId);
      }

      if (_followingId == null || _userInteracting || !_mapReady) return;
      for (final Vehicle v in next.vehicles) {
        if (v.id == _followingId && v.hasLocation) {
          _move(LatLng(v.latitude!, v.longitude!));
          break;
        }
      }
    });

    final int located = vehicles.where((v) => v.hasLocation).length;

    final Vehicle? following = _followingId == null
        ? null
        : vehicles.cast<Vehicle?>().firstWhere(
              (Vehicle? v) => v?.id == _followingId,
              orElse: () => null,
            );

    final String activeId = _selectedId ?? _followingId ?? '';
    final AsyncValue<VehicleDailyData> dailyDataAsync =
        ref.watch(vehicleDailyHistoryProvider(activeId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          UniversalLiveMap(
            mapController: _map,
            vehicles: vehicles,
            style: _style,
            fallbackCenter: _fallbackCenter,
            selectedId: _selectedId,
            followingId: _followingId,
            pendingFocusId: _pendingFocusId,
            onMapReady: () {
              setState(() => _mapReady = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.focusVehicleId != null) {
                  _focusVehicle(widget.focusVehicleId);
                } else if (_pendingFocusId != null) {
                  _focusVehicle(_pendingFocusId);
                } else {
                  _fitAll(vehicles);
                }
              });
            },
            onUserInteracting: (interacting) {
              _userInteracting = interacting;
            },
            onTapMap: () {
              if (_selectedId != null) setState(() => _selectedId = null);
            },
            onSelectVehicle: _selectVehicle,
            route: dailyDataAsync.valueOrNull?.route ?? [],
            stoppages: dailyDataAsync.valueOrNull?.stoppages ?? [],
            onTapStoppage: _showStoppageCard,
          ),

          // Legibility scrim behind the top controls.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + 90,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.mapTopScrim),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + Gap.sm,
            left: Gap.lg,
            right: Gap.lg,
            child: _MapHeader(
              locatedCount: located,
              totalCount: vehicles.length,
              followingName: following?.displayName,
              onStopFollowing: () => setState(() => _followingId = null),
              onRecenter: following != null && following.hasLocation
                  ? () => _move(
                        LatLng(following.latitude!, following.longitude!),
                        zoom: 17,
                      )
                  : null,
            ),
          ),

          if (following != null) NavigationHUD(vehicle: following),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 70,
            right: Gap.lg,
            child: Column(
              children: <Widget>[
                _MapButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Change map style',
                  onTap: _showMapStylePicker,
                ),
                const SizedBox(height: Gap.sm),
                _MapButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Fit all vehicles',
                  onTap: () => _fitAll(vehicles),
                ),
                const SizedBox(height: Gap.sm),
                _MapButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom in',
                  onTap: () {
                    _map.move(
                      _map.camera.center,
                      (_map.camera.zoom + 1).clamp(2, _style.maxZoom),
                    );
                  },
                ),
                const SizedBox(height: 2),
                _MapButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onTap: () {
                    _map.move(
                      _map.camera.center,
                      (_map.camera.zoom - 1).clamp(2, _style.maxZoom),
                    );
                  },
                ),
              ],
            ),
          ),

          // ODbL attribution — required, bottom-right by convention.
          Positioned(
            right: 0,
            bottom: 0,
            child: SafeArea(child: OsmAttribution(style: _style)),
          ),

          if (fleet.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xAA070B16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (located == 0 && vehicles.isNotEmpty)
            const Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                child: _NoLocationCard(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.locatedCount,
    required this.totalCount,
    required this.followingName,
    required this.onStopFollowing,
    this.onRecenter,
  });

  final int locatedCount;
  final int totalCount;
  final String? followingName;
  final VoidCallback onStopFollowing;
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (followingName != null) {
      return Material(
        color: theme.colorScheme.primary,
        borderRadius: Corners.rPill,
        child: InkWell(
          borderRadius: Corners.rPill,
          onTap: onRecenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 10, 6, 10),
            child: Row(
              children: <Widget>[
                Icon(Icons.gps_fixed_rounded,
                    size: 16, color: theme.colorScheme.onPrimary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Following $followingName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 34, minHeight: 34),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: theme.colorScheme.onPrimary),
                  onPressed: onStopFollowing,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
          borderRadius: Corners.rPill,
          opacity: theme.brightness == Brightness.dark ? 0.4 : 0.65,
          blur: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.satellite_alt_rounded,
                  size: 15, color: AppColors.signal),
              const SizedBox(width: Gap.sm),
              Text(
                '$locatedCount of $totalCount tracked',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: Corners.rPill,
          opacity: Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.65,
          blur: 16,
          onTap: onTap,
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    const List<(Color, String)> entries = <(Color, String)>[
      (AppColors.moving, 'Moving'),
      (AppColors.idle, 'Idle'),
      (AppColors.stopped, 'Stopped'),
      (AppColors.offline, 'Offline'),
    ];

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      borderRadius: Corners.rLg,
      opacity: Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.65,
      blur: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries
            .map(
              ((Color, String) e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: e.$1, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      e.$2,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 0,
                          ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NoLocationCard extends StatelessWidget {
  const _NoLocationCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: Gap.card,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withOpacity(0.96),
        borderRadius: Corners.rLg,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const EmptyState(
        icon: Icons.location_off_rounded,
        title: 'No positions yet',
        message: 'None of your vehicles have reported a GPS fix recently. '
            'They will appear here as soon as they do.',
        compact: true,
      ),
    );
  }
}
