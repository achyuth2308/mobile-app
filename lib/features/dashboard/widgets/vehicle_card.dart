import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../shared/widgets/live_address.dart';
import '../../../shared/widgets/status_chip.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.vehicle,
    required this.onTap,
    this.onTrack,
    this.dense = false,
    super.key,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback? onTrack;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color statusColor = AppColors.forStatus(vehicle.status.key);
    final bool alerting =
        vehicle.isOverspeeding && vehicle.status != VehicleStatus.offline;

    return Container(
      margin: EdgeInsets.only(bottom: dense ? Gap.md : Gap.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.night3 : theme.colorScheme.surfaceContainerHigh,
        borderRadius: Corners.rLg,
        border: Border.all(
          color: alerting ? AppColors.danger : statusColor.withOpacity(0.7),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.7 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: alerting 
                ? AppColors.danger.withOpacity(isDark ? 0.4 : 0.2) 
                : statusColor.withOpacity(isDark ? 0.25 : 0.1),
            blurRadius: 40,
            spreadRadius: isDark ? 2 : 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: Corners.rLg,
          gradient: isDark ? AppColors.glassSheen : null,
          border: isDark ? Border.all(
            color: Colors.white.withOpacity(0.08), 
            width: 0.5,
          ) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: Corners.rLg,
          child: InkWell(
          onTap: onTap,
          borderRadius: Corners.rLg,
          child: Padding(
            padding: EdgeInsets.all(dense ? Gap.md : Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Status-tinted vehicle glyph.
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.13),
                        borderRadius: Corners.rSm,
                        border:
                            Border.all(color: statusColor.withOpacity(0.25)),
                      ),
                      child: Icon(
                        VehicleIcons.forType(vehicle.type),
                        size: 22,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: Gap.md),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  vehicle.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (alerting) ...<Widget>[
                                const SizedBox(width: Gap.sm),
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: AppColors.danger,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vehicle.secondaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: Gap.sm),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        StatusChip(status: vehicle.status, compact: true),
                        const SizedBox(height: 6),
                        Text(
                          Fmt.relative(vehicle.lastPacketAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            letterSpacing: 0,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: Gap.md),

                // Address line.
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: LiveAddress(
                        vehicle: vehicle,
                        max: 52,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: Gap.md),

                // Telemetry strip.
                Row(
                  children: <Widget>[
                    _Metric(
                      value: '${vehicle.speed.round()}',
                      unit: 'km/h',
                      color: vehicle.isOverspeeding
                          ? AppColors.danger
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: Gap.lg),
                    if (vehicle.odometer != null)
                      _Metric(
                        value: vehicle.odometer!.toStringAsFixed(0),
                        unit: 'km',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    const Spacer(),
                    InfoPill(
                      icon: vehicle.ignition
                          ? Icons.power_settings_new_rounded
                          : Icons.power_off_rounded,
                      label: vehicle.ignition ? 'ON' : 'OFF',
                      color: vehicle.ignition
                          ? AppColors.moving
                          : theme.colorScheme.onSurfaceVariant,
                      background: vehicle.ignition
                          ? AppColors.moving.withOpacity(0.12)
                          : null,
                    ),
                    if (vehicle.batteryLevel != null) ...<Widget>[
                      const SizedBox(width: 6),
                      InfoPill(
                        icon: _batteryIcon(vehicle.batteryLevel!),
                        label: '${vehicle.batteryLevel!.round()}%',
                        color: vehicle.batteryLevel! < 20
                            ? AppColors.danger
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                    if (onTrack != null) ...<Widget>[
                      const SizedBox(width: 6),
                      _TrackButton(onTap: onTrack!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  IconData _batteryIcon(double level) {
    if (level >= 80) return Icons.battery_full_rounded;
    if (level >= 50) return Icons.battery_5_bar_rounded;
    if (level >= 20) return Icons.battery_3_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.unit, required this.color});

  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(value, style: AppTypography.metric(size: 17, color: color)),
          const SizedBox(width: 2),
          Text(
            unit,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Track on map',
      child: Material(
        color: scheme.primary.withOpacity(0.14),
        borderRadius: Corners.rXs,
        child: InkWell(
          onTap: onTap,
          borderRadius: Corners.rXs,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.near_me_rounded, size: 15, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
