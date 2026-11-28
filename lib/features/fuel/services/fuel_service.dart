import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../data/models/json_utils.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/core_providers.dart';
import '../models/fuel_telemetry_point.dart';

final Provider<FuelService> fuelServiceProvider =
    Provider<FuelService>((Ref ref) => FuelService(ref.read(apiClientProvider)));

final AutoDisposeFutureProviderFamily<Map<String, dynamic>?, String> manualFuelStateProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((Ref ref, String vehicleId) async {
  final FuelService service = ref.watch(fuelServiceProvider);
  return service.getManualFuelState(vehicleId);
});

enum FuelInterval {
  filtered('Filtered', Duration.zero),
  raw('Raw', Duration.zero),
  oneMin('1 min', Duration(minutes: 1)),
  fiveMin('5 min', Duration(minutes: 5)),
  fifteenMin('15 min', Duration(minutes: 15)),
  thirtyMin('30 min', Duration(minutes: 30));

  const FuelInterval(this.label, this.duration);
  final String label;
  final Duration duration;
}

class FuelReportData {
  const FuelReportData({
    required this.points,
    required this.summary,
    this.rawCount = 0,
    this.refuelEvents = const <Map<String, dynamic>>[],
    this.theftEvents = const <Map<String, dynamic>>[],
  });

  final List<FuelTelemetryPoint> points;
  final FuelReportSummary summary;
  final int rawCount;
  final List<Map<String, dynamic>> refuelEvents;
  final List<Map<String, dynamic>> theftEvents;
}

class FuelService {
  FuelService(this._api);

  final ApiClient _api;

  /// Fetches telemetry packets for the given vehicle and time range,
  /// matching the web app's fuel-analytics endpoint and algorithmic pipeline.
  Future<FuelReportData> getFuelReport({
    required String vehicleId,
    required DateTime start,
    required DateTime end,
    FuelInterval interval = FuelInterval.filtered,
    Vehicle? vehicle,
    CancelToken? cancelToken,
  }) async {
    final String sIso = start.toUtc().toIso8601String();
    final String eIso = end.toUtc().toIso8601String();

    List<Map<String, dynamic>> rawList = <Map<String, dynamic>>[];

    // 1. Fetch exactly like the web app: /vehicles/:id/history?startDate=...&endDate=...&sample=true&noCount=true&maxPoints=500
    try {
      final dynamic res = await _api.get<dynamic>(
        '/vehicles/$vehicleId/history',
        query: <String, dynamic>{
          'startDate': sIso,
          'endDate': eIso,
          'sample': true,
          'noCount': true,
          'maxPoints': 500,
        },
        cancelToken: cancelToken,
      );
      final List<Map<String, dynamic>> list = asMapList(res);
      if (list.isNotEmpty) {
        rawList = list;
      }
    } catch (e) {
      debugPrint('History fetch with web params failed, trying fallback: $e');
    }

    if (rawList.isEmpty) {
      try {
        final dynamic res = await _api.get<dynamic>(
          '/vehicles/$vehicleId/history',
          query: <String, dynamic>{
            'startDate': sIso,
            'endDate': eIso,
            'from': sIso,
            'to': eIso,
            'limit': 10000,
          },
          cancelToken: cancelToken,
        );
        rawList = asMapList(res);
      } catch (_) {}
    }

    if (rawList.isEmpty) {
      return FuelReportData(
        points: const <FuelTelemetryPoint>[],
        summary: FuelReportSummary(
          startDate: start,
          endDate: end,
          vehicleGroup: vehicle?.type ?? 'All Groups',
        ),
      );
    }

    // Sort ascending by device_time
    rawList.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final DateTime? da = asDate(a, <String>['device_time', 'time', 'timestamp']);
      final DateTime? db = asDate(b, <String>['device_time', 'time', 'timestamp']);
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });

    // 2. Resolve Vehicle Calibration Specs (je, Me, Ne from Web App)
    final Map<String, dynamic> rawVehicle = vehicle?.raw ?? <String, dynamic>{};
    final Map<String, dynamic> meta = (rawVehicle['metadata'] is Map)
        ? Map<String, dynamic>.from(rawVehicle['metadata'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> calib = (meta['fuelCalibration'] is Map)
        ? Map<String, dynamic>.from(meta['fuelCalibration'] as Map)
        : (meta['fuel'] is Map
            ? Map<String, dynamic>.from(meta['fuel'] as Map)
            : <String, dynamic>{});

    double tankSize = 300.0;
    if (calib['tanks'] is Map) {
      final Map tanks = calib['tanks'] as Map;
      double sum = 0.0;
      for (final Object? t in tanks.values) {
        if (t is Map) {
          sum += toDouble(t['tankSize']) ?? 0.0;
        }
      }
      if (sum > 0) tankSize = (sum * 10).round() / 10.0;
    } else {
      final double? parsedTank = toDouble(
          calib['tankSize'] ?? meta['tankSize'] ?? meta['tankCapacity'] ?? rawVehicle['tankCapacity']);
      if (parsedTank != null && parsedTank > 0) {
        tankSize = parsedTank;
      }
    }

    final double minFilling = toDouble(calib['minFilling']) ?? 9.0;
    final double minTheft = toDouble(calib['minTheft']) ?? 5.0;

    // 3. Web App Point Calibration Function Pe(rawFuel, time)
    double? calibrateFuel(dynamic rawFuelVal, DateTime? deviceTime) {
      if (rawFuelVal == null) return null;
      final double? n = toDouble(rawFuelVal);
      if (n == null || n.isNaN) return null;

      final DateTime? updatedAt = asDate(calib, <String>['updatedAt']);
      final int o = updatedAt?.millisecondsSinceEpoch ?? 0;
      final int s = deviceTime?.millisecondsSinceEpoch ?? 0;
      final bool c = o > 0 && s >= o;

      if (c && n <= tankSize * 1.15) {
        return (n * 10).round() / 10.0;
      }

      final String calType = asString(calib, <String>['calibrateType'], fallback: 'Auto');
      if (calType == 'Direct') {
        final double mult = asDouble(calib, <String>['directMultiplier'], fallback: 1.0);
        final double offset = asDouble(calib, <String>['directOffset'], fallback: 0.0);
        final String unit = asString(calib, <String>['directUnit'], fallback: 'Litres');
        final double iVal = n * mult + offset;
        if (unit == 'Percentage' && tankSize > 0) {
          return max(0.0, min(tankSize, (iVal / 100.0 * tankSize * 10).round() / 10.0));
        }
        return max(0.0, tankSize > 0 ? min(tankSize, (iVal * 10).round() / 10.0) : (iVal * 10).round() / 10.0);
      }

      List<dynamic> calPoints = <dynamic>[];
      if (calib['calibrationPoints'] is List) {
        calPoints = calib['calibrationPoints'] as List;
      } else if (calib['tanks'] is Map) {
        final Map tanks = calib['tanks'] as Map;
        if (tanks['1'] is Map && tanks['1']['calibrationPoints'] is List) {
          calPoints = tanks['1']['calibrationPoints'] as List;
        } else if (tanks['tank1'] is Map && tanks['tank1']['calibrationPoints'] is List) {
          calPoints = tanks['tank1']['calibrationPoints'] as List;
        }
      }

      if (calPoints.length >= 2) {
        final List<Map<String, double>> pts = calPoints
            .map((p) {
              if (p is! Map) return null;
              final Map m = p;
              final double? adc = toDouble(m['adcValue'] ?? m['frequency'] ?? m['volt']);
              final double? ltr = toDouble(m['litres'] ?? m['liters']);
              if (adc != null && ltr != null && !adc.isNaN && !ltr.isNaN) {
                return <String, double>{'adc': adc, 'ltr': ltr};
              }
              return null;
            })
            .whereType<Map<String, double>>()
            .toList();

        pts.sort((a, b) => a['adc']!.compareTo(b['adc']!));

        if (pts.length >= 2) {
          if (c && n <= pts.last['ltr']! * 1.1) {
            return (n * 10).round() / 10.0;
          }
          if (n <= pts.first['adc']!) return pts.first['ltr']!;
          if (n >= pts.last['adc']!) return pts.last['ltr']!;
          for (int t = 0; t < pts.length - 1; t++) {
            final Map<String, double> p1 = pts[t];
            final Map<String, double> p2 = pts[t + 1];
            if (n >= p1['adc']! && n <= p2['adc']!) {
              final double span = p2['adc']! - p1['adc']!;
              final double frac = span == 0 ? 0.0 : (n - p1['adc']!) / span;
              final double val = p1['ltr']! + frac * (p2['ltr']! - p1['ltr']!);
              return max(0.0, min(tankSize, (val * 10).round() / 10.0));
            }
          }
        }
      }

      final double minAdc = asDouble(calib, <String>['minAdc'],
          fallback: asDouble(meta, <String>['fuelEmptyAdc'], fallback: 0.0));
      final double maxAdc = asDouble(calib, <String>['maxAdc'],
          fallback: asDouble(meta, <String>['fuelFullAdc'], fallback: 4095.0));

      if (tankSize > 0 && maxAdc != minAdc && !minAdc.isNaN && !maxAdc.isNaN && (n > tankSize * 1.15 || !c)) {
        double frac = (n - minAdc) / (maxAdc - minAdc);
        frac = max(0.0, min(1.0, frac));
        return (tankSize * frac * 10).round() / 10.0;
      }

      if (n > 1000) {
        return ((n / 10.0) * 10).round() / 10.0;
      }

      return max(0.0, min(tankSize, (n * 10).round() / 10.0));
    }

    // 4. Map raw points through calibration
    final List<double?> nList = <double?>[];
    for (final Map<String, dynamic> pt in rawList) {
      final dynamic rawF = pt['fuel'] ?? (pt['attributes'] is Map ? pt['attributes']['fuel'] : null);
      final DateTime? t = asDate(pt, <String>['device_time', 'time', 'timestamp']);
      nList.add(calibrateFuel(rawF, t));
    }

    // 5. 5-point moving window median + speed smoothing (r in web app)
    final List<double?> rList = List<double?>.filled(rawList.length, null);
    double? aVal;
    for (int e = 0; e < rawList.length; e++) {
      final List<double> window = <double>[];
      final int startIdx = max(0, e - 2);
      final int endIdx = min(rawList.length - 1, e + 2);
      for (int k = startIdx; k <= endIdx; k++) {
        if (nList[k] != null) window.add(nList[k]!);
      }
      if (window.isNotEmpty) {
        window.sort();
        final double median = window[window.length ~/ 2];
        final double spd = asDouble(rawList[e], <String>['speed']);
        if (aVal == null) {
          aVal = median;
        } else if (spd <= 6) {
          if ((median - aVal).abs() >= 3) {
            aVal = median;
          } else {
            aVal = 0.5 * median + 0.5 * aVal;
          }
        } else {
          aVal = 0.25 * median + 0.75 * aVal;
        }
        rList[e] = max(0.0, min(tankSize, (aVal * 10).round() / 10.0));
      } else {
        rList[e] = aVal;
      }
    }

    // 6. Ignition transition detection for thefts
    final Map<int, double> hMap = <int, double>{};
    final Map<int, double> gMap = <int, double>{};
    const int fiveMinMs = 300 * 1000;

    for (int e = 1; e < rawList.length; e++) {
      final bool prevIgn = asBool(rawList[e - 1], <String>['ignition', 'acc']);
      final bool currIgn = asBool(rawList[e], <String>['ignition', 'acc']);
      final DateTime? currDate = asDate(rawList[e], <String>['device_time', 'time', 'timestamp']);
      final int currMs = currDate?.millisecondsSinceEpoch ?? 0;

      if (prevIgn && !currIgn) {
        final List<double> vals = <double>[];
        for (int i = e - 1; i >= 0; i--) {
          final DateTime? d = asDate(rawList[i], <String>['device_time', 'time', 'timestamp']);
          if (currMs - (d?.millisecondsSinceEpoch ?? 0) > fiveMinMs) break;
          if (rList[i] != null) vals.add(rList[i]!);
        }
        if (vals.isNotEmpty) {
          hMap[e] = vals.reduce((a, b) => a + b) / vals.length;
        }
      }

      if (!prevIgn && currIgn) {
        final List<double> vals = <double>[];
        for (int i = e; i < rawList.length; i++) {
          final DateTime? d = asDate(rawList[i], <String>['device_time', 'time', 'timestamp']);
          if ((d?.millisecondsSinceEpoch ?? 0) - currMs > fiveMinMs) break;
          if (rList[i] != null) vals.add(rList[i]!);
        }
        if (vals.isNotEmpty) {
          gMap[e] = vals.reduce((a, b) => a + b) / vals.length;
        }
      }
    }

    final Set<int> theftOffIndices = <int>{};
    for (final int offIdx in hMap.keys) {
      final int? onIdx = gMap.keys.where((k) => k > offIdx).firstOrNull;
      if (onIdx != null) {
        final double preF = hMap[offIdx]!;
        final double postF = gMap[onIdx]!;
        if (preF - postF >= minTheft) {
          theftOffIndices.add(offIdx);
        }
      }
    }

    // 7. Normalized fuel tracking (o in web app)
    final List<double> oList = List<double>.filled(rawList.length, 0.0);
    double pVal = rList.firstWhere((val) => val != null, orElse: () => 0.0) ?? 0.0;
    final List<Map<String, dynamic>> refuels = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> thefts = <Map<String, dynamic>>[];

    for (int e = 0; e < rawList.length; e++) {
      final Map<String, dynamic> pt = rawList[e];
      final double spd = asDouble(pt, <String>['speed']);
      final bool ign = asBool(pt, <String>['ignition', 'acc']);
      final double? h = rList[e];

      if (h != null) {
        final double g = h - pVal;
        bool isEvent = false;

        // Check refill
        if (spd <= 6 && g >= 2) {
          final DateTime? ptDate = asDate(pt, <String>['device_time', 'time', 'timestamp']);
          final int aMs = ptDate?.millisecondsSinceEpoch ?? 0;
          double c = h;
          int u = e;
          int f = e + 1;
          while (f < rawList.length) {
            final double nextSpd = asDouble(rawList[f], <String>['speed']);
            final DateTime? nextDate = asDate(rawList[f], <String>['device_time', 'time', 'timestamp']);
            if ((nextDate?.millisecondsSinceEpoch ?? 0) - aMs > 1500 * 1000 || nextSpd > 6) break;
            final double? rf = rList[f];
            if (rf != null && rf > c) {
              c = rf;
              u = f;
            }
            f++;
          }
          final double m = c - pVal;
          final DateTime? uDate = asDate(rawList[u], <String>['device_time', 'time', 'timestamp']);
          final int gMs = (uDate?.millisecondsSinceEpoch ?? 0) - aMs;
          if (m >= minFilling && u > e && gMs >= 45 * 1000) {
            bool settled = true;
            int checkCount = 0;
            for (int k = u + 1; k < rawList.length && checkCount < 5; k++) {
              final double? rk = rList[k];
              if (rk != null) {
                if (rk < pVal + m * 0.5) {
                  settled = false;
                  break;
                }
                checkCount++;
              }
            }
            if (settled) {
              isEvent = true;
              final double liters = (m * 10).round() / 10.0;
              final DateTime? uDate = asDate(rawList[u], <String>['device_time', 'time', 'timestamp']);
              final DateTime? eDate = asDate(rawList[e], <String>['device_time', 'time', 'timestamp']);
              refuels.add(<String, dynamic>{
                'liters': liters,
                'startIdx': e,
                'endIdx': u,
                'timestamp': uDate ?? DateTime.now(),
                'startTime': eDate,
                'startFuel': pVal,
                'endFuel': c,
                'address': asStringOrNull(rawList[u], <String>['address', 'location']),
              });
              pVal = c;
              e = u;
              oList[e] = max(0.0, min(tankSize, (pVal * 10).round() / 10.0));
              continue;
            }
          }
        }

        // Check theft
        if (!isEvent && spd <= 6 && !ign && g <= -2) {
          if (theftOffIndices.contains(e)) {
            final DateTime? ptDate = asDate(pt, <String>['device_time', 'time', 'timestamp']);
            final int aMs = ptDate?.millisecondsSinceEpoch ?? 0;
            double sVal = h;
            int lIdx = e;
            int d = e + 1;
            while (d < rawList.length) {
              final double nextSpd = asDouble(rawList[d], <String>['speed']);
              final bool nextIgn = asBool(rawList[d], <String>['ignition', 'acc']);
              final DateTime? nextDate = asDate(rawList[d], <String>['device_time', 'time', 'timestamp']);
              if ((nextDate?.millisecondsSinceEpoch ?? 0) - aMs > 1500 * 1000 || nextSpd > 6 || nextIgn) break;
              final double? ro = rList[d];
              if (ro != null && ro < sVal) {
                sVal = ro;
                lIdx = d;
              }
              d++;
            }
            final double mTheft = pVal - sVal;
            final DateTime? lDate = asDate(rawList[lIdx], <String>['device_time', 'time', 'timestamp']);
            final int gMs = (lDate?.millisecondsSinceEpoch ?? 0) - aMs;
            if (mTheft >= minTheft && lIdx > e && gMs >= 30 * 1000) {
              isEvent = true;
              final double liters = (mTheft * 10).round() / 10.0;
              final DateTime? lTime = asDate(rawList[lIdx], <String>['device_time', 'time', 'timestamp']);
              final DateTime? eTime = asDate(rawList[e], <String>['device_time', 'time', 'timestamp']);
              thefts.add(<String, dynamic>{
                'liters': liters,
                'startIdx': e,
                'endIdx': lIdx,
                'timestamp': lTime ?? DateTime.now(),
                'startTime': eTime,
                'startFuel': pVal,
                'endFuel': sVal,
                'address': asStringOrNull(rawList[lIdx], <String>['address', 'location']),
              });
              pVal = sVal;
              e = lIdx;
              oList[e] = max(0.0, min(tankSize, (pVal * 10).round() / 10.0));
              continue;
            }
          }
        }

        // Monotonic consumption tracking when no refill/theft
        if (!isEvent) {
          if (spd > 6) {
            if (g >= minFilling) {
              // Sudden spike while driving, ignore
            } else if (g < 0) {
              pVal = 0.88 * pVal + 0.12 * h;
            }
          } else {
            if (ign) {
              if (g < 0) pVal = 0.92 * pVal + 0.08 * h;
            } else {
              if (g.abs() < minFilling) pVal = 0.88 * pVal + 0.12 * h;
            }
          }
        }
      }
      oList[e] = max(0.0, min(tankSize, (pVal * 10).round() / 10.0));
    }

    // 8. Calculate distance (GPS Haversine sum), engine hours, and status
    double xDist = 0.0;
    double maxSpd = 0.0;
    double sumSpd = 0.0;
    double movingMin = 0.0;
    double idleMin = 0.0;

    double haversine(double lat1, double lon1, double lat2, double lon2) {
      final double dLat = (lat2 - lat1) * pi / 180.0;
      final double dLon = (lon2 - lon1) * pi / 180.0;
      final double a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
          sin(dLon / 2) * sin(dLon / 2);
      return 6371.0 * (2 * atan2(sqrt(a), sqrt(1.0 - a)));
    }

    final List<FuelTelemetryPoint> parsedPoints = <FuelTelemetryPoint>[];

    for (int e = 0; e < rawList.length; e++) {
      final Map<String, dynamic> pt = rawList[e];
      final double spd = asDouble(pt, <String>['speed']);
      final bool ign = asBool(pt, <String>['ignition', 'acc']);
      final DateTime timestamp = asDate(pt, <String>['device_time', 'time', 'timestamp']) ?? DateTime.now();

      if (e > 0) {
        final DateTime prevTime = asDate(rawList[e - 1], <String>['device_time', 'time', 'timestamp']) ?? timestamp;
        final int diffMs = timestamp.difference(prevTime).inMilliseconds;
        if (diffMs > 0) {
          final double mMin = min(15.0, max(0.0, diffMs / 60000.0));
          if (spd > 6) {
            movingMin += mMin;
          } else if (ign) {
            idleMin += mMin;
          }
        }

        final double lat1 = asDouble(rawList[e - 1], <String>['latitude', 'lat']);
        final double lng1 = asDouble(rawList[e - 1], <String>['longitude', 'lng', 'lon']);
        final double lat2 = asDouble(pt, <String>['latitude', 'lat']);
        final double lng2 = asDouble(pt, <String>['longitude', 'lng', 'lon']);
        if (lat1 != 0 && lng1 != 0 && lat2 != 0 && lng2 != 0) {
          final double d = haversine(lat1, lng1, lat2, lng2);
          if (d > 0.005 && d < 10.0) {
            xDist += d;
          }
        }
      }

      if (spd > maxSpd) maxSpd = spd;
      sumSpd += spd;

      final double normFuel = oList[e];
      final double rawF = nList[e] ?? normFuel;
      final double filtF = rList[e] ?? normFuel;

      parsedPoints.add(
        FuelTelemetryPoint(
          timestamp: timestamp,
          fuel: rawF,
          filteredFuel: filtF,
          normalizedFuel: normFuel,
          speed: spd,
          odo: asDouble(pt, <String>['odometer', 'odo']),
          ignition: ign,
          latitude: asDouble(pt, <String>['latitude', 'lat']),
          longitude: asDouble(pt, <String>['longitude', 'lng', 'lon']),
          address: asStringOrNull(pt, <String>['address', 'location']),
          raw: pt,
        ),
      );
    }

    // 9. Web App Summary Calculations
    final double startFuel = oList.isNotEmpty ? oList.first : 0.0;
    final double endFuel = oList.isNotEmpty ? oList.last : 0.0;
    final double totalFill = refuels.fold<double>(0.0, (sum, ref) => sum + (ref['liters'] as double));
    final double totalTheft = thefts.fold<double>(0.0, (sum, th) => sum + (th['liters'] as double));
    final double fuelConsumed = max(0.0, startFuel + totalFill - endFuel);

    double distKm = (xDist * 10).round() / 10.0;
    if (distKm <= 0 && parsedPoints.length >= 2) {
      final double startOdo = parsedPoints.first.odo;
      final double endOdo = parsedPoints.last.odo;
      if (endOdo >= startOdo && startOdo > 0) {
        distKm = ((endOdo - startOdo) * 10).round() / 10.0;
      }
    }
    final double kmpl = (fuelConsumed > 0 && distKm > 0)
        ? ((distKm / fuelConsumed) * 100).round() / 100.0
        : 0.0;

    final Map<String, dynamic> lastPt = rawList.last;
    final double lastSpeed = asDouble(lastPt, <String>['speed']);
    final bool lastIgn = asBool(lastPt, <String>['ignition', 'acc']);
    final String currentStatus = lastSpeed > 6
        ? 'ON (Moving)'
        : (lastIgn ? 'ON (Idle)' : 'OFF');

    final FuelReportSummary summary = FuelReportSummary(
      startDate: start,
      endDate: end,
      totalFuelConsumed: (fuelConsumed * 10).round() / 10.0,
      tripDistance: distKm,
      totalFuelFill: totalFill,
      theftDrain: totalTheft,
      startFuel: startFuel,
      endFuel: endFuel,
      refuelCount: refuels.length,
      drainCount: thefts.length,
      kmpl: kmpl,
      startOdo: parsedPoints.isNotEmpty ? parsedPoints.first.odo : 0.0,
      endOdo: parsedPoints.isNotEmpty ? parsedPoints.last.odo : 0.0,
      movingHours: (movingMin / 60.0 * 10).round() / 10.0,
      idleHours: (idleMin / 60.0 * 10).round() / 10.0,
      maxSpeed: maxSpd.roundToDouble(),
      avgSpeed: parsedPoints.isNotEmpty ? (sumSpd / parsedPoints.length).roundToDouble() : 0.0,
      tankSize: tankSize,
      fuelPercent: tankSize > 0 ? ((endFuel / tankSize) * 100.0).clamp(0.0, 100.0) : 0.0,
      currentStatus: currentStatus,
      currentSpeed: lastSpeed,
      vehicleGroup: 'All Groups',
    );

    // 10. Interval downsampling if requested
    final List<FuelTelemetryPoint> finalPoints =
        _filterByInterval(parsedPoints, interval);

    return FuelReportData(
      points: finalPoints,
      summary: summary,
      rawCount: rawList.length,
      refuelEvents: refuels,
      theftEvents: thefts,
    );
  }

  /// Downsamples points according to interval bucket duration.
  List<FuelTelemetryPoint> _filterByInterval(
      List<FuelTelemetryPoint> source, FuelInterval interval) {
    if (interval == FuelInterval.raw ||
        interval == FuelInterval.filtered ||
        interval.duration == Duration.zero) {
      return source;
    }

    if (source.isEmpty) return source;

    final List<FuelTelemetryPoint> sampled = <FuelTelemetryPoint>[];
    DateTime nextAllowed = source.first.timestamp;

    for (final FuelTelemetryPoint pt in source) {
      if (!pt.timestamp.isBefore(nextAllowed)) {
        sampled.add(pt);
        nextAllowed = pt.timestamp.add(interval.duration);
      }
    }

    if (sampled.isNotEmpty && sampled.last != source.last) {
      sampled.add(source.last);
    }

    return sampled;
  }

  Future<Map<String, dynamic>?> getVehicleFuelConfig(String vehicleId) async {
    try {
      final Response<dynamic> response =
          await _api.raw.get('/fuel/manual/config/$vehicleId');
      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[FUEL] getVehicleFuelConfig error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> saveVehicleFuelConfig({
    required String vehicleId,
    required String fuelType,
    required double tankCapacity,
    double initialFuel = 0.0,
    double initialOdometer = 0.0,
    double initialMileage = 8.0,
    double reserveFuelLevel = 10.0,
    double lowFuelAlertThreshold = 15.0,
    double criticalFuelAlertThreshold = 8.0,
  }) async {
    final Response<dynamic> response = await _api.raw.post(
      '/fuel/manual/config/$vehicleId',
      data: <String, dynamic>{
        'fuelType': fuelType,
        'tankCapacity': tankCapacity,
        'initialFuel': initialFuel,
        'initialOdometer': initialOdometer,
        'initialMileage': initialMileage,
        'reserveFuelLevel': reserveFuelLevel,
        'lowFuelAlertThreshold': lowFuelAlertThreshold,
        'criticalFuelAlertThreshold': criticalFuelAlertThreshold,
      },
    );
    if (response.data is Map && response.data['success'] == true) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception(response.data['error'] ?? 'Failed to save vehicle fuel configuration');
  }

  Future<Map<String, dynamic>?> getManualFuelState(String vehicleId) async {
    try {
      final Response<dynamic> response =
          await _api.raw.get('/fuel/manual/state/$vehicleId');
      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[FUEL] getManualFuelState error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> submitManualFuelEntry({
    required String vehicleId,
    required String entryType,
    required double fuelQuantity,
    double fuelFilled = 0.0,
    required double odometer,
    String? remarks,
    DateTime? entryDate,
  }) async {
    final Response<dynamic> response = await _api.raw.post(
      '/fuel/manual/entry/$vehicleId',
      data: <String, dynamic>{
        'entryType': entryType,
        'fuelQuantity': fuelQuantity,
        'fuelFilled': fuelFilled,
        'odometer': odometer,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (entryDate != null) 'entryDate': entryDate.toIso8601String(),
      },
    );
    if (response.data is Map && response.data['success'] == true) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception(response.data['error'] ?? 'Failed to submit fuel entry');
  }

  Future<List<Map<String, dynamic>>> getManualFuelEntries(String vehicleId) async {
    try {
      final Response<dynamic> response =
          await _api.raw.get('/fuel/manual/entries/$vehicleId');
      if (response.data is Map && response.data['success'] == true) {
        final dynamic data = response.data['data'];
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map && data['entries'] is List) {
          return (data['entries'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('[FUEL] getManualFuelEntries error: $e');
    }
    return <Map<String, dynamic>>[];
  }
}
