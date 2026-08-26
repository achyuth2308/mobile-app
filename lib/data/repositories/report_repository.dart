import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../providers/fleet_provider.dart';
import '../models/report_models.dart';
import '../models/vehicle.dart';

class ReportRepository {
  ReportRepository(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  /// Runs any `/api/reports/*` endpoint with a normalised query shape.
  Future<ReportResult> run({
    required ReportType type,
    required DateTime start,
    required DateTime end,
    String? vehicleId,
    List<String>? vehicleIds,
    CancelToken? cancelToken,
  }) async {
    // For reports with no vehicle selected, fetch all vehicles in parallel if it is not a fleet-wide consolidated/individual/routeHistory report
    final bool isFleetWideParallel = vehicleId == null &&
        type != ReportType.consolidated &&
        type != ReportType.individual &&
        type != ReportType.routeHistory;

    final List<Vehicle> vehicles = _ref.read(fleetProvider).vehicles;

    if (isFleetWideParallel) {
      final List<String> allIds = vehicles.map((v) => v.id).toList();
      if (allIds.isNotEmpty) {
        // Fetch each vehicle — ignore individual failures so one bad vehicle
        // doesn't wipe the whole result set.
        final List<ReportResult> results = (await Future.wait(
          allIds.map((String id) async {
            final Vehicle? vehicle = vehicles.where((v) => v.id == id).firstOrNull;
            try {
              final ReportResult res = await _fetch(
                type: type,
                start: start,
                end: end,
                vehicleId: id,
                vehicle: vehicle,
                cancelToken: cancelToken,
              );

              // Filter row matching this vehicle (only for Consolidated)
              ReportResult filteredRes = res;
              if (type == ReportType.consolidated) {
                final List<ReportRow> matchingRows = res.rows.where((ReportRow row) =>
                  row.vehicleId == id ||
                  row.vehicleName == vehicle?.displayName ||
                  row.raw['vehicle_id'] == id
                ).toList();
                filteredRes = ReportResult(
                  rows: matchingRows,
                  summary: ReportSummary.fromRows(matchingRows),
                  columns: res.columns,
                );
              }

              return await _enrichResult(
                res: filteredRes,
                type: type,
                vehicle: vehicle,
                id: id,
                start: start,
                end: end,
                cancelToken: cancelToken,
              );
            } catch (err) {
              debugPrint('FETCH FAILED FOR VEHICLE $id ($type): $err');
              return ReportResult(rows: const <ReportRow>[], summary: const ReportSummary());
            }
          }),
        ));
        final List<ReportRow> merged =
            results.expand((ReportResult r) => r.rows).toList();

        // De-duplicate rows by vehicle identification and date to handle bulk endpoints gracefully
        final Map<String, ReportRow> uniqueMap = <String, ReportRow>{};
        for (final ReportRow r in merged) {
          final String key = '${r.vehicleName ?? r.vehicleId ?? ""}_${r.plate ?? ""}_${r.date ?? ""}';
          uniqueMap[key] = r;
        }
        final List<ReportRow> deduplicated = uniqueMap.values.toList();

        return ReportResult(rows: deduplicated, summary: ReportSummary.fromRows(deduplicated));
      }
    }

    final Vehicle? vehicle = vehicleId != null
        ? vehicles.where((v) => v.id == vehicleId).firstOrNull
        : null;

    final ReportResult singleRes = await _fetch(
      type: type,
      start: start,
      end: end,
      vehicleId: vehicleId,
      vehicle: vehicle,
      vehicleIds: vehicleIds,
      cancelToken: cancelToken,
    );

    return await _enrichResult(
      res: singleRes,
      type: type,
      vehicle: vehicle,
      id: vehicleId,
      start: start,
      end: end,
      cancelToken: cancelToken,
    );
  }

  /// Helper to enrich and synthesize report results client-side (locations & odometer).
  Future<ReportResult> _enrichResult({
    required ReportResult res,
    required ReportType type,
    required Vehicle? vehicle,
    required String? id,
    required DateTime start,
    required DateTime end,
    required CancelToken? cancelToken,
  }) async {
    ReportResult processedRes = res;

    // 1. CONSOLIDATED ENRICHMENT & SYNTHESIS
    if (type == ReportType.consolidated) {
      if (processedRes.rows.isEmpty) {
        try {
          final ReportResult trips = await _fetch(
            type: ReportType.trip,
            start: start,
            end: end,
            vehicleId: id,
            vehicle: vehicle,
            cancelToken: cancelToken,
          );

          final int periodSeconds = end.difference(start).inSeconds;
          final List<ReportRow> updatedRows = <ReportRow>[];

          if (trips.rows.isNotEmpty) {
            final double totalDistance = trips.rows.map((r) => r.distanceTravelled ?? 0.0).fold(0.0, (a, b) => a + b);
            final int totalRunningSeconds = trips.rows.map((r) => r.durationSeconds ?? 0).fold(0, (a, b) => a + b);

            final double? startFuel = trips.rows.first.startFuel;
            final double? endFuel = trips.rows.last.endFuel;
            final double totalConsumption = trips.rows.map((r) => r.consumption ?? 0.0).fold(0.0, (a, b) => a + b);
            final double totalFilling = trips.rows.map((r) => r.filling ?? 0.0).fold(0.0, (a, b) => a + b);
            final double totalTheft = trips.rows.map((r) => r.theft ?? 0.0).fold(0.0, (a, b) => a + b);

            final int stoppedSeconds = (periodSeconds > totalRunningSeconds) ? (periodSeconds - totalRunningSeconds) : 0;

            final Map<String, dynamic> syntheticRaw = <String, dynamic>{
              'vehicle_id': id,
              'vehicle_name': vehicle?.displayName ?? '',
              'plate': vehicle?.registrationNumber ?? '',
              'registrationNumber': vehicle?.registrationNumber ?? '',
              'distance_travelled': totalDistance,
              'running_seconds': totalRunningSeconds,
              'stopped_seconds': stoppedSeconds,
              'idle_seconds': 0,
              'start_fuel': startFuel,
              'end_fuel': endFuel,
              'consumption': totalConsumption,
              'filling': totalFilling,
              'theft': totalTheft,
              'start_lat': trips.rows.first.startLat,
              'start_lng': trips.rows.first.startLng,
              'end_lat': trips.rows.last.endLat,
              'end_lng': trips.rows.last.endLng,
              'from_location': trips.rows.first.fromLocation,
              'to_location': trips.rows.last.toLocation,
            };
            updatedRows.add(ReportRow.fromJson(syntheticRaw));
          } else {
            final Map<String, dynamic> syntheticRaw = <String, dynamic>{
              'vehicle_id': id,
              'vehicle_name': vehicle?.displayName ?? '',
              'plate': vehicle?.registrationNumber ?? '',
              'registrationNumber': vehicle?.registrationNumber ?? '',
              'distance_travelled': 0.0,
              'running_seconds': 0,
              'stopped_seconds': periodSeconds,
              'idle_seconds': 0,
              'start_fuel': vehicle?.fuelLevel,
              'end_fuel': vehicle?.fuelLevel,
              'consumption': 0.0,
              'filling': 0.0,
              'theft': 0.0,
              'start_lat': vehicle?.latitude,
              'start_lng': vehicle?.longitude,
              'end_lat': vehicle?.latitude,
              'end_lng': vehicle?.longitude,
            };
            updatedRows.add(ReportRow.fromJson(syntheticRaw));
          }
          processedRes = ReportResult(
            rows: updatedRows,
            summary: ReportSummary.fromRows(updatedRows),
            columns: updatedRows.isEmpty ? <String>[] : updatedRows.first.cells.keys.toList(),
          );
        } catch (e) {
          debugPrint('Failed to synthesize consolidated report for vehicle $id: $e');
        }
      } else {
        try {
          final ReportResult trips = await _fetch(
            type: ReportType.trip,
            start: start,
            end: end,
            vehicleId: id,
            vehicle: vehicle,
            cancelToken: cancelToken,
          );
          if (trips.rows.isNotEmpty) {
            final ReportRow firstTrip = trips.rows.first;
            final ReportRow lastTrip = trips.rows.last;
            final List<ReportRow> updatedRows = <ReportRow>[];
            for (final ReportRow row in processedRes.rows) {
              final Map<String, dynamic> mutableRaw = Map<String, dynamic>.of(row.raw);
              mutableRaw['start_lat'] = firstTrip.startLat;
              mutableRaw['start_lng'] = firstTrip.startLng;
              mutableRaw['end_lat'] = lastTrip.endLat;
              mutableRaw['end_lng'] = lastTrip.endLng;
              mutableRaw['from_location'] = firstTrip.fromLocation;
              mutableRaw['to_location'] = lastTrip.toLocation;
              updatedRows.add(ReportRow.fromJson(mutableRaw));
            }
            processedRes = ReportResult(
              rows: updatedRows,
              summary: ReportSummary.fromRows(updatedRows),
              columns: updatedRows.isEmpty ? <String>[] : updatedRows.first.cells.keys.toList(),
            );
          } else {
            if (vehicle != null && vehicle.latitude != null && vehicle.longitude != null) {
              final List<ReportRow> updatedRows = <ReportRow>[];
              for (final ReportRow row in processedRes.rows) {
                final Map<String, dynamic> mutableRaw = Map<String, dynamic>.of(row.raw);
                mutableRaw['start_lat'] = vehicle.latitude;
                mutableRaw['start_lng'] = vehicle.longitude;
                mutableRaw['end_lat'] = vehicle.latitude;
                mutableRaw['end_lng'] = vehicle.longitude;
                updatedRows.add(ReportRow.fromJson(mutableRaw));
              }
              processedRes = ReportResult(
                rows: updatedRows,
                summary: ReportSummary.fromRows(updatedRows),
                columns: updatedRows.isEmpty ? <String>[] : updatedRows.first.cells.keys.toList(),
              );
            }
          }
        } catch (e) {
          debugPrint('Failed to enrich locations for vehicle $id: $e');
        }
      }
    }

    // 2. DAILY DISTANCE ODOMETER BACK-CALCULATION
    if (type == ReportType.distance && processedRes.rows.isNotEmpty) {
      try {
        final List<ReportRow> sortedRows = List<ReportRow>.from(processedRes.rows)
          ..sort((ReportRow a, ReportRow b) {
            final DateTime da = a.date ?? DateTime(2000);
            final DateTime db = b.date ?? DateTime(2000);
            return db.compareTo(da); // Descending (newest first)
          });

        double runningOdo = vehicle?.odometer ?? 0.0;
        final List<ReportRow> updatedRows = <ReportRow>[];

        for (final ReportRow row in sortedRows) {
          final double dist = row.distanceTravelled ?? 0.0;
          final Map<String, dynamic> mutableRaw = Map<String, dynamic>.of(row.raw);

          if (vehicle != null && vehicle.odometer != null && vehicle.odometer! > 0) {
            mutableRaw['end_odometer'] = runningOdo;
            mutableRaw['start_odometer'] = runningOdo - dist;
            runningOdo = runningOdo - dist;
          }

          updatedRows.add(ReportRow.fromJson(mutableRaw));
        }

        // Keep them sorted descending (newest first)
        processedRes = ReportResult(
          rows: updatedRows,
          summary: ReportSummary.fromRows(updatedRows),
          columns: updatedRows.isEmpty ? <String>[] : updatedRows.first.cells.keys.toList(),
        );
      } catch (e) {
        debugPrint('Failed to back-calculate odometer for vehicle $id: $e');
      }
    }

    return processedRes;
  }

  Future<ReportResult> _fetch({
    required ReportType type,
    required DateTime start,
    required DateTime end,
    String? vehicleId,
    Vehicle? vehicle,
    List<String>? vehicleIds,
    CancelToken? cancelToken,
  }) async {
    final dynamic res = await _api.get<dynamic>(
      type.path,
      query: <String, dynamic>{
        'startDate': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
        'from': start.toUtc().toIso8601String(),
        'to': end.toUtc().toIso8601String(),
        if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
        if (vehicleIds != null && vehicleIds.isNotEmpty)
          'vehicleIds': vehicleIds.join(','),
        if (type == ReportType.idle) 'onlyIdle': true,
      },
      cancelToken: cancelToken,
    );

    dynamic filteredRes = res;
    if (vehicleId != null && type != ReportType.consolidated) {
      filteredRes = _filterPayloadByVehicle(res, vehicleId);
    }

    if (vehicle != null && type != ReportType.consolidated) {
      _injectVehicleDetails(filteredRes, vehicle);
    }

    debugPrint('API RESPONSE FOR ${type.name}: $filteredRes');

    return ReportResult.parse(filteredRes);
  }

  dynamic _filterPayloadByVehicle(dynamic payload, String vehicleId) {
    if (payload is List) {
      return payload.where((item) {
        if (item is Map) {
          final String? rowVehicleId = item['vehicle_id']?.toString() ??
              item['vehicleId']?.toString() ??
              item['id']?.toString() ??
              item['deviceId']?.toString() ??
              item['device_id']?.toString();
          if (rowVehicleId != null && rowVehicleId.isNotEmpty) {
            return rowVehicleId == vehicleId;
          }
        }
        return true;
      }).toList();
    } else if (payload is Map<String, dynamic>) {
      final Map<String, dynamic> copy = Map<String, dynamic>.of(payload);
      copy.forEach((key, val) {
        if (val is List || val is Map) {
          copy[key] = _filterPayloadByVehicle(val, vehicleId);
        }
      });
      return copy;
    } else if (payload is Map) {
      try {
        final Map copy = Map.of(payload);
        copy.forEach((key, val) {
          if (val is List || val is Map) {
            copy[key] = _filterPayloadByVehicle(val, vehicleId);
          }
        });
        return copy;
      } catch (_) {}
    }
    return payload;
  }

  void _injectVehicleDetails(dynamic payload, Vehicle vehicle) {
    final String vehicleName = vehicle.displayName;
    final String registrationNumber = vehicle.registrationNumber;

    if (payload is List) {
      for (final dynamic item in payload) {
        if (item is Map<String, dynamic>) {
          item['vehicle_name'] = vehicleName;
          item['registrationNumber'] = registrationNumber;
          item['plate'] = registrationNumber;
        } else if (item is Map) {
          try {
            item['vehicle_name'] = vehicleName;
            item['registrationNumber'] = registrationNumber;
            item['plate'] = registrationNumber;
          } catch (_) {}
        }
      }
    } else if (payload is Map<String, dynamic>) {
      payload['vehicle_name'] = vehicleName;
      payload['registrationNumber'] = registrationNumber;
      payload['plate'] = registrationNumber;
      payload.forEach((String key, dynamic val) {
        if (val is List || val is Map) {
          _injectVehicleDetails(val, vehicle);
        }
      });
    } else if (payload is Map) {
      try {
        payload['vehicle_name'] = vehicleName;
        payload['registrationNumber'] = registrationNumber;
        payload['plate'] = registrationNumber;
      } catch (_) {}
      payload.forEach((dynamic key, dynamic val) {
        if (val is List || val is Map) {
          _injectVehicleDetails(val, vehicle);
        }
      });
    }
  }
}
