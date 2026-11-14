import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/live_address.dart';
import '../../../providers/core_providers.dart';
import '../../../data/repositories/vehicle_repository.dart';

class VehicleCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color statusColor = AppColors.forStatus(vehicle.status.key);
    final bool use2Columns = MediaQuery.sizeOf(context).width < 365;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN: Image & Name
              SizedBox(
                width: 86,
                child: Column(
                  children: [
                    Image.asset(
                      vehicle.statusAssetPath,
                      height: 46,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/vehicles/${vehicle.displayType}.png',
                        height: 46,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          VehicleIcons.forType(vehicle.displayType),
                          size: 36,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        Flexible(
                          child: Text(
                            vehicle.displayName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Color.lerp(statusColor, Colors.white, 0.4)
                                  : (statusColor == AppColors.idle
                                      ? const Color(0xFFB45309)
                                      : statusColor),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.20 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.45 : 0.28,
                          ),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        vehicle.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isDark
                              ? Color.lerp(statusColor, Colors.white, 0.25)
                              : (statusColor == AppColors.idle
                                  ? const Color(0xFFB45309)
                                  : statusColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

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
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500,
                            ),
                            maxLines: 2,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right_rounded,
                                size: 18),
                            color: theme.colorScheme.primary,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            onPressed: onTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Metrics Grid (3x2 or 2x3 depending on screen size)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: use2Columns
                          ? [
                              // Responsive Column 1 (Speed, Today km, Battery)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _MetricItem(
                                      label: 'Speed',
                                      value: '${vehicle.speed.round()} km/h',
                                      dotColor:
                                          const Color(0xFF4CAF50), // Green
                                    ),
                                    const SizedBox(height: 6),
                                    _MetricItem(
                                      label: 'Today km',
                                      value:
                                          '${vehicle.todayDistanceKm?.toStringAsFixed(0) ?? '0'} km',
                                      dotColor: const Color(0xFFE91E63), // Pink
                                    ),
                                    const SizedBox(height: 6),
                                    _MetricItem(
                                      label: 'Battery',
                                      value: (vehicle.batteryLevel != null &&
                                              vehicle.batteryLevel! > 0)
                                          ? '${vehicle.batteryLevel!.toStringAsFixed(2)} V'
                                          : 'N/A',
                                      dotColor: Colors.orange,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Responsive Column 2 (Odometer & Signal/GPS)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _MetricItem(
                                      label: 'Odometer',
                                      value: vehicle.odometer != null
                                          ? '${vehicle.odometer!.toStringAsFixed(0)} km'
                                          : 'N/A',
                                      dotColor: Colors.cyan,
                                    ),
                                    if (vehicle.hasFuel) ...[
                                      const SizedBox(height: 6),
                                      _MetricItem(
                                        icon: Icons.local_gas_station_rounded,
                                        label: 'Fuel',
                                        value:
                                            '${vehicle.fuelLevel! % 1 == 0 ? vehicle.fuelLevel!.toStringAsFixed(0) : vehicle.fuelLevel!.toStringAsFixed(1)} L',
                                        dotColor: const Color(0xFFF97316),
                                        onTap: () => context.push('/vehicle/${vehicle.id}/fuel-analytics'),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.signal_cellular_alt_rounded,
                                            size: 16,
                                            color: Colors.green),
                                        if (vehicle.satellites != null)
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(
                                                  Icons.gps_not_fixed_rounded,
                                                  size: 20,
                                                  color: Colors.grey),
                                              Text(
                                                  '${vehicle.satellites}',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : [
                              // Standard Column 1 (Speed & Battery)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _MetricItem(
                                      label: 'Speed',
                                      value: '${vehicle.speed.round()} km/h',
                                      dotColor:
                                          const Color(0xFF4CAF50), // Green
                                    ),
                                    const SizedBox(height: 6),
                                    _MetricItem(
                                      label: 'Battery',
                                      value: (vehicle.batteryLevel != null &&
                                              vehicle.batteryLevel! > 0)
                                          ? '${vehicle.batteryLevel!.toStringAsFixed(2)} V'
                                          : 'N/A',
                                      dotColor: Colors.orange,
                                    ),
                                  ],
                                ),
                              ),
                              // Standard Column 2 (Today km & Fuel)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _MetricItem(
                                      label: 'Today km',
                                      value:
                                          '${vehicle.todayDistanceKm?.toStringAsFixed(0) ?? '0'} km',
                                      dotColor: const Color(0xFFE91E63), // Pink
                                    ),
                                    if (vehicle.hasFuel) ...[
                                      const SizedBox(height: 6),
                                      _MetricItem(
                                        icon: Icons.local_gas_station_rounded,
                                        label: 'Fuel',
                                        value:
                                            '${vehicle.fuelLevel! % 1 == 0 ? vehicle.fuelLevel!.toStringAsFixed(0) : vehicle.fuelLevel!.toStringAsFixed(1)} L',
                                        dotColor: const Color(0xFFF97316),
                                        onTap: () => context.push('/vehicle/${vehicle.id}/fuel-analytics'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Standard Column 3 (Odometer & Signal/GPS)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _MetricItem(
                                      label: 'Odometer',
                                      value: vehicle.odometer != null
                                          ? '${vehicle.odometer!.toStringAsFixed(0)} km'
                                          : 'N/A',
                                      dotColor: Colors.cyan,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.signal_cellular_alt_rounded,
                                            size: 16,
                                            color: Colors.green),
                                        if (vehicle.satellites != null)
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(
                                                  Icons.gps_not_fixed_rounded,
                                                  size: 20,
                                                  color: Colors.grey),
                                              Text(
                                                '${vehicle.satellites}',
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
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
            const SizedBox(height: 5),
            _LiveStatusStrip(vehicle: vehicle),
            const SizedBox(height: 4),
            Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            const SizedBox(height: 5),

            // BOTTOM ROW: Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.location_on,
                      size: 16, color: Color(0xFFE91E63)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LiveAddress(
                    vehicle: vehicle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.info_outline_rounded,
                        color: theme.colorScheme.primary, size: 17),
                    onPressed: onTrack,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    void showDebugDialog() async {
      // Show loading indicator dialog
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) =>
              const Center(child: CircularProgressIndicator()),
        ),
      );

      try {
        final VehicleRepository vehicleRepo =
            ref.read(vehicleRepositoryProvider);
        final Vehicle detailedVehicle =
            await vehicleRepo.getVehicle(vehicle.id);
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog

        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text('${vehicle.name} Detailed Raw JSON'),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: SingleChildScrollView(
                child: SelectableText(
                  const JsonEncoder.withIndent("  ").convert(detailedVehicle.raw),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load detailed vehicle data: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }

    if (glass) {
      return Padding(
        padding: EdgeInsets.only(bottom: dense ? Gap.md : Gap.lg),
        child: GestureDetector(
          onLongPress: showDebugDialog,
          child: GlassCard(
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: content,
          ),
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
      margin: EdgeInsets.only(bottom: dense ? Gap.xs : Gap.sm),
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
          if (borderColor != Colors.transparent)
            BoxShadow(
              color: borderColor.withOpacity(isDark ? 0.4 : 0.35),
              blurRadius: 14,
              spreadRadius: 1.5,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: showDebugDialog,
        borderRadius: Corners.rLg,
        child: content,
      ),
    );
  }

  String _formatDateTimeShort(DateTime? dt) {
    if (dt == null) return 'N/A';
    final String date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final int h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final String min = dt.minute.toString().padLeft(2, '0');
    final String sec = dt.second.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$date  ${h.toString().padLeft(2, '0')}:$min:$sec $ampm';
  }
}

class _LiveStatusStrip extends StatefulWidget {
  const _LiveStatusStrip({required this.vehicle});
  final Vehicle vehicle;

  @override
  State<_LiveStatusStrip> createState() => _LiveStatusStripState();
}

class _LiveStatusStripState extends State<_LiveStatusStrip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _LiveStatusStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.status != widget.vehicle.status ||
        oldWidget.vehicle.statusChangedAt != widget.vehicle.statusChangedAt ||
        oldWidget.vehicle.lastPacketAt != widget.vehicle.lastPacketAt) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    final DateTime? ts =
        widget.vehicle.statusChangedAt ?? widget.vehicle.lastPacketAt;
    if (ts == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Vehicle v = widget.vehicle;
    final DateTime? since = v.statusChangedAt ?? v.lastPacketAt;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    Color bg;
    Color border;
    IconData icon;
    String statusTitle;

    switch (v.status) {
      case VehicleStatus.moving:
        color = const Color(0xFF16A34A);
        bg = isDark
            ? const Color(0xFF052E16).withValues(alpha: 0.6)
            : const Color(0xFFF0FDF4);
        border = isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0);
        icon = Icons.navigation_rounded;
        statusTitle = 'Moving';
      case VehicleStatus.idle:
        color = const Color(0xFFD97706);
        bg = isDark
            ? const Color(0xFF451A03).withValues(alpha: 0.6)
            : const Color(0xFFFFFBEB);
        border = isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
        icon = Icons.key_rounded;
        statusTitle = 'Idle';
      case VehicleStatus.stopped:
        color = const Color(0xFF475569);
        bg = isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
            : const Color(0xFFF8FAFC);
        border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        icon = Icons.local_parking_rounded;
        statusTitle = 'Stopped';
      case VehicleStatus.offline:
        color = const Color(0xFFDC2626);
        bg = isDark
            ? const Color(0xFF450A0A).withValues(alpha: 0.6)
            : const Color(0xFFFEF2F2);
        border = isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
        icon = Icons.cloud_off_rounded;
        statusTitle = 'No Data';
      case VehicleStatus.noData:
        color = const Color(0xFF64748B);
        bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
        border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        icon = Icons.sensors_off_rounded;
        statusTitle = 'Unreachable';
    }

    if (v.status == VehicleStatus.noData || since == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              statusTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    final String dateStr =
        '${since.day.toString().padLeft(2, '0')}/${since.month.toString().padLeft(2, '0')}/${since.year}';
    final String timeStr = Fmt.time12Sec(since);
    final String durStr = Fmt.statusDuration(since);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                ),
                children: [
                  TextSpan(
                    text: '$statusTitle $dateStr $timeStr',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' ($durStr)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.dotColor,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color dotColor;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Icon(icon, size: 12, color: dotColor)
            else
              Icon(Icons.circle, size: 8, color: dotColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: isDark
                      ? Colors.grey.shade200
                      : const Color(0xFF2E3355),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Padding(
          padding: EdgeInsets.only(left: icon != null ? 15 : 12),
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }
    return content;
  }
}
