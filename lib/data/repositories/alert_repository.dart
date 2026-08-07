import '../../core/config/backend_capabilities.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/alert.dart';
import '../models/json_utils.dart';

class AlertRepository {
  AlertRepository(this._api);

  final ApiClient _api;

  Future<List<FleetAlert>> getAlerts({
    int page = 1,
    int limit = 30,
    String? vehicleId,
    String? type,
    DateTime? start,
    DateTime? end,
  }) async {
    // `/api/alerts` is not deployed yet (404). Return empty so the screen
    // shows an honest "not enabled" state instead of a red error.
    if (!BackendCapabilities.alertsHistory) return const <FleetAlert>[];

    final dynamic res = await _api.get<dynamic>(
      '/alerts',
      query: <String, dynamic>{
        'page': page,
        'limit': limit,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (type != null) 'alertType': type,
        if (type != null) 'type': type,
        if (start != null) 'startDate': start.toUtc().toIso8601String(),
        if (end != null) 'endDate': end.toUtc().toIso8601String(),
      },
    );

    return asMapList(res)
        .map(FleetAlert.fromJson)
        .where((FleetAlert a) => a.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> getUnreadCount() async {
    if (!BackendCapabilities.alertsHistory) return 0;
    try {
      final dynamic res = await _api.get<dynamic>('/alerts/unread-count');
      if (res is Map<String, dynamic>) {
        return asInt(res, <String>['count', 'unread', 'total']);
      }
      if (res is num) return res.toInt();
    } on ApiException {
      // Endpoint is optional — the badge simply stays hidden.
    }
    return 0;
  }

  Future<void> markAsRead(String alertId) async {
    try {
      await _api.put<dynamic>('/alerts/$alertId/read');
    } on ApiException {/* non-critical */}
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.put<dynamic>('/alerts/read-all');
    } on ApiException {/* non-critical */}
  }

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final dynamic res = await _api.get<dynamic>('/alerts/preferences');
      if (res is Map<String, dynamic>) return res;
      if (res is Map) return Map<String, dynamic>.from(res);
    } on ApiException {/* fallback to local */}
    return <String, dynamic>{};
  }

  Future<void> updatePreferences(Map<String, bool> preferences) async {
    try {
      await _api.put<dynamic>('/alerts/preferences', body: preferences);
    } on ApiException {/* non-critical */}
  }
}
