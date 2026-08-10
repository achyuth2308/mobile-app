import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/live_address.dart';
import '../../../shared/widgets/status_chip.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({
    required this.vehicle,
    required this.onTap,
    this.onTrack,
    this.dense = false,
    this.glass = false,
    this.minimal = false,
    super.key,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback? onTrack;
  final bool dense;
  final bool glass;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color statusColor = AppColors.forStatus(vehicle.status.key);

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT COLUMN: Image & Name
                SizedBox(
                  width: 105,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/vehicles/${vehicle.displayType}.png',
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          VehicleIcons.forType(vehicle.displayType),
                          size: 40,
                          color: statusColor.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radio_button_unchecked,
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              vehicle.displayName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF2E3355),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (vehicle.registrationNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            vehicle.registrationNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // RIGHT COLUMN: Metrics
                Expanded(
                  child: Column(
                    children: [
                      _MetricRow(
                        label: 'Last Updated',
                        value: _formatDateTime(vehicle.lastPacketAt),
                        dotColor: const Color(0xFF9C27B0), // Purple
                      ),
                      _MetricRow(
                        label: 'Today km',
                        value: '${vehicle.todayDistanceKm?.toStringAsFixed(0) ?? '0'} km',
                        dotColor: const Color(0xFFE91E63), // Pink
                        trailing: const Icon(Icons.signal_cellular_alt_rounded, size: 16, color: Colors.green),
                      ),
                      _MetricRow(
                        label: 'Speed',
                        value: '${vehicle.speed.round()} km/h',
                        dotColor: const Color(0xFF4CAF50), // Green
                        trailing: SizedBox(
                          width: 20,
                          height: 20,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.gps_not_fixed_rounded, size: 20, color: Colors.grey),
                              Text(
                                '${vehicle.satellites ?? 0}',
                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!minimal) ...[
                        _MetricRow(
                          label: 'Odometer',
                          value: vehicle.odometer != null ? '${vehicle.odometer!.toStringAsFixed(0)} km' : 'N/A',
                          dotColor: Colors.cyan,
                        ),
                        _MetricRow(
                          label: 'Battery',
                          value: vehicle.batteryLevel != null ? '${vehicle.batteryLevel!.toStringAsFixed(0)}%' : 'N/A',
                          dotColor: Colors.orange,
                        ),
                        _MetricRow(
                          label: 'Since',
                          value: vehicle.lastPacketAt != null ? Fmt.relative(vehicle.lastPacketAt!).replaceAll(' ago', '') : '-',
                          dotColor: const Color(0xFF9C27B0), // Purple
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (!minimal) ...[
              const SizedBox(height: 12),
              
              // BOTTOM ROW: Address
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0, right: 6.0),
                    child: Icon(Icons.circle, size: 6, color: Color(0xFFE91E63)), // Pink dot
                  ),
                  Expanded(
                    child: LiveAddress(
                      vehicle: vehicle,
                      max: 9999,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
    );

    if (glass) {
      return Padding(
        padding: EdgeInsets.only(bottom: dense ? Gap.md : Gap.lg),
        child: GlassCard(
          padding: EdgeInsets.all(dense ? Gap.md : Gap.lg),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: dense ? Gap.md : Gap.lg),
      padding: EdgeInsets.all(dense ? Gap.md : Gap.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.night3 : theme.colorScheme.surface,
        borderRadius: Corners.rLg,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.rLg,
        child: content,
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    final String date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final int h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final String min = dt.minute.toString().padLeft(2, '0');
    final String sec = dt.second.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$date\n${h.toString().padLeft(2, '0')}:$min:$sec $ampm';
  }

  IconData _batteryIcon(double level) {
    if (level >= 80) return Icons.battery_full_rounded;
    if (level >= 50) return Icons.battery_5_bar_rounded;
    if (level >= 20) return Icons.battery_3_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.dotColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color dotColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, 
                fontSize: 11,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, right: 6.0),
            child: Icon(Icons.circle, size: 6, color: dotColor),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (trailing != null)
            SizedBox(
              width: 24,
              child: Align(
                alignment: Alignment.topRight,
                child: trailing!,
              ),
            ),
        ],
      ),
    );
  }
}
