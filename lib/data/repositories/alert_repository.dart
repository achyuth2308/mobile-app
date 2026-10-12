import '../../core/config/backend_capabilities.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/secure_store.dart';
import '../models/alert.dart';
import '../models/json_utils.dart';

class AlertRepository {
  AlertRepository(this._api, this._store);

  final ApiClient _api;
  final SecureStore _store;

  Future<List<FleetAlert>> getAlerts({
    int page = 1,
    int limit = 30,
    String? vehicleId,
    String? type,
    DateTime? start,
    DateTime? end,
    List<String>? vehicleIds,
  }) async {
    // `/api/alerts` is not deployed yet (404). Return empty so the screen
    // shows an honest "not enabled" state instead of a red error.
    if (!BackendCapabilities.alertsHistory) return const <FleetAlert>[];

    final Set<String> deletedIds = _store.getDeletedAlertIds();

    final String url = vehicleId != null ? '/vehicles/$vehicleId/alerts' : '/alerts';
    try {
      final dynamic res = await _api.get<dynamic>(
        url,
        query: <String, dynamic>{
          'page': page,
          'limit': limit,
          if (type != null) 'alertType': type,
          if (type != null) 'type': type,
          if (start != null) 'startDate': start.toUtc().toIso8601String(),
          if (end != null) 'endDate': end.toUtc().toIso8601String(),
        },
      );

      final DateTime? lastReadTime = _store.getLastAlertsReadTime();
      final Set<String> readIds = _store.getReadAlertIds();

      final List<FleetAlert> alerts = asMapList(res)
          .map(FleetAlert.fromJson)
          .where((FleetAlert a) =>
              a.id.isNotEmpty &&
              !deletedIds.contains(a.id) &&
              a.type.toLowerCase().trim() != 'stoppage')
          .map((FleetAlert a) {
            final bool isLocallyRead = a.isRead ||
                readIds.contains(a.id) ||
                (lastReadTime != null &&
                    a.createdAt != null &&
                    !a.createdAt!.isAfter(lastReadTime));
            return isLocallyRead ? a.copyWith(isRead: true) : a;
          })
          .toList(growable: false);

      if (alerts.isNotEmpty || vehicleId != null) {
        return alerts;
      }
    } catch (_) {}

    // Fallback: If /alerts returned empty and vehicleId is null (Fleet mode),
    // aggregate alerts from the fleet vehicles directly so all notifications are guaranteed to display!
    if (vehicleId == null && vehicleIds != null && vehicleIds.isNotEmpty) {
      try {
        final List<List<FleetAlert>> perVehicle = await Future.wait(
          vehicleIds.map(
            (vId) => getAlerts(
              vehicleId: vId,
              type: type,
              start: start,
              end: end,
              limit: 25,
            ),
          ),
        );
        final DateTime? lastReadTime = _store.getLastAlertsReadTime();
        final Set<String> readIds = _store.getReadAlertIds();
        final List<FleetAlert> combined = perVehicle
            .expand((l) => l)
            .map((FleetAlert a) {
              final bool isLocallyRead = a.isRead ||
                  readIds.contains(a.id) ||
                  (lastReadTime != null &&
                      a.createdAt != null &&
                      !a.createdAt!.isAfter(lastReadTime));
              return isLocallyRead ? a.copyWith(isRead: true) : a;
            })
            .toList();
        combined.sort((a, b) {
          final DateTime tA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime tB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tB.compareTo(tA);
        });
        return combined;
      } catch (_) {}
    }

    return const <FleetAlert>[];
  }

  Future<int> getUnreadCount({List<String>? vehicleIds}) async {
    final DateTime? lastReadTime = _store.getLastAlertsReadTime();

    // If server provides unread count AND we haven't marked everything read locally
    if (BackendCapabilities.alertsHistory && lastReadTime == null) {
      try {
        final dynamic res = await _api.get<dynamic>('/alerts/unread-count');
        if (res is Map<String, dynamic>) {
          return asInt(res, <String>['count', 'unread', 'total']);
        }
        if (res is num) return res.toInt();
      } on ApiException {/* optional */}
    }

    // Otherwise compute accurate unread count from recent alerts
    final List<FleetAlert> recent = await getAlerts(
      limit: 50,
      vehicleIds: vehicleIds,
    );
    return recent.where((FleetAlert a) => !a.isRead).length;
  }

  Future<void> markAsRead(String alertId) async {
    await _store.addReadAlertId(alertId);
    try {
      await _api.put<dynamic>('/alerts/$alertId/read');
    } on ApiException {/* non-critical */}
  }

  Future<void> markAllAsRead({DateTime? upToTime}) async {
    await _store.setLastAlertsReadTime(upToTime ?? DateTime.now());
    try {
      await _api.put<dynamic>('/alerts/read-all');
    } on ApiException {/* non-critical */}
  }

  Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final dynamic res = await _api.get<dynamic>('/alerts/preferences');
      if (res is Map<String, dynamic> && res['preferences'] is Map) {
        return Map<String, dynamic>.from(res['preferences']);
      }
    } on ApiException {/* fallback to local */}
    return null;
  }

  Future<void> updatePreferences(Map<String, bool> preferences) async {
    try {
      await _api.put<dynamic>('/alerts/preferences', body: <String, dynamic>{
        'preferences': preferences,
      });
    } on ApiException {/* non-critical */}
  }

  Future<void> deleteAlert(String alertId) async {
    await _store.addDeletedAlertId(alertId);
    try {
      await _api.delete<dynamic>('/alerts/$alertId');
    } on ApiException {/* non-critical */}
  }

  Future<void> deleteAlerts(Iterable<String> alertIds) async {
    await _store.addDeletedAlertIds(alertIds);
    for (final String id in alertIds) {
      try {
        await _api.delete<dynamic>('/alerts/$id');
      } catch (_) {}
    }
  }

  Future<void> clearVehicleAlerts(String vehicleId) async {
    try {
      await _api.delete<dynamic>('/vehicles/$vehicleId/alerts');
    } on ApiException {/* non-critical */}
  }

  Future<void> clearAllAlerts() async {
    try {
      await _api.delete<dynamic>('/alerts');
    } on ApiException {/* non-critical */}
  }
}
