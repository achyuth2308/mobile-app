import 'package:flutter/services.dart';

class SirenServicePlatform {
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  void startSiren({String? title, String? message}) {
    _isPlaying = true;
    // On native platforms, trigger repeated haptic pulses as fallback
    HapticFeedback.heavyImpact();
  }

  void stopSiren() {
    _isPlaying = false;
  }
}

SirenServicePlatform createSirenService() => SirenServicePlatform();
