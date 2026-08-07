import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';
import '../../../data/models/trip.dart';
import '../../../providers/core_providers.dart';
import '../../../shared/widgets/app_states.dart';
import '../../live_map/widgets/map_tiles.dart';

/// Stoppage / parking event along a historical route.
class StoppageEvent {
  const StoppageEvent({
    required this.lat,
    required this.lng,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.address,
    this.isOngoing = false,
  });

  final double lat;
  final double lng;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String? address;
  final bool isOngoing;

  String get durationString {
    final int hours = duration.inHours;
    final int mins = duration.inMinutes.remainder(60);
    final int secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${mins}m ${secs}s';
    }
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  String get compactDuration {
    final int hours = duration.inHours;
    final int mins = duration.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${mins}m';
    if (mins > 0) return '${mins}m';
    return '${duration.inSeconds}s';
  }
}

/// Convert any local or UTC DateTime to IST and represent as a UTC DateTime
/// so standard formatters format the IST calendar values directly.
String _toIstString(DateTime? d, String Function(DateTime) formatter) {
  if (d == null) return '—';
  final DateTime utc = d.toUtc();
  final DateTime ist = utc.add(const Duration(hours: 5, minutes: 30));
  final DateTime formatTarget = DateTime.utc(
    ist.year,
    ist.month,
    ist.day,
    ist.hour,
    ist.minute,
    ist.second,
    ist.millisecond,
    ist.microsecond,
  );
  return formatter(formatTarget);
}

String _formatTime(DateTime? d) => _toIstString(d, Fmt.time);
String _formatDate(DateTime? d) => _toIstString(d, Fmt.date);
String _formatDateShort(DateTime? d) => _toIstString(d, Fmt.dateShort);

/// Historical route playback.
///
/// The scrubber drives a single index into the point list; the marker,
/// travelled polyline and readouts are all pure functions of that index,
/// which keeps replay smooth and makes scrubbing feel instant.
class VehiclePlaybackTab extends ConsumerStatefulWidget {
  const VehiclePlaybackTab({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehiclePlaybackTab> createState() =>
      _VehiclePlaybackTabState();
}

class _VehiclePlaybackTabState extends ConsumerState<VehiclePlaybackTab>
    with AutomaticKeepAliveClientMixin {
  final MapController _map = MapController();
  bool _ready = false;

  List<TrackPoint> _points = <TrackPoint>[];
  List<StoppageEvent> _stoppages = <StoppageEvent>[];
  bool _loading = false;
  String? _error;

  double _playbackProgress = 0.0;
  bool _playing = false;
  double _speedMultiplier = 1;
  Timer? _ticker;

  static List<StoppageEvent> _computeStoppages(List<TrackPoint> points) {
    if (points.isEmpty) return <StoppageEvent>[];
    final List<StoppageEvent> stops = <StoppageEvent>[];
    TrackPoint? stopStart;
    TrackPoint? stopEnd;
    int movingCount = 0;

    for (int i = 0; i < points.length; i++) {
      final TrackPoint p = points[i];
      if (p.speed <= 3) {
        stopStart ??= p;
        stopEnd = p;
        movingCount = 0;
      } else {
        if (stopStart != null && stopEnd != null) {
          movingCount++;
          // Only break the stop if we have 2 consecutive points > 3 km/h
          if (movingCount >= 2) {
            final Duration diff = stopEnd.timestamp.difference(stopStart.timestamp);
            if (diff.inMinutes >= 5) {
              stops.add(StoppageEvent(
                lat: stopStart.latitude,
                lng: stopStart.longitude,
                startTime: stopStart.timestamp,
                endTime: stopEnd.timestamp,
                duration: diff,
                address: stopStart.address,
              ));
            }
            stopStart = null;
            stopEnd = null;
            movingCount = 0;
          }
        }
      }
    }

    if (stopStart != null && stopEnd != null) {
      final Duration diff = stopEnd.timestamp.difference(stopStart.timestamp);
      if (diff.inMinutes >= 5) {
        stops.add(StoppageEvent(
          lat: stopStart.latitude,
          lng: stopStart.longitude,
          startTime: stopStart.timestamp,
          endTime: stopEnd.timestamp,
          duration: diff,
          address: stopStart.address,
          isOngoing: true,
        ));
      }
    }

    return stops;
  }

  StoppageEvent? get _currentStoppage {
    if (_points.isEmpty) return null;
    final TrackPoint cursor = _currentPoint;
    for (final StoppageEvent s in _stoppages) {
      if (!cursor.timestamp.isBefore(s.startTime) &&
          !cursor.timestamp.isAfter(s.endTime)) {
        return s;
      }
    }
    return null;
  }

  TrackPoint get _currentPoint {
    if (_points.isEmpty) {
      return TrackPoint(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
      );
    }
    final int idx = _playbackProgress.floor().clamp(0, _points.length - 1);
    if (idx >= _points.length - 1) return _points.last;

    final double t = (_playbackProgress - idx).clamp(0.0, 1.0);
    final TrackPoint a = _points[idx];
    final TrackPoint b = _points[idx + 1];

    return TrackPoint(
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: a.longitude + (b.longitude - a.longitude) * t,
      timestamp: a.timestamp.add(
        Duration(
          milliseconds: (b.timestamp.difference(a.timestamp).inMilliseconds * t).round(),
        ),
      ),
      speed: a.speed + (b.speed - a.speed) * t,
      heading: a.heading + (b.heading - a.heading) * t,
      ignition: t < 0.5 ? a.ignition : b.ignition,
      address: t < 0.5 ? a.address : b.address,
    );
  }

  /// Only show the stopped card when the stoppage is >= 5 minutes.
  bool get _isCurrentlyStopped {
    if (_points.isEmpty) return false;
    final StoppageEvent? s = _currentStoppage;
    return s != null && s.duration.inMinutes >= 5;
  }

  late DateTimeRange _range = _todayRange();

  @override
  bool get wantKeepAlive => true;

  static DateTimeRange _todayRange() {
    final DateTime now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _playing = false;
      _ticker?.cancel();
    });

    try {
      final DateTime startLocal = _range.start;
      final DateTime endLocal = _range.end;

      final DateTime startIstUtc = DateTime.utc(
        startLocal.year, startLocal.month, startLocal.day,
        startLocal.hour, startLocal.minute, startLocal.second,
      );
      final DateTime endIstUtc = DateTime.utc(
        endLocal.year, endLocal.month, endLocal.day,
        endLocal.hour, endLocal.minute, endLocal.second,
      );

      final DateTime startQuery = startIstUtc.subtract(const Duration(hours: 5, minutes: 30));
      final DateTime endQuery = endIstUtc.subtract(const Duration(hours: 5, minutes: 30));

      final List<TrackPoint> pts =
          await ref.read(vehicleRepositoryProvider).getHistory(
                vehicleId: widget.vehicleId,
                start: startQuery,
                end: endQuery,
              );

      if (!mounted) return;

      // Sort chronologically — the API does not guarantee order.
      pts.sort((TrackPoint a, TrackPoint b) =>
          a.timestamp.compareTo(b.timestamp));

      // Filter strictly within selected UTC query range
      final List<TrackPoint> inRangePoints = pts.where((TrackPoint p) {
        final DateTime utcTime = p.timestamp.toUtc();
        return !utcTime.isBefore(startQuery) && !utcTime.isAfter(endQuery);
      }).toList();

      // Compute actual stoppages from full in-range points before downsampling
      final List<StoppageEvent> computedStops = _computeStoppages(inRangePoints);

      // Filter consecutive duplicates to keep map path clean
      final List<TrackPoint> cleanPoints = <TrackPoint>[];
      for (final TrackPoint p in inRangePoints) {
        if (cleanPoints.isEmpty) {
          cleanPoints.add(p);
        } else {
          final TrackPoint last = cleanPoints.last;
          if (p.latitude != last.latitude || p.longitude != last.longitude) {
            cleanPoints.add(p);
          }
        }
      }

      setState(() {
        _points = cleanPoints;
        _stoppages = computedStops;
        _playbackProgress = 0.0;
        _loading = false;
      });

      if (cleanPoints.isNotEmpty) await _fitRoute();
    } catch (e, stack) {
      debugPrint('Error in _load: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fitRoute() async {
    if (_points.isEmpty || !_ready) return;

    if (_points.length == 1) {
      _map.move(_points.first.latLng, 13);
      return;
    }

    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          _points.map((TrackPoint p) => p.latLng).toList(),
        ),
        padding: const EdgeInsets.all(48),
        maxZoom: 17,
      ),
    );
  }

  void _togglePlay() {
    if (_playing) {
      _ticker?.cancel();
      setState(() => _playing = false);
      return;
    }

    if (_playbackProgress >= _points.length - 1) _playbackProgress = 0.0;

    setState(() => _playing = true);
    _startTicker();
  }

  double get _effectiveSpeedMultiplier {
    switch (_speedMultiplier.round()) {
      case 1:
        return 1.0;
      case 2:
        return 4.0;
      case 3:
        return 12.0;
      case 4:
        return 36.0; // Blazing fast for rapid route playback
      default:
        return _speedMultiplier;
    }
  }

  void _startTicker() {
    _ticker?.cancel();

    // Replay tick runs at ~30 FPS (33ms) for sub-point smooth animation
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (Timer t) {
      if (!mounted || _playbackProgress >= _points.length - 1) {
        t.cancel();
        if (mounted) setState(() => _playing = false);
        return;
      }

      final int idx = _playbackProgress.floor();
      final TrackPoint a = _points[idx];
      final TrackPoint b = _points[idx + 1];
      final int diffMs = b.timestamp.difference(a.timestamp).inMilliseconds;
      final int effectiveDiffMs = diffMs.clamp(400, 3000);

      // Calculate step size so that progress smoothly advances
      final double step = (33.0 / effectiveDiffMs) * _effectiveSpeedMultiplier;

      setState(() {
        _playbackProgress += step;
        if (_playbackProgress >= _points.length - 1) {
          _playbackProgress = (_points.length - 1).toDouble();
        }
      });
      _followCamera();
    });
  }

  void _followCamera() {
    if (!_ready || _points.isEmpty) return;
    // Zoom 16.0 — street level with building footprints and narrow roads visible.
    final double zoom = _map.camera.zoom < 15.0 ? 16.0 : _map.camera.zoom;
    _map.move(_currentPoint.latLng, zoom);
  }

  /// Cumulative distance in km from first point to current progress.
  double get _distanceCovered {
    if (_points.length < 2 || _playbackProgress == 0) return 0;
    double total = 0;
    const Distance calc = Distance();
    final int idx = _playbackProgress.floor().clamp(0, _points.length - 1);
    for (int i = 1; i <= idx && i < _points.length; i++) {
      total += calc.as(
        LengthUnit.Kilometer,
        _points[i - 1].latLng,
        _points[i].latLng,
      );
    }
    // Also add the small interpolated slice to the current position
    if (idx < _points.length - 1) {
      total += calc.as(
        LengthUnit.Kilometer,
        _points[idx].latLng,
        _currentPoint.latLng,
      );
    }
    return total;
  }

  Future<void> _pickRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime(_range.start.year, _range.start.month, _range.start.day),
        end: DateTime(_range.end.year, _range.end.month, _range.end.day),
      ),
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );

    if (picked == null) return;

    // Always reset to full day when a new date is picked.
    setState(() {
      _range = DateTimeRange(
        start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        // ── Range selector ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _dateLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: Gap.xs),
              OutlinedButton(
                onPressed: _pickStartTime,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(_formatTime(_range.start)),
              ),
              const SizedBox(width: Gap.xs),
              OutlinedButton(
                onPressed: _pickEndTime,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(_formatTime(_range.end)),
              ),
              const SizedBox(width: Gap.xs),
              IconButton.filledTonal(
                tooltip: 'Reload route',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
        ),

        // ── Map ──────────────────────────────────────────────────
        Expanded(
          child: Stack(
            children: <Widget>[
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: const LatLng(17.385, 78.4867),
                  initialZoom: 11,
                  minZoom: 3,
                  maxZoom: 19,
                  backgroundColor: theme.colorScheme.surface,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    if (mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _ready = true);
                          if (_points.isNotEmpty) {
                            _fitRoute();
                          }
                        }
                      });
                    }
                  },
                ),
                children: <Widget>[
                  buildTileLayer(MapStyle.standard),
                  if (_points.length >= 2) ..._routeLayers(theme),
                  MarkerLayer(markers: _routeMarkers(theme)),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: OsmAttribution(style: MapStyle.standard, compact: true),
                  ),
                ],
              ),

              if (_loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x99070B16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: ErrorState(message: _error!, onRetry: _load),
                  ),
                )
              else if (_points.isEmpty)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: EmptyState(
                      icon: Icons.timeline_rounded,
                      title: 'No route data',
                      message: 'This vehicle did not report any positions in '
                          'the selected period.',
                      actionLabel: 'Choose another date',
                      onAction: _pickRange,
                    ),
                  ),
                ),


              // Floating info card — top-middle of the map
              if (_points.isNotEmpty && !_loading)
                Positioned(
                  top: Gap.md,
                  left: Gap.md,
                  right: Gap.md,
                  child: _PlaybackFloatingCard(
                    point: _currentPoint,
                    distKm: _distanceCovered,
                    playing: _playing,
                  ),
                ),

              // Active Stoppage Mini Card — Floating above the speed gauge when vehicle is stopped
              if (_points.isNotEmpty && !_loading && _isCurrentlyStopped)
                Positioned(
                  bottom: 152,
                  left: Gap.lg,
                  width: 195,
                  child: _ActiveStoppageLeftCard(
                    point: _currentPoint,
                    stoppage: _currentStoppage,
                  ),
                ),

              // Speed gauge — bottom-left, like the web app.
              if (_points.isNotEmpty && !_loading)
                Positioned(
                  bottom: Gap.lg,
                  left: Gap.lg,
                  child: _SpeedGauge(speed: _currentPoint.speed),
                ),
            ],
          ),
        ),

        // ── Transport controls ───────────────────────────────────
        if (_points.isNotEmpty && !_loading)
          _PlaybackControls(
            index: _playbackProgress.round().clamp(0, _points.length - 1),
            total: _points.length,
            playing: _playing,
            speed: _speedMultiplier,
            points: _points,
            onSeek: (double v) {
              setState(() => _playbackProgress = v);
            },
            onSeekEnd: _followCamera,
            onTogglePlay: _togglePlay,
            onSpeedChange: (double s) {
              setState(() => _speedMultiplier = s);
              if (_playing) _startTicker();
            },
            onRestart: () {
              setState(() => _playbackProgress = 0.0);
              _fitRoute();
            },
          ),
      ],
    );
  }

  String _dateLabel() {
    final DateTime istStart = _range.start.toUtc().add(const Duration(hours: 5, minutes: 30));
    final DateTime istEnd = _range.end.toUtc().add(const Duration(hours: 5, minutes: 30));
    final DateTime istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

    final bool sameDay = istStart.year == istEnd.year &&
        istStart.month == istEnd.month &&
        istStart.day == istEnd.day;

    if (sameDay) {
      final bool isToday = istStart.year == istNow.year &&
          istStart.month == istNow.month &&
          istStart.day == istNow.day;
      return isToday ? 'Today' : _formatDate(_range.start);
    }
    return '${_formatDateShort(_range.start)} — ${_formatDateShort(_range.end)}';
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_range.start),
    );
    if (time == null) return;

    final DateTime newStart = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
      time.hour,
      time.minute,
    );

    // Guard: start must be before end
    if (!newStart.isBefore(_range.end)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start time must be before end time')),
        );
      }
      return;
    }

    setState(() {
      _range = DateTimeRange(start: newStart, end: _range.end);
    });
    await _load();
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_range.end),
    );
    if (time == null) return;

    final DateTime newEnd = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
      time.hour,
      time.minute,
      59,
    );

    // Guard: end must be after start
    if (!newEnd.isAfter(_range.start)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
      }
      return;
    }

    setState(() {
      _range = DateTimeRange(start: _range.start, end: newEnd);
    });
    await _load();
  }

  /// Full route dimmed underneath, travelled portion highlighted on top with status colors.
  List<Widget> _routeLayers(ThemeData theme) {
    final List<LatLng> all =
        _points.map((TrackPoint p) => p.latLng).toList(growable: false);
    final int idx = _playbackProgress.floor().clamp(0, _points.length - 1);
    final List<TrackPoint> travelledPoints = _points.sublist(0, idx + 1);
    if (_playbackProgress > idx && idx < _points.length - 1) {
      travelledPoints.add(_currentPoint);
    }


    final List<Polyline<Object>> travelledPolylines = <Polyline<Object>>[
      Polyline<Object>(
        points: travelledPoints.map((TrackPoint p) => p.latLng).toList(),
        color: const Color(0xFF1565C0),
        strokeWidth: 5,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    ];

    return <Widget>[
      PolylineLayer<Object>(
        polylines: <Polyline<Object>>[
          Polyline<Object>(
            points: all,
            color: const Color(0xFF1565C0).withOpacity(0.24),
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        ],
      ),
      PolylineLayer<Object>(
        polylines: travelledPolylines,
      ),
    ];
  }

  List<Marker> _routeMarkers(ThemeData theme) {
    if (_points.isEmpty) return const <Marker>[];

    final TrackPoint cursor = _currentPoint;

    return <Marker>[
      // Playback waypoints — actual GPS fixes as blue dots (sampled every 10 points to avoid clutter)
      for (int i = 0; i < _points.length; i++)
        if (i % 10 == 0)
          Marker(
            point: _points[i].latLng,
            width: 8,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ),
      Marker(
        point: _points.first.latLng,
        width: 26,
        height: 26,
        child: const _RouteEndpoint(
          color: AppColors.moving,
          icon: Icons.play_arrow_rounded,
        ),
      ),
      Marker(
        point: _points.last.latLng,
        width: 26,
        height: 26,
        child: const _RouteEndpoint(
          color: AppColors.danger,
          icon: Icons.flag_rounded,
        ),
      ),
      // Stoppage Markers (P)
      for (final StoppageEvent stop in _stoppages)
        Marker(
          point: LatLng(stop.lat, stop.lng),
          width: 26,
          height: 26,
          child: GestureDetector(
            onTap: () {
              final int pIdx = _points.indexWhere((TrackPoint pt) =>
                  pt.timestamp.isAfter(stop.startTime) ||
                  pt.timestamp.isAtSameMomentAs(stop.startTime));
              if (pIdx != -1) {
                setState(() => _playbackProgress = pIdx.toDouble());
                _followCamera();
              }
            },
            child: _StoppagePin(duration: stop.duration),
          ),
        ),
      // Simple vehicle cursor — no popup card, no dots
      Marker(
        point: cursor.latLng,
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: _VehicleCursor(heading: cursor.heading),
      ),
    ];
  }
}

class _StoppagePin extends StatelessWidget {
  const _StoppagePin({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.danger.withOpacity(0.55),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Start / end pin.
class _RouteEndpoint extends StatelessWidget {
  const _RouteEndpoint({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.2),
          boxShadow: <BoxShadow>[
            BoxShadow(color: color.withOpacity(0.5), blurRadius: 8),
          ],
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      );
}

/// Simple animated vehicle cursor — just a dot + navigation arrow.
class _VehicleCursor extends StatelessWidget {
  const _VehicleCursor({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.signal.withOpacity(0.20),
            ),
          ),
          Transform.rotate(
            angle: heading * math.pi / 180,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.signal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.signal.withOpacity(0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.navigation_rounded,
                  size: 13, color: Colors.white),
            ),
          ),
        ],
      );
}

/// Circular speed gauge — mirrors the web app's bottom-left speedometer.
class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.speed});

  final double speed;

  @override
  Widget build(BuildContext context) {
    final int spd = speed.round();
    // max on gauge is 120 km/h
    final double fraction = (spd / 120).clamp(0.0, 1.0);
    final Color arcColor = spd > 80
        ? AppColors.danger
        : spd > 40
            ? AppColors.idle
            : AppColors.moving;

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _ArcPainter(fraction: fraction, color: arcColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'SPEED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$spd',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: arcColor,
                  height: 1,
                ),
              ),
              const Text(
                'Km/h',
                style: TextStyle(
                  fontSize: 8,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double startAngle = math.pi * 0.75;
    const double sweepFull = math.pi * 1.5;
    final Rect rect = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);

    // Background track
    canvas.drawArc(
      rect,
      startAngle,
      sweepFull,
      false,
      Paint()
        ..color = const Color(0xFFEEEEEE)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (fraction > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        sweepFull * fraction,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Combined vehicle dot + floating "Current Position" info card —
/// renders as a single tall Marker so the card hovers above the dot.
class _PlaybackMarker extends StatefulWidget {
  const _PlaybackMarker({required this.point, required this.distKm});

  final TrackPoint point;
  final double distKm;

  @override
  State<_PlaybackMarker> createState() => _PlaybackMarkerState();
}

class _PlaybackMarkerState extends State<_PlaybackMarker> {
  String? _address;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PlaybackMarker old) {
    super.didUpdateWidget(old);
    if (old.point.latitude != widget.point.latitude ||
        old.point.longitude != widget.point.longitude) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _resolveAddress();
      });
    }
  }

  void _resolveAddress() {
    if (widget.point.address != null &&
        widget.point.address!.trim().isNotEmpty) {
      setState(() => _address = widget.point.address);
      return;
    }
    setState(() => _address = null); // show nothing while resolving
    final TrackPoint snap = widget.point;
    Geocoder.getAddress(snap.latitude, snap.longitude).then((String a) {
      if (mounted && widget.point == snap && a != 'Location unavailable') {
        setState(() => _address = a);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int spd = widget.point.speed.round();
    final double dist = widget.distKm;
    final String time =
        '${widget.point.timestamp.day.toString().padLeft(2, '0')}-'
        '${widget.point.timestamp.month.toString().padLeft(2, '0')}-'
        '${widget.point.timestamp.year} '
        '${widget.point.timestamp.hour.toString().padLeft(2, '0')}:'
        '${widget.point.timestamp.minute.toString().padLeft(2, '0')}:'
        '${widget.point.timestamp.second.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Info card (mirrors web app "Current Position" popup) ──────
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Header
              const Text(
                'Current Position',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E),
                  letterSpacing: 0.3,
                ),
              ),
              const Divider(height: 8, thickness: 0.5),
              // LocTime
              _InfoRow(label: 'LocTime', value: time),
              // Speed
              _InfoRow(
                label: 'Speed',
                value: '$spd km/h',
                valueColor: spd > 80
                    ? AppColors.danger
                    : spd > 40
                        ? AppColors.idle
                        : AppColors.moving,
              ),
              // Distance covered
              _InfoRow(
                label: 'DistCov',
                value: dist < 1
                    ? '${(dist * 1000).round()} m'
                    : '${dist.toStringAsFixed(1)} km',
              ),
              // Address
              if (_address != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: Color(0xFF888888)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _address!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF444444),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ── Pointer triangle ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: CustomPaint(
            size: const Size(14, 8),
            painter: _TrianglePainter(),
          ),
        ),

        // ── Vehicle dot ───────────────────────────────────────────────
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.signal.withOpacity(0.22),
              ),
            ),
            Transform.rotate(
              angle: widget.point.heading * math.pi / 180,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.signal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.signal.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.navigation_rounded,
                    size: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 58,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF1565C0),
                ),
              ),
            ),
          ],
        ),
      );
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()..color = Colors.white;
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, p);
    // Subtle shadow on triangle
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter _) => false;
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.index,
    required this.total,
    required this.playing,
    required this.speed,
    required this.points,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onTogglePlay,
    required this.onSpeedChange,
    required this.onRestart,
  });

  final int index;
  final int total;
  final bool playing;
  final double speed;
  final List<TrackPoint> points;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSpeedChange;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        Gap.md,
        Gap.lg,
        MediaQuery.paddingOf(context).bottom + Gap.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _formatTime(points.first.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
              ),
              Expanded(
                child: Slider(
                  value: index.toDouble(),
                  min: 0,
                  max: (total - 1).toDouble().clamp(1, double.infinity),
                  onChanged: onSeek,
                  onChangeEnd: (_) => onSeekEnd(),
                ),
              ),
              Text(
                _formatTime(points.last.timestamp),
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: 'Restart',
                onPressed: onRestart,
                icon: const Icon(Icons.replay_rounded, size: 21),
              ),
              const SizedBox(width: Gap.md),
              SizedBox(
                width: 58,
                height: 58,
                child: FilledButton(
                  onPressed: onTogglePlay,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              PopupMenuButton<double>(
                tooltip: 'Playback speed',
                initialValue: speed,
                onSelected: onSpeedChange,
                itemBuilder: (BuildContext _) => <PopupMenuEntry<double>>[
                  for (final double s in <double>[1, 2, 3, 4])
                    PopupMenuItem<double>(
                      value: s,
                      child: Text('${s.round()}× speed'),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: Corners.rSm,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    '${speed.round()}×',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Point ${index + 1} of $total',
            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}

class _PlaybackFloatingCard extends StatefulWidget {
  const _PlaybackFloatingCard({
    required this.point,
    required this.distKm,
    required this.playing,
  });

  final TrackPoint point;
  final double distKm;
  final bool playing;

  @override
  State<_PlaybackFloatingCard> createState() => _PlaybackFloatingCardState();
}

class _PlaybackFloatingCardState extends State<_PlaybackFloatingCard> {
  String? _address;
  Timer? _debounce;
  DateTime? _lastFetchTime;
  LatLng? _lastFetchLatLng;
  int _lastRequestId = 0;

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PlaybackFloatingCard old) {
    super.didUpdateWidget(old);
    
    final LatLng target = widget.point.latLng;
    final DateTime now = DateTime.now();

    if (widget.point.address != null &&
        widget.point.address!.trim().isNotEmpty) {
      _debounce?.cancel();
      setState(() => _address = widget.point.address);
      return;
    }

    // 1. If paused / scrubbing (user is seeking):
    // Resolve location instantly with a very brief debounce (150ms) to ensure smooth scrub feeling
    if (!widget.playing) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _resolveAddress();
      });
      return;
    }

    // 2. If playing (running playback animation):
    // Throttled: Fetch every 150 meters OR every 3 seconds to keep it highly dynamic but rate-limited
    final bool firstFetch = _lastFetchTime == null || _lastFetchLatLng == null;
    final double distSq = firstFetch ? 0.0 :
        (target.latitude - _lastFetchLatLng!.latitude) * (target.latitude - _lastFetchLatLng!.latitude) +
        (target.longitude - _lastFetchLatLng!.longitude) * (target.longitude - _lastFetchLatLng!.longitude);

    final bool significantlyMoved = distSq > 0.0000022; // ~150 meters squared
    final bool cooldownOver = _lastFetchTime == null || now.difference(_lastFetchTime!) > const Duration(seconds: 3);

    if (firstFetch || (significantlyMoved && cooldownOver)) {
      _debounce?.cancel();
      _lastFetchTime = now;
      _lastFetchLatLng = target;
      _resolveAddress();
    }
  }

  void _resolveAddress() {
    if (widget.point.address != null &&
        widget.point.address!.trim().isNotEmpty) {
      setState(() => _address = widget.point.address);
      return;
    }
    // Prevent flickering: don't clear old address while loading new one
    if (_address == null) {
      setState(() => _address = 'Locating...');
    }
    final int currentId = ++_lastRequestId;
    final TrackPoint snap = widget.point;
    Geocoder.getAddress(snap.latitude, snap.longitude).then((String a) {
      if (mounted && currentId == _lastRequestId && a != 'Location unavailable') {
        setState(() => _address = a);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TrackPoint p = widget.point;
    final int spd = p.speed.round();

    final String timeStr = _toIstString(p.timestamp, Fmt.timeSec);
    final String dateStr = _toIstString(p.timestamp, Fmt.dateShort);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xEC1A233A), // Dark blue-grey glass
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                // Time & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Speed & Ignition
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '$spd km/h',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.ignition ? 'Ignition on' : 'Ignition off',
                      style: TextStyle(
                        fontSize: 9,
                        color: p.ignition
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Heading navigation arrow (cyan)
                Transform.rotate(
                  angle: p.heading * math.pi / 180,
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xFF00E5FF), // Bright Cyan arrow
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 0.8,
              color: Colors.white.withOpacity(0.08),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: Color(0xFF00E5FF), // Cyan location icon
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _address ?? 'Locating...',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Active Stoppage 2-Column Floating Card (Left side overlay when vehicle is stopped).
class _ActiveStoppageLeftCard extends StatefulWidget {
  const _ActiveStoppageLeftCard({
    required this.point,
    this.stoppage,
  });

  final TrackPoint point;
  final StoppageEvent? stoppage;

  @override
  State<_ActiveStoppageLeftCard> createState() => _ActiveStoppageLeftCardState();
}

class _ActiveStoppageLeftCardState extends State<_ActiveStoppageLeftCard> {
  String? _address;
  int _lastReqId = 0;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  @override
  void didUpdateWidget(covariant _ActiveStoppageLeftCard old) {
    super.didUpdateWidget(old);
    if (old.point.latitude != widget.point.latitude ||
        old.point.longitude != widget.point.longitude) {
      _fetchAddress();
    }
  }

  void _fetchAddress() {
    if (widget.point.address != null && widget.point.address!.trim().isNotEmpty) {
      setState(() => _address = widget.point.address);
      return;
    }
    final int req = ++_lastReqId;
    Geocoder.getAddress(widget.point.latitude, widget.point.longitude).then((String addr) {
      if (mounted && req == _lastReqId) {
        setState(() => _address = addr);
      }
    });
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final Uri uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final StoppageEvent? stop = widget.stoppage;
    final Duration dur = stop?.duration ?? Duration.zero;
    final String durStr = dur > Duration.zero ? stop!.compactDuration : '0s';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Material(
        color: const Color(0xF2111728), // Sleek dark glass
        child: InkWell(
          onTap: () => _openGoogleMaps(widget.point.latitude, widget.point.longitude),
          splashColor: const Color(0x333B82F6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.4),
                width: 0.9,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Header: Stopped + Duration badge
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.pause_circle_filled_rounded,
                      size: 13,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Stopped',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF6B6B),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durStr,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Address (2 lines readable)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _address ?? 'Locating...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Action: View on Maps indicator
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'View on Maps',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 10,
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
