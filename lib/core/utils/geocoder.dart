import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/app_config.dart';

class _GeocodeTask {
  _GeocodeTask(this.key, this.lat, this.lon, this.completer);
  final String key;
  final double lat;
  final double lon;
  final Completer<String> completer;
}

class Geocoder {
  static final Map<String, String> _cache = <String, String>{};
  static final Map<String, Completer<String>> _inFlight = <String, Completer<String>>{};
  static final Queue<_GeocodeTask> _queue = Queue<_GeocodeTask>();
  static bool _isProcessing = false;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      validateStatus: (int? status) => true,
    ),
  );

  /// Reverse geocodes coordinates to a human-readable address.
  /// On Flutter Web, routes via our own backend proxy to avoid CORS issues
  /// with ArcGIS. On mobile/desktop, calls ArcGIS directly.
  static Future<String> getAddress(double lat, double lon) {
    if (lat == 0 && lon == 0) return Future<String>.value('Location unavailable');

    // 3 decimal places is ~110m resolution (matches web app caching)
    final String key = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

    // 1. Return from cache immediately if available
    if (_cache.containsKey(key)) {
      return Future<String>.value(_cache[key]!);
    }

    // 2. Return existing in-flight future if another row already requested the same spot
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!.future;
    }

    final Completer<String> completer = Completer<String>();
    _inFlight[key] = completer;
    _queue.add(_GeocodeTask(key, lat, lon, completer));

    _processQueue();

    return completer.future;
  }

  static void _processQueue() {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    Future<void>.microtask(() async {
      while (_queue.isNotEmpty) {
        final _GeocodeTask task = _queue.removeFirst();

        // Double check cache
        if (_cache.containsKey(task.key)) {
          if (!task.completer.isCompleted) {
            task.completer.complete(_cache[task.key]);
          }
          _inFlight.remove(task.key);
          continue;
        }

        // Fallback: show coordinates if geocoding fails
        String result = '${task.lat.toStringAsFixed(4)}, ${task.lon.toStringAsFixed(4)}';

        try {
          String? label;

          if (kIsWeb) {
            // On Flutter Web, ArcGIS blocks cross-origin requests.
            // Route through our own backend proxy which has no CORS restrictions.
            final String proxyUrl =
                '${AppConfig.apiBaseUrl}/api/geocode/reverse'
                '?lat=${task.lat}&lng=${task.lon}';

            final Response<dynamic> res = await _dio.get(proxyUrl);
            if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
              label = (res.data as Map<String, dynamic>)['label']?.toString();
            }
          } else {
            // Mobile / Desktop: call ArcGIS directly (no CORS restrictions)
            final Response<dynamic> res = await _dio.get(
              'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/reverseGeocode',
              queryParameters: <String, dynamic>{
                'location': '${task.lon},${task.lat}',
                'f': 'json',
              },
            );

            if (res.statusCode == 200 && res.data != null && res.data is Map<String, dynamic>) {
              final Map<String, dynamic> data = res.data as Map<String, dynamic>;
              final Map<String, dynamic>? addressObj = data['address'] as Map<String, dynamic>?;
              if (addressObj != null) {
                final String? longLabel = addressObj['LongLabel']?.toString();
                final String? matchAddr = addressObj['Match_addr']?.toString();
                final String? address = addressObj['Address']?.toString();
                final String? city = addressObj['City']?.toString();

                String parsed = longLabel ?? matchAddr ?? '';
                if (parsed.isEmpty && address != null && address.isNotEmpty) {
                  parsed = city != null && city.isNotEmpty ? '$address, $city' : address;
                }
                if (parsed.isNotEmpty) label = parsed;
              }
            }
          }

          if (label != null && label.isNotEmpty) {
            result = label;
          }
        } catch (_) {
          // Graceful fallback on network/timeout error — result stays as coordinates
        }

        _cache[task.key] = result;
        _inFlight.remove(task.key);
        if (!task.completer.isCompleted) {
          task.completer.complete(result);
        }

        // Pacing delay to avoid rate-limits
        if (_queue.isNotEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      _isProcessing = false;
    });
  }
}
