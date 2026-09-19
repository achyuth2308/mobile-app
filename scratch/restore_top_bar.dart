import 'dart:io';

void main() async {
  final file = File(r'lib\features\vehicle\tabs\vehicle_playback_tab.dart');
  var content = await file.readAsString();

  final insertionPoint = '        // FLOATING INFO CARD';
  
  final topFloatingBarCode = '''
        // TOP FLOATING BAR (Back, Name)
        Positioned(
          top: MediaQuery.of(context).padding.top + Gap.md,
          left: Gap.md,
          right: Gap.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BACK BUTTON PILL (Left)
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMap ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMap ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: isDarkMap ? Colors.white : Colors.black87),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // VEHICLE NAME PILL (Center)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMap ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDarkMap ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        vehicle?.displayName.toUpperCase() ?? 'VEHICLE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDarkMap ? Colors.white : Colors.black87,
                        ),
                      ),
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
''';

  content = content.replaceFirst(insertionPoint, topFloatingBarCode + '\n' + insertionPoint);
  
  // Need to add `dart:ui` import if it's missing, and need `vehicle` variable inside `build`.
  if (!content.contains('import \\'dart:ui\\' as dart_ui;')) {
    content = content.replaceFirst('import \\'dart:math\\' as math;', 'import \\'dart:math\\' as math;\\nimport \\'dart:ui\\' as dart_ui;');
  }
  
  if (!content.contains('final vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));')) {
    content = content.replaceFirst(
      '    if (!_isInitialized) {',
      '    final vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));\\n    if (!_isInitialized) {'
    );
  }
  
  await file.writeAsString(content);
}
