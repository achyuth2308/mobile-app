import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/report_models.dart';
import '../../../data/models/trip.dart';
import '../../../data/models/vehicle.dart';
import 'animated_vehicle_marker.dart';
import 'map_tiles.dart';
import 'vehicle_marker.dart';

// ── Trail smoothing helpers ──────────────────────────────────────────────────

/// Ramer-Douglas-Peucker simplification.
/// Removes GPS noise while keeping the overall shape of the path.
/// [toleranceMeters] controls how aggressively to simplify.
List<LatLng> _rdpSimplify(List<LatLng> points, double toleranceMeters) {
  if (points.length <= 2) return List.of(points);

  const Distance dist = Distance();
  double maxD = 0;
  int maxIdx = 0;

  for (int i = 1; i < points.length - 1; i++) {
    final double d = _perpendicularDist(points[i], points.first, points.last, dist);
    if (d > maxD) {
      maxD = d;
      maxIdx = i;
    }
  }

  if (maxD > toleranceMeters) {
    final left  = _rdpSimplify(points.sublist(0, maxIdx + 1), toleranceMeters);
    final right = _rdpSimplify(points.sublist(maxIdx),        toleranceMeters);
    return [...left.sublist(0, left.length - 1), ...right];
  } else {
    return [points.first, points.last];
  }
}

double _perpendicularDist(LatLng p, LatLng a, LatLng b, Distance dist) {
  final double d1  = dist.distance(a, p);
  final double d2  = dist.distance(b, p);
  final double len = dist.distance(a, b);
  if (len < 0.001) return d1;
  final double s = (d1 + d2 + len) / 2;
  return 2 * math.sqrt(math.max(0, s * (s - d1) * (s - d2) * (s - len))) / len;
}

/// Catmull-Rom spline interpolation.
/// Adds [segments] smooth intermediate points between each pair of GPS waypoints.
List<LatLng> _catmullRom(List<LatLng> points, {int segments = 8}) {
  if (points.length < 2) return List.of(points);

  final result = <LatLng>[];

  for (int i = 0; i < points.length - 1; i++) {
    final p0 = points[(i - 1).clamp(0, points.length - 1)];
    final p1 = points[i];
    final p2 = points[(i + 1).clamp(0, points.length - 1)];
    final p3 = points[(i + 2).clamp(0, points.length - 1)];

    for (int j = 0; j < segments; j++) {
      final double t  = j / segments;
      final double t2 = t * t;
      final double t3 = t2 * t;

      final double lat = 0.5 * (
        (2 * p1.latitude) +
        (-p0.latitude + p2.latitude) * t +
        (2 * p0.latitude - 5 * p1.latitude + 4 * p2.latitude - p3.latitude) * t2 +
        (-p0.latitude + 3 * p1.latitude - 3 * p2.latitude + p3.latitude) * t3
      );
      final double lng = 0.5 * (
        (2 * p1.longitude) +
        (-p0.longitude + p2.longitude) * t +
        (2 * p0.longitude - 5 * p1.longitude + 4 * p2.longitude - p3.longitude) * t2 +
        (-p0.longitude + 3 * p1.longitude - 3 * p2.longitude + p3.longitude) * t3
      );
      result.add(LatLng(lat, lng));
    }
  }

  result.add(points.last);
  return result;
}

// ── Widget ───────────────────────────────────────────────────────────────────

class UniversalLiveMap extends StatefulWidget {
  const UniversalLiveMap({
    super.key,
    required this.mapController,
    required this.vehicles,
    required this.style,
    required this.fallbackCenter,
    required this.selectedId,
    required this.followingId,
    required this.onMapReady,
    required this.onUserInteracting,
    required this.onTapMap,
    required this.onSelectVehicle,
    this.pendingFocusId,
    this.route = const [],
    this.stoppages = const [],
    this.onTapStoppage,
  });

  final MapController mapController;
  final List<Vehicle> vehicles;
  final MapStyle style;
  final LatLng fallbackCenter;
  final String? selectedId;
  final String? followingId;
  final String? pendingFocusId;
  final VoidCallback onMapReady;
  final ValueChanged<bool> onUserInteracting;
  final VoidCallback onTapMap;
  final ValueChanged<Vehicle> onSelectVehicle;
  final List<TrackPoint> route;
  final List<ReportRow> stoppages;
  final void Function(ReportRow, int)? onTapStoppage;

  @override
  State<UniversalLiveMap> createState() => _UniversalLiveMapState();
}

class _UniversalLiveMapState extends State<UniversalLiveMap> {
  final ValueNotifier<LatLng?> _activeVisualPosition = ValueNotifier(null);
  
  // Stores fresh GPS points that arrive via websocket while watching a vehicle,
  // since widget.route is only fetched once from the DB upon selection.
  final List<TrackPoint> _livePoints = [];
  String? _lastActiveId;
  LatLng? _lastGpsPos;

  // Cache for gap routes from OSRM
  final Map<String, List<LatLng>> _estimatedGaps = {};
  
  // Track in-flight OSRM HTTP requests to prevent duplicate network calls (e.g. at 60fps)
  final Set<String> _inFlightRequests = {};

  Future<void> _fetchGapRoute(String key, LatLng start, LatLng end) async {
    if (_inFlightRequests.contains(key)) return;
    _inFlightRequests.add(key);

    try {
      final url = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final List<LatLng> routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          if (mounted) {
            setState(() {
              _estimatedGaps[key] = [start, ...routePoints, end];
            });
          }
        } else {
          // No Route found
          if (mounted) {
            setState(() {
              _estimatedGaps[key] = [];
            });
          }
        }
      } else if (response.statusCode == 429) {
        // Rate Limit hit. We do NOT cache an empty result here.
        // Dropping it from _inFlightRequests allows us to retry later.
        debugPrint('OSRM Rate Limit hit for gap \$key');
      } else {
        debugPrint('OSRM returned status code \${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching gap route \$key: \$e');
    } finally {
      if (mounted) {
        // Cleanup in-flight tracker on both success and failure
        _inFlightRequests.remove(key);
      }
    }
  }

  @override
  void dispose() {
    _activeVisualPosition.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UniversalLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final String? activeId = widget.selectedId ?? widget.followingId;
    
    // If we switched to a different vehicle, clear the live trail buffer
    if (activeId != _lastActiveId) {
      _livePoints.clear();
      _lastActiveId = activeId;
      _lastGpsPos = null;
    }
    
    // If we are tracking a vehicle, check if its GPS position updated via socket
    if (activeId != null) {
      final Vehicle? activeVehicle = widget.vehicles.cast<Vehicle?>().firstWhere(
            (v) => v?.id == activeId, 
            orElse: () => null,
          );
          
      if (activeVehicle != null && activeVehicle.hasLocation) {
        final newPos = LatLng(activeVehicle.latitude!, activeVehicle.longitude!);
        if (_lastGpsPos == null || const Distance().distance(_lastGpsPos!, newPos) > 2) {
          _livePoints.add(TrackPoint(
            latitude: activeVehicle.latitude!,
            longitude: activeVehicle.longitude!,
            speed: activeVehicle.speed ?? 0.0,
            heading: activeVehicle.heading ?? 0.0,
            timestamp: activeVehicle.lastPacketAt ?? DateTime.now(),
          ));
          _lastGpsPos = newPos;
        }
      }
    }
  }

  List<Marker> _buildMarkers(String? activeId) {
    return widget.vehicles
        .where((Vehicle v) => v.hasLocation)
        .map(
          (Vehicle v) => Marker(
            key: ValueKey<String>(v.id),
            point: LatLng(v.latitude!, v.longitude!),
            width: 120,
            height: 120,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => widget.onSelectVehicle(v),
              child: Center(
                child: AnimatedVehicleMarker(
                  key: ValueKey<String>('anim_${v.id}'),
                  point: LatLng(v.latitude!, v.longitude!),
                  heading: v.heading ?? 0.0,
                  status: v.status,
                  speed: v.speed ?? 0.0,
                  visualPositionNotifier: (v.id == activeId) ? _activeVisualPosition : null,
                  builder: (BuildContext context, double animatedHeading) => VehicleMarkerPin(
                    vehicle: v,
                    selected: v.id == widget.selectedId,
                    showLabel: false,
                    useSprite: true,
                    headingOverride: animatedHeading,
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  /// Build the smoothed base polyline segments from historical route data + live socket points.
  /// Breaks segments on large time/distance gaps (e.g. signal loss) and triggers OSRM fill for those gaps.
  ({List<List<LatLng>> baseSegments, List<List<LatLng>> estimatedGaps}) _buildBasePolylines(String? activeId) {
    const Distance distCalc = Distance();
    final List<List<LatLng>> segments = [];
    final List<List<LatLng>> gapSegments = [];
    List<LatLng> currentSegment = [];
    DateTime? lastTimestamp;
    LatLng? lastPoint;

    final combinedRoute = [...widget.route, ..._livePoints];

    final int limit = (activeId != null && combinedRoute.length > 1) 
        ? combinedRoute.length - 1 
        : combinedRoute.length;

    for (int i = 0; i < limit; i++) {
      final p = combinedRoute[i];
      if (p.latitude == null || p.longitude == null) continue;
      final point = LatLng(p.latitude!, p.longitude!);

      if (currentSegment.isNotEmpty && lastTimestamp != null && lastPoint != null) {
        final double d = distCalc.distance(lastPoint, point);
        
        final double timeGapSec = (p.timestamp.difference(lastTimestamp).inSeconds).abs().toDouble();
        final double impliedSpeed = (timeGapSec > 0) ? (d / timeGapSec) * 3.6 : 0;
        
        // Break segment if > 3 minutes (180s) gap, or unrealistic speed (teleportation)
        if (timeGapSec > 180 || impliedSpeed > 150) {
          if (currentSegment.length >= 2) {
            segments.add(currentSegment);
          }

          // Trigger OSRM call for significant physical gaps (>50m)
          if (d > 50) {
            final String gapKey = '${lastPoint.latitude.toStringAsFixed(5)},${lastPoint.longitude.toStringAsFixed(5)}-${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
            if (_estimatedGaps.containsKey(gapKey)) {
               final route = _estimatedGaps[gapKey]!;
               if (route.isNotEmpty) {
                 gapSegments.add(route);
               }
            } else {
               _fetchGapRoute(gapKey, lastPoint, point);
            }
          }

          currentSegment = [];
        } else {
          // Skip micro-jitter (points too close together)
          if (d < 5) continue;
          
          // Skip stationary drift ONLY if genuinely stopped/drifting in a tiny radius
          final double speed = p.speed ?? 0.0;
          if (speed < 2.0 && d < 15) continue;
        }
      }
      
      currentSegment.add(point);
      lastTimestamp = p.timestamp;
      lastPoint = point;
    }

    if (currentSegment.length >= 2) {
      segments.add(currentSegment);
    }

    // Simplify and smooth EACH segment independently
    final List<List<LatLng>> smoothedSegments = [];
    for (final seg in segments) {
      final simplified = _rdpSimplify(seg, 8.0);
      if (simplified.length >= 2) {
        smoothedSegments.add(_catmullRom(simplified, segments: 6));
      }
    }

    return (baseSegments: smoothedSegments, estimatedGaps: gapSegments);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String? activeId = widget.selectedId ?? widget.followingId;
    final Vehicle? activeVehicle = activeId != null
        ? widget.vehicles.cast<Vehicle?>().firstWhere((v) => v?.id == activeId, orElse: () => null)
        : null;

    final List<Marker> markers = _buildMarkers(activeId);
    final polylineData = _buildBasePolylines(activeId);
    final List<List<LatLng>> basePolylineSegments = polylineData.baseSegments;
    final List<List<LatLng>> estimatedGapSegments = polylineData.estimatedGaps;
    final List<ReportRow> filteredStoppages = widget.stoppages.where((stop) => (stop.durationSecVal ?? 0) >= 120).toList();

    return Stack(
      children: <Widget>[
          FlutterMap(
            mapController: widget.mapController,
            options: MapOptions(
              initialCenter: widget.fallbackCenter,
              initialZoom: 10.5,
              minZoom: 2,
              maxZoom: widget.style.maxZoom,
              backgroundColor: theme.colorScheme.surface,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: widget.onMapReady,
              onPointerDown: (_, __) => widget.onUserInteracting(true),
              onPointerUp: (_, __) => widget.onUserInteracting(false),
              onTap: (_, __) => widget.onTapMap(),
            ),
            children: <Widget>[
              buildTileLayer(widget.style),
              if (estimatedGapSegments.isNotEmpty)
                PolylineLayer(
                  polylines: estimatedGapSegments.map((segment) {
                    return Polyline(
                      points: segment,
                      color: Colors.grey.withOpacity(0.9),
                      strokeWidth: 4.0,
                      pattern: StrokePattern.dashed(segments: const [8, 8]),
                      strokeJoin: StrokeJoin.round,
                      strokeCap: StrokeCap.round,
                    );
                  }).toList(),
                ),
              if (widget.route.isNotEmpty && basePolylineSegments.isNotEmpty)
                PolylineLayer(
                  polylines: basePolylineSegments.map((segment) {
                    return Polyline(
                      points: segment,
                      color: const Color(0xFFFFB74D), // Light Orange
                      strokeWidth: 2.0, // Thin 2px width
                      strokeJoin: StrokeJoin.round,
                      strokeCap: StrokeCap.round,
                    );
                  }).toList(),
                ),
              if (filteredStoppages.isNotEmpty)
                MarkerLayer(
                  markers: List.generate(filteredStoppages.length, (index) {
                    final stop = filteredStoppages[index];
                    final lat = stop.startLat ?? stop.endLat;
                    final lng = stop.startLng ?? stop.endLng;
                    if (lat == null || lng == null) return null;
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onTapStoppage != null) {
                            widget.onTapStoppage!(stop, index + 1);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                ),
              if (markers.isNotEmpty)
                MarkerLayer(markers: markers),
            ],
          ),
      ],
    );
  }
}

