import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/json_utils.dart';
import '../config/app_config.dart';

class Geocoder {
  static final Map<String, String> _cache = <String, String>{};
  static final Map<String, Completer<String>> _inFlight = <String, Completer<String>>{};

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      validateStatus: (int? status) => true,
    ),
  );

  /// Checks if an address string is detailed (contains shop/landmark, colony, road, and/or pincode).
  static bool _isDetailedAddress(String? addr) {
    if (addr == null || addr.isEmpty) return false;
    final String clean = addr.trim();
    if (clean.startsWith('Location') || clean == '...' || clean == 'Place') return false;
    final List<String> parts = clean.split(',').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
    return parts.length >= 4 || RegExp(r'\b\d{6}\b').hasMatch(clean);
  }

  /// Synchronously returns a cached address for the coordinates or nearby coordinates (~100m).
  static String? getCachedAddress(double lat, double lon) {
    if (lat == 0 && lon == 0) return null;
    final String key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) {
      final String val = _cache[key]!;
      if (val.isNotEmpty && val != 'Location unavailable') return val;
    }

    final String clusterKey = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';
    if (_cache.containsKey(clusterKey)) {
      final String val = _cache[clusterKey]!;
      if (val.isNotEmpty && val != 'Location unavailable') return val;
    }

    // Proximity search within adjacent ~11m grid tiles
    for (final double dLat in const <double>[-0.0001, 0.0001, -0.0002, 0.0002]) {
      for (final double dLon in const <double>[-0.0001, 0.0001, -0.0002, 0.0002]) {
        final String nearbyKey = '${(lat + dLat).toStringAsFixed(4)},${(lon + dLon).toStringAsFixed(4)}';
        if (_cache.containsKey(nearbyKey)) {
          final String val = _cache[nearbyKey]!;
          if (val.isNotEmpty && val != 'Location unavailable') return val;
        }
      }
    }
    return null;
  }

  /// Reverse geocodes coordinates to a human-readable, street-level detailed address.
  /// Prioritizes High-Definition Google Maps & Backend Proxy (with L1/L2 Redis/L3 DB cache)
  /// for shop names, landmarks, colony, road, city, state, country, and pincode.
  /// Falls back smoothly to ArcGIS, Photon, BigDataCloud, and Nominatim.
  static Future<String> getAddress(double lat, double lon) async {
    if (lat == 0 && lon == 0) return 'Location unavailable';

    final String key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    final String clusterKey = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

    // 1. Check exact or cluster cache (only return early if already detailed)
    if (_cache.containsKey(key)) {
      final String val = _cache[key]!;
      if (val.isNotEmpty && val != 'Location unavailable' && _isDetailedAddress(val)) {
        return val;
      }
    }
    if (_cache.containsKey(clusterKey)) {
      final String val = _cache[clusterKey]!;
      if (val.isNotEmpty && val != 'Location unavailable' && _isDetailedAddress(val)) {
        return val;
      }
    }

    // 2. Proximity cache lookup (only return early if already detailed)
    final String? prox = getCachedAddress(lat, lon);
    if (prox != null && prox.isNotEmpty && _isDetailedAddress(prox)) {
      return prox;
    }

    // 3. Deduplicate in-flight requests
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!.future;
    }
    if (_inFlight.containsKey(clusterKey)) {
      return _inFlight[clusterKey]!.future;
    }

    final Completer<String> completer = Completer<String>();
    _inFlight[key] = completer;
    _inFlight[clusterKey] = completer;

    try {
      final String? result = await _resolveFast(lat, lon);
      final String finalAddr = (result != null && result.isNotEmpty)
          ? result
          : (prox ?? 'Location unavailable');

      if (finalAddr != 'Location unavailable') {
        _cache[key] = finalAddr;
        _cache[clusterKey] = finalAddr;
      }
      _inFlight.remove(key);
      _inFlight.remove(clusterKey);
      if (!completer.isCompleted) {
        completer.complete(finalAddr);
      }
      return finalAddr;
    } catch (_) {
      _inFlight.remove(key);
      _inFlight.remove(clusterKey);
      if (!completer.isCompleted) {
        completer.complete(prox ?? 'Location unavailable');
      }
      return prox ?? 'Location unavailable';
    }
  }

  static Future<String?> _resolveFast(double lat, double lon) async {
    // ── High-Detail Provider 1: Backend Multi-Tier Proxy (Google + Redis + Postgres) ──
    Future<String?> fetchBackendProxy() async {
      try {
        final Response<dynamic> res = await _dio.get(
          '${AppConfig.apiRoot}/geocode/reverse?lat=$lat&lng=$lon',
        );
        final dynamic raw = res.data;
        final dynamic data = raw is String ? jsonDecode(raw) : raw;
        if (res.statusCode == 200 && data is Map && data['success'] == true) {
          final String? label = data['label']?.toString() ?? data['address']?.toString();
          if (label != null && label.trim().isNotEmpty && label != 'Location unavailable') {
            return formatToNearestAddress(label);
          }
        }
      } catch (_) {}
      return null;
    }

    // ── High-Detail Provider 2: Google Maps Geocoding API ──────────────────────────
    Future<String?> fetchGoogle() async {
      try {
        const String apiKey = 'AIzaSyBUfwgEy51elZbDcxVXIPJ4x8-7_oMUZDk';
        final Response<dynamic> res = await _dio.get(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$apiKey',
        );
        final dynamic raw = res.data;
        final dynamic data = raw is String ? jsonDecode(raw) : raw;
        if (res.statusCode == 200 && data is Map) {
          final dynamic status = data['status'];
          final dynamic results = data['results'];
          if (status == 'OK' && results is List && results.isNotEmpty) {
            for (final dynamic item in results) {
              if (item is Map && item['formatted_address'] != null) {
                final String formatted = item['formatted_address'].toString();
                final String cleaned = formatToNearestAddress(formatted);
                if (_isDetailedAddress(cleaned)) {
                  return cleaned;
                }
              }
            }
            final dynamic first = results.first;
            if (first is Map && first['formatted_address'] != null) {
              return formatToNearestAddress(first['formatted_address'].toString());
            }
          }
        }
      } catch (_) {}
      return null;
    }

    // ── Fallback Provider 3: ArcGIS World Geocoder ────────────────────────────────
    Future<String?> fetchArcGis() async {
      try {
        final Response<dynamic> res = await _dio.get(
          'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/reverseGeocode?f=pjson&location=$lon,$lat',
        );
        final dynamic raw = res.data;
        final dynamic data = raw is String ? jsonDecode(raw) : raw;
        if (res.statusCode == 200 && data is Map) {
          final dynamic address = data['address'];
          if (address is Map) {
            final String? matchAddr = address['Match_addr']?.toString() ??
                address['LongLabel']?.toString() ??
                address['Address']?.toString();
            if (matchAddr != null && matchAddr.trim().isNotEmpty) {
              String clean = matchAddr.trim();
              if (clean.endsWith(', IND')) {
                clean = clean.substring(0, clean.length - 5);
              }
              return formatToNearestAddress(clean);
            }
          }
        }
      } catch (_) {}
      return null;
    }

    // ── Fallback Provider 4: OpenStreetMap Nominatim (Native only) ───────────────
    Future<String?> fetchNominatim() async {
      if (kIsWeb) return null; // Browser blocks CORS and forbids User-Agent header on web
      try {
        final Response<dynamic> res = await _dio.get(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
          options: Options(
            headers: const <String, String>{
              'User-Agent': 'FuelTracks/1.0 (support@fueltracks.in)',
              'Accept-Language': 'en',
            },
          ),
        );
        final dynamic raw = res.data;
        final dynamic data = raw is String ? jsonDecode(raw) : raw;
        if (res.statusCode == 200 && data is Map) {
          final dynamic d = data;
          final dynamic addr = d['address'];
          if (addr is Map) {
            final List<String> parts = <String>[];
            final dynamic amenity = addr['amenity'] ?? addr['shop'] ?? addr['building'];
            if (amenity != null && amenity.toString().isNotEmpty) parts.add(amenity.toString());
            final dynamic road = addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'];
            if (road != null && road.toString().isNotEmpty) parts.add(road.toString());
            final dynamic city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state_district'];
            if (city != null && city.toString().isNotEmpty) parts.add(city.toString());
            final dynamic state = addr['state'];
            if (state != null && state.toString().isNotEmpty) parts.add(state.toString());
            final dynamic postcode = addr['postcode'];
            if (postcode != null && postcode.toString().isNotEmpty) parts.add(postcode.toString());
            if (parts.isNotEmpty) {
              return formatToNearestAddress(parts.join(', '));
            }
          }
          final String? full = d['display_name']?.toString();
          if (full != null && full.isNotEmpty) {
            return formatToNearestAddress(full);
          }
        }
      } catch (_) {}
      return null;
    }

    // ── Fallback Provider 5: BigDataCloud ─────────────────────────────────────────
    Future<String?> fetchBigDataCloud() async {
      try {
        final Response<dynamic> res = await _dio.get(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=en',
        );
        final dynamic raw = res.data;
        final dynamic data = raw is String ? jsonDecode(raw) : raw;
        if (res.statusCode == 200 && data is Map) {
          final List<String> parts = <String>[];
          final dynamic locality = data['locality'];
          if (locality != null && locality.toString().trim().isNotEmpty) {
            parts.add(locality.toString().trim());
          }
          final dynamic city = data['city'];
          if (city != null && city.toString().trim().isNotEmpty && !parts.contains(city.toString().trim())) {
            parts.add(city.toString().trim());
          }
          final dynamic principalSubdivision = data['principalSubdivision'];
          if (principalSubdivision != null && principalSubdivision.toString().trim().isNotEmpty && !parts.contains(principalSubdivision.toString().trim())) {
            parts.add(principalSubdivision.toString().trim());
          }
          final dynamic postcode = data['postcode'];
          if (postcode != null && postcode.toString().trim().isNotEmpty) {
            parts.add(postcode.toString().trim());
          }
          if (parts.isNotEmpty) {
            return formatToNearestAddress(parts.join(', '));
          }
        }
      } catch (_) {}
      return null;
    }

    // ── Fallback Provider 6: Photon ──────────────────────────────────────────────
    Future<String?> fetchPhoton() async {
      try {
        final Response<dynamic> res = await _dio.get(
          'https://photon.komoot.io/reverse?lat=$lat&lon=$lon',
        ).timeout(const Duration(milliseconds: 2500));
        final dynamic raw = res.data;
        final dynamic data = raw is String ? jsonDecode(raw) : raw;
        if (res.statusCode == 200 && data is Map) {
          final dynamic features = data['features'];
          if (features is List && features.isNotEmpty) {
            final dynamic first = features.first;
            if (first is Map) {
              final dynamic props = first['properties'];
              if (props is Map) {
                final List<String> parts = <String>[];
                final dynamic name = props['name'] ?? props['street'];
                if (name != null && name.toString().isNotEmpty) parts.add(name.toString());
                final dynamic district = props['district'] ?? props['locality'];
                if (district != null && district.toString().isNotEmpty && !parts.contains(district.toString())) {
                  parts.add(district.toString());
                }
                final dynamic city = props['city'] ?? props['town'] ?? props['county'];
                if (city != null && city.toString().isNotEmpty && !parts.contains(city.toString())) {
                  parts.add(city.toString());
                }
                final dynamic state = props['state'];
                if (state != null && state.toString().isNotEmpty && !parts.contains(state.toString())) {
                  parts.add(state.toString());
                }
                final dynamic postcode = props['postcode'];
                if (postcode != null && postcode.toString().isNotEmpty && !parts.contains(postcode.toString())) {
                  parts.add(postcode.toString());
                }
                if (parts.isNotEmpty) {
                  return formatToNearestAddress(parts.join(', '));
                }
              }
            }
          }
        }
      } catch (_) {}
      return null;
    }

    // ── Stage 1: Try High-Detail Providers (Backend Proxy & Google Maps) ───────────
    try {
      final List<Future<String?>> highDetailTasks = <Future<String?>>[
        fetchBackendProxy(),
        fetchGoogle(),
      ];
      final Completer<String?> highCompleter = Completer<String?>();
      int highRemaining = highDetailTasks.length;
      for (final Future<String?> task in highDetailTasks) {
        task.then((String? res) {
          if (res != null && _isDetailedAddress(res) && !highCompleter.isCompleted) {
            highCompleter.complete(res);
          } else {
            highRemaining--;
            if (highRemaining == 0 && !highCompleter.isCompleted) {
              highCompleter.complete(res); // Accept whatever returned if both done
            }
          }
        }).catchError((_) {
          highRemaining--;
          if (highRemaining == 0 && !highCompleter.isCompleted) {
            highCompleter.complete(null);
          }
        });
      }

      final String? highResult = await highCompleter.future.timeout(
        const Duration(milliseconds: 2800),
        onTimeout: () => null,
      );

      if (highResult != null && highResult.isNotEmpty && !RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(highResult)) {
        return highResult;
      }
    } catch (_) {}

    // ── Stage 2: Fallback to Secondary Geocoders if Google/Proxy unavailable ──────
    try {
      final List<Future<String?>> fallbackTasks = <Future<String?>>[
        fetchArcGis(),
        fetchBigDataCloud(),
        fetchPhoton(),
        if (!kIsWeb) fetchNominatim(),
      ];
      final Completer<String?> completer = Completer<String?>();
      int remaining = fallbackTasks.length;
      for (final Future<String?> task in fallbackTasks) {
        unawaited(
          task.then((String? res) {
            if (res != null && res.isNotEmpty && !completer.isCompleted) {
              completer.complete(res);
            } else {
              remaining--;
              if (remaining == 0 && !completer.isCompleted) {
                completer.complete(null);
              }
            }
          }).catchError((_) {
            remaining--;
            if (remaining == 0 && !completer.isCompleted) {
              completer.complete(null);
            }
          }),
        );
      }

      final String? winner = await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );

      if (winner != null && winner.isNotEmpty && !RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(winner)) {
        return winner;
      }
    } catch (_) {}

    return null;
  }

  /// Formats any raw or geocoded address into a clean, complete human-readable address.
  /// Preserves street/road, landmarks, locality, district, state, country, and postal code.
  /// Safely strips Plus Codes (e.g. 47XR+PJQ) and "Unnamed Road".
  static String formatToNearestAddress(String raw, {int maxWords = 50}) {
    if (raw.isEmpty) return 'Location unavailable';
    if (raw == 'Location unavailable' || raw == '...') return raw;
    if (RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(raw.trim())) {
      return raw.trim();
    }

    // 1. Clean out plus codes, unnamed road, and special prefixes
    String cleaned = raw
        .replaceAll(RegExp(r'^[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}[,\s]*'), '')
        .replaceAll(RegExp(r'\b[A-Z0-9]{4,8}\+[A-Z0-9]{2,4}\b[,\s]*'), '')
        .replaceAll(RegExp(r'Unnamed Road,\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Unnamed Road', caseSensitive: false), '')
        .trim();

    // 2. Clean up any double commas and leading/trailing punctuation
    cleaned = cleaned.replaceAll(RegExp(r',\s*,'), ',');
    if (cleaned.startsWith(',')) cleaned = cleaned.substring(1).trim();
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }

    return cleaned.isNotEmpty ? cleaned : raw.trim();
  }

  /// Extracts a clean, concise town or locality name from a formatted address.
  /// E.g. "Moktyala, Krishna, Andhra Pradesh 521175, India" -> "Moktyala".
  static String cleanPlaceName(String raw) {
    if (raw.isEmpty || raw.startsWith('Location')) return 'Place';
    if (RegExp(r'^\d+\.\d+').hasMatch(raw)) return 'Place';
    final List<String> parts = raw.split(',').map((String s) => s.trim()).toList();
    const Set<String> ignored = <String>{
      'india',
      'andhra pradesh',
      'telangana',
      'karnataka',
      'maharashtra',
      'tamil nadu',
      'unnamed road',
    };
    final List<String> candidates = parts.where((String p) {
      if (p.isEmpty) return false;
      if (RegExp(r'^\d+$').hasMatch(p)) return false;
      if (RegExp(r'\b\d{6}\b').hasMatch(p)) return false;
      if (ignored.contains(p.toLowerCase())) return false;
      if (RegExp(r'^(nh|sh)\s*\d+', caseSensitive: false).hasMatch(p)) return false;
      return true;
    }).toList();

    if (candidates.isNotEmpty) {
      return candidates.first;
    }
    return parts.first.isNotEmpty ? parts.first : 'Place';
  }

  /// Geocodes a text query to a list of matching locations.
  static Future<List<GeocodeSearchResult>> searchPlaces(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return <GeocodeSearchResult>[];
    try {
      const String apiKey = 'AIzaSyBUfwgEy51elZbDcxVXIPJ4x8-7_oMUZDk';
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(q)}&key=$apiKey';
      final Response<dynamic> res = await _dio.get(url);
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = res.data as Map<String, dynamic>;
        if (data['status'] == 'OK' && data['results'] != null) {
          final List<dynamic> results = data['results'] as List<dynamic>;
          return results.map((dynamic r) {
            final Map<String, dynamic> item = r as Map<String, dynamic>;
            final dynamic geom = item['geometry'];
            final dynamic loc = geom is Map ? geom['location'] : null;
            final double lat = toDouble(loc?['lat']) ?? 0.0;
            final double lng = toDouble(loc?['lng']) ?? 0.0;
            final String fullAddress = item['formatted_address']?.toString() ?? '';
            final String name = cleanPlaceName(fullAddress.isNotEmpty ? fullAddress : q);
            return GeocodeSearchResult(
              name: name,
              address: fullAddress,
              lat: lat,
              lon: lng,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return <GeocodeSearchResult>[];
  }
}

class GeocodeSearchResult {
  const GeocodeSearchResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
  });

  final String name;
  final String address;
  final double lat;
  final double lon;
}
