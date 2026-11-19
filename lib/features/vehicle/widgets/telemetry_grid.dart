import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';

/// Instrument-cluster telemetry display with clear hierarchy,
/// balanced compact 2x2 primary metrics grid, and a unified diagnostics bar.
class TelemetryGrid extends StatelessWidget {
  const TelemetryGrid({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    final bool hasFuel = vehicle.fuelLevel != null &&
        vehicle.fuelLevel! > 0 &&
        vehicle.fuelLevel! <= 400;

    final String fuelStr = hasFuel
        ? (vehicle.fuelLevel! % 1 == 0
            ? vehicle.fuelLevel!.round().toString()
            : vehicle.fuelLevel!.toStringAsFixed(1))
        : '';

    final String odoStr = vehicle.odometer != null
        ? NumberFormat('#,###').format(vehicle.odometer!.round())
        : '0';

    final Color statusColor = AppColors.forStatus(vehicle.status.key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Eyebrow Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE TELEMETRY',
                style: AppTypography.eyebrow(scheme.onSurfaceVariant),
              ),
              Row(
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
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Balanced Compact 2x2 Primary Telemetry Grid ───────────
        Column(
          children: [
            Row(
              children: [
                if (hasFuel) ...[
                  Expanded(
                    child: _PrimaryCard(
                      icon: Icons.local_gas_station_rounded,
                      label: 'Fuel Level',
                      value: fuelStr,
                      unit: 'L',
                      accentColor: vehicle.fuelLevel! < 15
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF059669),
                      progress: (vehicle.fuelLevel! / 100.0).clamp(0.0, 1.0),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: _PrimaryCard(
                    icon: Icons.speed_rounded,
                    label: 'Current Speed',
                    value: '${vehicle.speed.round()}',
                    unit: 'km/h',
                    accentColor: vehicle.isOverspeeding
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF0284C7),
                    badge: vehicle.isOverspeeding
                        ? 'OVERSPEED'
                        : (vehicle.speedLimit != null
                            ? 'Limit ${vehicle.speedLimit!.round()}'
                            : null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _PrimaryCard(
                    icon: Icons.route_rounded,
                    label: "Today's Distance",
                    value: vehicle.todayDistanceKm != null
                        ? vehicle.todayDistanceKm!.toStringAsFixed(1)
                        : '0.0',
                    unit: 'km',
                    accentColor: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PrimaryCard(
                    icon: Icons.timeline_rounded,
                    label: 'Total Odometer',
                    value: odoStr,
                    unit: 'km',
                    accentColor: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ── Unified Diagnostics Strip ──────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
            borderRadius: BorderRadius.circular(10),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Battery
              Expanded(
                child: _DiagnosticTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Battery',
                  value: vehicle.batteryLevel != null && vehicle.batteryLevel! > 0
                      ? '${vehicle.batteryLevel!.toStringAsFixed(1)} V'
                      : '--',
                  accentColor: vehicle.batteryLevel != null && vehicle.batteryLevel! < 11.5
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFF59E0B),
                ),
              ),
              _VerticalDivider(isDark: isDark),

              // Heading
              Expanded(
                child: _DiagnosticTile(
                  icon: Icons.explore_rounded,
                  label: 'Heading',
                  value: '${Fmt.heading(vehicle.heading)} ${vehicle.heading.round()}°',
                  accentColor: const Color(0xFF0D9488),
                ),
              ),
              _VerticalDivider(isDark: isDark),

              // GPS Satellites
              Expanded(
                child: _DiagnosticTile(
                  icon: Icons.satellite_alt_rounded,
                  label: 'Satellites',
                  value: vehicle.satellites != null ? '${vehicle.satellites}' : '--',
                  accentColor: const Color(0xFF2563EB),
                ),
              ),

              if (vehicle.gsmSignal != null) ...[
                _VerticalDivider(isDark: isDark),
                Expanded(
                  child: _DiagnosticTile(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: 'GSM Signal',
                    value: '${vehicle.gsmSignal}${vehicle.gsmSignal! > 5 ? '%' : '/5'}',
                    accentColor: const Color(0xFFEC4899),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accentColor,
    this.badge,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color accentColor;
  final String? badge;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: accentColor),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
    );
  }
}
