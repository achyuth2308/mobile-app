import 'dart:io';

void main() async {
  final file = File(r'lib\features\vehicle\tabs\vehicle_playback_tab.dart');
  var content = await file.readAsString();

  // 1. Pass isDarkMap to _PlaybackControls
  content = content.replaceFirst(
    'speed: _speedMultiplier,',
    'speed: _speedMultiplier,\n                  isDarkMap: isDarkMap,'
  );

  // 2. Add isDarkMap to _PlaybackControls constructor
  content = content.replaceFirst(
    'required this.onRestart,',
    'required this.onRestart,\n    required this.isDarkMap,'
  );
  content = content.replaceFirst(
    'final VoidCallback onRestart;',
    'final VoidCallback onRestart;\n  final bool isDarkMap;'
  );

  // 3. Update _PlaybackControlsState.build
  final buildRegex = RegExp(r'@override\s+Widget build\(BuildContext context\) \{\s+final ThemeData theme = Theme.of\(context\);\s+final bool isDark = theme.brightness == Brightness.dark;\s+return Padding\(\s+padding: const EdgeInsets.fromLTRB\(16, 0, 16, 16\),\s+child: AnimatedContainer\([\s\S]*?child: _isExpanded \? _buildExpandedControls\(isDark, theme\) : _buildCollapsedButton\(isDark, theme\),\s+\),\s+\),\s+\),\s+\);\s+\}');
  
  if (!buildRegex.hasMatch(content)) {
    print('Failed to match build method!');
    return;
  }
  
  content = content.replaceFirst(buildRegex, '''
    @override
    Widget build(BuildContext context) {
      final ThemeData theme = Theme.of(context);
      final bool isDarkMap = widget.isDarkMap;
  
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: _isExpanded ? double.infinity : 180,
              decoration: BoxDecoration(
                color: isDarkMap ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDarkMap ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isExpanded ? _buildExpandedControls(isDarkMap, theme) : _buildCollapsedButton(isDarkMap, theme),
              ),
            ),
          ),
        ),
      );
    }
''');

  // 4. Update _buildCollapsedButton
  final collapsedRegex = RegExp(r'Widget _buildCollapsedButton\(bool isDark, ThemeData theme\) \{[\s\S]*?child: Row\(\s+mainAxisSize: MainAxisSize.min,\s+mainAxisAlignment: MainAxisAlignment.center,\s+children: \[\s+Container\(\s+padding: const EdgeInsets.all\(8\),\s+decoration: const BoxDecoration\(\s+color: Color\(0xFF3B82F6\),\s+shape: BoxShape.circle,\s+\),\s+child: const Icon\(Icons.play_arrow_rounded, color: Colors.white, size: 24\),\s+\),\s+const SizedBox\(width: 12\),\s+const Text\(\s+''Play History'',\s+style: TextStyle\(\s+fontSize: 16,\s+fontWeight: FontWeight.bold,\s+letterSpacing: 0.5,\s+color: Colors.black87,\s+\),\s+\),\s+\],\s+\),\s+\),\s+\);\s+\}');
  
  if (!collapsedRegex.hasMatch(content)) {
    print('Failed to match collapsed button!');
  } else {
    content = content.replaceFirst(collapsedRegex, '''
    Widget _buildCollapsedButton(bool isDarkMap, ThemeData theme) {
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
                decoration: BoxDecoration(
                  color: isDarkMap ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: isDarkMap ? Colors.white : Colors.black87, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Play History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDarkMap ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }
''');
  }

  // 5. Update _buildExpandedControls' play button
  final expandedRegex = RegExp(r'          // Play/Pause Button\s+Container\(\s+width: 48,\s+height: 48,\s+decoration: const BoxDecoration\(\s+color: Color\(0xFF3B82F6\),\s+shape: BoxShape.circle,\s+\),\s+child: IconButton\(\s+onPressed: widget.onTogglePlay,\s+icon: Icon\(\s+widget.playing \? Icons.pause_rounded : Icons.play_arrow_rounded,\s+color: Colors.white,\s+\),\s+\),\s+\),');
  if (!expandedRegex.hasMatch(content)) {
    print('Failed to match expanded button!');
  } else {
    content = content.replaceFirst(expandedRegex, '''
          // Play/Pause Button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.onTogglePlay,
              icon: Icon(
                widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
''');
  }

  await file.writeAsString(content);
  print('Done applying changes!');
}
