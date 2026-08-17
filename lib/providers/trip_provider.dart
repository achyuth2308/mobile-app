import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_trip.dart';
import '../data/repositories/trip_repository.dart';
import 'core_providers.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class TripState {
  const TripState({
    this.trips = const <UserTrip>[],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<UserTrip> trips;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  List<UserTrip> get activeTrips =>
      trips.where((UserTrip t) => t.isActive).toList();
  List<UserTrip> get plannedTrips =>
      trips.where((UserTrip t) => t.isPlanned).toList();
  List<UserTrip> get completedTrips =>
      trips.where((UserTrip t) => t.isCompleted).toList();

  TripState copyWith({
    List<UserTrip>? trips,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      TripState(
        trips: trips ?? this.trips,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class TripController extends Notifier<TripState> {
  @override
  TripState build() => const TripState();

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<UserTrip> trips = await _repo.getTrips();
      state = state.copyWith(trips: trips, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<UserTrip?> create(UserTrip trip, {bool startNow = false}) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      UserTrip created = await _repo.createTrip(trip);
      if (startNow) {
        created = await _repo.startTrip(created.id);
      }
      state = state.copyWith(
        isSaving: false,
        trips: <UserTrip>[created, ...state.trips],
      );
      return created;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<bool> start(String tripId) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final UserTrip updated = await _repo.startTrip(tripId);
      _replaceTrip(updated);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<bool> end(String tripId) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final UserTrip updated = await _repo.endTrip(tripId);
      _replaceTrip(updated);
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<bool> cancel(String tripId) async {
    try {
      await _repo.cancelTrip(tripId);
      state = state.copyWith(
        trips: state.trips.where((UserTrip t) => t.id != tripId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void _replaceTrip(UserTrip updated) {
    final List<UserTrip> next = state.trips
        .map((UserTrip t) => t.id == updated.id ? updated : t)
        .toList();
    state = state.copyWith(trips: next);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final Provider<TripRepository> tripRepositoryProvider =
    Provider<TripRepository>((Ref ref) => TripRepository(ref.watch(apiClientProvider)));

final NotifierProvider<TripController, TripState> tripProvider =
    NotifierProvider<TripController, TripState>(TripController.new);
