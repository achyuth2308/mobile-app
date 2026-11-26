import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/backend_capabilities.dart';
import '../../core/realtime/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/license_tier_utils.dart';
import '../../data/models/user.dart';
import '../../data/models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/customer_support_sheet.dart';
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
      if (mounted) setState(() => _version = 'v1.1.6 (22)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final AppUser? user = ref.watch(authProvider).user;
    final FleetState fleet = ref.watch(fleetProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFEDF1F7),
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFEDF1F7),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: <Widget>[
            // ── Executive Profile Card ─────────────────────────────
            _ExecutiveProfileCard(
              user: user,
              vehicleCount: fleet.vehicles.length,
              licenseTier: _resolveLicenseTier(fleet.vehicles),
            ),

            const SizedBox(height: 20),

            // ── Fleet & Operations ─────────────────────────────────
            _SettingsGroup(
              title: 'FLEET & OPERATIONS',
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFFDC2626),
                  iconBgColor: const Color(0xFFFEF2F2),
                  title: 'Alerts & Thresholds',
                  subtitle: 'Speed, idle & security thresholds',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    useRootNavigator: true,
                    builder: (_) => const NotificationPreferencesSheet(),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.alt_route_rounded,
                  iconColor: const Color(0xFF0D9488),
                  iconBgColor: const Color(0xFFF0FDFA),
                  title: 'Route Deviations',
                  subtitle: 'Geofence corridors & trip alerts',
                  onTap: () => context.push('/routes'),
                ),
                _SettingsTile(
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFEFCE8),
                  title: 'Subscriptions & Billing',
                  subtitle: 'GPS validity, recharge & invoices',
                  onTap: () => context.push('/renewals'),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Account & Security ─────────────────────────────────
            _SettingsGroup(
              title: 'ACCOUNT & SECURITY',
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBgColor: const Color(0xFFEFF6FF),
                  title: 'Edit Profile',
                  subtitle: 'Name, phone & regional timezone',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const EditProfileSheet(),
                  ),
                ),
                if (BackendCapabilities.changePassword)
                  _SettingsTile(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBgColor: const Color(0xFFFAF5FF),
                    title: 'Change Password',
                    subtitle: 'Update account login credentials',
                    onTap: () => _changePassword(context),
                  )
                else
                  _SettingsTile(
                    icon: Icons.lock_reset_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    iconBgColor: const Color(0xFFFAF5FF),
                    title: 'Reset Password',
                    subtitle: 'Update account login credentials',
                    onTap: () => context.push('/forgot-password'),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Support & Compliance ───────────────────────────────
            _SettingsGroup(
              title: 'SUPPORT & LEGAL',
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.support_agent_rounded,
                  iconColor: const Color(0xFF475569),
                  iconBgColor: const Color(0xFFF8FAFC),
                  title: 'Contact Support',
                  subtitle: 'Direct lines, WhatsApp & portal access',
                  onTap: () => showCustomerSupportSheet(context),
                ),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF475569),
                  iconBgColor: const Color(0xFFF8FAFC),
                  title: 'Privacy Policy',
                  subtitle: 'Data protection & encrypted telemetry',
                  onTap: () => LegalDocumentSheet.show(
                    context,
                    LegalDocumentType.privacyPolicy,
                  ),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF475569),
                  iconBgColor: const Color(0xFFF8FAFC),
                  title: 'Terms of Service',
                  subtitle: 'Service agreement & platform terms',
                  onTap: () => LegalDocumentSheet.show(
                    context,
                    LegalDocumentType.termsOfService,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Sign Out Action ────────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFECACA),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out of FuelTracks',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Footer ─────────────────────────────────────────────
            Center(
              child: Column(
                children: <Widget>[
                  const Text(
                    'FuelTracks Telemetry Suite',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _version,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Logout',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to logout?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE5E7EB),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: Text(
                          'No',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true || !context.mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) return;

    ref.read(fleetProvider.notifier).clear();
    await ref.read(authProvider.notifier).logout();
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

  String _resolveLicenseTier(List<Vehicle> vehicles) =>
      LicenseTierUtils.resolveLicenseTier(vehicles);
}

class _ExecutiveProfileCard extends StatelessWidget {
  const _ExecutiveProfileCard({
    required this.user,
    required this.vehicleCount,
    required this.licenseTier,
  });

  final AppUser user;
  final int vehicleCount;
  final String licenseTier;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final String displayName =
        user.name.trim().isNotEmpty ? user.name.trim() : 'Operator';
    final String orgName =
        user.orgName.trim().isNotEmpty ? user.orgName.trim() : 'FuelTracks Fleet';
    final bool isSameOrg =
        orgName.trim().toLowerCase() == displayName.trim().toLowerCase();
    final String badgeLabel =
        isSameOrg ? 'FLEET ADMINISTRATOR' : orgName.toUpperCase();
    final IconData badgeIcon =
        isSameOrg ? Icons.verified_user_rounded : Icons.business_rounded;

    final (Color tierColor, Color tierBg, Color tierBorder) =
        switch (licenseTier) {
      'Premium' => (
          const Color(0xFFD97706),
          const Color(0xFFFEFCE8),
          const Color(0xFFFEF08A)
        ),
      'Advanced' => (
          const Color(0xFF7C3AED),
          const Color(0xFFFAF5FF),
          const Color(0xFFE9D5FF)
        ),
      'Standard Plus' => (
          const Color(0xFF0D9488),
          const Color(0xFFF0FDFA),
          const Color(0xFF99F6E4)
        ),
      _ => (
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          const Color(0xFFBFDBFE)
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Gradient Squircle Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF4F6BFF), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF4F6BFF).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFDCFCE7),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                badgeIcon,
                                size: 12,
                                color: const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                badgeLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF16A34A),
                                  letterSpacing: 0.4,
                                ),
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

          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),

          // Operational Status Chips
          Row(
            children: <Widget>[
              _QuickStatusChip(
                icon: Icons.directions_car_rounded,
                label: '$vehicleCount Vehicles',
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFDBEAFE),
              ),
              const SizedBox(width: 8),
              const _QuickStatusChip(
                icon: Icons.sensors_rounded,
                label: 'Live GPS',
                color: Color(0xFF16A34A),
                bgColor: Color(0xFFF0FDF4),
                borderColor: Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 8),
              _QuickStatusChip(
                icon: Icons.shield_rounded,
                label: licenseTier,
                color: tierColor,
                bgColor: tierBg,
                borderColor: tierBorder,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStatusChip extends StatelessWidget {
  const _QuickStatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 0.8,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 52,
                      endIndent: 16,
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: theme.colorScheme.primary.withOpacity(0.06),
        splashColor: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14.5),
          child: Row(
            children: <Widget>[
              // Direct Clean Colored Vector Icon (Matching Reference App)
              Icon(icon, color: iconColor, size: 23),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
