import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/report_models.dart';

class ReportRepository {
  ReportRepository(this._api);

  final ApiClient _api;

  /// Runs any `/api/reports/*` endpoint with a normalised query shape.
  Future<ReportResult> run({
    required ReportType type,
    required DateTime start,
    required DateTime end,
    String? vehicleId,
    List<String>? vehicleIds,
    CancelToken? cancelToken,
  }) async {
    final dynamic res = await _api.get<dynamic>(
      type.path,
      query: <String, dynamic>{
        'startDate': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
        // Several backends read `from`/`to` instead — send both, the
        // unused pair is ignored server-side.
        'from': start.toUtc().toIso8601String(),
        'to': end.toUtc().toIso8601String(),
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        if (vehicleIds != null && vehicleIds.isNotEmpty)
          'vehicleIds': vehicleIds.join(','),
        if (type == ReportType.idle) 'onlyIdle': true,
      },
      cancelToken: cancelToken,
    );

    return ReportResult.parse(res);
  }
}
