import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/backend_capabilities.dart';
import '../../core/realtime/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/glass_card.dart';
import 'account_deletion_sheet.dart';
import 'edit_profile_sheet.dart';
import 'legal_document_sheet.dart';
import 'notification_preferences_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version} (${info.buildNumber})');
    } catch (_) {
      if (mounted) setState(() => _version = 'v1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = ref.watch(authProvider).user;
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final AsyncValue<SocketStatus> socket = ref.watch(socketStatusProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Gap.lg, Gap.lg, Gap.lg, Gap.navClearance),
          children: <Widget>[
            // ── Identity ─────────────────────────────────────────────
            _ProfileHeader(user: user),

            const SizedBox(height: Gap.xxl),

          // ── Account ──────────────────────────────────────────────
          _SettingsGroup(
            title: 'ACCOUNT',
            children: <Widget>[
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                subtitle: 'Name, phone and timezone',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => const EditProfileSheet(),
                ),
              ),
              if (BackendCapabilities.changePassword)
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  onTap: () => _changePassword(context),
                )
              else
                _SettingsTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Reset password',
                  subtitle: 'We will email you a secure link',
                  onTap: () => context.push('/forgot-password'),
                ),
              _SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'Renewals & billing',
                subtitle: 'Subscriptions and payment history',
                onTap: () => context.push('/renewals'),
              ),
            ],
          ),

          const SizedBox(height: Gap.lg),

          // ── Fleet tools ──────────────────────────────────────────
          _SettingsGroup(
            title: 'FLEET',
            children: <Widget>[
              if (BackendCapabilities.geofences)
                _SettingsTile(
                  icon: Icons.fence_rounded,
                  title: 'Geofences',
                  subtitle: 'Zones and entry/exit alerts',
                  onTap: () => context.push('/geofences'),
                ),
              _SettingsTile(
                icon: Icons.add_road_rounded,
                title: 'Route Management',
                subtitle: 'Set routes & get trip/deviation alerts',
                onTap: () => context.push('/routes'),
              ),
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notification preferences',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  useRootNavigator: true,
                  builder: (_) => const NotificationPreferencesSheet(),
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.lg),

          // ── Appearance ───────────────────────────────────────────
          _SettingsGroup(
            title: 'APPEARANCE',
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.palette_outlined,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: Gap.lg),
                    Expanded(
                      child: Text('Theme', style: theme.textTheme.titleSmall),
                    ),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<ThemeMode>>[
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 17),
                          tooltip: 'Light',
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 17),
                          tooltip: 'Dark',
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 17),
                          tooltip: 'System',
                        ),
                      ],
                      selected: <ThemeMode>{themeMode},
                      onSelectionChanged: (Set<ThemeMode> s) =>
                          ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  ],
                ),
              ),
            ],
          ),



          // ── Legal & support ──────────────────────────────────────
          _SettingsGroup(
            title: 'SUPPORT & LEGAL',
            children: <Widget>[
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Contact support',
                subtitle: AppConfig.supportEmail,
                onTap: () => _email(),
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                subtitle: 'Data handling & security practices',
                onTap: () => LegalDocumentSheet.show(
                  context,
                  LegalDocumentType.privacyPolicy,
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of service',
                subtitle: 'User agreement & service terms',
                onTap: () => LegalDocumentSheet.show(
                  context,
                  LegalDocumentType.termsOfService,
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.lg),

          // ── Danger zone ──────────────────────────────────────────
          _SettingsGroup(
            title: 'DANGER ZONE',
            children: <Widget>[
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: () => _confirmLogout(context),
              ),

            ],
          ),

          const SizedBox(height: Gap.x3l),

          Center(
            child: Column(
              children: <Widget>[
                Opacity(
                  opacity: 0.5,
                  child: Text('FuelTracks', style: theme.textTheme.labelMedium),
                ),
                const SizedBox(height: 2),
                Text(
                  _version,
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to monitor your fleet.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    ref.read(fleetProvider.notifier).clear();
    await ref.read(authProvider.notifier).logout();

    if (!context.mounted) return;
    context.go('/login');
  }

  Future<void> _changePassword(BuildContext context) async {
    final TextEditingController current = TextEditingController();
    final TextEditingController next = TextEditingController();

    final bool? submit = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: Gap.md),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (submit != true || !context.mounted) return;

    final bool ok = await ref.read(authProvider.notifier).changePassword(
          currentPassword: current.text,
          newPassword: next.text,
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Password updated.'
              : ref.read(authProvider).error ?? 'Could not update password.',
        ),
      ),
    );
  }


  Future<void> _email() async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: <String, String>{'subject': 'FuelTracks support'},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            gradient: AppColors.brandGradient,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.initials,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: Gap.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (user.orgName.isNotEmpty) ...<Widget>[
                const SizedBox(height: Gap.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: Corners.rXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.business_rounded,
                          size: 11, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(
                        user.orgName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

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
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: Gap.x3l + Gap.md,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = danger ? AppColors.danger : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: danger
                  ? AppColors.danger
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
