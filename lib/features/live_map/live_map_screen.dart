import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'widgets/map_tiles.dart';
import '../../shared/map/app_map_controller.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/report_models.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/auth_provider.dart';
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
  const LiveMapScreen({this.focusVehicleId, this.showTrail = false, super.key});

  final String? focusVehicleId;
  final bool showTrail;

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen>
    with TickerProviderStateMixin {
  final AppMapControllerWrapper _map = AppMapControllerWrapper();

  String? _selectedId;
  String? _followingId;
  String? _pendingFocusId;
  MapStyle _style = MapStyle.google;
  bool _mapReady = false;
  bool _userInteracting = false;
  bool _isHistoryMode = false;

  /// India-centred default until the first fix arrives.
  static const LatLng _fallbackCenter = LatLng(17.385, 78.4867);

  void _setFollowingId(String? id) {
    if (!mounted) return;
    setState(() {
      _followingId = id;
      _isHistoryMode = false; // Reset to Live mode when selecting/following vehicle
    });
    Future.microtask(() {
      if (mounted) {
        ref.read(activeFollowingVehicleIdProvider.notifier).state = id;
      }
    });
  }

  void _toggleHistoryMode(bool history) {
    final String activeId = _selectedId ?? _followingId ?? '';
    if (history && activeId.isNotEmpty) {
      context.push('/vehicle/$activeId?tab=history');
    } else {
      setState(() {
        _isHistoryMode = false;
      });
      final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
      final Vehicle? v = vehicles.cast<Vehicle?>().firstWhere((v) => v?.id == activeId, orElse: () => null);
      if (v != null && v.hasLocation && _mapReady) {
        _move(LatLng(v.latitude!, v.longitude!), zoom: 17.0);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedId = widget.focusVehicleId;
    _followingId = widget.focusVehicleId;
    _pendingFocusId = widget.focusVehicleId;
    _style = MapStyleX.fromKey(ref.read(secureStoreProvider).mapType);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeFollowingVehicleIdProvider.notifier).state = widget.focusVehicleId;
      }
    });
  }

  @override
  void dispose() {
    // Clear active following vehicle globally
    ref.read(activeFollowingVehicleIdProvider.notifier).state = null;
    super.dispose();
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
    _map.move(target, zoom ?? _map.getZoom());
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
      _setFollowingId(target.id);
      setState(() {
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

    _setFollowingId(null);

    if (located.length == 1) {
      _move(
        LatLng(located.first.latitude!, located.first.longitude!),
        zoom: 17,
      );
      return;
    }

    _map.fitBounds(
      located.map((Vehicle v) => LatLng(v.latitude!, v.longitude!)).toList(),
      padding: 60.0,
    );
  }

  void _selectVehicle(Vehicle v) {
    unawaited(HapticFeedback.selectionClick());
    _setFollowingId(v.id);
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
          _setFollowingId(_followingId == v.id ? null : v.id);
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
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent, // Don't dim the map!
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        alignment: Alignment.centerLeft, // Float on the left side
        insetPadding: const EdgeInsets.only(left: 24, right: 24, top: 100, bottom: 100),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: StoppageDetailCard(
            stoppage: stoppage,
            stopNumber: stopNumber,
          ),
        ),
      ),
    );
  }

  void _showMapStylePicker() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        final ThemeData theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Map Type',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...MapStyle.values.map((MapStyle s) {
                  final bool isSelected = s == _style;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() {
                        _style = s;
                      });
                      await ref.read(secureStoreProvider).setMapType(s.name);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            s.icon,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              s.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FleetState fleet = ref.watch(fleetProvider);
    final List<Vehicle> vehicles = fleet.vehicles;
    final String? apiKey = ref.read(authProvider).user?.apiKey;

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

    // If focusVehicleId is passed (e.g. Live Tracking from Vehicle Detail),
    // show only that specific vehicle. Otherwise show all fleet vehicles.
    final List<Vehicle> visibleVehicles =
        widget.focusVehicleId != null && widget.focusVehicleId!.isNotEmpty
            ? vehicles.where((v) => v.id == widget.focusVehicleId).toList()
            : vehicles;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: <Widget>[
          UniversalLiveMap(
            mapController: _map,
            vehicles: visibleVehicles,
            style: _style,
            apiKey: apiKey,
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
              if (interacting && _followingId != null) {
                // Break the camera lock when the user drags the map
                _setFollowingId(null);
              }
            },
            onTapMap: () {
              if (_selectedId != null) setState(() => _selectedId = null);
            },
            onSelectVehicle: _selectVehicle,
            route: _isHistoryMode ? (dailyDataAsync.valueOrNull?.route ?? []) : [],
            stoppages: _isHistoryMode ? (dailyDataAsync.valueOrNull?.stoppages ?? []) : [],
            showTrail: true,
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
              isHistoryMode: _isHistoryMode,
              onStopFollowing: () {
                if (widget.focusVehicleId != null && context.canPop()) {
                  context.pop();
                } else {
                  _setFollowingId(null);
                }
              },
              onToggleHistoryMode: _toggleHistoryMode,
              onRecenter: following != null && following.hasLocation
                  ? () => _move(
                        LatLng(following.latitude!, following.longitude!),
                        zoom: 17,
                      )
                  : null,
              onRefresh: () {
                ref.invalidate(fleetProvider);
                if (activeId.isNotEmpty) {
                  ref.invalidate(vehicleDailyHistoryProvider(activeId));
                }
              },
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
                      _map.getCenter(),
                      (_map.getZoom() + 1).clamp(2, _style.maxZoom),
                    );
                  },
                ),
                const SizedBox(height: 2),
                _MapButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom out',
                  onTap: () {
                    _map.move(
                      _map.getCenter(),
                      (_map.getZoom() - 1).clamp(2, _style.maxZoom),
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
    required this.isHistoryMode,
    required this.onStopFollowing,
    required this.onToggleHistoryMode,
    this.onRecenter,
    this.onRefresh,
  });

  final int locatedCount;
  final int totalCount;
  final String? followingName;
  final bool isHistoryMode;
  final VoidCallback onStopFollowing;
  final ValueChanged<bool> onToggleHistoryMode;
  final VoidCallback? onRecenter;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (followingName != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Back button with shadow so it's visible over any map
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.35),
              ),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
                onPressed: onStopFollowing,
              ),
            ),
            const SizedBox(width: 8),

            // Vehicle Name — white text with dark shadow for readability
            Flexible(
              child: Text(
                followingName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1)),
                    Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ],
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
