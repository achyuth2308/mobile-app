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

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab pops that branch to its root — the standard
      // iOS/Android expectation.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int index = widget.navigationShell.currentIndex;
    final String? activeFollowingId = ref.watch(activeFollowingVehicleIdProvider);

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: index,
        onTap: _onTap,
        theme: theme,
        activeFollowingVehicleId: activeFollowingId,
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.theme,
    this.activeFollowingVehicleId,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ThemeData theme;
  final String? activeFollowingVehicleId;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = theme.colorScheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    // Dynamically build nav items
    final List<_NavItemData> navItems = [
      const _NavItemData(
        label: 'Fleet',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        branchIndex: 0,
      ),
      const _NavItemData(
        label: 'Live Map',
        icon: Icons.map_outlined,
        activeIcon: Icons.map_rounded,
        branchIndex: 1,
      ),
    ];

    if (activeFollowingVehicleId != null) {
      navItems.add(
        const _NavItemData(
          label: 'Details',
          icon: Icons.info_outline_rounded,
          activeIcon: Icons.info_rounded,
          isDetails: true,
        ),
      );
    }

    navItems.addAll([
      const _NavItemData(
        label: 'Reports',
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights_rounded,
        branchIndex: 2,
      ),
      const _NavItemData(
        label: 'Trips',
        icon: Icons.route_outlined,
        activeIcon: Icons.route_rounded,
        branchIndex: 3,
      ),
      const _NavItemData(
        label: 'Account',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        branchIndex: 4,
      ),
    ]);

    return Container(
      margin:
          EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, bottomInset > 0 ? 8 : Gap.md),
      height: 66,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withOpacity(0.97),
        borderRadius: Corners.rXl,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(
              scheme.brightness == Brightness.dark ? 0.42 : 0.10,
            ),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List<Widget>.generate(navItems.length, (int i) {
          final _NavItemData item = navItems[i];
          final bool selected = !item.isDetails && item.branchIndex == currentIndex;

          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: item.label,
              child: InkWell(
                onTap: () {
                  if (item.isDetails) {
                    context.push('/vehicle/$activeFollowingVehicleId');
                  } else if (item.branchIndex != null) {
                    onTap(item.branchIndex!);
                  }
                },
                borderRadius: Corners.rLg,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: Motion.fast,
                      curve: Motion.emphasized,
                      padding: EdgeInsets.symmetric(
                        horizontal: selected ? 16 : 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withOpacity(0.18)
                            : Colors.transparent,
                        borderRadius: Corners.rPill,
                      ),
                      child: Icon(
                        selected ? item.activeIcon : item.icon,
                        size: 22,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: Motion.fast,
                      style: theme.textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.1,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      child: Text(item.label),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.branchIndex,
    this.isDetails = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int? branchIndex;
  final bool isDetails;
}
