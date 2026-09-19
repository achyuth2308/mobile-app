import 'dart:io';

void main() {
  final c = File('lib/features/vehicle/tabs/vehicle_playback_tab.dart').readAsStringSync();
  print('build: \${c.indexOf('  @override\\n  Widget build(BuildContext context) {')}');
  print('pickStartTime: \${c.indexOf('  Future<void> _pickStartTime() async {')}');
}
