import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../../../shared/widgets/app_states.dart';

class VehicleSettingsScreen extends ConsumerStatefulWidget {
  const VehicleSettingsScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehicleSettingsScreen> createState() =>
      _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState
    extends ConsumerState<VehicleSettingsScreen> {
  late double _speedLimit;
  late double _overspeedDuration;
  late double _idleDuration;

  bool _enableSpeedAlert = true;
  bool _enableIdleAlert = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final Vehicle? vehicle = ref.read(vehicleByIdProvider(widget.vehicleId));
    _speedLimit = vehicle?.speedLimit ?? 60.0;
    _overspeedDuration = vehicle?.overspeedDurationAlert ?? 3.0;
    _idleDuration = vehicle?.idleDurationAlert ?? 10.0;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(fleetProvider.notifier).updateSettings(
            widget.vehicleId,
            overSpeedLimit: _speedLimit,
            overspeedDurationAlert: _overspeedDuration,
            idleDurationAlert: _idleDuration,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const <Widget>[
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: Gap.sm),
                Text('Vehicle settings saved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Settings')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Vehicle not found',
          message: 'Unable to load vehicle details.',
        ),
      );
    }

    final Color cardBg = isDark
        ? const Color(0xFF0F2138)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Gap.lg),
                children: <Widget>[
                  // ── Hero Vehicle Header ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(Gap.md),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: Corners.rLg,
                      border: Border.all(color: borderColor),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(Gap.md),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withOpacity(0.12),
                            borderRadius: Corners.rMd,
                          ),
                          child: Icon(
                            Icons.directions_car_rounded,
                            color: AppColors.brand,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                vehicle.displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                vehicle.registrationNumber.isNotEmpty
                                    ? vehicle.registrationNumber
                                    : 'IMEI: ${vehicle.imei}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: vehicle.status),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.xl),

                  // ── Section 1: Overspeed Limit ─────────────────────
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    title: 'Overspeed Threshold',
                    subtitle: 'Alert triggers when vehicle speed exceeds limit',
                    icon: Icons.speed_rounded,
                    iconColor: const Color(0xFFFF9800),
                    badgeText: '${_speedLimit.round()} km/h',
                    badgeColor: const Color(0xFFFF9800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Slider(
                          value: _speedLimit,
                          min: 30,
                          max: 140,
                          divisions: 110,
                          label: '${_speedLimit.round()} km/h',
                          activeColor: const Color(0xFFFF9800),
                          onChanged: (double v) =>
                              setState(() => _speedLimit = v),
                        ),
                        const SizedBox(height: Gap.xs),
                        Wrap(
                          spacing: Gap.xs,
                          runSpacing: Gap.xs,
                          children: <double>[40, 60, 80, 100, 120]
                              .map(
                                (double preset) => ChoiceChip(
                                  label: Text('${preset.round()} km/h'),
                                  selected: _speedLimit == preset,
                                  selectedColor: const Color(0xFFFF9800)
                                      .withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _speedLimit == preset
                                        ? const Color(0xFFFF9800)
                                        : scheme.onSurfaceVariant,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _speedLimit = preset),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.lg),

                  // ── Section 2: Overspeed Duration ──────────────────
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    title: 'Overspeed Duration',
                    subtitle:
                        'Speeding duration required before firing alert',
                    icon: Icons.timer_rounded,
                    iconColor: const Color(0xFF2196F3),
                    badgeText: '${_overspeedDuration.round()} mins',
                    badgeColor: const Color(0xFF2196F3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Slider(
                          value: _overspeedDuration,
                          min: 1,
                          max: 15,
                          divisions: 14,
                          label: '${_overspeedDuration.round()} mins',
                          activeColor: const Color(0xFF2196F3),
                          onChanged: (double v) =>
                              setState(() => _overspeedDuration = v),
                        ),
                        const SizedBox(height: Gap.xs),
                        Wrap(
                          spacing: Gap.xs,
                          children: <double>[1, 3, 5, 10]
                              .map(
                                (double preset) => ChoiceChip(
                                  label: Text('${preset.round()} mins'),
                                  selected: _overspeedDuration == preset,
                                  selectedColor: const Color(0xFF2196F3)
                                      .withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _overspeedDuration == preset
                                        ? const Color(0xFF2196F3)
                                        : scheme.onSurfaceVariant,
                                  ),
                                  onSelected: (_) => setState(
                                      () => _overspeedDuration = preset),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.lg),

                  // ── Section 3: Idle Duration ───────────────────────
                  _SettingsCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    title: 'Idle Duration Alert',
                    subtitle:
                        'Alert triggers when engine is ON but stationary',
                    icon: Icons.hourglass_empty_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    badgeText: '${_idleDuration.round()} mins',
                    badgeColor: const Color(0xFF9C27B0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Slider(
                          value: _idleDuration,
                          min: 5,
                          max: 60,
                          divisions: 55,
                          label: '${_idleDuration.round()} mins',
                          activeColor: const Color(0xFF9C27B0),
                          onChanged: (double v) =>
                              setState(() => _idleDuration = v),
                        ),
                        const SizedBox(height: Gap.xs),
                        Wrap(
                          spacing: Gap.xs,
                          children: <double>[5, 10, 15, 30]
                              .map(
                                (double preset) => ChoiceChip(
                                  label: Text('${preset.round()} mins'),
                                  selected: _idleDuration == preset,
                                  selectedColor: const Color(0xFF9C27B0)
                                      .withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _idleDuration == preset
                                        ? const Color(0xFF9C27B0)
                                        : scheme.onSurfaceVariant,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _idleDuration = preset),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.lg),

                  // ── Section 4: Alert Notification Toggles ──────────
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: Corners.rLg,
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: <Widget>[
                        SwitchListTile(
                          value: _enableSpeedAlert,
                          activeColor: AppColors.brand,
                          title: const Text('Speed Alert Notifications'),
                          subtitle: const Text('Send push alert on overspeeding'),
                          onChanged: (bool val) =>
                              setState(() => _enableSpeedAlert = val),
                        ),
                        Divider(height: 1, color: borderColor),
                        SwitchListTile(
                          value: _enableIdleAlert,
                          activeColor: AppColors.brand,
                          title: const Text('Idle Engine Notifications'),
                          subtitle:
                              const Text('Send alert on prolonged idling'),
                          onChanged: (bool val) =>
                              setState(() => _enableIdleAlert = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Gap.xxl),
                ],
              ),
            ),

            // ── Save Action Bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: Corners.rLg,
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Settings',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      VehicleStatus.moving => (const Color(0xFF2E7D32), 'Running'),
      VehicleStatus.idle => (const Color(0xFFED6C02), 'Idle'),
      VehicleStatus.stopped => (const Color(0xFF757575), 'Parking'),
      VehicleStatus.offline => (const Color(0xFFD32F2F), 'Offline'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: Corners.rPill,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.cardBg,
    required this.borderColor,
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.badgeText,
    required this.badgeColor,
    required this.child,
  });

  final Color cardBg;
  final Color borderColor;
  final bool isDark;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String badgeText;
  final Color badgeColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: Corners.rLg,
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Gap.xs + 2),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: Corners.rSm,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: Corners.rPill,
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          child,
        ],
      ),
    );
  }
}
