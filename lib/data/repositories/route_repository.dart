import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/json_utils.dart';
import '../models/route.dart';

/// All route API calls go through `/api/vehicles/routes/*` which is
/// accessible to any authenticated user, including the 'customer' role.
class RouteRepository {
  RouteRepository(this._api);

  final ApiClient _api;

  // ── Read ──────────────────────────────────────────────────────────

  Future<List<AppRoute>> getRoutes() async {
    try {
      final dynamic res = await _api.get<dynamic>('/vehicles/routes/list');
      return asMapList(res)
          .map(AppRoute.fromJson)
          .where((AppRoute r) => r.id.isNotEmpty)
          .toList(growable: false);
    } on ApiException {
      rethrow;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────

  Future<AppRoute> createRoute(AppRoute route) async {
    final dynamic res = await _api.post<dynamic>(
      '/vehicles/routes/create',
      body: route.toCreateJson(),
    );
    final Map<String, dynamic> data =
        res is Map<String, dynamic> ? res : <String, dynamic>{};
    return AppRoute.fromJson(data);
  }

  Future<AppRoute> updateRoute(
    String id, {
    String? name,
    List<Map<String, double>>? coordinates,
    double? tolerance,
    bool? isActive,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      if (name != null) 'name': name,
      if (coordinates != null) 'coordinates': coordinates,
      if (tolerance != null) 'tolerance': tolerance.round(),
      if (isActive != null) 'is_active': isActive,
    };
    final dynamic res =
        await _api.put<dynamic>('/vehicles/routes/$id', body: body);
    final Map<String, dynamic> data =
        res is Map<String, dynamic> ? res : <String, dynamic>{};
    return AppRoute.fromJson(data);
  }

  Future<void> deleteRoute(String id) =>
      _api.delete<dynamic>('/vehicles/routes/$id');

  // ── Assignment ────────────────────────────────────────────────────

  /// Assigns a list of vehicle IDs to this route.
  /// Passing an empty list unassigns all vehicles.
  Future<void> assignRoute(String routeId, List<String> vehicleIds) =>
      _api.post<dynamic>(
        '/vehicles/routes/$routeId/assign',
        body: <String, dynamic>{'vehicleIds': vehicleIds},
      );
}
