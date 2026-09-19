import 'dart:io';

void main() async {
  final file = File(r'lib\features\vehicle\tabs\vehicle_playback_tab.dart');
  var content = await file.readAsString();

  // 1. Replace `build` method layout
  final startMarker = '  @override\n  Widget build(BuildContext context) {';
  final endMarker = '  Future<void> _pickStartTime() async {';
  
  int startIndex = content.indexOf(startMarker);
  int endIndex = content.indexOf(endMarker);
  
  if (startIndex != -1 && endIndex != -1) {
    final before = content.substring(0, startIndex);
    final after = content.substring(endIndex);
    
    final newBuild = '''  @override
  Widget build(BuildContext context) {
    super.build(context);

    final ThemeData theme = Theme.of(context);
    final String mapTypeKey = ref.watch(secureStoreProvider).mapType;
    final MapStyle mapType = MapStyleX.fromKey(mapTypeKey);
    final bool isDarkMap = mapType == MapStyle.satellite;

    if (!_isInitialized) {
      return _buildInitialSelectionScreen(theme);
    }
    
    final vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));
    final String vehicleName = vehicle?.displayName.toUpperCase() ?? 'VEHICLE';

    return Stack(
      children: <Widget>[
        // MAP
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
            buildTileLayer(
              MapStyleX.fromKey(ref.read(secureStoreProvider).mapType),
              apiKey: ref.read(authProvider).user?.apiKey,
            ),
            if (_points.length >= 2) ..._routeLayers(theme),
            MarkerLayer(markers: _routeMarkers(theme)),
            Align(
              alignment: Alignment.bottomRight,
              child: OsmAttribution(
                style: MapStyleX.fromKey(ref.read(secureStoreProvider).mapType),
                compact: true,
              ),
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
                onAction: () => setState(() => _isInitialized = false),
              ),
            ),
          ),

        // TOP FLOATING BAR (Back, Name, Date)
        Positioned(
          top: MediaQuery.of(context).padding.top + Gap.md,
          left: Gap.md,
          right: Gap.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // BACK BUTTON PILL
              _GlassContainer(
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: isDarkMap ? Colors.white : Colors.black87),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              
              // VEHICLE NAME PILL
              _GlassContainer(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Text(
                    vehicleName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDarkMap ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              
              // DATE PICKER PILL
              _GlassContainer(
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(Icons.calendar_month_rounded, color: isDarkMap ? Colors.white : Colors.black87),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Select Playback Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton.icon(onPressed: _pickStartDate, icon: const Icon(Icons.calendar_today_rounded, size: 16), label: Text(_formatDateShort(_range.start)))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton.icon(onPressed: _pickEndDate, icon: const Icon(Icons.event_rounded, size: 16), label: Text(_formatDateShort(_range.end)))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: OutlinedButton.icon(onPressed: _pickStartTime, icon: const Icon(Icons.access_time_rounded, size: 16), label: Text(_formatTime(_range.start)))),
                                const SizedBox(width: 8),
                                Expanded(child: OutlinedButton.icon(onPressed: _pickEndTime, icon: const Icon(Icons.access_time_filled_rounded, size: 16), label: Text(_formatTime(_range.end)))),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  if (!_loading) _load();
                                },
                                child: const Text('Apply & Reload'),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // FLOATING INFO CARD
        if (_points.isNotEmpty && !_loading)
          Positioned(
            top: MediaQuery.of(context).padding.top + Gap.md + 64 + Gap.md,
            left: Gap.md,
            right: Gap.md,
            child: _PlaybackFloatingCard(
              point: _currentPoint,
              distKm: _distanceCovered,
              playing: _playing,
            ),
          ),
          
        // SPEEDOMETER (Animated Reveal)
        if (_points.isNotEmpty && !_loading)
          Positioned(
            bottom: Gap.md + 80 + Gap.md, // Above the playback controls
            left: Gap.md,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _hasStartedPlayback ? 1.0 : 0.0,
              child: _SpeedGauge(speed: _currentPoint.speed),
            ),
          ),

        // BOTTOM CONTROLS & STOPPAGE
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_points.isNotEmpty && !_loading && _isCurrentlyStopped)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: _ActiveStoppageBottomCard(
                    point: _currentPoint,
                    stoppage: _currentStoppage,
                  ),
                ),
              if (_points.isNotEmpty && !_loading && _isCurrentlyStopped)
                const SizedBox(height: Gap.md),
              if (_points.isNotEmpty && !_loading)
                _PlaybackControls(
                  index: _playbackProgress.floor().clamp(0, _points.length - 1),
                  total: _points.length,
                  playing: _playing,
                  speed: _speed,
                  points: _points,
                  onSeek: _seek,
                  onSeekEnd: _seekEnd,
                  onTogglePlay: _togglePlay,
                  onSpeedChange: _setSpeed,
                  onRestart: _restart,
                ),
            ],
          ),
        ),
      ],
    );
  }

''';
    content = before + newBuild + after;
  }

  // 2. Add _hasStartedPlayback state
  if (!content.contains('bool _hasStartedPlayback = false;')) {
    content = content.replaceFirst('  bool _playing = false;', '  bool _playing = false;\n  bool _hasStartedPlayback = false;');
    content = content.replaceFirst(
      '  void _togglePlay() {',
      '  void _togglePlay() {\n    if (!_hasStartedPlayback) setState(() => _hasStartedPlayback = true);'
    );
  }

  // 3. Fix Locating... flash
  content = content.replaceAll(
    'setState(() => _address = null); // show nothing while resolving',
    "if (_address == null) setState(() => _address = 'Locating...');"
  );
  
  // Also pass currentId down to prevent race conditions if it wasn't there
  // Actually, wait, _PlaybackFloatingCard might just have:
  /*
      setState(() => _address = null); // show nothing while resolving
      final TrackPoint snap = widget.point;
      Geocoder.getAddress(snap.latitude, snap.longitude).then((String a) {
  */
  // Which I just replaced with my if(_address == null) logic!

  // 4. Map Markers: Use green flag and red flag pins
  final markerOld = '''  List<Marker> _routeMarkers(ThemeData theme) {
    if (_points.isEmpty) return const <Marker>[];

    final TrackPoint cursor = _currentPoint;

    return <Marker>[
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
          icon: Icons.stop_rounded,
        ),
      ),''';
  
  final markerBetterNew = '''  List<Marker> _routeMarkers(ThemeData theme) {
    if (_points.isEmpty) return const <Marker>[];

    final TrackPoint cursor = _currentPoint;

    return <Marker>[
      Marker(
        point: _points.first.latLng,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: const _FlagPin(color: AppColors.moving),
      ),
      Marker(
        point: _points.last.latLng,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: const _FlagPin(color: AppColors.danger),
      ),''';
  content = content.replaceFirst(markerOld, markerBetterNew);

  // 5. Update the _PlaybackControls widget to be a StatefulWidget
  final oldControlsStart = 'class _PlaybackControls extends StatelessWidget {';
  final oldControlsEnd = 'class _PlaybackFloatingCard extends StatefulWidget {'; // Because HEAD was restored, it's StatefulWidget
  
  final controlsStartIndex = content.indexOf(oldControlsStart);
  final controlsEndIndex = content.indexOf(oldControlsEnd);
  
  if (controlsStartIndex != -1 && controlsEndIndex != -1) {
    final newControls = '''class _PlaybackControls extends StatefulWidget {
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
  State<_PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<_PlaybackControls> {
  bool _isExpanded = false;

  String _formatTime(DateTime dt) {
    return '\${dt.hour.toString().padLeft(2, '0')}:\${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: _isExpanded ? double.infinity : 180,
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isExpanded ? _buildExpandedControls(isDark, theme) : _buildCollapsedButton(isDark, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedButton(bool isDark, ThemeData theme) {
    return InkWell(
      key: const ValueKey('collapsed'),
      onTap: () {
        setState(() => _isExpanded = true);
        widget.onTogglePlay(); // Start playing immediately
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Play History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedControls(bool isDark, ThemeData theme) {
    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          // Play/Pause Button
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.onTogglePlay,
              icon: Icon(
                widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Slider
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(widget.points[widget.index].timestamp),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    Text(
                      _formatTime(widget.points.last.timestamp),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ],
                ),
                SizedBox(
                  height: 24,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: const Color(0xFF38BDF8),
                      inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                      thumbColor: const Color(0xFF38BDF8),
                    ),
                    child: Slider(
                      value: widget.index.toDouble(),
                      min: 0,
                      max: (widget.total - 1).toDouble().clamp(1, double.infinity),
                      onChanged: widget.onSeek,
                      onChangeEnd: (_) => widget.onSeekEnd(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // Speed Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: [1.0, 2.0, 4.0, 8.0].contains(widget.speed) ? widget.speed : 1.0,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              isDense: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: const [
                DropdownMenuItem(value: 1.0, child: Text('1x')),
                DropdownMenuItem(value: 2.0, child: Text('2x')),
                DropdownMenuItem(value: 4.0, child: Text('4x')),
                DropdownMenuItem(value: 8.0, child: Text('8x')),
              ],
              onChanged: (v) {
                if (v != null) widget.onSpeedChange(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagPin extends StatelessWidget {
  const _FlagPin({required this.color});
  final Color color;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.location_on, color: color, size: 40),
        const Positioned(
          top: 6,
          child: Icon(Icons.flag_rounded, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

''';
    content = content.replaceRange(controlsStartIndex, controlsEndIndex, newControls);
  }

  // Replace _GlassContainer logic if it doesn't exist
  if (!content.contains('class _GlassContainer')) {
    content += '''\nclass _GlassContainer extends StatelessWidget {
  const _GlassContainer({super.key, required this.child, this.borderRadius, this.shape});
  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape? shape;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(100),
      child: BackdropFilter(
        filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.4),
            borderRadius: borderRadius,
            shape: shape ?? BoxShape.rectangle,
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}\n''';
    // Add import dart:ui
    content = content.replaceFirst("import 'dart:math' as math;", "import 'dart:math' as math;\nimport 'dart:ui' as dart_ui;");
  }

  await file.writeAsString(content);
  print('apply_all completed.');
}
