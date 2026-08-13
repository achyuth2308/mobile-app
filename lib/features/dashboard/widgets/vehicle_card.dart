import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/live_address.dart';

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

    final Widget content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN: Image & Name
              SizedBox(
                width: 90,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/vehicles/${vehicle.displayType}.png',
                      height: 60,
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
                          Icons.circle,
                          size: 10,
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
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        vehicle.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF5E657D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // RIGHT COLUMN: Metrics Grid
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row (Last Update & Button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Last update • ${_formatDateTimeShort(vehicle.lastPacketAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            color: theme.colorScheme.primary,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: onTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Metrics Grid (3x2)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Col 1
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetricItem(
                                label: 'Today km',
                                value: '${vehicle.todayDistanceKm?.toStringAsFixed(0) ?? '0'} km',
                                dotColor: const Color(0xFFE91E63), // Pink
                              ),
                              const SizedBox(height: 12),
                              _MetricItem(
                                label: 'Battery',
                                value: vehicle.batteryLevel != null ? '${vehicle.batteryLevel!.toStringAsFixed(2)} V' : 'N/A',
                                dotColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        // Col 2
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetricItem(
                                label: 'Speed',
                                value: '${vehicle.speed.round()} km/h',
                                dotColor: const Color(0xFF4CAF50), // Green
                              ),
                              const SizedBox(height: 12),
                              _MetricItem(
                                label: 'Since',
                                value: vehicle.lastPacketAt != null ? Fmt.relative(vehicle.lastPacketAt!).replaceAll(' ago', '') : '-',
                                dotColor: const Color(0xFF9C27B0), // Purple
                              ),
                            ],
                          ),
                        ),
                        // Col 3
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _MetricItem(
                                label: 'Odometer',
                                value: vehicle.odometer != null ? '${vehicle.odometer!.toStringAsFixed(0)} km' : 'N/A',
                                dotColor: Colors.cyan,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Icon(Icons.signal_cellular_alt_rounded, size: 16, color: Colors.green),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(Icons.gps_not_fixed_rounded, size: 20, color: Colors.grey),
                                      Text(
                                        '${vehicle.satellites ?? 0}',
                                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!minimal) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            const SizedBox(height: 12),

            // BOTTOM ROW: Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20, color: Color(0xFFE91E63)),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.navigation_rounded, color: theme.colorScheme.primary, size: 20),
                    onPressed: onTrack,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (glass) {
      return Padding(
        padding: EdgeInsets.only(bottom: dense ? Gap.md : Gap.lg),
        child: GlassCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: content,
        ),
      );
    }

    final Color borderColor = switch (vehicle.status.key.toLowerCase()) {
      'offline' => AppColors.danger,
      'moving' || 'running' || 'online' => AppColors.moving,
      'idle' || 'idling' => AppColors.idle,
      'stopped' || 'parked' => AppColors.stopped,
      _ => AppColors.offline,
    };

    return Container(
      margin: EdgeInsets.only(bottom: dense ? Gap.md : Gap.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.night3 : Colors.white,
        borderRadius: Corners.rLg,
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
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

  String _formatDateTimeShort(DateTime? dt) {
    if (dt == null) return 'N/A';
    final String date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final int h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final String min = dt.minute.toString().padLeft(2, '0');
    final String sec = dt.second.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$date  ${h.toString().padLeft(2, '0')}:$min:$sec $ampm';
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  final String label;
  final String value;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: dotColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade200 : const Color(0xFF2E3355),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
