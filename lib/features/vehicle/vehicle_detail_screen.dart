import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/vehicle_icons.dart';
import '../../data/models/vehicle.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/status_chip.dart';
import 'tabs/vehicle_info_tab.dart';
import 'tabs/vehicle_live_tab.dart';
import 'tabs/vehicle_playback_tab.dart';

/// Three-tab vehicle workspace: Live, History (playback), Info.
///
/// On mount it joins `vehicle:{id}` for a higher-frequency stream, and on
/// dispose it leaves the room again — an important server-load and battery
/// consideration when a customer opens many vehicles in a session.
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socketServiceProvider).joinVehicle(widget.vehicleId);
      ref.read(secureStoreProvider).setLastVehicleId(widget.vehicleId);
    });
  }

  @override
  void dispose() {
    // Leave the room so the server stops streaming this vehicle to us.
    ref.read(socketServiceProvider).leaveVehicle(widget.vehicleId);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicle == null) {
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

    final Color statusColor = AppColors.forStatus(vehicle.status.key);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool _) => <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 148,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Live zoomed tracking',
                icon: const Icon(Icons.gps_fixed_rounded),
                onPressed: vehicle.hasLocation
                    ? () => context.go('/map?focus=${vehicle.id}')
                    : null,
              ),
              const SizedBox(width: Gap.xs),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DetailHeader(vehicle: vehicle, color: statusColor),
            ),
            bottom: TabBar(
              controller: _tabs,
              tabs: const <Widget>[
                Tab(text: 'Live'),
                Tab(text: 'History'),
                Tab(text: 'Info'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: <Widget>[
            VehicleLiveTab(vehicleId: widget.vehicleId),
            VehiclePlaybackTab(vehicleId: widget.vehicleId),
            VehicleInfoTab(vehicleId: widget.vehicleId),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.vehicle, required this.color});

  final Vehicle vehicle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withOpacity(0.16),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.x3l, Gap.lg, 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: Corners.rSm,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(VehicleIcons.forType(vehicle.type),
                    color: color, size: 23),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      vehicle.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        StatusChip(status: vehicle.status, compact: true),
                        const SizedBox(width: Gap.sm),
                        Flexible(
                          child: Text(
                            Fmt.relative(vehicle.lastPacketAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 0,
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
        ),
      ),
    );
  }
}
