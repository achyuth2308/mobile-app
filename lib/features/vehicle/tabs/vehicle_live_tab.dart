import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/share_helper.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';
import '../../../providers/auth_provider.dart';

import '../../../shared/widgets/live_address.dart';
import '../../live_map/widgets/map_tiles.dart';
import '../../live_map/widgets/vehicle_marker.dart';
import '../widgets/telemetry_grid.dart';

/// Live tab: a pinned mini-map plus a full telemetry grid, both updating
/// from the same throttled fleet stream.
class VehicleLiveTab extends ConsumerStatefulWidget {
  const VehicleLiveTab({
    required this.vehicleId,
    this.onTabSelect,
    super.key,
  });

  final String vehicleId;
  final ValueChanged<int>? onTabSelect;

  @override
  ConsumerState<VehicleLiveTab> createState() => _VehicleLiveTabState();
}

class _VehicleLiveTabState extends ConsumerState<VehicleLiveTab>
    with AutomaticKeepAliveClientMixin {
  final MapController _map = MapController();
  bool _ready = false;

  LatLng? _lastCamera;

  @override
  bool get wantKeepAlive => true;

  void _follow(Vehicle v) {
    if (!v.hasLocation || !_ready) return;

    final LatLng target = LatLng(v.latitude!, v.longitude!);

    // Skip sub-metre jitter — avoids constant camera churn while parked.
    if (_lastCamera != null &&
        (_lastCamera!.latitude - target.latitude).abs() < 0.00002 &&
        (_lastCamera!.longitude - target.longitude).abs() < 0.00002) {
      return;
    }
    _lastCamera = target;
    _map.move(target, _map.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ThemeData theme = Theme.of(context);
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicle == null) return const SizedBox.shrink();

    ref.listen<Vehicle?>(vehicleByIdProvider(widget.vehicleId),
        (Vehicle? _, Vehicle? next) {
      if (next != null) _follow(next);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.x4l),
      children: <Widget>[
        // ── Mini map ─────────────────────────────────────────────
        ClipRRect(
          borderRadius: Corners.rLg,
          child: SizedBox(
            height: 255,
            child: vehicle.hasLocation
                ? Stack(
                    children: <Widget>[
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter:
                              LatLng(vehicle.latitude!, vehicle.longitude!),
                          initialZoom: 15.5,
                          minZoom: 3,
                          maxZoom: 19,
                          backgroundColor: theme.colorScheme.surfaceContainer,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag |
                                InteractiveFlag.doubleTapZoom,
                          ),
                          onMapReady: () {
                            if (mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _ready = true);
                              });
                            }
                          },
                        ),
                        children: <Widget>[
                          buildTileLayer(
                            MapStyleX.fromKey(
                              ref.read(secureStoreProvider).mapType,
                            ),
                            apiKey: ref.read(authProvider).user?.apiKey,
                          ),
                          MarkerLayer(
                            markers: <Marker>[
                              Marker(
                                point: LatLng(
                                    vehicle.latitude!, vehicle.longitude!),
                                width: 44,
                                height: 48,
                                alignment: const Alignment(0.0, -0.89),
                                child: GestureDetector(
                                  onTap: () => context.push('/vehicle-map?focus=${vehicle.id}'),
                                  child: VehicleMarkerPin(
                                    vehicle: vehicle,
                                    selected: true,
                                    useSprite: true,
                                    headingOverride: vehicle.heading,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: OsmAttribution(
                              style: MapStyle.standard,
                              compact: true,
                            ),
                          ),
                        ],
                      ),

                      // Live indicator overlay pill (Top-Left)
                      Positioned(
                        top: Gap.sm,
                        left: Gap.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'LIVE GPS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Map action buttons (Top-Right)
                      Positioned(
                        top: Gap.sm,
                        right: Gap.sm,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Re-center on vehicle
                            Material(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  if (vehicle.hasLocation) {
                                    _map.move(
                                      LatLng(vehicle.latitude!, vehicle.longitude!),
                                      _map.camera.zoom,
                                    );
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Tap-to-expand overlay — opens full zoomed live map
                            Material(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => context.push(
                                  '/vehicle-map?focus=${vehicle.id}',
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.fullscreen_rounded,
                                          size: 16, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Full Screen',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Container(
                    color: theme.colorScheme.surfaceContainer,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.location_off_rounded,
                              size: 30,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: Gap.sm),
                          Text('No GPS fix available',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: Gap.md),
        _LiveStatusLocationCard(vehicle: vehicle),
        const SizedBox(height: Gap.md),
        TelemetryGrid(vehicle: vehicle),
        const SizedBox(height: Gap.md),
        _LiveQuickActions(
          vehicle: vehicle,
          onTabSelect: widget.onTabSelect,
        ),
      ],
    );
  }
}

class _LiveStatusLocationCard extends StatelessWidget {
  const _LiveStatusLocationCard({required this.vehicle});
  final Vehicle vehicle;

  Future<void> _openDirections(Vehicle v) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${v.latitude},${v.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color statusAccent = AppColors.forStatus(vehicle.status.key);

    final String titleText = switch (vehicle.status) {
      VehicleStatus.moving => 'Moving',
      VehicleStatus.idle => 'Idling',
      VehicleStatus.stopped => 'Stopped',
      VehicleStatus.offline => 'Offline',
      VehicleStatus.noData => 'No Data',
    };
    final IconData statusIcon = switch (vehicle.status) {
      VehicleStatus.moving => Icons.navigation_rounded,
      VehicleStatus.idle => Icons.pause_circle_filled_rounded,
      VehicleStatus.stopped => Icons.stop_circle_rounded,
      VehicleStatus.offline => Icons.cloud_off_rounded,
      VehicleStatus.noData => Icons.sensors_off_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: Corners.rMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Streamlined Status Header (No Duplication) ─────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: statusAccent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, size: 18, color: statusAccent),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            titleText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: statusAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: vehicle.ignition
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : scheme.onSurfaceVariant.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: vehicle.ignition
                                        ? const Color(0xFF059669)
                                        : scheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  vehicle.ignition ? 'Ignition ON' : 'Ignition OFF',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: vehicle.ignition
                                        ? const Color(0xFF059669)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Since ${Fmt.time(vehicle.statusChangedAt ?? vehicle.lastPacketAt)} · ${Fmt.statusDuration(vehicle.statusChangedAt ?? vehicle.lastPacketAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),

          // ── Location & Directions Row ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 10, Gap.md, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.place_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: LiveAddress(
                    vehicle: vehicle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (vehicle.hasLocation) ...[
                  const SizedBox(width: Gap.sm),
                  FilledButton.tonalIcon(
                    onPressed: () => _openDirections(vehicle),
                    icon: const Icon(Icons.navigation_rounded, size: 14),
                    label: const Text('Directions'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      foregroundColor: scheme.primary,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
                      textStyle: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (vehicle.driverPhone != null && vehicle.driverPhone!.isNotEmpty) ...[
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    vehicle.driverName ?? 'Driver',
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _call(vehicle.driverPhone!),
                    icon: const Icon(Icons.phone_rounded, size: 13),
                    label: Text(vehicle.driverPhone!, style: const TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveQuickActions extends StatelessWidget {
  const _LiveQuickActions({
    required this.vehicle,
    this.onTabSelect,
  });

  final Vehicle vehicle;
  final ValueChanged<int>? onTabSelect;

  Future<void> _callDriver(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final IconData vehicleMovingIcon = switch (vehicle.displayType.toLowerCase()) {
      'truck' || 'tipper' || 'lorry' => Icons.local_shipping_rounded,
      'bike' || 'motorcycle' || 'scooter' => Icons.two_wheeler_rounded,
      'bus' => Icons.directions_bus_rounded,
      _ => Icons.directions_car_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Gap.sm),
          child: Text(
            'QUICK ACTIONS',
            style: AppTypography.eyebrow(scheme.onSurfaceVariant),
          ),
        ),
        Row(
          children: [
            // Action 1: History
            Expanded(
              child: _QuickActionButton(
                icon: vehicleMovingIcon,
                label: 'History',
                accentColor: const Color(0xFF6366F1),
                onTap: () => onTabSelect?.call(1),
              ),
            ),
            const SizedBox(width: 8),

            // Action 2: Share WhatsApp / Location
            Expanded(
              child: _QuickActionButton(
                icon: Icons.share_rounded,
                label: 'Share Live',
                accentColor: const Color(0xFF10B981),
                onTap: () => ShareHelper.shareVehicleLocation(vehicle),
              ),
            ),
            const SizedBox(width: 8),

            // Action 3: Call Driver or Vehicle Info
            if (vehicle.driverPhone != null && vehicle.driverPhone!.isNotEmpty)
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call Driver',
                  accentColor: const Color(0xFFF59E0B),
                  onTap: () => _callDriver(vehicle.driverPhone!),
                ),
              )
            else
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Vehicle Info',
                  accentColor: const Color(0xFF0284C7),
                  onTap: () => onTabSelect?.call(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
      borderRadius: Corners.rMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: Corners.rMd,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: accentColor),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
