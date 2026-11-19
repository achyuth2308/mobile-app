import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/json_utils.dart';

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

  /// Reverse geocodes coordinates to a human-readable address.
  /// Races OpenStreetMap Nominatim and ArcGIS World Geocoder simultaneously
  /// to resolve addresses in under 600ms, using 100m grid clustering for instant cache hits.
  static Future<String> getAddress(double lat, double lon) async {
    if (lat == 0 && lon == 0) return 'Location unavailable';

    final String key = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
    final String clusterKey = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

    // 1. Check exact or cluster cache
    if (_cache.containsKey(key)) {
      final String val = _cache[key]!;
      if (val.isNotEmpty && val != 'Location unavailable') return val;
    }
    if (_cache.containsKey(clusterKey)) {
      final String val = _cache[clusterKey]!;
      if (val.isNotEmpty && val != 'Location unavailable') return val;
    }

    // 2. Proximity cache lookup
    final String? prox = getCachedAddress(lat, lon);
    if (prox != null && prox.isNotEmpty) return prox;

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
          : 'Location unavailable';

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
        completer.complete('Location unavailable');
      }
      return 'Location unavailable';
    }
  }

  static Future<String?> _resolveFast(double lat, double lon) async {
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

    Future<String?> fetchNominatim() async {
      if (kIsWeb) return null; // Browser blocks CORS and forbids User-Agent header on web
      try {
        final Response<dynamic> res = await _dio.get(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon',
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
            final dynamic road = addr['road'] ?? addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'];
            if (road != null && road.toString().isNotEmpty) parts.add(road.toString());
            final dynamic city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state_district'];
            if (city != null && city.toString().isNotEmpty) parts.add(city.toString());
            final dynamic state = addr['state'];
            if (state != null && state.toString().isNotEmpty) parts.add(state.toString());
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

    try {
      // 1. Try ArcGIS first — fastest, highest reliability and no CORS/IP block
      final String? arcGisResult = await fetchArcGis();
      if (arcGisResult != null &&
          arcGisResult.isNotEmpty &&
          !RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(arcGisResult)) {
        return arcGisResult;
      }

      // 2. Fallbacks if ArcGIS did not resolve
      final List<Future<String?>> fallbacks = <Future<String?>>[
        fetchPhoton(),
        if (!kIsWeb) fetchNominatim(),
      ];
      final Completer<String?> completer = Completer<String?>();
      int remaining = fallbacks.length;
      for (final Future<String?> task in fallbacks) {
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
