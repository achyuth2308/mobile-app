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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
    );
  }
}
