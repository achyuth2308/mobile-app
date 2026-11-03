import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/share_helper.dart';
import '../../core/utils/vehicle_icons.dart';
import '../../data/models/vehicle.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/safety_parking_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/live_address.dart';

/// Vehicle Menu Screen (Springboard for vehicle actions & navigation)
class VehicleMenuScreen extends ConsumerStatefulWidget {
  const VehicleMenuScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehicleMenuScreen> createState() => _VehicleMenuScreenState();
}

class _VehicleMenuScreenState extends ConsumerState<VehicleMenuScreen> {
  bool? _optimisticSafetyPark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(socketServiceProvider).joinVehicle(widget.vehicleId);
      ref.read(secureStoreProvider).setLastVehicleId(widget.vehicleId);
    });
  }

  /// Safety Parking can only be ARMED when the vehicle is fully parked:
  /// ignition OFF **and** speed == 0.
  Future<void> _handleEngineCutToggle(BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final bool isImmobilized = vehicle.isImmobilized;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isImmobilized ? const Color(0xFF10B981) : const Color(0xFFDC2626)).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isImmobilized ? Icons.settings_backup_restore_rounded : Icons.warning_rounded,
              color: isImmobilized ? const Color(0xFF10B981) : const Color(0xFFDC2626),
              size: 38,
            ),
          ),
          title: Text(
            isImmobilized ? 'Restore Engine Power?' : '⚠️ DANGER: Cut Off Engine?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isImmobilized
                    ? 'This will close the relay circuit and restore ignition power to ${vehicle.displayName}, allowing the driver to start the vehicle.'
                    : 'Cutting the engine is an EMERGENCY SAFETY ACTION that will immediately disable the ignition circuit of ${vehicle.displayName}.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              if (!isImmobilized) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ensure the vehicle is stationary or parked in a safe spot before cutting the circuit.',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: Icon(
                      isImmobilized ? Icons.power_rounded : Icons.power_off_rounded,
                      size: 16,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: isImmobilized ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    label: Text(
                      isImmobilized ? 'Restore' : 'CUT ENGINE',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (proceed != true || !context.mounted) return;

    try {
      await ref.read(vehicleRepositoryProvider).sendImmobilizerCommand(vehicle.id, !isImmobilized);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isImmobilized
                  ? '✅ Engine restored for ${vehicle.displayName}.'
                  : '🛑 Engine cut command sent for ${vehicle.displayName}.',
            ),
            backgroundColor: isImmobilized ? AppColors.moving : AppColors.danger,
          ),
        );
      }
      ref.read(fleetProvider.notifier).load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  bool _canArmSafetyParking(Vehicle vehicle) =>
      !vehicle.ignition && vehicle.speed == 0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicle == null) {
      final bool isLoading = ref.watch(fleetProvider).isLoading;
      if (isLoading) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Vehicle unavailable',
          message: 'This vehicle is no longer part of your fleet, or the list '
              'has not finished loading.',
          actionLabel: 'Back to fleet',
          onAction: () => context.go('/dashboard'),
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color statusColor = AppColors.forStatus(vehicle.status.key);

    // Auto-disarm Safety Parking when the vehicle starts moving or engine turns ON
    ref.listen<Vehicle?>(vehicleByIdProvider(widget.vehicleId), (previous, next) {
      if (next == null) return;
      final bool wasArmed = previous?.isSafetyParkActive ?? false;
      final bool isMovingNow = next.speed > 0; // Only auto-disarm when actually moving, not idle
      if (wasArmed && isMovingNow) {
        // Reset optimistic state and auto-disarm
        setState(() => _optimisticSafetyPark = false);
        ref.read(safetyParkingProvider.notifier).autoDisarmIfMoving(
          vehicleId: next.id,
          ignition: next.ignition,
          speed: next.speed,
        );
      }
    });

    final bool isArmed = _optimisticSafetyPark ?? vehicle.isSafetyParkActive;
    final bool canArm = _canArmSafetyParking(vehicle);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Icon(Icons.circle, size: 10, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                vehicle.displayName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Share Location',
                    onPressed: () => ShareHelper.shareVehicleLocation(vehicle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    tooltip: 'Vehicle Settings',
                    onPressed: () =>
                        context.push('/vehicle/${widget.vehicleId}/settings'),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.x4l),
        children: [
          // ── Hero Card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2238) : Colors.white,
              borderRadius: Corners.rLg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/vehicles/${vehicle.displayType}.png',
                      height: 60,
                      width: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        VehicleIcons.forType(vehicle.displayType),
                        size: 40,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  vehicle.displayName.toUpperCase(),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  vehicle.status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _HeroMetric(
                      label: 'Speed',
                      value: '${vehicle.speed.round()} km/h',
                      color: AppColors.success,
                    ),
                    _HeroMetric(
                      label: 'Odometer',
                      value: vehicle.odometer != null
                          ? '${vehicle.odometer!.toStringAsFixed(0)} km'
                          : 'N/A',
                      color: Colors.cyan,
                    ),
                    _HeroMetric(
                      label: 'Battery',
                      value: vehicle.batteryLevel != null
                          ? '${vehicle.batteryLevel!.toStringAsFixed(1)} V'
                          : 'N/A',
                      color: Colors.orange,
                    ),
                    _HeroMetric(
                      label: 'Ignition',
                      value: vehicle.ignition ? 'ON' : 'OFF',
                      color: vehicle.ignition
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_rounded,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LiveAddress(
                        vehicle: vehicle,
                        max: 100,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF4A5568),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.md),

          // ── Safety Parking Quick Control Banner ───────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Corners.rLg,
              boxShadow: [
                BoxShadow(
                  color: (isArmed ? const Color(0xFFDC2626) : Colors.black)
                      .withValues(alpha: isArmed ? 0.15 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: isArmed
                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                  : (isDark ? const Color(0xFF1E2640) : const Color(0xFFF0F7FF)),
              shape: RoundedRectangleBorder(
                borderRadius: Corners.rLg,
                side: BorderSide(
                  color: isArmed
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB).withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: InkWell(
                borderRadius: Corners.rLg,
                onTap: () async {
                  final bool nextState = !isArmed;

                  // Block arming while vehicle is moving or engine is ON
                  if (nextState && !_canArmSafetyParking(vehicle)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '⚠️ Safety Parking can only be armed when the vehicle is parked (Engine OFF & Speed = 0).',
                          ),
                          backgroundColor: Color(0xFFB45309),
                          duration: Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  setState(() {
                    _optimisticSafetyPark = nextState;
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nextState
                              ? '🛡️ Safety Parking ARMED for ${vehicle.displayName}!'
                              : 'Safety Parking Disarmed.',
                        ),
                        backgroundColor: nextState ? const Color(0xFFDC2626) : const Color(0xFF475569),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }

                  try {
                    if (nextState) {
                      await ref.read(safetyParkingProvider.notifier).arm(vehicle.id);
                    } else {
                      await ref.read(safetyParkingProvider.notifier).disarm(vehicle.id);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() {
                        _optimisticSafetyPark = !nextState;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update Safety Parking: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: isArmed
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isArmed ? const Color(0xFFDC2626) : const Color(0xFF2563EB))
                                  .withOpacity(0.35),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          isArmed ? Icons.security_rounded : Icons.shield_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Safety Parking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isArmed
                                        ? const Color(0xFFDC2626)
                                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isArmed ? 'ARMED' : 'DISARMED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: isArmed ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArmed
                                  ? 'Siren triggers if moved or ignition turns ON'
                                  : !canArm
                                      ? (vehicle.speed > 0
                                          ? 'Unavailable while moving — park the vehicle first'
                                          : 'Unavailable while engine is ON — turn off ignition first')
                                      : 'Tap anywhere to arm anti-theft parking guard',
                              style: TextStyle(
                                fontSize: 11,
                                color: isArmed
                                    ? const Color(0xFFDC2626)
                                    : !canArm
                                        ? const Color(0xFFB45309)
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isArmed
                              ? const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFFDC2626)])
                              : !canArm
                                  ? null
                                  : const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                          color: !canArm
                              ? (isDark ? Colors.orange.withValues(alpha: 0.2) : const Color(0xFFFEF3C7))
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          border: !canArm
                              ? Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5), width: 1.2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: (isArmed
                                      ? const Color(0xFFDC2626)
                                      : !canArm
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF2563EB))
                                  .withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArmed
                                  ? 'ARMED'
                                  : !canArm
                                      ? (vehicle.speed > 0 ? 'MOVING' : 'IDLE')
                                      : 'ARM GUARD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isArmed || canArm
                                    ? Colors.white
                                    : const Color(0xFFB45309),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isArmed
                                  ? Icons.shield_rounded
                                  : !canArm
                                      ? (vehicle.speed > 0
                                          ? Icons.directions_car_rounded
                                          : Icons.power_settings_new_rounded)
                                      : Icons.chevron_right_rounded,
                              size: 15,
                              color: isArmed || canArm
                                  ? Colors.white
                                  : const Color(0xFFB45309),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: Gap.md),

          // ── Special Emergency Engine Cut Off Banner ───────────────────
          _EngineCutSpecialBanner(
            vehicle: vehicle,
            onToggle: () => _handleEngineCutToggle(context, ref, vehicle),
          ),

          const SizedBox(height: Gap.lg),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: Gap.md),
            child: Text(
              'VEHICLE MENU',
              style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant),
            ),
          ),

          // ── Menu List Items ───────────────────────────────────────────
          _MenuItemCard(
            title: 'Vehicle Detail',
            subtitle: 'Live map, status banner, telemetry & tabbed view',
            icon: Icons.space_dashboard_rounded,
            accentColor: const Color(0xFF3B82F6), // Blue
            onTap: () => context.push('/vehicle/${widget.vehicleId}/detail'),
          ),

          _MenuItemCard(
            title: 'Live Map Tracking',
            subtitle: 'Full-screen interactive map with real-time location',
            icon: Icons.map_rounded,
            accentColor: const Color(0xFF10B981), // Emerald
            onTap: () => context.push('/vehicle-map?focus=${widget.vehicleId}'),
          ),

          _MenuItemCard(
            title: 'Playback & History',
            subtitle: 'Replay past trips, route trails & stoppage analysis',
            icon: Icons.history_rounded,
            accentColor: const Color(0xFFF59E0B), // Amber
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/detail?tab=1'),
          ),

          _MenuItemCard(
            title: 'Alerts & Events',
            subtitle: 'View overspeed, geofence, ignition & battery logs',
            icon: Icons.notifications_active_rounded,
            accentColor: const Color(0xFFEF4444), // Red
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/detail?tab=2'),
          ),

          _MenuItemCard(
            title: 'Geofences',
            subtitle: 'Virtual boundaries, entry/exit zones & alerts',
            icon: Icons.fence_rounded,
            accentColor: const Color(0xFF10B981), // Emerald
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/geofences'),
          ),

          _MenuItemCard(
            title: 'Vehicle Info & Specs',
            subtitle: 'Hardware details, IMEI, driver assignment & docs',
            icon: Icons.info_outline_rounded,
            accentColor: const Color(0xFF06B6D4), // Cyan
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/detail?tab=3'),
          ),

          _MenuItemCard(
            title: 'Alert & Notification Configuration',
            subtitle: 'Speed limits, alert thresholds & notification toggles',
            icon: Icons.notifications_active_outlined,
            accentColor: const Color(0xFF64748B), // Slate
            onTap: () => context.push('/vehicle/${widget.vehicleId}/settings'),
          ),

          // ── Dedicated Individual Reports ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'REPORTS',
              style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant),
            ),
          ),

          _MenuItemCard(
            title: 'Trip Report',
            subtitle: 'Automated trips, start/end locations, duration & distance',
            icon: Icons.route_rounded,
            accentColor: const Color(0xFF8B5CF6), // Purple
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=trip'),
          ),

          _MenuItemCard(
            title: 'Full Day Trip Report',
            subtitle: 'Daily aggregated travel summary and total distance',
            icon: Icons.today_rounded,
            accentColor: const Color(0xFF6366F1), // Indigo
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=dailyTrip'),
          ),

          _MenuItemCard(
            title: 'Geofence Trips',
            subtitle: 'Corridor transit, entry/exit logs & geofence journeys',
            icon: Icons.alt_route_rounded,
            accentColor: const Color(0xFF0D9488), // Teal
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=geofenceTransit'),
          ),

          _MenuItemCard(
            title: 'Stoppage Report',
            subtitle: 'Halt locations, stoppage durations & parking logs',
            icon: Icons.pause_circle_rounded,
            accentColor: const Color(0xFFEA580C), // Orange
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=stoppages'),
          ),

          _MenuItemCard(
            title: 'Idle Report',
            subtitle: 'Engine idle time, stationary waste & locations',
            icon: Icons.access_time_rounded,
            accentColor: const Color(0xFFD97706), // Amber
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=idle'),
          ),

          _MenuItemCard(
            title: 'Primary Engine On',
            subtitle: 'Engine ON/OFF events, total duration & nearest locations',
            icon: Icons.power_settings_new_rounded,
            accentColor: const Color(0xFF059669), // Emerald
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/engine-on'),
          ),

          _MenuItemCard(
            title: 'Overspeeding Report',
            subtitle: 'Speed limit violations, top speeds & violation spots',
            icon: Icons.speed_rounded,
            accentColor: const Color(0xFFE11D48), // Rose
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=overspeeding'),
          ),

          _MenuItemCard(
            title: 'Consolidated Report',
            subtitle: 'Consolidated distance, running time, idle & halts',
            icon: Icons.group_work_rounded,
            accentColor: const Color(0xFF16A34A), // Green
            onTap: () =>
                context.go('/reports?vehicle=${widget.vehicleId}&type=consolidated'),
          ),

          if (vehicle.hasFuel) ...[
            _MenuItemCard(
              title: 'Fuel Analytics & Report',
              subtitle: 'Interactive dual-axis graph, refills, theft & packet log',
              icon: Icons.local_gas_station_rounded,
              accentColor: const Color(0xFF0284C7), // Sky / Cyan
              onTap: () =>
                  context.push('/vehicle/${widget.vehicleId}/fuel-analytics'),
            ),
            _MenuItemCard(
              title: 'Fuel Consolidated Report',
              subtitle: 'Fuel consumption, refuels, theft & mileage breakdown',
              icon: Icons.ev_station_rounded,
              accentColor: const Color(0xFFEA580C), // Orange
              onTap: () =>
                  context.go('/reports?vehicle=${widget.vehicleId}&type=fuelConsolidated'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2238) : Colors.white,
        borderRadius: Corners.rLg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Corners.rLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: Corners.rLg,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2E3355),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _EngineCutSpecialBanner extends StatelessWidget {
  const _EngineCutSpecialBanner({
    required this.vehicle,
    required this.onToggle,
  });

  final Vehicle vehicle;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isCut = vehicle.isImmobilized;

    // Danger / Alert accent colors
    final Color primaryColor = isCut ? const Color(0xFF10B981) : const Color(0xFFDC2626);
    final Color bgColor = isCut
        ? (isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF450A0A).withOpacity(0.5) : const Color(0xFFFEF2F2));
    final Color borderColor = isCut
        ? const Color(0xFF10B981).withOpacity(0.5)
        : const Color(0xFFDC2626).withOpacity(0.4);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Corners.rLg,
        boxShadow: [
          BoxShadow(
            color: (isCut ? const Color(0xFF10B981) : const Color(0xFFDC2626))
                .withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rLg,
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        child: InkWell(
          borderRadius: Corners.rLg,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Warning pulsing emblem / icon badge
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isCut
                        ? const Color(0xFF10B981)
                        : const Color(0xFFDC2626),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isCut ? const Color(0xFF10B981) : const Color(0xFFDC2626))
                            .withOpacity(0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isCut ? Icons.power_rounded : Icons.power_settings_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Engine Cut Off Relay',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isCut
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFFDC2626).withOpacity(0.3) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isCut ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isCut ? 'CIRCUIT CUT' : 'NORMAL / ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isCut
                                    ? Colors.white
                                    : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCut
                            ? 'Relay circuit is disabled. Tap to restore ignition.'
                            : 'Emergency ignition cutoff — tap to immobilize vehicle',
                        style: TextStyle(
                          fontSize: 11,
                          color: isCut
                              ? const Color(0xFF059669)
                              : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dedicated Special Action Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCut
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isCut ? const Color(0xFF10B981) : const Color(0xFFDC2626))
                            .withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCut ? Icons.settings_backup_restore_rounded : Icons.power_settings_new_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCut ? 'RESTORE' : 'CUT OFF',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}