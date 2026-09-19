import 'dart:io';

void main() async {
  final file = File(r'lib\features\vehicle\tabs\vehicle_playback_tab.dart');
  var content = await file.readAsString();

  // 1. Map Markers: Use green flag and red flag pins
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
      
  final markerNew = '''  List<Marker> _routeMarkers(ThemeData theme) {
    if (_points.isEmpty) return const <Marker>[];

    final TrackPoint cursor = _currentPoint;

    return <Marker>[
      Marker(
        point: _points.first.latLng,
        width: 36,
        height: 36,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_on, color: AppColors.moving, size: 36),
      ),
      Marker(
        point: _points.last.latLng,
        width: 36,
        height: 36,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_on, color: AppColors.danger, size: 36),
      ),''';

  content = content.replaceFirst(markerOld, markerNew);
  if (!content.contains('width: 36')) print('Warning: Marker replacement failed.');

  // Wait, the user specifically asked for "green flag and end represented as red flag pins"
  // Let's use Icons.flag_rounded or a composite pin.
  // I will use a custom pin with a flag inside it!
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
  content = content.replaceFirst(markerNew, markerBetterNew);
  // Actually, wait, `markerOld` replacement was skipped, I should replace `markerOld` directly!
  content = content.replaceAll(markerOld, markerBetterNew);
  
  // 2. Add `_lastKnownAddress` logic
  if (!content.contains('String? _lastKnownAddress;')) {
    content = content.replaceFirst(
      '  TrackPoint get _currentPoint =>',
      '  String? _lastKnownAddress;\n\n  TrackPoint get _currentPoint =>'
    );
    
    // Add _currentAddress getter
    content = content.replaceFirst(
      '  TrackPoint get _currentPoint =>',
      '''  String get _currentAddress {
    final pt = _points.isEmpty ? null : _points[_playbackProgress.floor().clamp(0, _points.length - 1)];
    if (pt != null && pt.address != null && pt.address!.isNotEmpty) {
      _lastKnownAddress = pt.address;
    }
    return _lastKnownAddress ?? 'Locating...';
  }

  TrackPoint get _currentPoint =>'''
    );
  }

  // 3. Replace `point.address ?? 'Locating...'` with the new address getter in the build method.
  // Wait, _PlaybackFloatingCard and _ActiveStoppageBottomCard both take `point.address`.
  // I can just pass the computed address to them!
  content = content.replaceAll(
    'point: _currentPoint,',
    'point: _currentPoint,\n              address: _currentAddress,'
  );
  // Remove duplicate address: _currentAddress if any
  content = content.replaceAll('address: _currentAddress,\n              address: _currentAddress,', 'address: _currentAddress,');

  // 4. Update the _PlaybackControls widget to be a StatefulWidget
  final oldControlsStart = 'class _PlaybackControls extends StatelessWidget {';
  final oldControlsEnd = 'class _PlaybackFloatingCard extends ConsumerWidget {';
  
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
        width: _isExpanded ? double.infinity : 200,
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

  // 5. Update _PlaybackFloatingCard and _ActiveStoppageBottomCard
  content = content.replaceAll(
    'class _PlaybackFloatingCard extends ConsumerWidget {\n  const _PlaybackFloatingCard({\n    required this.point,\n    required this.distKm,\n    required this.playing,\n  });\n\n  final TrackPoint point;',
    'class _PlaybackFloatingCard extends ConsumerWidget {\n  const _PlaybackFloatingCard({\n    required this.point,\n    required this.address,\n    required this.distKm,\n    required this.playing,\n  });\n\n  final TrackPoint point;\n  final String address;'
  );
  content = content.replaceAll("point.address ?? 'Locating...'", "address");

  content = content.replaceAll(
    'class _ActiveStoppageBottomCard extends ConsumerWidget {\n  const _ActiveStoppageBottomCard({\n    required this.point,\n    this.stoppage,\n  });\n\n  final TrackPoint point;',
    'class _ActiveStoppageBottomCard extends ConsumerWidget {\n  const _ActiveStoppageBottomCard({\n    required this.point,\n    required this.address,\n    this.stoppage,\n  });\n\n  final TrackPoint point;\n  final String address;'
  );

  // Speedometer reveal animation tied to Play History button press
  // Wait, _isExpanded is inside _PlaybackControlsState, but Speedometer is inside _VehiclePlaybackTabState!
  // I need to track playback started state in _VehiclePlaybackTabState.
  if (!content.contains('bool _hasStartedPlayback = false;')) {
    content = content.replaceFirst('  bool _playing = false;', '  bool _playing = false;\n  bool _hasStartedPlayback = false;');
    content = content.replaceFirst(
      '  void _togglePlay() {',
      '  void _togglePlay() {\n    if (!_hasStartedPlayback) setState(() => _hasStartedPlayback = true);'
    );
    // Wrap speedometer in AnimatedOpacity
    final speedometerStr = 'child: _SpeedGauge(speed: _currentPoint.speed),';
    final animatedSpeedometerStr = '''child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _hasStartedPlayback ? 1.0 : 0.0,
              child: _SpeedGauge(speed: _currentPoint.speed),
            ),''';
    content = content.replaceFirst(speedometerStr, animatedSpeedometerStr);
  }

  await file.writeAsString(content);
  print('Mod11 completed.');
}
