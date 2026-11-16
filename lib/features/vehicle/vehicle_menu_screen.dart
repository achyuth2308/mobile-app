import 'dart:ui' show PointerDeviceKind;
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
  bool? _optimisticAcOff;

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

  Future<void> _handleAcToggle(BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final bool currentAcOff = _optimisticAcOff ?? vehicle.isAcOff;
    final bool nextAcOff = !currentAcOff;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (nextAcOff ? const Color(0xFF0284C7) : const Color(0xFF10B981)).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              nextAcOff ? Icons.ac_unit_rounded : Icons.power_settings_new_rounded,
              color: nextAcOff ? const Color(0xFF0284C7) : const Color(0xFF10B981),
              size: 38,
            ),
          ),
          title: Text(
            nextAcOff ? 'Turn Off Air Conditioner?' : 'Restore Air Conditioner?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nextAcOff
                    ? 'This will cut the secondary relay circuit to turn OFF the air conditioning in ${vehicle.displayName}. Use this to save fuel or reduce engine idling load.'
                    : 'This will restore the secondary relay circuit and re-enable the air conditioning system for ${vehicle.displayName}.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: nextAcOff ? const Color(0xFFF0F9FF) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (nextAcOff ? const Color(0xFF0284C7) : const Color(0xFF10B981)).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      nextAcOff ? Icons.eco_outlined : Icons.check_circle_outline_rounded,
                      color: nextAcOff ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nextAcOff
                            ? 'Switching off the AC reduces fuel burn and alternator load while idling.'
                            : 'Cooling circuit will be energized and cabin AC will resume operation.',
                        style: TextStyle(
                          color: nextAcOff ? const Color(0xFF0369A1) : const Color(0xFF047857),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                      nextAcOff ? Icons.power_settings_new_rounded : Icons.ac_unit_rounded,
                      size: 16,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: nextAcOff ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    label: Text(
                      nextAcOff ? 'TURN OFF AC' : 'TURN ON AC',
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

    setState(() => _optimisticAcOff = nextAcOff);

    try {
      await ref.read(vehicleRepositoryProvider).sendAcCommand(vehicle.id, nextAcOff);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextAcOff
                  ? '❄️ AC turned OFF for ${vehicle.displayName}.'
                  : '❄️ AC power restored for ${vehicle.displayName}.',
            ),
            backgroundColor: nextAcOff ? const Color(0xFF0284C7) : AppColors.moving,
          ),
        );
      }
      ref.read(fleetProvider.notifier).load();
    } catch (e) {
      if (context.mounted) {
        setState(() => _optimisticAcOff = currentAcOff);
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
      backgroundColor: isDark ? const Color(0xFF12151F) : const Color(0xFFF4F7FC),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.7),
                  statusColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
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
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
                      vehicle.statusAssetPath,
                      height: 60,
                      width: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
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
                                  maxLines: 2,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    height: 1.2,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      vehicle.status.label.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: statusColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          () {
                            final String rawType = vehicle.type.trim();
                            final bool isGenericType = rawType.isEmpty ||
                                rawType.toLowerCase() == 'general' ||
                                rawType.toLowerCase() == 'default';

                            String? subtitle;
                            if (vehicle.driverName != null &&
                                vehicle.driverName!.trim().isNotEmpty) {
                              subtitle = 'Driver: ${vehicle.driverName!.trim()}';
                            } else if (vehicle.registrationNumber.trim().isNotEmpty &&
                                vehicle.name.trim().isNotEmpty &&
                                vehicle.registrationNumber.trim() !=
                                    vehicle.name.trim()) {
                              subtitle = vehicle.displayName ==
                                      vehicle.registrationNumber.trim()
                                  ? vehicle.name.trim().toUpperCase()
                                  : vehicle.registrationNumber.trim().toUpperCase();
                            } else if (!isGenericType) {
                              subtitle = rawType.toUpperCase();
                            }

                            if (subtitle == null || subtitle.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 3.5),
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF64748B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            );
                          }(),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isCompact = constraints.maxWidth < 580;
                    if (isCompact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              _HeroMetric(
                                label: 'Speed',
                                value: '${vehicle.speed.round()} km/h',
                                color: vehicle.speed > 0
                                    ? AppColors.moving
                                    : const Color(0xFF64748B),
                                icon: Icons.speed_rounded,
                              ),
                              const SizedBox(width: 8),
                              _HeroMetric(
                                label: 'Odometer',
                                value: vehicle.odometer != null
                                    ? '${vehicle.odometer!.toStringAsFixed(0)} km'
                                    : 'N/A',
                                color: const Color(0xFF0284C7),
                                icon: Icons.straighten_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _HeroMetric(
                                label: 'Battery',
                                value: vehicle.batteryLevel != null
                                    ? '${vehicle.batteryLevel!.toStringAsFixed(1)} V'
                                    : 'N/A',
                                color: const Color(0xFFEA580C),
                                icon: Icons.battery_charging_full_rounded,
                              ),
                              const SizedBox(width: 8),
                              _HeroMetric(
                                label: 'Ignition',
                                value: vehicle.ignition ? 'ON' : 'OFF',
                                color: vehicle.ignition
                                    ? AppColors.moving
                                    : const Color(0xFFEF4444),
                                icon: Icons.power_settings_new_rounded,
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroMetric(
                          label: 'Speed',
                          value: '${vehicle.speed.round()} km/h',
                          color: vehicle.speed > 0
                              ? AppColors.moving
                              : const Color(0xFF64748B),
                          icon: Icons.speed_rounded,
                          width: 132,
                        ),
                        _HeroMetric(
                          label: 'Odometer',
                          value: vehicle.odometer != null
                              ? '${vehicle.odometer!.toStringAsFixed(0)} km'
                              : 'N/A',
                          color: const Color(0xFF0284C7),
                          icon: Icons.straighten_rounded,
                          width: 132,
                        ),
                        _HeroMetric(
                          label: 'Battery',
                          value: vehicle.batteryLevel != null
                              ? '${vehicle.batteryLevel!.toStringAsFixed(1)} V'
                              : 'N/A',
                          color: const Color(0xFFEA580C),
                          icon: Icons.battery_charging_full_rounded,
                          width: 132,
                        ),
                        _HeroMetric(
                          label: 'Ignition',
                          value: vehicle.ignition ? 'ON' : 'OFF',
                          color: vehicle.ignition
                              ? AppColors.moving
                              : const Color(0xFFEF4444),
                          icon: Icons.power_settings_new_rounded,
                          width: 132,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2EAF8),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_rounded,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: LiveAddress(
                          vehicle: vehicle,
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
                ),
              ],
            ),
          ),

          const SizedBox(height: Gap.md),

          // ── Dual Action Tracking Dock (Live Tracking & Trip History) ────
          Row(
            children: [
              Expanded(
                child: _TrackDockButton(
                  title: 'Live Tracking',
                  subtitle: 'Real-time GPS trail',
                  badgeText: 'GPS LIVE',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  glowColor: const Color(0xFF10B981),
                  icon: Icons.navigation_rounded,
                  onTap: () => context.push('/vehicle-map?focus=${widget.vehicleId}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackDockButton(
                  title: 'History',
                  subtitle: 'Past routes & stops',
                  badgeText: 'REPLAY',
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  glowColor: const Color(0xFFF59E0B),
                  icon: Icons.play_circle_fill_rounded,
                  onTap: () => context.push('/vehicle/${widget.vehicleId}/detail?tab=1'),
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.lg),

          // ── Priority 3: Quick Remote Controls ─────────────────────────
          const _SectionHeader(label: 'QUICK CONTROLS'),

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7.5),
                        decoration: BoxDecoration(
                          color: isArmed
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isArmed ? const Color(0xFFDC2626) : const Color(0xFF2563EB))
                                  .withOpacity(0.35),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          isArmed ? Icons.security_rounded : Icons.shield_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Safety Parking',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isArmed
                                        ? const Color(0xFFDC2626)
                                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isArmed ? 'ARMED' : 'OFF',
                                    style: TextStyle(
                                      fontSize: 8.5,
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
                                  ? 'Siren triggers if moved or ignition ON'
                                  : !canArm
                                      ? (vehicle.speed > 0
                                          ? 'Unavailable while moving'
                                          : 'Unavailable while engine ON')
                                      : 'Anti-theft guard',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isArmed
                                    ? const Color(0xFFDC2626)
                                    : !canArm
                                        ? const Color(0xFFB45309)
                                        : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
                        decoration: BoxDecoration(
                          gradient: isArmed
                              ? const LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFFDC2626)])
                              : !canArm
                                  ? null
                                  : const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                          color: !canArm
                              ? (isDark ? Colors.orange.withOpacity(0.2) : const Color(0xFFFEF3C7))
                              : null,
                          borderRadius: BorderRadius.circular(14),
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
                            Icon(
                              isArmed
                                  ? Icons.shield_rounded
                                  : !canArm
                                      ? (vehicle.speed > 0
                                          ? Icons.directions_car_rounded
                                          : Icons.power_settings_new_rounded)
                                      : Icons.shield_outlined,
                              size: 12,
                              color: isArmed || canArm ? Colors.white : const Color(0xFFB45309),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isArmed
                                  ? 'ARMED'
                                  : !canArm
                                      ? (vehicle.speed > 0 ? 'MOVING' : 'IDLE')
                                      : 'ARM',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isArmed || canArm
                                    ? Colors.white
                                    : const Color(0xFFB45309),
                                letterSpacing: 0.4,
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
          ),

          const SizedBox(height: Gap.md),

          // ── Special Emergency Engine Cut Off Banner ───────────────────
          _EngineCutSpecialBanner(
            vehicle: vehicle,
            onToggle: () => _handleEngineCutToggle(context, ref, vehicle),
          ),

          const SizedBox(height: Gap.md),

          // ── Air Conditioning Quick Control Banner ─────────────────────────
          _AcControlSpecialBanner(
            vehicle: vehicle,
            isAcOff: _optimisticAcOff ?? vehicle.isAcOff,
            onToggle: () => _handleAcToggle(context, ref, vehicle),
          ),

          const SizedBox(height: Gap.lg),

          // ── Vehicle Analytics & Reports Hub ───────────────────────────
          _ReportsHubSection(
            vehicleId: widget.vehicleId,
          ),

          if (vehicle.hasFuel) ...[
            const SizedBox(height: Gap.lg),
            _FuelReportsSection(
              vehicleId: widget.vehicleId,
            ),
          ],

          const SizedBox(height: Gap.lg),

          // ── Vehicle Operations ─────────────────────────────────────────
          const _SectionHeader(label: 'VEHICLE OPERATIONS'),

          _MenuItemCard(
            title: 'Vehicle Detail',
            subtitle: 'Live telemetry & gauges',
            icon: Icons.space_dashboard_rounded,
            accentColor: const Color(0xFF3B82F6),
            badgeText: 'LIVE',
            badgeColor: const Color(0xFF3B82F6),
            onTap: () => context.push('/vehicle/${widget.vehicleId}/detail'),
          ),
          const SizedBox(height: 5),

          _MenuItemCard(
            title: 'Alerts & Events',
            subtitle: 'Overspeed, geofence & ignition logs',
            icon: Icons.notifications_active_rounded,
            accentColor: const Color(0xFFEF4444),
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/detail?tab=2'),
          ),
          const SizedBox(height: 5),

          _MenuItemCard(
            title: 'Geofences',
            subtitle: 'Boundaries & zone alerts',
            icon: Icons.fence_rounded,
            accentColor: const Color(0xFF059669),
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/geofences'),
          ),
          const SizedBox(height: 5),

          _MenuItemCard(
            title: 'Fitment Certificate',
            subtitle: 'AIS-140 compliance PDF',
            icon: Icons.verified_user_rounded,
            accentColor: const Color(0xFF10B981),
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/fitment-certificate'),
          ),
          const SizedBox(height: 5),

          _MenuItemCard(
            title: 'Vehicle Info & Specs',
            subtitle: 'Hardware, IMEI & driver info',
            icon: Icons.info_outline_rounded,
            accentColor: const Color(0xFF06B6D4),
            onTap: () =>
                context.push('/vehicle/${widget.vehicleId}/detail?tab=3'),
          ),
          const SizedBox(height: 5),

          _MenuItemCard(
            title: 'Alert Settings',
            subtitle: 'Speed limits & alert toggles',
            icon: Icons.tune_rounded,
            accentColor: const Color(0xFF64748B),
            onTap: () => context.push('/vehicle/${widget.vehicleId}/settings'),
          ),

          const SizedBox(height: Gap.xl),
        ],
      ),
    ),
  );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.width,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget card = Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 8.5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.25 : 0.18),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppTypography.mono,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      return card;
    }
    return Expanded(child: card);
  }
}

class _TrackDockButton extends StatelessWidget {
  const _TrackDockButton({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.gradient,
    required this.glowColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeText;
  final LinearGradient gradient;
  final Color glowColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.38 : 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.28),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 21),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeText.contains('LIVE')) ...[
                            Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF6EE7B7),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF6EE7B7),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernReportTile extends StatelessWidget {
  const _ModernReportTile({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2238) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, color: accentColor, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _ReportsHubSection extends StatefulWidget {
  const _ReportsHubSection({
    required this.vehicleId,
  });

  final String vehicleId;

  @override
  State<_ReportsHubSection> createState() => _ReportsHubSectionState();
}

class _ReportsHubSectionState extends State<_ReportsHubSection> {
  int _activeCategory = 0; // 0: All, 1: Trips, 2: Safety, 3: Engine

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          label: 'VEHICLE ANALYTICS & REPORTS',
          trailing: '8 Modules',
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildCategoryChip(0, 'All (8)', isDark),
              const SizedBox(width: 6),
              _buildCategoryChip(1, 'Trips', isDark),
              const SizedBox(width: 6),
              _buildCategoryChip(2, 'Safety', isDark),
              const SizedBox(width: 6),
              _buildCategoryChip(3, 'Engine', isDark),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildFilteredGrid(context, isDark),
      ],
    );
  }

  Widget _buildCategoryChip(int index, String label, bool isDark) {
    final bool isSelected = _activeCategory == index;
    const Color brandColor = Color(0xFF6366F1);

    return InkWell(
      onTap: () {
        setState(() {
          _activeCategory = index;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? brandColor
              : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? brandColor
                : (isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredGrid(BuildContext context, bool isDark) {
    final List<Widget> items = [];

    final tripReport = _ModernReportTile(
      title: 'Trip Report',
      icon: Icons.route_rounded,
      accentColor: const Color(0xFF8B5CF6),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=trip'),
    );
    final fullDayTrip = _ModernReportTile(
      title: 'Full Day Trip',
      icon: Icons.today_rounded,
      accentColor: const Color(0xFF6366F1),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=dailyTrip'),
    );
    final geofenceTrips = _ModernReportTile(
      title: 'Geofence Trips',
      icon: Icons.alt_route_rounded,
      accentColor: const Color(0xFF0D9488),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=geofenceTransit'),
    );
    final stoppageReport = _ModernReportTile(
      title: 'Stoppage Report',
      icon: Icons.pause_circle_rounded,
      accentColor: const Color(0xFFEA580C),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=stoppages'),
    );
    final idleReport = _ModernReportTile(
      title: 'Idle Report',
      icon: Icons.access_time_rounded,
      accentColor: const Color(0xFFD97706),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=idle'),
    );
    final primaryEngineOn = _ModernReportTile(
      title: 'Primary Engine On',
      icon: Icons.power_settings_new_rounded,
      accentColor: const Color(0xFF059669),
      onTap: () => context.push('/vehicle/${widget.vehicleId}/engine-on'),
    );
    final overspeeding = _ModernReportTile(
      title: 'Overspeeding',
      icon: Icons.speed_rounded,
      accentColor: const Color(0xFFE11D48),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=overspeeding'),
    );
    final consolidated = _ModernReportTile(
      title: 'Consolidated',
      icon: Icons.group_work_rounded,
      accentColor: const Color(0xFF16A34A),
      onTap: () => context.go('/reports?vehicle=${widget.vehicleId}&type=consolidated'),
    );

    switch (_activeCategory) {
      case 1: // Trips
        items.addAll([tripReport, fullDayTrip, geofenceTrips, stoppageReport]);
        break;
      case 2: // Safety
        items.addAll([overspeeding, stoppageReport, geofenceTrips]);
        break;
      case 3: // Engine
        items.addAll([idleReport, primaryEngineOn]);
        break;
      default: // All (8 modules)
        items.addAll([
          tripReport,
          fullDayTrip,
          geofenceTrips,
          stoppageReport,
          idleReport,
          primaryEngineOn,
          overspeeding,
          consolidated,
        ]);
        break;
    }

    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      if (i + 1 < items.length) {
        rows.add(
          Row(
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 8),
              Expanded(child: items[i + 1]),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            children: [
              Expanded(child: items[i]),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      }
      if (i + 2 < items.length) {
        rows.add(const SizedBox(height: 7));
      }
    }

    return Column(children: rows);
  }
}

/// Dedicated Fuel Reports Section for fuel-equipped vehicles
class _FuelReportsSection extends StatelessWidget {
  const _FuelReportsSection({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context) {
    final kmplReport = _ModernReportTile(
      title: 'KMPL Report',
      icon: Icons.speed_rounded,
      accentColor: const Color(0xFF0284C7),
      onTap: () => context.push('/vehicle/$vehicleId/fuel-analytics'),
    );
    final lphReport = _ModernReportTile(
      title: 'LPH Report',
      icon: Icons.timelapse_rounded,
      accentColor: const Color(0xFFD97706),
      onTap: () => context.push('/vehicle/$vehicleId/fuel-analytics'),
    );
    final refillReport = _ModernReportTile(
      title: 'Refill Report',
      icon: Icons.local_gas_station_rounded,
      accentColor: const Color(0xFF16A34A),
      onTap: () => context.go('/reports?vehicle=$vehicleId&type=fuelConsolidated'),
    );
    final theftReport = _ModernReportTile(
      title: 'Theft Report',
      icon: Icons.warning_amber_rounded,
      accentColor: const Color(0xFFE11D48),
      onTap: () => context.go('/reports?vehicle=$vehicleId&type=fuelConsolidated'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          label: 'FUEL REPORTS',
          trailing: '4 Modules',
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: kmplReport),
            const SizedBox(width: 8),
            Expanded(child: lphReport),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(child: refillReport),
            const SizedBox(width: 8),
            Expanded(child: theftReport),
          ],
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
    this.badgeText,
    this.badgeColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2238) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.035),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.32),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.18),
                        accentColor.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accentColor).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText!,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor ?? accentColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    size: 16,
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
            color: primaryColor.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rLg,
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        child: InkWell(
          borderRadius: Corners.rLg,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                // Icon badge
                Container(
                  padding: const EdgeInsets.all(7.5),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isCut ? Icons.power_rounded : Icons.power_settings_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Engine Cut Off',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isCut
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFFDC2626).withOpacity(0.3) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: primaryColor,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isCut ? 'CUT' : 'ACTIVE',
                              style: TextStyle(
                                fontSize: 8.5,
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
                        isCut ? 'Circuit disabled' : 'Emergency cut',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isCut
                              ? const Color(0xFF059669)
                              : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCut
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
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
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isCut ? 'RESTORE' : 'CUT OFF',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
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

class _AcControlSpecialBanner extends StatelessWidget {
  const _AcControlSpecialBanner({
    required this.vehicle,
    required this.isAcOff,
    required this.onToggle,
  });

  final Vehicle vehicle;
  final bool isAcOff;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color primaryColor = isAcOff ? const Color(0xFFF59E0B) : const Color(0xFF0284C7);
    final Color bgColor = isAcOff
        ? (isDark ? const Color(0xFF332200).withOpacity(0.4) : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF0C243B).withOpacity(0.4) : const Color(0xFFF0F9FF));
    final Color borderColor = isAcOff
        ? const Color(0xFFF59E0B).withOpacity(0.45)
        : const Color(0xFF0284C7).withOpacity(0.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Corners.rLg,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(isDark ? 0.2 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.rLg,
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        child: InkWell(
          borderRadius: Corners.rLg,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                // AC icon badge
                Container(
                  padding: const EdgeInsets.all(7.5),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isAcOff ? Icons.power_off_rounded : Icons.ac_unit_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Air Conditioner',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isAcOff
                                  ? (isDark ? const Color(0xFFF59E0B).withOpacity(0.25) : const Color(0xFFFEF3C7))
                                  : (isDark ? const Color(0xFF0284C7).withOpacity(0.25) : const Color(0xFFE0F2FE)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              isAcOff ? 'OFF' : 'ON',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: isAcOff
                                    ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                                    : (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAcOff ? 'AC relay cut' : 'AC running',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isAcOff
                              ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                              : (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7)),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Dedicated Action Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAcOff
                          ? [const Color(0xFF0284C7), const Color(0xFF0EA5E9)]
                          : [const Color(0xFF0284C7), const Color(0xFF0369A1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAcOff ? Icons.ac_unit_rounded : Icons.power_settings_new_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isAcOff ? 'TURN ON' : 'TURN OFF',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
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


/// Beautiful gradient-line section header widget
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
