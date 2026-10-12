import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/realtime/socket_service.dart';
import '../data/models/vehicle.dart';
import 'core_providers.dart';
import 'fleet_provider.dart';

/// Manages the unread alert count for the app bar bell badge and live alerts.
class UnreadAlertsCountNotifier extends StateNotifier<int> {
  UnreadAlertsCountNotifier(this._ref) : super(0) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<SocketEvent>? _socketSub;

  Future<void> _init() async {
    // Initial fetch
    unawaited(refresh());

    // Listen to real-time events from the socket connection
    try {
      _socketSub = _ref.read(socketServiceProvider).events$.listen((SocketEvent event) {
        if (event.name == 'alert:new' || event.name == 'geofence:event') {
          state = state + 1;
        }
      });
    } catch (_) {}
  }

  /// Refreshes the unread count from the backend API or fleet alerts list.
  Future<void> refresh() async {
    try {
      final repo = _ref.read(alertRepositoryProvider);
      final List<Vehicle> vehicles = _ref.read(fleetProvider).vehicles;
      final List<String> vIds = vehicles.map((Vehicle v) => v.id).toList();

      final int count = await repo.getUnreadCount(vehicleIds: vIds);
      state = count;
    } catch (_) {}
  }

  void increment() {
    state = state + 1;
  }

  void reset() {
    state = 0;
  }

  void setCount(int count) {
    state = count.clamp(0, 9999);
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<UnreadAlertsCountNotifier, int>
    unreadAlertsCountProvider =
    StateNotifierProvider<UnreadAlertsCountNotifier, int>(
  (Ref ref) => UnreadAlertsCountNotifier(ref),
);
