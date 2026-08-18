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
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: Corners.rXl,
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
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
                        Colors.grey.shade600,
                      ).copyWith(letterSpacing: 2.0),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          '${stats.total}',
                          style: AppTypography.metric(
                            size: 36,
                            color: Colors.grey.shade900,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: Gap.xs),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            stats.total == 1 ? 'vehicle' : 'vehicles',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
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
          const SizedBox(height: Gap.md),
          // Proportional composition bar.
          _CompositionBar(stats: stats),
          const SizedBox(height: Gap.md),
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
          color: Colors.white.withOpacity(0.05),
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
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.moving.withOpacity(0.3 * percent),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percent),
              duration: Motion.slow,
              curve: Motion.emphasized,
              builder: (BuildContext _, double v, Widget? __) =>
                  CircularProgressIndicator(
                value: v,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.grey.shade100,
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
                  size: 18,
                  color: Colors.grey.shade900,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const Text(
                'online',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count vehicles',
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.emphasized,
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : Colors.grey.shade50,
          borderRadius: Corners.rMd,
          border: Border.all(
            color: selected
                ? color.withOpacity(0.4)
                : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: Corners.rMd,
            splashColor: color.withOpacity(0.2),
            highlightColor: color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
              child: Column(
                children: <Widget>[
                  Icon(icon, size: 20, color: selected ? color : color.withOpacity(0.8)),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: AppTypography.metric(
                      size: 20,
                      color: Colors.grey.shade900,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.2,
                      color: selected ? color : Colors.grey.shade600,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
