import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

const String _whatsappSvg = '''
<svg viewBox="0 0 24 24" width="24" height="24">
  <path fill="#25D366" d="M12.04 2C6.58 2 2.13 6.45 2.13 11.91C2.13 13.66 2.59 15.36 3.45 16.86L2.05 22L7.3 20.62C8.75 21.41 10.38 21.83 12.04 21.83C17.5 21.83 21.95 17.38 21.95 11.92C21.95 9.27 20.92 6.78 19.05 4.91C17.18 3.03 14.69 2 12.04 2M12.05 3.67C14.25 3.67 16.31 4.53 17.87 6.09C19.42 7.65 20.28 9.72 20.28 11.92C20.28 16.46 16.58 20.15 12.04 20.15C10.56 20.15 9.11 19.76 7.85 19L7.55 18.83L4.43 19.65L5.26 16.61L5.06 16.29C4.24 15 3.8 13.47 3.8 11.91C3.81 7.37 7.5 3.67 12.05 3.67M8.53 7.33C8.37 7.33 8.1 7.39 7.87 7.64C7.65 7.89 7 8.5 7 9.71C7 10.93 7.89 12.1 8 12.27C8.14 12.44 9.76 14.94 12.25 16C12.84 16.27 13.3 16.42 13.66 16.53C14.25 16.72 14.79 16.69 15.22 16.63C15.7 16.56 16.68 16.03 16.89 15.45C17.1 14.87 17.1 14.38 17.04 14.27C16.97 14.17 16.81 14.11 16.56 13.99C16.31 13.86 15.09 13.26 14.87 13.18C14.64 13.1 14.5 13.06 14.31 13.3C14.15 13.55 13.67 14.11 13.53 14.27C13.38 14.44 13.24 14.46 13 14.34C12.74 14.21 11.9 13.94 10.9 13.05C10.12 12.35 9.59 11.49 9.45 11.24C9.3 11 9.43 10.87 9.56 10.74C9.67 10.63 9.81 10.44 9.94 10.3C10.07 10.15 10.11 10.05 10.2 9.88C10.29 9.71 10.24 9.57 10.18 9.45C10.12 9.33 9.64 8.14 9.43 7.66C9.23 7.18 9.04 7.24 8.89 7.23C8.75 7.23 8.58 7.23 8.42 7.23"/>
</svg>
''';

void showCustomerSupportSheet(BuildContext context) {
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
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (BuildContext ctx) {
      return SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),

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
                      child: const Icon(
                        Icons.headset_mic_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
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
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 2.5,
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                    SizedBox(width: 3.5),
                                    Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF059669),
                                      ),
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
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
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
                color:
                    scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.4),
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
                          Icon(
                            Icons.phone_android_rounded,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DIRECT SUPPORT LINES',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
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
                            Clipboard.setData(
                              const ClipboardData(text: '+917337433350'),
                            );
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Line 1 copied'),
                                ),
                              );
                          },
                        ),
                        const SizedBox(width: 8),
                        _SupportLineCard(
                          lineLabel: 'LINE 2',
                          phone: '+91 73374 33351',
                          onCall: () => launch('tel:+917337433351'),
                          onCopy: () {
                            Clipboard.setData(
                              const ClipboardData(text: '+917337433351'),
                            );
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Line 2 copied'),
                                ),
                              );
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
                            Clipboard.setData(
                              const ClipboardData(text: '+917337433356'),
                            );
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Line 3 copied'),
                                ),
                              );
                          },
                        ),
                        const SizedBox(width: 8),
                        _SupportLineCard(
                          lineLabel: 'LINE 4',
                          phone: '+91 73374 33354',
                          onCall: () => launch('tel:+917337433354'),
                          onCopy: () {
                            Clipboard.setData(
                              const ClipboardData(text: '+917337433354'),
                            );
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Line 4 copied'),
                                ),
                              );
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
                          Icon(
                            Icons.language_rounded,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE & CORRESPONDENCE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color:
                            isDark ? scheme.surface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.outlineVariant
                              .withValues(alpha: isDark ? 0.35 : 0.6),
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
                            onAction: () =>
                                launch('https://www.fueltracks.in'),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.7,
                            color: scheme.outlineVariant
                                .withValues(alpha: isDark ? 0.25 : 0.4),
                          ),
                          _SupportRowCard(
                            icon: Icons.mail_outline_rounded,
                            iconColor: const Color(0xFF6366F1),
                            title: 'fueltrackstpl@gmail.com',
                            subtitle: 'Operations & Ticket Inquiries',
                            actionLabel: 'Email',
                            copyText: 'fueltrackstpl@gmail.com',
                            onAction: () =>
                                launch('mailto:fueltrackstpl@gmail.com'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                color: scheme.outlineVariant
                    .withValues(alpha: isDark ? 0.35 : 0.6),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
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
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 13,
                      color: brandGreen,
                    ),
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
                  ..showSnackBar(
                    SnackBar(content: Text('$title copied')),
                  );
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
