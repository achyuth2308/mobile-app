import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../providers/core_providers.dart';

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
                Text(
                  'Notification Preferences',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
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
            _buildPreferenceTile(
              context: context,
              icon: Icons.warning_amber_rounded,
              title: 'Harsh Driving Events',
              subtitle: 'Harsh braking or rapid acceleration',
              value: prefs.harsh,
              onChanged: (_) => notifier.toggleHarsh(),
            ),
            
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
