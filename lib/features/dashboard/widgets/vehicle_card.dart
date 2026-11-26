import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/vehicle_icons.dart';
import '../../../data/models/vehicle.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/live_address.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';
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

    final String cleanName = () {
      final String raw = vehicle.displayName.trim();
      if (raw.contains('_')) {
        return raw.replaceFirst('_', '\n').replaceAll('_', ' ').toUpperCase();
      }
      final List<String> parts = raw.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first}\n${parts.sublist(1).join(' ')}'.toUpperCase();
      }
      return raw.toUpperCase();
    }();

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
                width: 102,
                child: Column(
                  children: [
                    Image.asset(
                      vehicle.statusAssetPath,
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/vehicles/${vehicle.displayType}.png',
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          VehicleIcons.forType(vehicle.displayType),
                          size: 34,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () => _showEditVehicleDialog(
                        context,
                        ref,
                        vehicle,
                        focusOdometer: false,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                cleanName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: 0.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
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
                      child: Row(
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
                            vehicle.effectiveStatusLabel,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

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
                            'Last update \u2022 ${_formatDateTimeShort(vehicle.lastPacketAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF0F172A),
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
                                      labelColor: const Color(0xFFF43F5E), // Sharp Rose
                                      valueColor: const Color(0xFFEC4899), // Primary Pink
                                      icon: Icons.speed_rounded,
                                    ),
                                    const SizedBox(height: 6),
                                    _MetricItem(
                                      label: 'Today km',
                                      value:
                                          '${vehicle.todayDistanceKm?.toStringAsFixed(0) ?? '0'} km',
                                      labelColor: const Color(0xFFEA580C), // Sharp Orange
                                      valueColor: const Color(0xFFD95D0B), // Burnt Orange
                                      icon: Icons.near_me_rounded,
                                    ),
                                    const SizedBox(height: 6),
                                    _MetricItem(
                                      label: 'Battery',
                                      value: (vehicle.batteryLevel != null &&
                                              vehicle.batteryLevel! > 0)
                                          ? '${vehicle.batteryLevel!.toStringAsFixed(2)} V'
                                          : 'N/A',
                                      labelColor: const Color(0xFF8B5CF6), // Sharp Violet/Lilac
                                      valueColor: const Color(0xFF421477), // Dark Purple
                                      icon: Icons.battery_charging_full_rounded,
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
                                      labelColor: const Color(0xFF059669), // Sharp Emerald Green
                                      valueColor: const Color(0xFF10B981), // Emerald
                                      icon: Icons.alt_route_rounded,
                                      onTap: () => _showEditVehicleDialog(
                                        context,
                                        ref,
                                        vehicle,
                                        focusOdometer: true,
                                      ),
                                    ),
                                    if (vehicle.hasFuel || vehicle.isNonSensorFuel) ...[
                                       const SizedBox(height: 6),
                                       _MetricItem(
                                         icon: Icons.local_gas_station_rounded,
                                         label: vehicle.isNonSensorFuel ? 'NS Fuel' : 'Fuel',
                                         value: vehicle.fuelLevel != null
                                             ? '${vehicle.fuelLevel! % 1 == 0 ? vehicle.fuelLevel!.toStringAsFixed(0) : vehicle.fuelLevel!.toStringAsFixed(1)} L'
                                             : '0 L',
                                         labelColor: const Color(0xFF0284C7),
                                         valueColor: const Color(0xFF1D4ED8),
                                         onTap: () => context.push('/vehicle/${vehicle.id}'),
                                       ),
                                       if (vehicle.isNonSensorFuel) ...[
                                         const SizedBox(height: 6),
                                         _MetricItem(
                                           icon: Icons.water_drop_rounded,
                                           label: 'Fuel Used',
                                           value: vehicle.effectiveFuelUsed != null
                                               ? '${vehicle.effectiveFuelUsed! % 1 == 0 ? vehicle.effectiveFuelUsed!.toStringAsFixed(0) : vehicle.effectiveFuelUsed!.toStringAsFixed(1)} L'
                                               : '0 L',
                                           labelColor: const Color(0xFFD97706),
                                           valueColor: const Color(0xFFB45309),
                                           onTap: () => context.push('/vehicle/${vehicle.id}'),
                                         ),
                                       ],
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
                                      labelColor: const Color(0xFFF43F5E), // Sharp Rose
                                      valueColor: const Color(0xFFEC4899), // Primary Pink
                                      icon: Icons.speed_rounded,
                                    ),
                                    const SizedBox(height: 6),
                                    _MetricItem(
                                      label: 'Battery',
                                      value: (vehicle.batteryLevel != null &&
                                              vehicle.batteryLevel! > 0)
                                          ? '${vehicle.batteryLevel!.toStringAsFixed(2)} V'
                                          : 'N/A',
                                      labelColor: const Color(0xFF8B5CF6), // Sharp Violet/Lilac
                                      valueColor: const Color(0xFF421477), // Dark Purple
                                      icon: Icons.battery_charging_full_rounded,
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
                                      labelColor: const Color(0xFFEA580C), // Sharp Orange
                                      valueColor: const Color(0xFFD95D0B), // Burnt Orange
                                      icon: Icons.near_me_rounded,
                                    ),
                                    if (vehicle.hasFuel || vehicle.isNonSensorFuel) ...[
                                       const SizedBox(height: 6),
                                       _MetricItem(
                                         icon: Icons.local_gas_station_rounded,
                                         label: vehicle.isNonSensorFuel ? 'NS Fuel' : 'Fuel',
                                         value: vehicle.fuelLevel != null
                                             ? '${vehicle.fuelLevel! % 1 == 0 ? vehicle.fuelLevel!.toStringAsFixed(0) : vehicle.fuelLevel!.toStringAsFixed(1)} L'
                                             : '0 L',
                                         labelColor: const Color(0xFF0284C7),
                                         valueColor: const Color(0xFF1D4ED8),
                                         onTap: () => context.push('/vehicle/${vehicle.id}'),
                                       ),
                                       if (vehicle.isNonSensorFuel) ...[
                                         const SizedBox(height: 6),
                                         _MetricItem(
                                           icon: Icons.water_drop_rounded,
                                           label: 'Fuel Used',
                                           value: vehicle.effectiveFuelUsed != null
                                               ? '${vehicle.effectiveFuelUsed! % 1 == 0 ? vehicle.effectiveFuelUsed!.toStringAsFixed(0) : vehicle.effectiveFuelUsed!.toStringAsFixed(1)} L'
                                               : '0 L',
                                           labelColor: const Color(0xFFD97706),
                                           valueColor: const Color(0xFFB45309),
                                           onTap: () => context.push('/vehicle/${vehicle.id}'),
                                         ),
                                       ],
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
                                      labelColor: const Color(0xFF059669), // Sharp Emerald Green
                                      valueColor: const Color(0xFF10B981), // Emerald
                                      icon: Icons.alt_route_rounded,
                                      onTap: () => _showEditVehicleDialog(
                                        context,
                                        ref,
                                        vehicle,
                                        focusOdometer: true,
                                      ),
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
                  padding: EdgeInsets.only(top: 2),
                  child: _ColorfulLocationPin(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: LiveAddress(
                    vehicle: vehicle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                      height: 1.25,
                    ),
                  ),
                ),
                if (onTrack != null) ...[
                  const SizedBox(width: 8),
                  _JumpingGoogleMapPinButton(onTap: onTrack!),
                ],
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
        color = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);
        bg = isDark
            ? const Color(0xFF18181B).withValues(alpha: 0.8)
            : const Color(0xFFF4F4F5);
        border = isDark ? const Color(0xFF27272A) : const Color(0xFFD4D4D8);
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
        color = const Color(0xFF7C3AED);
        bg = isDark
            ? const Color(0xFF2E1065).withValues(alpha: 0.6)
            : const Color(0xFFF5F3FF);
        border = isDark ? const Color(0xFF5B21B6) : const Color(0xFFDDD6FE);
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
                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
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
    required this.labelColor,
    required this.valueColor,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color valColor = valueColor;
    if (isDark) {
      if (valueColor == const Color(0xFF421477)) {
        valColor = const Color(0xFFC084FC);
      } else if (valueColor == const Color(0xFF1D4ED8)) {
        valColor = const Color(0xFF60A5FA);
      }
    }

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── VARIABLE NAME UP (Sharp micro-icon + crisp typography) ──
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: labelColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null && label == 'Odometer') ...[
              const SizedBox(width: 2.5),
              Icon(
                Icons.edit_rounded,
                size: 9.5,
                color: labelColor.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1.5),

        // ── VALUE DOWN (Sharp & vibrant) ──
        Padding(
          padding: const EdgeInsets.only(left: 17),
          child: Text(
            value,
            style: TextStyle(
              color: valColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              height: 1.2,
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

const String _googleMapsPinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 92 136" width="22" height="22">
  <path fill="#4285F4" d="M46 0C20.6 0 0 20.6 0 46c0 10.9 3.8 21 10.2 29L46 136l13-75-13-15z"/>
  <path fill="#34A853" d="M10.2 75L46 136l12.8-21.8L23 87z"/>
  <path fill="#FBBC04" d="M58.8 114.2L81.8 75c6.4-7.9 10.2-17.9 10.2-29 0-7.9-2-15.3-5.5-21.8z"/>
  <path fill="#EA4335" d="M46 0c14.3 0 27.1 6.5 35.5 16.8L58.8 52.3 46 46z"/>
  <circle cx="46" cy="46" r="18" fill="#FFFFFF"/>
</svg>
''';

class _ColorfulLocationPin extends StatelessWidget {
  const _ColorfulLocationPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 18,
      child: SvgPicture.string(
        '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 28" width="16" height="18">
          <defs>
            <linearGradient id="pinGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stop-color="#FF3366" />
              <stop offset="35%" stop-color="#FF6B4A" />
              <stop offset="70%" stop-color="#FFA800" />
              <stop offset="100%" stop-color="#00D26A" />
            </linearGradient>
            <radialGradient id="innerPin" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="#FFFFFF" />
              <stop offset="100%" stop-color="#E2E8F0" />
            </radialGradient>
          </defs>
          <path fill="url(#pinGrad)" d="M12 2C7.58 2 4 5.58 4 10c0 5.6 8 16 8 16s8-10.4 8-16c0-4.42-3.58-8-8-8z"/>
          <circle cx="12" cy="10" r="3.5" fill="url(#innerPin)"/>
          <circle cx="12" cy="10" r="1.8" fill="#FF3366"/>
        </svg>''',
      ),
    );
  }
}

class _JumpingGoogleMapPinButton extends StatefulWidget {
  const _JumpingGoogleMapPinButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<_JumpingGoogleMapPinButton> createState() =>
      _JumpingGoogleMapPinButtonState();
}

class _JumpingGoogleMapPinButtonState
    extends State<_JumpingGoogleMapPinButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _jumpAnim;
  late final Animation<double> _shadowScaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _jumpAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -5.5)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -5.5, end: 0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: 20,
      ),
    ]).animate(_controller);

    _shadowScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.55, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 20,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 32,
          height: 32,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext ctx, Widget? child) {
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Dynamic Ground Shadow that shrinks when pin jumps up
                  Positioned(
                    bottom: 4,
                    child: Transform.scale(
                      scaleX: _shadowScaleAnim.value,
                      scaleY: 0.6,
                      child: Container(
                        width: 12,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.18,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Animated Bouncy Jumping Google Maps Pin
                  Transform.translate(
                    offset: Offset(0, _jumpAnim.value - 1.5),
                    child: SvgPicture.string(
                      _googleMapsPinSvg,
                      width: 22,
                      height: 22,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

void _showEditVehicleDialog(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle, {
  bool focusOdometer = false,
}) {
  final TextEditingController nameCtrl =
      TextEditingController(text: vehicle.name);
  final TextEditingController odoCtrl = TextEditingController(
    text: vehicle.odometer != null ? vehicle.odometer!.toStringAsFixed(0) : '',
  );
  final FocusNode nameFocus = FocusNode();
  final FocusNode odoFocus = FocusNode();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final ThemeData theme = Theme.of(ctx);
      final bool isDark = theme.brightness == Brightness.dark;
      bool isSaving = false;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            setState(() => isSaving = true);
            try {
              final String newName = nameCtrl.text.trim();
              final double? newOdo = double.tryParse(odoCtrl.text.trim());

              await ref.read(fleetProvider.notifier).updateVehicleDetails(
                    vehicle.id,
                    name: newName,
                    odometer: newOdo,
                  );

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Vehicle updated successfully',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                setState(() => isSaving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update vehicle: $e'),
                    backgroundColor: Colors.red.shade600,
                  ),
                );
              }
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (focusOdometer && odoFocus.canRequestFocus) {
              odoFocus.requestFocus();
            } else if (!focusOdometer && nameFocus.canRequestFocus) {
              nameFocus.requestFocus();
            }
          });

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit Vehicle',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        vehicle.registrationNumber.isNotEmpty
                            ? vehicle.registrationNumber
                            : vehicle.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Name Field
                    Text(
                      'Vehicle Name',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      focusNode: nameFocus,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter vehicle name',
                        prefixIcon: const Icon(Icons.directions_car_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vehicle name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Odometer Field
                    Text(
                      'Odometer Reading',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: odoCtrl,
                      focusNode: odoFocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 15420',
                        suffixText: 'km',
                        prefixIcon: const Icon(Icons.alt_route_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final num? parsed = num.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid positive number';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
