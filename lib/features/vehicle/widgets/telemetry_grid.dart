import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';


/// Instrument-cluster grid of every live signal the tracker reports.
class TelemetryGrid extends StatelessWidget {
  const TelemetryGrid({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<_Cell> cells = <_Cell>[
      _Cell(
        icon: Icons.speed_rounded,
        label: 'Speed',
        value: '${vehicle.speed.round()}',
        unit: 'km/h',
        color: vehicle.isOverspeeding ? AppColors.danger : null,
        subtitle: vehicle.speedLimit != null
            ? 'Limit ${vehicle.speedLimit!.round()}'
            : null,
      ),
      _Cell(
        icon: vehicle.ignition
            ? Icons.power_settings_new_rounded
            : Icons.power_off_rounded,
        label: 'Ignition',
        value: vehicle.ignition ? 'ON' : 'OFF',
        color: vehicle.ignition ? AppColors.moving : AppColors.offline,
      ),
      _Cell(
        icon: Icons.explore_rounded,
        label: 'Heading',
        value: Fmt.heading(vehicle.heading),
        unit: '${vehicle.heading.round()}°',
      ),
      if (vehicle.odometer != null)
        _Cell(
          icon: Icons.timeline_rounded,
          label: 'Odometer',
          value: vehicle.odometer!.toStringAsFixed(0),
          unit: 'km',
        ),
      if (vehicle.todayDistanceKm != null)
        _Cell(
          icon: Icons.route_rounded,
          label: 'Today',
          value: vehicle.todayDistanceKm!.toStringAsFixed(1),
          unit: 'km',
        ),
      if (vehicle.fuelLevel != null)
        _Cell(
          icon: Icons.local_gas_station_rounded,
          label: 'Fuel',
          value: vehicle.fuelLevel!.round().toString(),
          unit: vehicle.fuelLevel! > 100 ? 'L' : '%',
          color: vehicle.fuelLevel! < 15 ? AppColors.danger : null,
        ),
      if (vehicle.batteryLevel != null && vehicle.batteryLevel! > 0)
        _Cell(
          icon: Icons.battery_charging_full_rounded,
          label: 'Battery',
          value: vehicle.batteryLevel!.toStringAsFixed(2),
          unit: 'V',
          color: vehicle.batteryLevel! < 11.5 ? AppColors.danger : null,
        ),
      if (vehicle.gsmSignal != null)
        _Cell(
          icon: Icons.signal_cellular_alt_rounded,
          label: 'GSM',
          value: '${vehicle.gsmSignal}',
          unit: vehicle.gsmSignal! > 5 ? '%' : '/5',
          color: vehicle.gsmSignal! <= (vehicle.gsmSignal! > 5 ? 20 : 1) ? AppColors.idle : null,
        ),
      if (vehicle.satellites != null)
        _Cell(
          icon: Icons.satellite_alt_rounded,
          label: 'Satellites',
          value: '${vehicle.satellites}',
          color: vehicle.satellites! < 4 ? AppColors.idle : null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Gap.md),
          child: Text(
            'LIVE TELEMETRY',
            style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 110,
            mainAxisSpacing: Gap.sm,
            crossAxisSpacing: Gap.sm,
            childAspectRatio: 0.98,
          ),
          itemBuilder: (BuildContext context, int i) =>
              _TelemetryCell(cell: cells[i]),
        ),
      ],
    );
  }
}

class _Cell {
  const _Cell({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final String? subtitle;
}

class _TelemetryCell extends StatelessWidget {
  const _TelemetryCell({required this.cell});

  final _Cell cell;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = cell.color ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: Corners.rLg,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Icon(
            cell.icon,
            size: 17,
            color: cell.color ?? theme.colorScheme.onSurfaceVariant,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      cell.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metric(size: 24, color: accent)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (cell.unit != null) ...<Widget>[
                    const SizedBox(width: 2),
                    Text(
                      cell.unit!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                cell.subtitle ?? cell.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 0.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
