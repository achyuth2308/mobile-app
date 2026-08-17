import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/json_utils.dart';
import '../models/trip.dart';
import '../models/vehicle.dart';

class VehicleRepository {
  VehicleRepository(this._api);

  final ApiClient _api;

  /// `GET /api/vehicles` — the authoritative fleet snapshot.
  ///
  /// Also used as the **foreground re-sync** after the app returns from the
  /// background, before the socket is reconnected.
  Future<List<Vehicle>> getVehicles({CancelToken? cancelToken}) async {
    final dynamic res =
        await _api.get<dynamic>('/vehicles', cancelToken: cancelToken);

    return asMapList(res)
        .map(Vehicle.fromJson)
        .where((Vehicle v) => v.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<Vehicle> getVehicle(String id) async {
    final dynamic res = await _api.get<dynamic>('/vehicles/$id');
    final Map<String, dynamic> map =
        res is Map<String, dynamic> ? res : <String, dynamic>{};
    return Vehicle.fromJson(map);
  }

  /// `GET /api/vehicles/:id/history` — raw GPS fixes for playback.
  Future<List<TrackPoint>> getHistory({
    required String vehicleId,
    required DateTime start,
    required DateTime end,
    CancelToken? cancelToken,
  }) async {
    final dynamic res = await _api.get<dynamic>(
      '/vehicles/$vehicleId/history',
      query: <String, dynamic>{
        'startDate': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
        'from': start.toUtc().toIso8601String(),
        'to': end.toUtc().toIso8601String(),
        'limit': 20000,
      },
      cancelToken: cancelToken,
    );

    final List<Map<String, dynamic>> list = asMapList(res);
    return list
        .map(TrackPoint.fromJson)
        .where((TrackPoint p) => p.isValid)
        .toList(growable: false);
  }

  /// `GET /api/vehicles/:id/route` — coordinate list for the polyline.
  /// Falls back to /history when the route endpoint is unavailable.
  Future<List<TrackPoint>> getRoute({
    required String vehicleId,
    required DateTime start,
    required DateTime end,
  }) async {
    final dynamic res = await _api.get<dynamic>(
      '/vehicles/$vehicleId/route',
      query: <String, dynamic>{
        'startDate': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
        'from': start.toUtc().toIso8601String(),
        'to': end.toUtc().toIso8601String(),
        'limit': 20000,
      },
    );

    final List<TrackPoint> pts = asMapList(res)
        .map(TrackPoint.fromJson)
        .where((TrackPoint p) => p.isValid)
        .toList();

    // Some deployments return a bare [[lat,lng], ...] array.
    if (pts.isEmpty && res is List) {
      final List<TrackPoint> raw = <TrackPoint>[];
      for (final dynamic e in res) {
        if (e is List && e.length >= 2) {
          raw.add(TrackPoint(
            latitude: (e[0] as num).toDouble(),
            longitude: (e[1] as num).toDouble(),
            timestamp: DateTime.now(),
          ));
        }
      }
      return raw;
    }
    return pts;
  }

  /// `GET /api/vehicles/:id/report` — daily aggregate for the detail header.
  Future<Map<String, dynamic>> getDailyReport({
    required String vehicleId,
    DateTime? date,
  }) async {
    final DateTime d = date ?? DateTime.now();
    final dynamic res = await _api.get<dynamic>(
      '/vehicles/$vehicleId/report',
      query: <String, dynamic>{
        'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
      },
    );
    if (res is Map<String, dynamic>) return res;
    return <String, dynamic>{};
  }

  Future<List<Trip>> getTrips({
    required String vehicleId,
    required DateTime start,
    required DateTime end,
  }) async {
    final dynamic res = await _api.get<dynamic>(
      '/reports/trip',
      query: <String, dynamic>{
        'vehicleId': vehicleId,
        'startDate': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
      },
    );
    return asMapList(res).map(Trip.fromJson).toList(growable: false);
  }

  Future<void> sendImmobilizerCommand(String vehicleId, bool cutEngine) async {
    // TODO: Swap this mock with the actual backend API endpoint
    // e.g. await _api.post('/vehicles/$vehicleId/command', body: {'type': cutEngine ? 'engineStop' : 'engineResume'});
    await Future<void>.delayed(const Duration(seconds: 2));
    if (vehicleId.isEmpty) {
      throw Exception('Invalid vehicle ID');
    }
  }

  Future<void> updateSettings(String vehicleId, {
    double? overSpeedLimit,
    double? overspeedDurationAlert,
    double? idleDurationAlert,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (overSpeedLimit != null) body['overSpeedLimit'] = overSpeedLimit;
    if (overspeedDurationAlert != null) body['overspeedDurationAlert'] = overspeedDurationAlert;
    if (idleDurationAlert != null) body['idleDurationAlert'] = idleDurationAlert;

    if (body.isEmpty) return;

    await _api.patch<dynamic>('/vehicles/$vehicleId/settings', body: body);
  }
}
