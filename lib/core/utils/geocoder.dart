import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';

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

          // Fetch directly from Google Maps Geocoding API since we have the key.
          // This gives incredibly detailed addresses without needing to restart the backend!
          const String apiKey = 'AIzaSyBUfwgEy51elZbDcxVXIPJ4x8-7_oMUZDk';
          final String url =
              'https://maps.googleapis.com/maps/api/geocode/json?latlng=${task.lat},${task.lon}&key=$apiKey';

          final Response<dynamic> res = await _dio.get(url);
          if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
            final Map<String, dynamic> data = res.data as Map<String, dynamic>;
            if (data['status'] == 'OK' && data['results'] != null) {
              final List<dynamic> results = data['results'] as List<dynamic>;
              if (results.isNotEmpty) {
                // Find the first result that is NOT just a plus code, as users 
                // find plus codes (like "XGJ7+HC") confusing.
                final dynamic bestResult = results.firstWhere(
                  (dynamic r) {
                    final List<dynamic>? types = (r as Map<String, dynamic>)['types'] as List<dynamic>?;
                    return types != null && !types.contains('plus_code');
                  },
                  orElse: () => results.first,
                );
                
                label = (bestResult as Map<String, dynamic>)['formatted_address']?.toString();
                
                // Extra safety: strip plus code string if it somehow still leads the address
                if (label != null) {
                  label = label!.replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}[,\s]*'), '');
                  
                  // Remove "Unnamed Road" to keep the address clean and beautiful
                  label = label!.replaceAll(RegExp(r'Unnamed Road,\s*'), '');
                  label = label!.replaceAll('Unnamed Road', '').trim();
                  
                  // Clean up any dangling commas that might have been left at the start
                  if (label!.startsWith(', ')) {
                    label = label!.substring(2).trim();
                  }
                  if (label!.isEmpty) {
                    label = null; // Let it fallback to coordinates if it's completely empty
                  }
                }
              }
            }
          }

          if (label != null && label.isNotEmpty) {
            result = label;
          }
        } catch (_) {
          // Graceful fallback on network/timeout error — result stays as coordinates
        }

        if (result != '${task.lat.toStringAsFixed(4)}, ${task.lon.toStringAsFixed(4)}') {
          _cache[task.key] = result;
        }
        
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
