import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../data/models/alert.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';

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

    // 3 ─ Global listener for in-app alert snackbars.
    _socketSub = ref.read(socketServiceProvider).events$.listen((event) {
      if (event.name == 'alert:new' || event.name == 'geofence:event') {
        try {
          FleetAlert newAlert = FleetAlert.fromJson(event.payload);

          if (newAlert.vehicleName == null && newAlert.vehicleId != null) {
            final vehicle = ref
                .read(fleetProvider)
                .vehicles
                .where((v) => v.id == newAlert.vehicleId)
                .firstOrNull;
            if (vehicle != null) {
              newAlert = newAlert.copyWith(vehicleName: vehicle.name);
            }
          }

          if (!mounted) return;

          final String title = newAlert.title;
          final String msg = newAlert.vehicleName != null
              ? '${newAlert.vehicleName} - ${newAlert.message}'
              : newAlert.message;

          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('$title\n$msg',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              showCloseIcon: true,
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            ),
          );
        } catch (_) {}
      }
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

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: index,
        onTap: _onTap,
        theme: theme,
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.theme,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ThemeData theme;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem('Fleet', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _NavItem('Live Map', Icons.map_outlined, Icons.map_rounded),
    _NavItem('Alerts', Icons.notifications_none_rounded,
        Icons.notifications_rounded),
    _NavItem('Reports', Icons.insights_outlined, Icons.insights_rounded),
    _NavItem('Account', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = theme.colorScheme;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

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
        children: List<Widget>.generate(_items.length, (int i) {
          final _NavItem item = _items[i];
          final bool selected = i == currentIndex;

          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: item.label,
              child: InkWell(
                onTap: () => onTap(i),
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
                      child: i == 2
                          ? _AlertsIcon(selected: selected, item: item)
                          : Icon(
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

/// Alerts tab icon with an unread badge.
class _AlertsIcon extends ConsumerWidget {
  const _AlertsIcon({required this.selected, required this.item});

  final bool selected;
  final _NavItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int unread = ref.watch(unreadAlertsProvider);

    final Widget icon = Icon(
      selected ? item.activeIcon : item.icon,
      size: 22,
      color: selected ? scheme.primary : scheme.onSurfaceVariant,
    );

    if (unread == 0) return icon;

    return Badge(
      label: Text(unread > 99 ? '99+' : '$unread'),
      backgroundColor: scheme.error,
      textColor: scheme.onError,
      child: icon,
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Unread badge count, refreshed on alert screen visits and socket alerts.
final StateProvider<int> unreadAlertsProvider =
    StateProvider<int>((Ref ref) => 0);
