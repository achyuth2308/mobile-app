  @override
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

        // TOP FLOATING BAR (Back, Name) - NO DATE PICKER
        Positioned(
          top: MediaQuery.of(context).padding.top + Gap.md,
          left: Gap.md,
          right: Gap.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BACK BUTTON PILL (Left)
              _GlassContainer(
                shape: BoxShape.circle,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: isDarkMap ? Colors.white : Colors.black87),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              
              const Spacer(),
              
              // VEHICLE NAME PILL (Center)
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
              
              const Spacer(),
              
              // Empty space to balance the back button
              const SizedBox(width: 48),
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
              address: _currentAddress,
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
                    address: _currentAddress,
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
