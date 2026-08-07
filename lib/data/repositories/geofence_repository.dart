import '../../core/config/backend_capabilities.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/geofence.dart';
import '../models/json_utils.dart';

class GeofenceRepository {
  GeofenceRepository(this._api);

  final ApiClient _api;

  Future<List<Geofence>> getGeofences() async {
    if (!BackendCapabilities.geofences) return const <Geofence>[];

    final dynamic res = await _api.get<dynamic>('/admin/geofences');
    return asMapList(res)
        .map(Geofence.fromJson)
        .where((Geofence g) => g.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<Geofence> create(Geofence geofence) async {
    if (!BackendCapabilities.geofences) {
      throw const ApiException(
        message: 'Geofencing is not enabled on your account yet.',
        statusCode: 404,
      );
    }
    final dynamic res = await _api.post<dynamic>(
      '/admin/geofences',
      body: geofence.toCreateJson(),
    );
    return Geofence.fromJson(
      res is Map<String, dynamic> ? res : <String, dynamic>{},
    );
  }

  Future<Geofence> update(String id, Map<String, dynamic> changes) async {
    final dynamic res = await _api.put<dynamic>('/admin/geofences/$id', body: changes);
    return Geofence.fromJson(
      res is Map<String, dynamic> ? res : <String, dynamic>{},
    );
  }

  Future<void> delete(String id) => _api.delete<dynamic>('/admin/geofences/$id');
}
