import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/share_helper.dart';
import '../../data/models/vehicle.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/safety_parking_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../alerts/alerts_screen.dart';
import 'tabs/vehicle_info_tab.dart';
import 'tabs/vehicle_live_tab.dart';
import 'tabs/vehicle_playback_tab.dart';

/// Comprehensive Tabbed Vehicle Detail Screen (Live, History, Alerts, Info)
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({
    required this.vehicleId,
    this.initialTab = 0,
    super.key,
  });

  final String vehicleId;
  final int initialTab;

  @override
  ConsumerState<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(socketServiceProvider).joinVehicle(widget.vehicleId);
      ref.read(secureStoreProvider).setLastVehicleId(widget.vehicleId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicle == null) {
      final bool isLoading = ref.watch(fleetProvider).isLoading;
      if (isLoading) {
        return Scaffold(
          appBar: _tabController.index == 1 ? null : AppBar(),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      return Scaffold(
        appBar: _tabController.index == 1 ? null : AppBar(),
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

    return Scaffold(
      appBar: _tabController.index == 1 ? null : AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vehicle/${widget.vehicleId}');
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                vehicle.displayName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Location via WhatsApp',
            onPressed: () => _shareLocation(vehicle),
          ),
          if (vehicle.isSafetyParkActive)
            IconButton(
              icon: const Icon(
                Icons.security_rounded,
                size: 20,
                color: Color(0xFFDC2626),
              ),
              tooltip: 'Safety Parking ARMED (Tap to Disarm)',
              onPressed: () async {
                await ref.read(safetyParkingProvider.notifier).disarm(vehicle.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Safety Parking Disarmed.'),
                      backgroundColor: Color(0xFF475569),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            tooltip: 'Vehicle Options',
            onPressed: () => _showQuickActionsSheet(context, ref, vehicle),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: 'Live'),
            Tab(text: 'History'),
            Tab(text: 'Alerts'),
            Tab(text: 'Info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          VehicleLiveTab(
            vehicleId: widget.vehicleId,
            onTabSelect: (int tabIndex) => _tabController.animateTo(tabIndex),
          ),
          VehiclePlaybackTab(vehicleId: widget.vehicleId),
          AlertsScreen(vehicleId: widget.vehicleId),
          VehicleInfoTab(vehicleId: widget.vehicleId),
        ],
      ),
    );
  }

  Future<void> _confirmEngineToggle(BuildContext context, WidgetRef ref, Vehicle vehicle) async {
    final bool isImmobilized = vehicle.isImmobilized;
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          icon: Icon(
            isImmobilized ? Icons.settings_backup_restore_rounded : Icons.power_settings_new_rounded,
            color: isImmobilized ? AppColors.moving : AppColors.danger,
            size: 40,
          ),
          title: Text(isImmobilized ? 'Restore Engine?' : 'Cut Off Engine?'),
          content: Text(
            isImmobilized
                ? 'This will restore the ignition circuit, allowing  to start again.'
                : 'WARNING: This will disable \'s ignition/fuel circuit. '
                  'The vehicle cannot be restarted until restored. Ensure the vehicle is in a safe location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isImmobilized ? AppColors.moving : AppColors.danger,
              ),
              child: Text(isImmobilized ? 'Restore Engine' : 'Cut Engine'),
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
                  ? '✅ Engine restored for .'
                  : '🛑 Engine cut command sent for .',
            ),
            backgroundColor: isImmobilized ? AppColors.moving : AppColors.danger,
          ),
        );
      }
      unawaited(ref.read(fleetProvider.notifier).load());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update engine status.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _shareLocation(Vehicle vehicle) async {
    await ShareHelper.shareVehicleLocation(vehicle);
  }

  void _showQuickActionsSheet(
      BuildContext context, WidgetRef ref, Vehicle vehicle) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.forStatus(vehicle.status.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicle.displayName.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (vehicle.type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Safety Parking tile
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: vehicle.isSafetyParkActive
                          ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      vehicle.isSafetyParkActive
                          ? Icons.security_rounded
                          : Icons.shield_outlined,
                      color: vehicle.isSafetyParkActive
                          ? const Color(0xFFDC2626)
                          : scheme.onSurface,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    vehicle.isSafetyParkActive
                        ? 'Disarm Safety Parking'
                        : 'Arm Safety Parking (Theft Siren)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    vehicle.isSafetyParkActive
                        ? 'Active — siren will sound if moved'
                        : 'Alerts if moved from current spot',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  trailing: Switch(
                    value: vehicle.isSafetyParkActive,
                    activeThumbColor: const Color(0xFFDC2626),
                    onChanged: (bool val) async {
                      Navigator.pop(ctx);
                      if (val) {
                        await ref
                            .read(safetyParkingProvider.notifier)
                            .arm(vehicle.id);
                      } else {
                        await ref
                            .read(safetyParkingProvider.notifier)
                            .disarm(vehicle.id);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              val
                                  ? '🛡️ Safety Parking ARMED for ${vehicle.displayName}!'
                                  : 'Safety Parking Disarmed.',
                            ),
                            backgroundColor: val
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF475569),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),

                // Emergency Engine Cut tile
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: vehicle.isImmobilized
                          ? const Color(0xFF10B981).withValues(alpha: 0.14)
                          : const Color(0xFFDC2626).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: vehicle.isImmobilized
                          ? const Color(0xFF10B981)
                          : const Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    vehicle.isImmobilized
                        ? 'Restore Engine Circuit'
                        : 'Emergency Engine Cut',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: vehicle.isImmobilized
                          ? const Color(0xFF047857)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  subtitle: Text(
                    vehicle.isImmobilized
                        ? 'Engine is cut — tap to restore'
                        : 'Disable ignition starter in emergency',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_confirmEngineToggle(context, ref, vehicle));
                  },
                ),

                const Divider(height: 1),

                // Full Screen Map
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fullscreen_rounded,
                        color: scheme.onSurface, size: 22),
                  ),
                  title: const Text(
                    'Full Screen Live Map',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Interactive map with zoom and live tracking',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(context.push('/vehicle-map?focus=${vehicle.id}'));
                  },
                ),

                // Vehicle Settings
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.settings_outlined,
                        color: scheme.onSurface, size: 22),
                  ),
                  title: const Text(
                    'Vehicle Settings',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Speed limits, geofences, and alarms',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(context.push('/vehicle/${vehicle.id}/settings'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
