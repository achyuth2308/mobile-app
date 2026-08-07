import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';

/// The hero panel: total fleet count with a proportional status bar and
/// four tappable status filters underneath.
///
/// Design rationale: an operator's first question is "is anything wrong right
/// now?" — so the composition bar answers it pre-attentively, before any
/// number is read.
class FleetOverviewCard extends ConsumerWidget {
  const FleetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final FleetStats stats = ref.watch(fleetStatsProvider);
    final VehicleStatus? active = ref.watch(fleetFilterProvider);

    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        borderRadius: Corners.rXl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.colorScheme.surfaceContainerHigh,
            theme.colorScheme.surfaceContainer,
          ],
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'TOTAL FLEET',
                      style: AppTypography.eyebrow(
                        theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          '${stats.total}',
                          style: AppTypography.metric(
                            size: 42,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            stats.total == 1 ? 'vehicle' : 'vehicles',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _OnlineRing(percent: stats.onlinePercent, online: stats.online),
            ],
          ),

          const SizedBox(height: Gap.xl),

          // Proportional composition bar.
          _CompositionBar(stats: stats),

          const SizedBox(height: Gap.xl),

          Row(
            children: <Widget>[
              Expanded(
                child: _StatusTile(
                  label: 'Moving',
                  count: stats.moving,
                  color: AppColors.moving,
                  icon: Icons.navigation_rounded,
                  selected: active == VehicleStatus.moving,
                  onTap: () => _toggle(ref, VehicleStatus.moving),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _StatusTile(
                  label: 'Idle',
                  count: stats.idle,
                  color: AppColors.idle,
                  icon: Icons.hourglass_bottom_rounded,
                  selected: active == VehicleStatus.idle,
                  onTap: () => _toggle(ref, VehicleStatus.idle),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _StatusTile(
                  label: 'Stopped',
                  count: stats.stopped,
                  color: AppColors.stopped,
                  icon: Icons.local_parking_rounded,
                  selected: active == VehicleStatus.stopped,
                  onTap: () => _toggle(ref, VehicleStatus.stopped),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: _StatusTile(
                  label: 'Offline',
                  count: stats.offline,
                  color: AppColors.offline,
                  icon: Icons.cloud_off_rounded,
                  selected: active == VehicleStatus.offline,
                  onTap: () => _toggle(ref, VehicleStatus.offline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggle(WidgetRef ref, VehicleStatus status) {
    final StateController<VehicleStatus?> ctrl =
        ref.read(fleetFilterProvider.notifier);
    ctrl.state = ctrl.state == status ? null : status;
  }
}

class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.stats});

  final FleetStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: Corners.rPill,
        ),
      );
    }

    final List<(int, Color)> segments = <(int, Color)>[
      (stats.moving, AppColors.moving),
      (stats.idle, AppColors.idle),
      (stats.stopped, AppColors.stopped),
      (stats.offline, AppColors.offline),
    ].where(((int, Color) s) => s.$1 > 0).toList();

    return ClipRRect(
      borderRadius: Corners.rPill,
      child: SizedBox(
        height: 8,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < segments.length; i++) ...<Widget>[
              Expanded(
                flex: segments[i].$1,
                child: AnimatedContainer(
                  duration: Motion.normal,
                  color: segments[i].$2,
                ),
              ),
              if (i < segments.length - 1) const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _OnlineRing extends StatelessWidget {
  const _OnlineRing({required this.percent, required this.online});

  final double percent;
  final int online;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 74,
            height: 74,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percent),
              duration: Motion.slow,
              curve: Motion.emphasized,
              builder: (BuildContext _, double v, Widget? __) =>
                  CircularProgressIndicator(
                value: v,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.moving),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${(percent * 100).round()}%',
                style: AppTypography.metric(
                  size: 17,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'online',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count vehicles',
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.emphasized,
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.16)
              : theme.colorScheme.surface.withOpacity(0.5),
          borderRadius: Corners.rMd,
          border: Border.all(
            color: selected
                ? color.withOpacity(0.5)
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: Corners.rMd,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: Gap.md, horizontal: 6),
              child: Column(
                children: <Widget>[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(height: 6),
                  Text(
                    '$count',
                    style: AppTypography.metric(
                      size: 19,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      letterSpacing: 0.1,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Attention strip: only rendered when something actually needs action.
class AttentionStrip extends ConsumerWidget {
  const AttentionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FleetStats stats = ref.watch(fleetStatsProvider);

    final List<Widget> items = <Widget>[];

    if (stats.overspeeding > 0) {
      items.add(_AttentionChip(
        icon: Icons.speed_rounded,
        label: '${stats.overspeeding} overspeeding',
        color: AppColors.danger,
        onTap: () => ref.read(fleetSearchProvider.notifier).state = '',
      ));
    }

    if (stats.expiringSoon > 0) {
      items.add(_AttentionChip(
        icon: Icons.event_busy_rounded,
        label: '${stats.expiringSoon} expiring soon',
        color: AppColors.idle,
        onTap: () {},
      ));
    }

    if (stats.totalDistanceToday > 0) {
      items.add(_AttentionChip(
        icon: Icons.route_rounded,
        label: '${Fmt.distance(stats.totalDistanceToday)} today',
        color: AppColors.signal,
        onTap: () {},
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
          itemBuilder: (BuildContext _, int i) => items[i],
        ),
      ),
    );
  }
}

class _AttentionChip extends StatelessWidget {
  const _AttentionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color.withOpacity(0.12),
        borderRadius: Corners.rPill,
        child: InkWell(
          onTap: onTap,
          borderRadius: Corners.rPill,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
}
