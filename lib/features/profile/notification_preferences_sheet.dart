import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/vehicle.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';

class NotificationPreferencesSheet extends ConsumerWidget {
  const NotificationPreferencesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final NotificationPreferences prefs = ref.watch(notificationPreferencesProvider);
    final NotificationPreferencesNotifier notifier =
        ref.read(notificationPreferencesProvider.notifier);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Alert & Notification Configuration',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Customize which notifications you want to receive on this device.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Gap.lg),
            const Divider(),
            const SizedBox(height: Gap.sm),

            _buildPreferenceTile(
              context: context,
              icon: Icons.sos_rounded,
              title: 'SOS & Safety Alerts',
              subtitle: 'Emergency button triggers, crash events, towing, power cut',
              value: prefs.sos,
              onChanged: (_) => notifier.toggleSos(),
            ),
            _buildPreferenceTile(
              context: context,
              icon: Icons.alarm_rounded,
              title: 'Theft Alarms',
              subtitle: 'Unauthorized vehicle movement, vibration or tampering',
              value: prefs.theft,
              onChanged: (_) => notifier.toggleTheft(),
            ),
            _buildPreferenceTile(
              context: context,
              icon: Icons.speed_rounded,
              title: 'Overspeed Alerts',
              subtitle: 'Exceeding designated speed limits',
              value: prefs.overspeed,
              onChanged: (_) => notifier.toggleOverspeed(),
            ),
            _buildPreferenceTile(
              context: context,
              icon: Icons.login_rounded,
              title: 'Geofence Entry/Exit',
              subtitle: 'Vehicles entering or leaving defined zones',
              value: prefs.geofence,
              onChanged: (_) => notifier.toggleGeofence(),
            ),
            _buildPreferenceTile(
              context: context,
              icon: Icons.power_settings_new_rounded,
              title: 'Ignition & Movement',
              subtitle: 'Engine start, stop, idle, moving, stopped',
              value: prefs.ignition,
              onChanged: (_) => notifier.toggleIgnition(),
            ),

            const SizedBox(height: Gap.lg),
            const Divider(),
            const SizedBox(height: Gap.md),

            // ── Vehicle Thresholds ──
            const _ThresholdsSection(),

            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preferences saved successfully!'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save Preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final ThemeData theme = Theme.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.sm,
        vertical: Gap.xs,
      ),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: value ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ThresholdsSection extends ConsumerStatefulWidget {
  const _ThresholdsSection();

  @override
  ConsumerState<_ThresholdsSection> createState() => _ThresholdsSectionState();
}

class _ThresholdsSectionState extends ConsumerState<_ThresholdsSection> {
  String? _selectedVehicleId;
  double _speedLimit = 80.0;
  double _idleDuration = 10.0;
  double _stoppageDuration = 10.0;
  bool _isSavingThresholds = false;

  void _loadVehicleThresholds(Vehicle vehicle) {
    final Map<String, dynamic> metadata = (vehicle.raw['metadata'] as Map<String, dynamic>?) ?? {};
    setState(() {
      _selectedVehicleId = vehicle.id;
      _speedLimit = (metadata['overSpeedLimit'] as num?)?.toDouble() ??
          (metadata['speedLimit'] as num?)?.toDouble() ??
          80.0;
      _idleDuration = (metadata['idleDurationAlert'] as num?)?.toDouble() ?? 10.0;
      _stoppageDuration = (metadata['stoppageThreshold'] as num?)?.toDouble() ?? 10.0;
    });
  }

  Future<void> _saveVehicleThresholds() async {
    if (_selectedVehicleId == null) return;
    setState(() => _isSavingThresholds = true);
    try {
      await ref.read(fleetProvider.notifier).updateSettings(
            _selectedVehicleId!,
            overSpeedLimit: _speedLimit,
            idleDurationAlert: _idleDuration,
            stoppageThreshold: _stoppageDuration,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle thresholds updated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update thresholds: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingThresholds = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Vehicle> vehicles = ref.watch(fleetProvider).vehicles;

    if (vehicles.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedVehicleId == null && vehicles.isNotEmpty) {
      final first = vehicles.first;
      _selectedVehicleId = first.id;
      final Map<String, dynamic> metadata = (first.raw['metadata'] as Map<String, dynamic>?) ?? {};
      _speedLimit = (metadata['overSpeedLimit'] as num?)?.toDouble() ??
          (metadata['speedLimit'] as num?)?.toDouble() ??
          80.0;
      _idleDuration = (metadata['idleDurationAlert'] as num?)?.toDouble() ?? 10.0;
      _stoppageDuration = (metadata['stoppageThreshold'] as num?)?.toDouble() ?? 10.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: Gap.xs),
            Text(
              'Alert Thresholds Configuration',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'Configure overspeed limit, idle duration, and stoppage alert thresholds.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: Gap.md),

        // Vehicle Selector Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicleId,
              isExpanded: true,
              items: vehicles.map((v) {
                return DropdownMenuItem<String>(
                  value: v.id,
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_rounded, size: 18),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          v.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final found = vehicles.firstWhere((v) => v.id == val);
                _loadVehicleThresholds(found);
              },
            ),
          ),
        ),

        const SizedBox(height: Gap.lg),

        // Overspeed threshold slider
        _buildSliderTile(
          title: 'Overspeed Threshold',
          valueText: '${_speedLimit.round()} km/h',
          icon: Icons.speed_rounded,
          color: const Color(0xFFFF9800),
          slider: Slider(
            value: _speedLimit,
            min: 30,
            max: 140,
            divisions: 110,
            activeColor: const Color(0xFFFF9800),
            onChanged: (v) => setState(() => _speedLimit = v),
          ),
        ),

        const SizedBox(height: Gap.md),

        // Idle duration threshold slider
        _buildSliderTile(
          title: 'Idle Time Threshold',
          valueText: '${_idleDuration.round()} mins',
          icon: Icons.hourglass_empty_rounded,
          color: const Color(0xFF9C27B0),
          slider: Slider(
            value: _idleDuration,
            min: 5,
            max: 60,
            divisions: 55,
            activeColor: const Color(0xFF9C27B0),
            onChanged: (v) => setState(() => _idleDuration = v),
          ),
        ),

        const SizedBox(height: Gap.md),

        // Stoppage duration threshold slider
        _buildSliderTile(
          title: 'Stoppage Time Threshold',
          valueText: '${_stoppageDuration.round()} mins',
          icon: Icons.pause_circle_filled_rounded,
          color: const Color(0xFFE91E63),
          slider: Slider(
            value: _stoppageDuration,
            min: 5,
            max: 60,
            divisions: 55,
            activeColor: const Color(0xFFE91E63),
            onChanged: (v) => setState(() => _stoppageDuration = v),
          ),
        ),

        const SizedBox(height: Gap.md),

        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _isSavingThresholds ? null : _saveVehicleThresholds,
            icon: _isSavingThresholds
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text(_isSavingThresholds ? 'Saving...' : 'Apply Thresholds to Vehicle'),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String valueText,
    required IconData icon,
    required Color color,
    required Widget slider,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Gap.xs),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueText,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
