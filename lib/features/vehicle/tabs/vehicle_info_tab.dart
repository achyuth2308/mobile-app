import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';
import '../../../data/models/route.dart';
import '../../../data/models/user_trip.dart';
import '../../../data/models/vehicle.dart';

import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';
import '../../../providers/route_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../shared/widgets/live_address.dart';

import 'package:local_auth/local_auth.dart';

class VehicleInfoTab extends ConsumerStatefulWidget {
  const VehicleInfoTab({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehicleInfoTab> createState() => _VehicleInfoTabState();
}

class _VehicleInfoTabState extends ConsumerState<VehicleInfoTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final Vehicle detailed =
            await ref.read(vehicleRepositoryProvider).getVehicle(widget.vehicleId);
        if (mounted) {
          ref.read(fleetProvider.notifier).upsertVehicle(detailed);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final Vehicle? v = ref.watch(vehicleByIdProvider(widget.vehicleId));
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    if (v == null) return const SizedBox.shrink();

    final IconData vehicleIcon = switch (v.displayType.toLowerCase()) {
      'truck' || 'tipper' || 'lorry' => Icons.local_shipping_rounded,
      'bike' || 'motorcycle' || 'scooter' => Icons.two_wheeler_rounded,
      'bus' => Icons.directions_bus_rounded,
      _ => Icons.directions_car_rounded,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xxl),
      children: <Widget>[
        if (v.isExpiringSoon || v.isExpired) ...<Widget>[
          _RenewalBanner(vehicle: v),
          const SizedBox(height: Gap.md),
        ],

        // ── 1. Engine Security (Safe, Clear, Protected) ────────────
        ImmobilizerCard(vehicle: v),
        const SizedBox(height: Gap.md),

        // ── 2. Vehicle Details (With Visual Icons & Badges) ────────
        _SectionCard(
          title: 'VEHICLE DETAILS',
          vehicle: v,
          items: <_InfoItem>[
            _InfoItem(
              icon: Icons.badge_outlined,
              iconColor: const Color(0xFF0284C7),
              label: 'Registration',
              value: v.displayName,
            ),
            _InfoItem(
              icon: vehicleIcon,
              iconColor: const Color(0xFF6366F1),
              label: 'Vehicle Type',
              value: v.type.toUpperCase(),
            ),
            if (v.speedLimit != null)
              _InfoItem(
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Speed Limit',
                value: '${v.speedLimit!.round()} km/h',
              ),
            _InfoItem(
              icon: Icons.verified_rounded,
              iconColor: v.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              label: 'Status',
              value: '',
              badgeText: v.isActive ? 'ACTIVE' : 'INACTIVE',
              badgeColor: v.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
            ),
          ],
        ),

        const SizedBox(height: Gap.md),

        // ── 3. Device & GPS Location (Plain Language, Visual Icons) ──
        _SectionCard(
          title: 'DEVICE & LOCATION',
          vehicle: v,
          items: <_InfoItem>[
            _InfoItem(
              icon: Icons.memory_rounded,
              iconColor: const Color(0xFF0D9488),
              label: 'Device IMEI',
              value: v.imei.isEmpty ? '—' : v.imei,
              isCopyable: true,
            ),
            if (v.deviceId.isNotEmpty)
              _InfoItem(
                icon: Icons.qr_code_rounded,
                iconColor: const Color(0xFF0284C7),
                label: 'Device ID',
                value: v.deviceId,
                isCopyable: true,
              ),
            _InfoItem(
              icon: Icons.access_time_rounded,
              iconColor: const Color(0xFF64748B),
              label: 'Last Seen',
              value: Fmt.dateTime(v.lastPacketAt),
            ),
            _InfoItem(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFEF4444),
              label: 'Location',
              value: v.address ?? 'Location unavailable',
              isCopyable: true,
              customWidget: LiveAddress(
                vehicle: v,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ),
            if (v.satellites != null)
              _InfoItem(
                icon: Icons.satellite_alt_rounded,
                iconColor: const Color(0xFF2563EB),
                label: 'GPS Signal',
                value: '${v.satellites} Satellites',
                badgeText: v.satellites! >= 6 ? 'STRONG' : 'WEAK',
                badgeColor: v.satellites! >= 6 ? const Color(0xFF059669) : const Color(0xFFF59E0B),
              ),
            if (v.gsmSignal != null)
              _InfoItem(
                icon: Icons.signal_cellular_alt_rounded,
                iconColor: const Color(0xFFEC4899),
                label: 'GSM Signal',
                value: '${v.gsmSignal}${v.gsmSignal! > 5 ? '%' : '/5'}',
              ),
          ],
        ),

        const SizedBox(height: Gap.md),

        // ── 4. Assigned Driver ─────────────────────────────────────
        _AssignedDriverCard(vehicle: v),

        const SizedBox(height: Gap.md),

        // ── 5. Validity & Plan ─────────────────────────────────────
        _SectionCard(
          title: 'VALIDITY & PLAN',
          vehicle: v,
          items: <_InfoItem>[
            _InfoItem(
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF6366F1),
              label: 'Expiry Date',
              value: Fmt.date(v.resolvedExpiryDate),
            ),
            _InfoItem(
              icon: Icons.verified_user_rounded,
              iconColor: (v.daysToExpiry != null && v.daysToExpiry! < 30)
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF059669),
              label: 'Plan Status',
              value: Fmt.expiry(v.daysToExpiry),
              badgeText: (v.daysToExpiry != null && v.daysToExpiry! > 0) ? 'ACTIVE' : 'EXPIRED',
              badgeColor: (v.daysToExpiry != null && v.daysToExpiry! > 0)
                  ? const Color(0xFF059669)
                  : const Color(0xFFEF4444),
            ),
          ],
        ),

        const SizedBox(height: Gap.md),

        // ── 6. Assigned Routes ─────────────────────────────────────
        _AssignedRoutesCard(vehicle: v),

        if (v.isTamilNadu) ...[
          const SizedBox(height: Gap.md),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981).withOpacity(0.12),
              foregroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            onPressed: () =>
                context.push('/vehicle/${v.id}/fitment-certificate'),
            icon: const Icon(Icons.verified_user_rounded, size: 16),
            label: const Text(
              'View & Download Fitment Certificate',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],

        const SizedBox(height: Gap.md),

        // ── 6. Reports Action ──────────────────────────────────────
        OutlinedButton.icon(
          onPressed: () => context.go('/reports?vehicle=${v.id}'),
          icon: const Icon(Icons.insights_rounded, size: 15),
          label: const Text('View Vehicle Reports'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(vertical: 6),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),

        const SizedBox(height: 8),

        // ── 7. Support / Assistance Helper (Tappable) ────────────
        Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: Corners.rSm,
          child: InkWell(
            borderRadius: Corners.rSm,
            onTap: () => _showCustomerSupportSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.headset_mic_rounded, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Need help or vehicle updates? Tap for customer support.',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.primary),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const String _whatsappSvg = '''
<svg viewBox="0 0 24 24" width="24" height="24">
  <path fill="#25D366" d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91C2.13 13.66 2.59 15.36 3.45 16.86L2.05 22L7.3 20.62C8.75 21.41 10.38 21.83 12.04 21.83C17.5 21.83 21.95 17.38 21.95 11.92C21.95 9.27 20.92 6.78 19.05 4.91C17.18 3.03 14.69 2 12.04 2M12.05 3.67C14.25 3.67 16.31 4.53 17.87 6.09C19.42 7.65 20.28 9.72 20.28 11.92C20.28 16.46 16.58 20.15 12.04 20.15C10.56 20.15 9.11 19.76 7.85 19L7.55 18.83L4.43 19.65L5.26 16.61L5.06 16.29C4.24 15 3.8 13.47 3.8 11.91C3.81 7.37 7.5 3.67 12.05 3.67M8.53 7.33C8.37 7.33 8.1 7.39 7.87 7.64C7.65 7.89 7 8.5 7 9.71C7 10.93 7.89 12.1 8 12.27C8.14 12.44 9.76 14.94 12.25 16C12.84 16.27 13.3 16.42 13.66 16.53C14.25 16.72 14.79 16.69 15.22 16.63C15.7 16.56 16.68 16.03 16.89 15.45C17.1 14.87 17.1 14.38 17.04 14.27C16.97 14.17 16.81 14.11 16.56 13.99C16.31 13.86 15.09 13.26 14.87 13.18C14.64 13.1 14.5 13.06 14.31 13.3C14.15 13.55 13.67 14.11 13.53 14.27C13.38 14.44 13.24 14.46 13 14.34C12.74 14.21 11.9 13.94 10.9 13.05C10.12 12.35 9.59 11.49 9.45 11.24C9.3 11 9.43 10.87 9.56 10.74C9.67 10.63 9.81 10.44 9.94 10.3C10.07 10.15 10.11 10.05 10.2 9.88C10.29 9.71 10.24 9.57 10.18 9.45C10.12 9.33 9.64 8.14 9.43 7.66C9.23 7.18 9.04 7.24 8.89 7.23C8.75 7.23 8.58 7.23 8.42 7.23"/>
</svg>
''';

void _showCustomerSupportSheet(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final ColorScheme scheme = theme.colorScheme;
  final bool isDark = theme.brightness == Brightness.dark;

  Future<void> launch(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext ctx) {
      return SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // ── Header with Brand Icon & Active Badge ──────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.headset_mic_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'FuelTracks Support',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 2.5, backgroundColor: Color(0xFF10B981)),
                                    SizedBox(width: 3.5),
                                    Text(
                                      'ACTIVE',
                                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Dedicated telematics & fleet assistance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 0.7,
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
              ),

              // ── Scrollable Body ────────────────────────────────
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    // 1. Hero Quick Connect (3 Cards)
                    Row(
                      children: [
                        _QuickActionCard(
                          icon: Icons.phone_in_talk_rounded,
                          iconColor: const Color(0xFF0284C7),
                          title: 'Call Office',
                          subtitle: '040-35651100',
                          onTap: () => launch('tel:04035651100'),
                        ),
                        const SizedBox(width: 8),
                        _QuickActionCard(
                          iconWidget: SvgPicture.string(
                            _whatsappSvg,
                            width: 18,
                            height: 18,
                          ),
                          iconColor: const Color(0xFF25D366),
                          title: 'WhatsApp',
                          subtitle: 'Instant Chat',
                          onTap: () => launch('https://wa.me/917337433350'),
                        ),
                        const SizedBox(width: 8),
                        _QuickActionCard(
                          icon: Icons.email_rounded,
                          iconColor: const Color(0xFF6366F1),
                          title: 'Email Us',
                          subtitle: 'info@fueltracks',
                          onTap: () => launch('mailto:info@fueltracks.in'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 2. Direct Support Lines (2x2 Grid)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'DIRECT SUPPORT LINES',
                            style: AppTypography.eyebrow(scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _SupportLineCard(
                          lineLabel: 'LINE 1',
                          phone: '+91 73374 33350',
                          onCall: () => launch('tel:+917337433350'),
                          onCopy: () {
                            Clipboard.setData(const ClipboardData(text: '+917337433350'));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('Line 1 copied')));
                          },
                        ),
                        const SizedBox(width: 8),
                        _SupportLineCard(
                          lineLabel: 'LINE 2',
                          phone: '+91 73374 33351',
                          onCall: () => launch('tel:+917337433351'),
                          onCopy: () {
                            Clipboard.setData(const ClipboardData(text: '+917337433351'));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('Line 2 copied')));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SupportLineCard(
                          lineLabel: 'LINE 3',
                          phone: '+91 73374 33356',
                          onCall: () => launch('tel:+917337433356'),
                          onCopy: () {
                            Clipboard.setData(const ClipboardData(text: '+917337433356'));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('Line 3 copied')));
                          },
                        ),
                        const SizedBox(width: 8),
                        _SupportLineCard(
                          lineLabel: 'LINE 4',
                          phone: '+91 73374 33354',
                          onCall: () => launch('tel:+917337433354'),
                          onCopy: () {
                            Clipboard.setData(const ClipboardData(text: '+917337433354'));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(content: Text('Line 4 copied')));
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 3. Email & Web Portal
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.language_rounded, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE & CORRESPONDENCE',
                            style: AppTypography.eyebrow(scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? scheme.surface : const Color(0xFFF8FAFC),
                        borderRadius: Corners.rMd,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _SupportRowCard(
                            icon: Icons.language_rounded,
                            iconColor: const Color(0xFF0D9488),
                            title: 'www.fueltracks.in',
                            subtitle: 'Official Web & Fleet Portal',
                            actionLabel: 'Visit',
                            copyText: 'https://www.fueltracks.in',
                            onAction: () => launch('https://www.fueltracks.in'),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.7,
                            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                          ),
                          _SupportRowCard(
                            icon: Icons.mail_outline_rounded,
                            iconColor: const Color(0xFF6366F1),
                            title: 'fueltrackstpl@gmail.com',
                            subtitle: 'Operations & Ticket Inquiries',
                            actionLabel: 'Email',
                            copyText: 'fueltrackstpl@gmail.com',
                            onAction: () => launch('mailto:fueltrackstpl@gmail.com'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.iconWidget,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: isDark
            ? iconColor.withValues(alpha: 0.12)
            : iconColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iconColor.withValues(alpha: isDark ? 0.25 : 0.22),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: iconWidget ?? Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportLineCard extends StatelessWidget {
  const _SupportLineCard({
    required this.lineLabel,
    required this.phone,
    required this.onCall,
    required this.onCopy,
  });

  final String lineLabel;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    const Color brandGreen = Color(0xFF059669);

    return Expanded(
      child: Material(
        color: isDark ? scheme.surface : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onCall,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: brandGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        lineLabel,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: brandGreen,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, size: 13, color: brandGreen),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportRowCard extends StatelessWidget {
  const _SupportRowCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.copyText,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final String? copyText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (copyText != null) ...[
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyText!));
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(' copied')));
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 11, color: iconColor),
                  const SizedBox(width: 3),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
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

class _InfoItem {
  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.badgeText,
    this.badgeColor,
    this.isCopyable = false,
    this.customWidget,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? badgeText;
  final Color? badgeColor;
  final bool isCopyable;
  final Widget? customWidget;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.items,
    this.vehicle,
  });

  final String title;
  final List<_InfoItem> items;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            title,
            style: AppTypography.eyebrow(scheme.onSurfaceVariant),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
            borderRadius: Corners.rMd,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _InfoCardRow(
                  item: items[i],
                  vehicle: vehicle,
                ),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.7,
                    color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}



class _InfoCardRow extends StatelessWidget {
  const _InfoCardRow({
    required this.item,
    this.vehicle,
  });

  final _InfoItem item;
  final Vehicle? vehicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: item.isCopyable && item.value != '—'
          ? () {
              String textToCopy = item.value;
              final Vehicle? v = vehicle;
              if (item.label == 'Location' && v != null && v.hasLocation) {
                textToCopy = Geocoder.getCachedAddress(v.latitude!, v.longitude!) ??
                    (v.address != null && v.address!.isNotEmpty ? v.address! : item.value);
              }
              Clipboard.setData(ClipboardData(text: textToCopy));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('${item.label} copied')));
            }
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Icon Anchor
            Padding(
              padding: const EdgeInsets.only(top: 1.5),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: (item.iconColor ?? scheme.primary).withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  size: 13,
                  color: item.iconColor ?? scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Label
            Padding(
              padding: const EdgeInsets.only(top: 2.5),
              child: Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Value / Badge
            Expanded(
              child: item.customWidget ??
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (item.value.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      if (item.badgeText != null) ...[
                        if (item.value.isNotEmpty) const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (item.badgeColor ?? const Color(0xFF10B981)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            item.badgeText!,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: item.badgeColor ?? const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
            ),
            if (item.isCopyable && item.value != '—') ...[
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
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
      padding: Gap.cardTight,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: Corners.rMd,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            expired ? Icons.error_rounded : Icons.schedule_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  expired ? 'Subscription expired' : 'Renewal due soon',
                  style: theme.textTheme.titleSmall?.copyWith(color: color, fontSize: 12),
                ),
                Text(
                  Fmt.expiry(vehicle.daysToExpiry),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          FilledButton(
            onPressed: () => context.push('/renewals'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }
}



class ImmobilizerCard extends ConsumerStatefulWidget {
  const ImmobilizerCard({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  ConsumerState<ImmobilizerCard> createState() => _ImmobilizerCardState();
}

class _ImmobilizerCardState extends ConsumerState<ImmobilizerCard> {
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
      if (!canAuthenticate) return true;
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
            size: 38,
          ),
          title: Text(isImmobilized ? 'Restore Engine?' : 'Stop / Cut Engine?'),
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
              child: Text(isImmobilized ? 'Restore' : 'Proceed to Cut'),
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
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isImmobilized = widget.vehicle.isImmobilized;
    final Color stateColor = isImmobilized ? const Color(0xFFEF4444) : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'ENGINE SECURITY',
            style: AppTypography.eyebrow(scheme.onSurfaceVariant),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
            borderRadius: Corners.rMd,
            border: Border.all(
              color: stateColor.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isImmobilized ? Icons.lock_rounded : Icons.check_circle_rounded,
                  color: stateColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isImmobilized ? 'Engine Stopped' : 'Engine Safe & Active',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: stateColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isImmobilized
                          ? 'Vehicle ignition is cut off'
                          : 'Vehicle is ready to drive',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                isImmobilized
                    ? FilledButton.icon(
                        onPressed: _handleToggle,
                        icon: const Icon(Icons.settings_backup_restore_rounded, size: 13),
                        label: const Text('Restore'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _handleToggle,
                        icon: const Icon(Icons.lock_outline_rounded, size: 12),
                        label: const Text('Stop Engine'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
            ],
          ),
        ),
      ],
    );
  }
}



class _AssignedDriverCard extends ConsumerWidget {
  const _AssignedDriverCard({required this.vehicle});
  final Vehicle vehicle;

  Future<void> _callDriver(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showDriverDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameCtrl =
        TextEditingController(text: vehicle.driverName ?? '');
    final TextEditingController phoneCtrl =
        TextEditingController(text: vehicle.driverPhone ?? '');
    bool isSaving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHigh
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            final ColorScheme scheme = Theme.of(context).colorScheme;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline_rounded,
                            size: 20, color: scheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.driverName != null &&
                                      vehicle.driverName!.trim().isNotEmpty
                                  ? 'Edit Assigned Driver'
                                  : 'Assign Driver',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              vehicle.displayName,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Driver Full Name',
                      hintText: 'e.g. Ramesh Kumar',
                      prefixIcon: const Icon(Icons.person_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Driver Phone Number',
                      hintText: 'e.g. +91 98765 43210',
                      prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final String name = nameCtrl.text.trim();
                                  final String phone = phoneCtrl.text.trim();
                                  setStateSheet(() => isSaving = true);
                                  try {
                                    await ref
                                        .read(vehicleRepositoryProvider)
                                        .updateDriver(
                                          vehicle.id,
                                          driverName: name,
                                          driverPhone: phone,
                                        );
                                    final Vehicle updated = vehicle.copyWith(
                                      driverName: name,
                                      driverPhone: phone,
                                    );
                                    ref
                                        .read(fleetProvider.notifier)
                                        .upsertVehicle(updated);
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Driver updated successfully'),
                                            backgroundColor:
                                                Color(0xFF059669),
                                          ),
                                        );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setStateSheet(() => isSaving = false);
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to update driver: $e'),
                                            backgroundColor:
                                                const Color(0xFFEF4444),
                                          ),
                                        );
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Driver'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool hasDriver = vehicle.driverName != null && vehicle.driverName!.trim().isNotEmpty;
    final bool hasPhone = vehicle.driverPhone != null && vehicle.driverPhone!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 5),
              child: Text(
                'ASSIGNED DRIVER',
                style: AppTypography.eyebrow(scheme.onSurfaceVariant),
              ),
            ),
            if (hasDriver)
              InkWell(
                onTap: () => _showDriverDialog(context, ref),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 12, color: scheme.primary),
                      const SizedBox(width: 3),
                      Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
            borderRadius: Corners.rMd,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: hasDriver
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded, size: 13, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Driver Name',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            vehicle.driverName!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPhone) ...[
                      Divider(
                        height: 1,
                        thickness: 0.7,
                        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: isDark ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF059669)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Phone Number',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              vehicle.driverPhone!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: vehicle.driverPhone!));
                                HapticFeedback.selectionClick();
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(const SnackBar(content: Text('Phone number copied')));
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(Icons.copy_rounded, size: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _callDriver(vehicle.driverPhone!),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.call_rounded, size: 11, color: Color(0xFF059669)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Call',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline_rounded, size: 13, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No driver assigned to this vehicle.',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showDriverDialog(context, ref),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 12),
                        label: const Text(
                          'Assign Driver',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}



class _AssignedRoutesCard extends ConsumerWidget {
  const _AssignedRoutesCard({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final List<AppRoute> routes = ref.watch(routeProvider).routes;
    final List<AppRoute> assigned = routes
        .where((AppRoute r) => r.vehicleIds.contains(vehicle.id))
        .toList();
    final List<UserTrip> trips = ref.watch(tripProvider).trips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(
            'ASSIGNED ROUTES',
            style: AppTypography.eyebrow(scheme.onSurfaceVariant),
          ),
        ),
        if (assigned.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
              borderRadius: Corners.rMd,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
                width: 1,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.025),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.alt_route_rounded, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'No route assigned to this vehicle.',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/routes'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Assign Route', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
        else
          ...assigned.map((AppRoute r) {
            final List<UserTrip> onThisRoute = trips
                .where((UserTrip t) =>
                    t.vehicleId == vehicle.id &&
                    (t.routeId == r.id ||
                        (t.routeName != null && t.routeName == r.name)))
                .toList();

            return Container(
              margin: const EdgeInsets.only(bottom: Gap.sm),
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(
                color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
                borderRadius: Corners.rMd,
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.alt_route_rounded,
                          size: 18, color: AppColors.brand),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          r.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          r.coordinates.isNotEmpty
                              ? '${r.coordinates.length} waypoints'
                              : 'Active',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onThisRoute.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Trip status: ${onThisRoute.first.status.replaceAll('_', ' ').toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}


