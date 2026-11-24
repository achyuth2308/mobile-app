import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/models/alert.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../core/utils/formatters.dart';
import '../live_map/providers/live_map_providers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

/// Root shell: owns the bottom navigation and starts the real-time session
/// once, for the whole authenticated experience.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<dynamic>? _socketSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  Future<void> _startSession() async {
    if (!mounted) return;

    // 1 ─ REST snapshot first so the first frame is real data.
    await ref.read(fleetProvider.notifier).load();
    if (!mounted) return;

    // 2 ─ Then bring up the live channel and join the org room.
    await ref.read(socketServiceProvider).connect();
    if (!mounted) return;
    ref.read(fleetProvider.notifier).attachSocket();

    // 3 ─ Global listener for real-time system notifications (replaces snackbar).
    _socketSub = ref.read(socketServiceProvider).events$.listen((event) {
      // FCM background and foreground handlers automatically handle push notifications,
      // so we don't need to manually trigger local notifications from the UI shell.
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        if (widget.navigationShell.currentIndex != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              widget.navigationShell.goBranch(0);
            }
          });
          return;
        }

        final DateTime now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: false,
        body: widget.navigationShell,
        bottomNavigationBar: _ModernBottomNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (int index) => widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}

class _ModernBottomNavBar extends StatelessWidget {
  const _ModernBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color activeColor =
        isDark ? const Color(0xFF818CF8) : const Color(0xFF4F6BFF);
    // Crisp Solid Black in light mode, clean white in dark mode (no washed-out grey!)
    final Color inactiveColor =
        isDark ? Colors.white70 : const Color(0xFF0F172A);
    final Color bgColor =
        isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color borderColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    const List<_NavItemData> items = <_NavItemData>[
      _NavItemData(
        label: 'Home',
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
      ),
      _NavItemData(
        label: 'Live Map',
        activeIcon: Icons.explore_rounded,
        inactiveIcon: Icons.explore_outlined,
      ),
      _NavItemData(
        label: 'Reports',
        activeIcon: Icons.bar_chart_rounded,
        inactiveIcon: Icons.bar_chart_outlined,
      ),
      _NavItemData(
        label: 'Profile',
        activeIcon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List<Widget>.generate(items.length, (int index) {
              final _NavItemData item = items[index];
              final bool isSelected = index == currentIndex;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      onTap(index);
                    },
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 12 : 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            // Bouncy animated scaling icon
                            AnimatedScale(
                              scale: isSelected ? 1.14 : 1.0,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                isSelected
                                    ? item.activeIcon
                                    : item.inactiveIcon,
                                size: 23,
                                color: isSelected ? activeColor : inactiveColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Animated font-weight and color transition
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: isSelected ? 11.5 : 11.0,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                letterSpacing: isSelected ? -0.2 : -0.1,
                                color: isSelected ? activeColor : inactiveColor,
                                height: 1.1,
                              ),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Animated glowing dash indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              width: isSelected ? 18 : 0,
                              height: 3,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? activeColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: isSelected
                                    ? <BoxShadow>[
                                        BoxShadow(
                                          color: activeColor.withOpacity(0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
}
