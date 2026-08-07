import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../../../shared/widgets/status_chip.dart';

/// Compact live card shown when a marker is tapped.
///
/// It watches the vehicle provider directly, so the speed and address keep
/// updating in place while the sheet is open — no stale snapshot.
class VehiclePeekSheet extends ConsumerWidget {
  const VehiclePeekSheet({
    required this.vehicleId,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onOpenDetails,
    super.key,
  });

  final String vehicleId;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(vehicleId));
    final ThemeData theme = Theme.of(context);

    if (vehicle == null) return const SizedBox.shrink();

    final Color statusColor = AppColors.forStatus(vehicle.status.key);
    final bool alerting = vehicle.isOverspeeding &&
        vehicle.status != VehicleStatus.offline;

    final Color borderColor;
    final double borderWidth;
    if (alerting) {
      borderColor = AppColors.danger.withOpacity(0.75);
      borderWidth = 1.4;
    } else {
      switch (vehicle.status) {
        case VehicleStatus.moving:
          borderColor = AppColors.moving.withOpacity(0.65);
          borderWidth = 1.3;
        case VehicleStatus.idle:
          borderColor = AppColors.idle.withOpacity(0.65);
          borderWidth = 1.3;
        case VehicleStatus.stopped:
          borderColor = AppColors.stopped.withOpacity(0.55);
          borderWidth = 1.2;
        case VehicleStatus.offline:
          borderColor = theme.colorScheme.outlineVariant;
          borderWidth = 1.0;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        0,
        Gap.md,
        MediaQuery.paddingOf(context).bottom + Gap.navClearance - 40,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: Corners.rXl,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            if (alerting)
              BoxShadow(
                color: AppColors.danger.withOpacity(0.20),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            else if (vehicle.status == VehicleStatus.moving)
              BoxShadow(
                color: AppColors.moving.withOpacity(0.14),
                blurRadius: 12,
                offset: const Offset(0, 3),
              )
            else if (vehicle.status == VehicleStatus.idle)
              BoxShadow(
                color: AppColors.idle.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 3),
              )
            else if (vehicle.status == VehicleStatus.stopped)
              BoxShadow(
                color: AppColors.stopped.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: Corners.rSm,
                  ),
                  child: Icon(
                    VehicleIcons.forType(vehicle.type),
                    color: statusColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        vehicle.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        Fmt.relative(vehicle.lastPacketAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(status: vehicle.status, compact: true),
              ],
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: vehicle.status == VehicleStatus.stopped
                  ? Padding(
                      padding: const EdgeInsets.only(top: Gap.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs + 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: Corners.rSm,
                          border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.pause_circle_filled_rounded, size: 14, color: AppColors.danger),
                            const SizedBox(width: Gap.sm),
                            Text(
                              'Stopped since ${Fmt.time(vehicle.lastPacketAt)} (${Fmt.relative(vehicle.lastPacketAt)})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: Gap.lg),

            Row(
              children: <Widget>[
                _PeekMetric(
                  label: 'Speed',
                  value: '${vehicle.speed.round()}',
                  unit: 'km/h',
                  color: vehicle.isOverspeeding ? AppColors.danger : null,
                ),
                _divider(theme),
                _PeekMetric(
                  label: 'Heading',
                  value: Fmt.heading(vehicle.heading),
                  unit: '${vehicle.heading.round()}°',
                ),
                _divider(theme),
                _PeekMetric(
                  label: 'Ignition',
                  value: vehicle.ignition ? 'ON' : 'OFF',
                  unit: '',
                  color: vehicle.ignition ? AppColors.moving : null,
                ),
              ],
            ),

            const SizedBox(height: Gap.lg),

            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.5),
                borderRadius: Corners.rSm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.place_outlined,
                      size: 15, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      Fmt.address(vehicle.address, max: 90),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Gap.lg),

            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onToggleFollow();
                    },
                    icon: Icon(
                      isFollowing
                          ? Icons.gps_off_rounded
                          : Icons.gps_fixed_rounded,
                      size: 18,
                    ),
                    label: Text(isFollowing ? 'Unfollow' : 'Follow'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                IconButton.filledTonal(
                  tooltip: 'Open in Google Maps',
                  onPressed: vehicle.hasLocation
                      ? () {
                          HapticFeedback.selectionClick();
                          _openExternalMaps(vehicle);
                        }
                      : null,
                  icon: const Icon(Icons.directions_rounded, size: 20),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onOpenDetails();
                    },
                    icon: const Icon(Icons.open_in_full_rounded, size: 17),
                    label: const Text('Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: Gap.md),
        color: theme.colorScheme.outlineVariant,
      );

  Future<void> _openExternalMaps(Vehicle v) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${v.latitude},${v.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PeekMetric extends StatelessWidget {
  const _PeekMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant)
                .copyWith(fontSize: 9.5),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metric(
                    size: 18,
                    color: color ?? theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...<Widget>[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
