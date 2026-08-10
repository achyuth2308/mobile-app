import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/repositories/vehicle_repository.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:local_auth/local_auth.dart';

class VehicleInfoTab extends ConsumerWidget {
  const VehicleInfoTab({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Vehicle? v = ref.watch(vehicleByIdProvider(vehicleId));
    final ThemeData theme = Theme.of(context);

    if (v == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.x4l),
      children: <Widget>[
        if (v.isExpiringSoon || v.isExpired) ...<Widget>[
          _RenewalBanner(vehicle: v),
          const SizedBox(height: Gap.lg),
        ],

        _ImmobilizerCard(vehicle: v),
        const SizedBox(height: Gap.lg),

        _Section(
          title: 'VEHICLE',
          rows: <(String, String)>[
            ('Registration', v.registrationNumber.isEmpty ? '—' : v.registrationNumber),
            ('Name', v.name.isEmpty ? '—' : v.name),
            ('Type', v.type.toUpperCase()),
            if (v.speedLimit != null)
              ('Speed limit', '${v.speedLimit!.round()} km/h'),
            ('Status', v.isActive ? 'Active' : 'Inactive'),
          ],
        ),

        const SizedBox(height: Gap.lg),

        _Section(
          title: 'DEVICE',
          rows: <(String, String)>[
            ('IMEI', v.imei.isEmpty ? '—' : v.imei),
            if (v.deviceId.isNotEmpty) ('Device ID', v.deviceId),
            ('Last packet', Fmt.full(v.lastPacketAt)),
            ('Coordinates', Fmt.coordinates(v.latitude, v.longitude)),
            if (v.satellites != null) ('Satellites', '${v.satellites}'),
            if (v.gsmSignal != null) ('GSM signal', '${v.gsmSignal}/5'),
          ],
          copyable: const <String>{'IMEI', 'Coordinates', 'Device ID'},
        ),

        if (v.driverName != null || v.driverPhone != null) ...<Widget>[
          const SizedBox(height: Gap.lg),
          _Section(
            title: 'DRIVER',
            rows: <(String, String)>[
              if (v.driverName != null) ('Name', v.driverName!),
              if (v.driverPhone != null) ('Phone', v.driverPhone!),
            ],
            copyable: const <String>{'Phone'},
          ),
        ],

        const SizedBox(height: Gap.lg),

        _Section(
          title: 'SUBSCRIPTION',
          rows: <(String, String)>[
            ('Expiry date', Fmt.date(v.expiryDate)),
            ('Status', Fmt.expiry(v.daysToExpiry)),
          ],
        ),

        const SizedBox(height: Gap.xxl),

        OutlinedButton.icon(
          onPressed: () => context.push('/reports?vehicle=${v.id}'),
          icon: const Icon(Icons.insights_rounded, size: 18),
          label: const Text('Run a report for this vehicle'),
        ),

        const SizedBox(height: Gap.lg),

        Center(
          child: Text(
            'Vehicle data is managed by your service provider.\n'
            'Contact them to update registration or driver details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.copyable = const <String>{},
  });

  final String title;
  final List<(String, String)> rows;
  final Set<String> copyable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Gap.sm),
          child: Text(
            title,
            style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Column(
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
                _InfoRow(
                  label: rows[i].$1,
                  value: rows[i].$2,
                  copyable: copyable.contains(rows[i].$1),
                ),
                if (i < rows.length - 1)
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
              ],
            ],
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.copyable,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: copyable && value != '—'
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('$label copied')));
            }
          : null,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 120,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (copyable && value != '—') ...<Widget>[
              const SizedBox(width: Gap.sm),
              Icon(
                Icons.copy_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RenewalBanner extends StatelessWidget {
  const _RenewalBanner({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool expired = vehicle.isExpired;
    final Color color = expired ? AppColors.danger : AppColors.idle;

    return Container(
      padding: Gap.card,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: Corners.rLg,
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            expired ? Icons.error_rounded : Icons.schedule_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  expired ? 'Subscription expired' : 'Renewal due soon',
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.expiry(vehicle.daysToExpiry),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          FilledButton(
            onPressed: () => context.push('/renewals'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            ),
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }
}

class _ImmobilizerCard extends ConsumerStatefulWidget {
  const _ImmobilizerCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  ConsumerState<_ImmobilizerCard> createState() => _ImmobilizerCardState();
}

class _ImmobilizerCardState extends ConsumerState<_ImmobilizerCard> {
  bool _loading = false;
  final LocalAuthentication _auth = LocalAuthentication();

  Future<void> _handleToggle() async {
    final bool isImmobilized = widget.vehicle.isImmobilized;
    final bool proceed = await _showWarningDialog(isImmobilized);
    if (!proceed || !mounted) return;

    final bool authenticated = await _authenticate();
    if (!authenticated || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication required to proceed.')),
        );
      }
      return;
    }

    setState(() => _loading = true);

    try {
      await ref
          .read(vehicleRepositoryProvider)
          .sendImmobilizerCommand(widget.vehicle.id, !isImmobilized);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isImmobilized
                ? 'Engine restored successfully.'
                : 'Engine cut command sent.'),
            backgroundColor: isImmobilized ? AppColors.moving : AppColors.danger,
          ),
        );
      }
      
      // Trigger a silent foreground re-sync to get the new attributes back
      unawaited(ref.read(fleetProvider.notifier).load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _authenticate() async {
    try {
      final bool canAuthenticate = await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
      if (!canAuthenticate) {
        // Fallback: if device has no security, we allow it since the dialog was accepted.
        return true;
      }
      return await _auth.authenticate(
        localizedReason: 'Confirm identity to control engine',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> _showWarningDialog(bool isImmobilized) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            isImmobilized ? Icons.settings_backup_restore_rounded : Icons.power_settings_new_rounded,
            color: isImmobilized ? AppColors.moving : AppColors.danger,
            size: 40,
          ),
          title: Text(isImmobilized ? 'Restore Engine?' : 'Cut Engine?'),
          content: Text(
            isImmobilized
                ? 'This will restore the ignition circuit, allowing the vehicle to be started again.'
                : 'WARNING: This will disable the vehicle\'s ignition circuit. '
                  'The vehicle will not be able to start again until you restore the engine. '
                  'Ensure the vehicle is in a safe location.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: isImmobilized ? AppColors.moving : AppColors.danger,
              ),
              child: Text(isImmobilized ? 'Restore' : 'Proceed'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isImmobilized = widget.vehicle.isImmobilized;
    final Color color = isImmobilized ? AppColors.danger : AppColors.moving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Gap.sm),
          child: Text(
            'ENGINE CONTROL',
            style: AppTypography.eyebrow(theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: Corners.rSm,
                ),
                child: Icon(
                  isImmobilized ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isImmobilized ? 'Engine Immobilized' : 'Engine Normal',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isImmobilized
                          ? 'Vehicle cannot be started.'
                          : 'Ignition circuit is active.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(right: Gap.sm),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _handleToggle,
                  icon: Icon(
                    isImmobilized ? Icons.settings_backup_restore_rounded : Icons.power_settings_new_rounded,
                    size: 16,
                  ),
                  label: Text(isImmobilized ? 'Restore' : 'Cut Engine'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isImmobilized ? null : AppColors.danger,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
