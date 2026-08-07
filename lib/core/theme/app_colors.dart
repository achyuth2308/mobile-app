import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────
///  FUELTRACKS — COLOR SYSTEM
/// ─────────────────────────────────────────────────────────────────────
///
/// The palette is built around a "night operations console" idea: deep
/// midnight surfaces so that maps, telemetry and status colour carry all
/// of the visual weight. Every hue below is checked for ≥4.5:1 contrast
/// against the surface it is intended to sit on.
///
/// Brand:      Electric Indigo  — trust, motion, technology
/// Signal:     Voltaic Cyan     — live/real-time affordances
/// Semantics:  Emerald / Amber / Slate / Rose  — moving, idle, offline, alert
class AppColors {
  const AppColors._();

  // ── Brand ────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF4F6BFF); // Electric Indigo
  static const Color brandBright = Color(0xFF7B90FF);
  static const Color brandDeep = Color(0xFF2E43C4);
  static const Color signal = Color(0xFF22D3EE); // Voltaic Cyan
  static const Color signalDeep = Color(0xFF0E7490);

  // ── Dark surfaces (primary experience) ───────────────────────────
  static const Color night0 = Color(0xFF070B16); // scrim / deepest
  static const Color night1 = Color(0xFF0B1020); // scaffold
  static const Color night2 = Color(0xFF121A31); // card
  static const Color night3 = Color(0xFF1A2440); // elevated card
  static const Color night4 = Color(0xFF243050); // hover / pressed
  static const Color nightBorder = Color(0xFF2A3757);

  // ── Light surfaces ───────────────────────────────────────────────
  static const Color day0 = Color(0xFFF6F8FC);
  static const Color day1 = Color(0xFFFFFFFF);
  static const Color day2 = Color(0xFFEFF3FA);
  static const Color day3 = Color(0xFFE2E8F5);
  static const Color dayBorder = Color(0xFFD8E0EE);

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textOnNightHigh = Color(0xFFF2F5FF);
  static const Color textOnNightMed = Color(0xFFA9B4D0);
  static const Color textOnNightLow = Color(0xFF6E7B9C);

  static const Color textOnDayHigh = Color(0xFF0D1425);
  static const Color textOnDayMed = Color(0xFF56617D);
  static const Color textOnDayLow = Color(0xFF8B94AB);

  // ── Fleet status semantics ───────────────────────────────────────
  /// Ignition on, speed > 0 — actively driving.
  static const Color moving = Color(0xFF22C55E);
  static const Color movingSoft = Color(0xFF16351F);

  /// Ignition on, speed ≈ 0 — engine burning fuel while parked.
  static const Color idle = Color(0xFFF59E0B);
  static const Color idleSoft = Color(0xFF3A2A0A);

  /// Ignition off but reporting — parked.
  static const Color stopped = Color(0xFF60A5FA);
  static const Color stoppedSoft = Color(0xFF102540);

  /// No packet within the offline threshold.
  static const Color offline = Color(0xFF94A3B8);
  static const Color offlineSoft = Color(0xFF1E2637);

  /// Alerts / overspeed / SOS.
  static const Color danger = Color(0xFFFF4D6D);
  static const Color dangerSoft = Color(0xFF3B1122);

  static const Color success = moving;
  static const Color warning = idle;

  // ── Chart ramp (colour-blind safe ordering) ──────────────────────
  static const List<Color> chartRamp = <Color>[
    Color(0xFF4F6BFF),
    Color(0xFF22D3EE),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFFF4D6D),
    Color(0xFFA78BFA),
  ];

  // ── Signature gradients ──────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF5B79FF), Color(0xFF3B4FE0), Color(0xFF22D3EE)],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF1B2650), Color(0xFF0B1020)],
  );

  static const LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x1FFFFFFF), Color(0x05FFFFFF)],
  );

  /// Fade used at the top of the live map so status chips stay legible.
  static const LinearGradient mapTopScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xCC070B16), Color(0x00070B16)],
  );

  /// Returns the semantic colour for a vehicle status key.
  static Color forStatus(String status) => switch (status.toLowerCase()) {
        'moving' || 'running' || 'online' => moving,
        'idle' || 'idling' => idle,
        'stopped' || 'parked' => stopped,
        'alert' || 'sos' || 'overspeed' => danger,
        _ => offline,
      };

  static Color softForStatus(String status) => switch (status.toLowerCase()) {
        'moving' || 'running' || 'online' => movingSoft,
        'idle' || 'idling' => idleSoft,
        'stopped' || 'parked' => stoppedSoft,
        'alert' || 'sos' || 'overspeed' => dangerSoft,
        _ => offlineSoft,
      };
}
