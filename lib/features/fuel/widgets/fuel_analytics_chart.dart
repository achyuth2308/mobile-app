import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_telemetry_point.dart';

/// Fuel & Speed Chart matching the desktop "Fuel Raw Data (Graph)" portal:
/// - Filtered Fuel: Sky Blue Area Chart with smooth gradient fill
/// - Speed: Vibrant Orange polyline mapped to Right Y-Axis (0..100 km/h)
/// - Engine: Sun-Yellow step line along bottom axis (ON vs OFF)
class FuelAnalyticsChart extends StatelessWidget {
  const FuelAnalyticsChart({
    required this.points,
    this.height = 260.0,
    this.showFilteredFuel = true,
    this.showSpeed = false,
    this.showEngine = false,
    this.showAllFuel = false,
    this.showNormalize = false,
    super.key,
  });

  final List<FuelTelemetryPoint> points;
  final double height;
  final bool showFilteredFuel;
  final bool showSpeed;
  final bool showEngine;
  final bool showAllFuel;
  final bool showNormalize;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded,
                size: 38, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No fuel telemetry data for this period',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 1. Decimate points to ~60 points if dense to avoid performance lag and visual clutter
    final List<FuelTelemetryPoint> displayPoints;
    if (points.length > 70) {
      final double step = (points.length - 1) / 60.0;
      final List<FuelTelemetryPoint> sampled = <FuelTelemetryPoint>[];
      for (int i = 0; i < 60; i++) {
        final int idx = (i * step).round().clamp(0, points.length - 1);
        sampled.add(points[idx]);
      }
      if (sampled.last != points.last) {
        sampled.add(points.last);
      }
      displayPoints = sampled;
    } else {
      displayPoints = points;
    }

    // 2. Find first valid fuel reading to forward-fill midnight parked periods (00:00 to morning)
    double firstValidFuel = 0.0;
    for (final FuelTelemetryPoint pt in displayPoints) {
      final double val = pt.filteredFuel > 0 ? pt.filteredFuel : pt.displayFuel;
      if (val > 0) {
        firstValidFuel = val;
        break;
      }
    }

    // 3. Compute min & max bounds across active series
    double minFuel = double.infinity;
    double maxFuel = -double.infinity;
    double maxSpeed = 0.0;

    for (final FuelTelemetryPoint p in displayPoints) {
      final double f = p.filteredFuel > 0 ? p.filteredFuel : p.displayFuel;
      if (f > 0) {
        minFuel = min(minFuel, f);
        maxFuel = max(maxFuel, f);
      }
      maxSpeed = max(maxSpeed, p.speed);
    }

    if (minFuel == double.infinity) {
      minFuel = 0.0;
      maxFuel = firstValidFuel > 0 ? firstValidFuel + 20 : 100.0;
    }

    // Left Y-Axis (Fuel): scale from 0 to ceil(maxFuel)
    final double plotMinFuel = 0.0;
    final double plotMaxFuel = max(40.0, ((maxFuel + 20) / 25.0).ceil() * 25.0);

    // Right Y-Axis (Speed): 0 to 100 km/h (or higher if vehicle drove faster)
    final double plotMaxSpeed =
        max(100.0, ((maxSpeed + 15) / 25.0).ceil() * 25.0);

    // Build spots for each series
    final List<FlSpot> filteredFuelSpots = <FlSpot>[];
    final List<FlSpot> speedSpots = <FlSpot>[];
    final List<FlSpot> engineSpots = <FlSpot>[];

    final double engineOnY = plotMinFuel + (0.05 * (plotMaxFuel - plotMinFuel));
    double lastKnownFuel = firstValidFuel;

    for (int i = 0; i < displayPoints.length; i++) {
      final FuelTelemetryPoint pt = displayPoints[i];
      final double x = i.toDouble();

      // Filtered Fuel (Blue Area) - forward filled so overnight parking stays flat at startFuel
      if (showFilteredFuel) {
        double fVal = pt.filteredFuel > 0 ? pt.filteredFuel : pt.displayFuel;
        if (fVal <= 0.0 && lastKnownFuel > 0.0) {
          fVal = lastKnownFuel;
        } else if (fVal > 0.0) {
          lastKnownFuel = fVal;
        }
        filteredFuelSpots.add(FlSpot(x, fVal.clamp(plotMinFuel, plotMaxFuel)));
      }

      // Speed (Orange line mapped to Right Y-Axis scale)
      if (showSpeed) {
        final double speedFraction = (pt.speed / plotMaxSpeed).clamp(0.0, 1.0);
        final double speedY =
            plotMinFuel + (speedFraction * (plotMaxFuel - plotMinFuel));
        speedSpots.add(FlSpot(x, speedY));
      }

      // Engine Ignition (Yellow bottom step line: elevated when ON, baseline when OFF)
      if (showEngine) {
        final double eY = pt.ignition ? engineOnY : plotMinFuel;
        engineSpots.add(FlSpot(x, eY));
      }
    }

    final double maxX = (displayPoints.length - 1).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: max(1, maxX),
          minY: plotMinFuel,
          maxY: plotMaxFuel,
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            // Subtle, sleek touch dot indicators (replaces oversized circle blobs)
            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((int index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    strokeWidth: 1.2,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, idx) => FlDotCirclePainter(
                      radius: 3.5,
                      color: bar.color ?? const Color(0xFF0284C7),
                      strokeWidth: 1.8,
                      strokeColor: Colors.white,
                    ),
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) =>
                  const Color(0xFF0F172A).withValues(alpha: 0.95),
              tooltipRoundedRadius: 8,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                if (touchedSpots.isEmpty) return [];
                final int idx = touchedSpots.first.x.round();
                if (idx < 0 || idx >= displayPoints.length) return [];
                final FuelTelemetryPoint pt = displayPoints[idx];

                final String timeStr = DateFormat('HH:mm:ss dd/MM/yyyy').format(pt.timestamp);
                final double currentFuel = pt.filteredFuel > 0 ? pt.filteredFuel : pt.displayFuel;
                final double finalFuel = currentFuel > 0 ? currentFuel : lastKnownFuel;
                final String fuelStr = 'Fuel : ${finalFuel.toStringAsFixed(2)} Ltrs';
                final String ignStr = 'Engine : ${pt.ignition ? 'ON' : 'OFF'}';
                final String odoStr = 'Odo : ${pt.odo.toStringAsFixed(2)}';
                final String spdStr = 'Speed (Kms) : ${pt.speed.round()}';

                final List<String> lines = <String>[
                  timeStr,
                  fuelStr,
                  ignStr,
                  odoStr,
                  spdStr
                ];

                // Correctly identify Vehicle 24V supply vs Internal GPS battery
                final dynamic rawExtVolt = pt.raw['voltage'] ??
                    pt.raw['extVolt'] ??
                    pt.raw['external_voltage'] ??
                    pt.raw['vIn'];
                final dynamic rawIntBatt = pt.raw['battery'] ??
                    pt.raw['vBatt'] ??
                    pt.raw['internal_battery'];

                if (rawExtVolt != null) {
                  final double? dVolt = double.tryParse(rawExtVolt.toString());
                  if (dVolt != null) {
                    lines.add('Veh Battery : ${dVolt.toStringAsFixed(2)} V');
                  } else {
                    lines.add('Veh Battery : $rawExtVolt V');
                  }
                }
                if (rawIntBatt != null) {
                  lines.add('GPS Battery : $rawIntBatt V');
                }

                return List<LineTooltipItem?>.generate(
                  touchedSpots.length,
                  (int i) {
                    if (i == 0) {
                      return LineTooltipItem(
                        lines.join('\n'),
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      );
                    }
                    return null;
                  },
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: max(1.0, (plotMaxFuel - plotMinFuel) / 4),
            verticalInterval: max(1.0, maxX / 4),
            getDrawingHorizontalLine: (value) => const FlLine(
              color: Color(0xFFE2E8F0),
              strokeWidth: 0.8,
            ),
            getDrawingVerticalLine: (value) => const FlLine(
              color: Color(0xFFE2E8F0),
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
              left: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
              right: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
              top: BorderSide(color: Color(0xFFCBD5E1), width: 0.8),
            ),
          ),
          titlesData: FlTitlesData(
            // Left Axis = Fuel (Ltrs) - Matching desktop portal left Y-axis
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: max(1.0, (plotMaxFuel - plotMinFuel) / 4),
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${value.round()}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Right Axis = Speed (km/h) - Matching desktop portal right Y-axis (only when Speed active)
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: showSpeed,
                reservedSize: showSpeed ? 30 : 0,
                interval: max(1.0, (plotMaxFuel - plotMinFuel) / 4),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final double fraction =
                      ((value - plotMinFuel) / (plotMaxFuel - plotMinFuel))
                          .clamp(0.0, 1.0);
                  final int speedVal = (fraction * plotMaxSpeed).round();
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '$speedVal',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            // Bottom Axis = Time (Date & Time)
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: max(1.0, maxX / 4),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int idx = value.round();
                  if (idx < 0 || idx >= displayPoints.length) {
                    return const SizedBox.shrink();
                  }
                  final DateTime t = displayPoints[idx].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('HH:mm').format(t),
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            // 1. ENGINE IGNITION (Yellow step line along bottom axis)
            if (showEngine && engineSpots.isNotEmpty)
              LineChartBarData(
                spots: engineSpots,
                isCurved: false,
                color: const Color(0xFFEAB308), // Sun Yellow
                barWidth: 2.8,
                dotData: const FlDotData(show: false),
              ),

            // 2. FILTERED FUEL (Sky-Blue Filled Area)
            if (showFilteredFuel && filteredFuelSpots.isNotEmpty)
              LineChartBarData(
                spots: filteredFuelSpots,
                isCurved: false,
                color: const Color(0xFF38BDF8),
                barWidth: 1.8,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.70),
                      const Color(0xFF0284C7).withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),

            // 3. SPEED (Vibrant Orange Line)
            if (showSpeed && speedSpots.isNotEmpty)
              LineChartBarData(
                spots: speedSpots,
                isCurved: false,
                color: const Color(0xFFEA580C), // Vibrant Orange
                barWidth: 1.6,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}
