import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/route.dart';
import '../data/repositories/route_repository.dart';
import 'core_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class RouteState {
  const RouteState({
    this.routes = const <AppRoute>[],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<AppRoute> routes;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  RouteState copyWith({
    List<AppRoute>? routes,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      RouteState(
        routes: routes ?? this.routes,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class RouteController extends Notifier<RouteState> {
  @override
  RouteState build() => const RouteState();

  RouteRepository get _repo => ref.read(routeRepositoryProvider);

  // ── Load ──────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<AppRoute> routes = await _repo.getRoutes();
      state = state.copyWith(routes: routes, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // ── Create ────────────────────────────────────────────────────

  Future<AppRoute?> create(AppRoute route) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final AppRoute created = await _repo.createRoute(route);
      state = state.copyWith(
        isSaving: false,
        routes: <AppRoute>[...state.routes, created],
      );
      return created;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  // ── Assign vehicles ────────────────────────────────────────────

  Future<bool> assign(String routeId, List<String> vehicleIds) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.assignRoute(routeId, vehicleIds);
      // Update local state to reflect assignment
      final List<AppRoute> updated = state.routes.map((AppRoute r) {
        if (r.id == routeId) return r.copyWith(vehicleIds: vehicleIds);
        return r;
      }).toList();
      state = state.copyWith(isSaving: false, routes: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  // ── Toggle active ──────────────────────────────────────────────

  Future<void> toggleActive(AppRoute route) async {
    try {
      final AppRoute updated = await _repo.updateRoute(
        route.id,
        isActive: !route.isActive,
      );
      final List<AppRoute> next = state.routes
          .map((AppRoute r) => r.id == route.id ? updated : r)
          .toList();
      state = state.copyWith(routes: next);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Delete ────────────────────────────────────────────────────

  Future<bool> delete(String routeId) async {
    try {
      await _repo.deleteRoute(routeId);
      state = state.copyWith(
        routes: state.routes.where((AppRoute r) => r.id != routeId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final Provider<RouteRepository> routeRepositoryProvider =
    Provider<RouteRepository>(
        (Ref ref) => RouteRepository(ref.watch(apiClientProvider)));

final NotifierProvider<RouteController, RouteState> routeProvider =
    NotifierProvider<RouteController, RouteState>(RouteController.new);
