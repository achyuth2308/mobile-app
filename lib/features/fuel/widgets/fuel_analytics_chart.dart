import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_telemetry_point.dart';

class FuelAnalyticsChart extends StatefulWidget {
  const FuelAnalyticsChart({
    required this.points,
    this.showAllFuel = false,
    this.showFilteredFuel = true,
    this.showNormalize = true,
    this.showSpeed = true,
    this.showEngine = true,
    super.key,
  });

  final List<FuelTelemetryPoint> points;
  final bool showAllFuel;
  final bool showFilteredFuel;
  final bool showNormalize;
  final bool showSpeed;
  final bool showEngine;

  @override
  State<FuelAnalyticsChart> createState() => _FuelAnalyticsChartState();
}

class _FuelAnalyticsChartState extends State<FuelAnalyticsChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No fuel telemetry data for this period',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Compute min & max bounds for Fuel and Speed
    double minFuel = double.infinity;
    double maxFuel = -double.infinity;
    double maxSpeed = 0.0;

    for (final FuelTelemetryPoint p in widget.points) {
      final double f = p.displayFuel;
      if (f > 0) {
        minFuel = min(minFuel, f);
        maxFuel = max(maxFuel, f);
      }
      maxSpeed = max(maxSpeed, p.speed);
    }

    if (minFuel == double.infinity) {
      minFuel = 0.0;
      maxFuel = 100.0;
    }

    // The web app sets the Fuel Y-axis baseline to 0 (full tank scale).
    // Starting from 0 prevents small 3-5L ripples from taking up the entire screen height!
    const double plotMinFuel = 0.0;
    final double plotMaxFuel =
        max(100.0, ((maxFuel * 1.18) / 50.0).ceil() * 50.0);

    final double plotMaxSpeed = max(60.0, (maxSpeed / 20.0).ceil() * 20.0);

    final List<FlSpot> filteredFuelSpots = <FlSpot>[];
    final List<FlSpot> speedSpots = <FlSpot>[];
    final List<FlSpot> engineSpots = <FlSpot>[];

    for (int i = 0; i < widget.points.length; i++) {
      final FuelTelemetryPoint pt = widget.points[i];
      final double x = i.toDouble();

      // Filtered Fuel spots (cyan / sky blue area line)
      if (widget.showFilteredFuel) {
        filteredFuelSpots.add(FlSpot(x, pt.filteredFuel > 0 ? pt.filteredFuel : pt.displayFuel));
      }

      // Speed is mapped from [0..plotMaxSpeed] to [plotMinFuel..plotMaxFuel]
      if (widget.showSpeed) {
        final double speedNorm = (pt.speed / plotMaxSpeed).clamp(0.0, 1.0);
        final double speedY = plotMinFuel + (speedNorm * (plotMaxFuel - plotMinFuel));
        speedSpots.add(FlSpot(x, speedY));
      }

      // Engine ignition indicator (step line at bottom of plot height if ignition == true)
      if (widget.showEngine && pt.ignition) {
        final double engineY = plotMinFuel + (0.04 * (plotMaxFuel - plotMinFuel));
        engineSpots.add(FlSpot(x, engineY));
      }
    }

    final double maxX = (widget.points.length - 1).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Chart Sub-header with Dual Axis Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEA580C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Speed (km/h)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0284C7),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Fuel Level (Ltrs)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. The LineChart
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max(1, maxX),
                minY: plotMinFuel,
                maxY: plotMaxFuel,
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((int spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.7),
                          strokeWidth: 1.0,
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4.0,
                            color: bar.color ?? const Color(0xFF0284C7),
                            strokeWidth: 2.0,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (response != null &&
                        response.lineBarSpots != null &&
                        response.lineBarSpots!.isNotEmpty) {
                      final int idx = response.lineBarSpots!.first.x.round();
                      if (idx >= 0 && idx < widget.points.length) {
                        setState(() => _hoveredIndex = idx);
                      }
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot spot) =>
                        const Color(0xFF1E293B).withValues(alpha: 0.95),
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      if (touchedSpots.isEmpty) return [];
                      final int idx = touchedSpots.first.x.round();
                      if (idx < 0 || idx >= widget.points.length) return [];
                      final FuelTelemetryPoint pt = widget.points[idx];

                      final String timeStr =
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(pt.timestamp);
                      final String fuelStr =
                          'Fuel : ${pt.displayFuel.toStringAsFixed(1)} ltrs';
                      final String speedStr =
                          'Speed : ${pt.speed.round()} Kmph';
                      final String ignStr =
                          'Ignition : ${pt.ignition ? 'ON' : 'OFF'}';
                      final String odoStr =
                          'Device Odo : ${pt.odo.toStringAsFixed(1)}';

                      final String fullText =
                          '$timeStr\n$fuelStr\n$speedStr\n$ignStr\n$odoStr';

                      // Return list with exact same length as touchedSpots
                      return List<LineTooltipItem?>.generate(
                        touchedSpots.length,
                        (int i) {
                          if (i == 0) {
                            return LineTooltipItem(
                              fullText,
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
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
                  horizontalInterval: max(1.0, (plotMaxFuel - plotMinFuel) / 5),
                  verticalInterval: max(1.0, maxX / 5),
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => const FlLine(
                    color: Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    left: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    right: BorderSide(color: Color(0xFFCBD5E1), width: 1),
                    top: BorderSide.none,
                  ),
                ),
                titlesData: FlTitlesData(
                  // Left Axis = Speed (km/h)
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: (plotMaxFuel - plotMinFuel) / 4,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final double fraction =
                            ((value - plotMinFuel) / (plotMaxFuel - plotMinFuel))
                                .clamp(0.0, 1.0);
                        final int speedVal = (fraction * plotMaxSpeed).round();
                        return Text(
                          '$speedVal',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEA580C),
                          ),
                        );
                      },
                    ),
                  ),
                  // Right Axis = Fuel (Ltrs)
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: (plotMaxFuel - plotMinFuel) / 4,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${value.round()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  // Bottom Axis = Time
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: max(1.0, maxX / 4),
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int idx = value.round();
                        if (idx < 0 || idx >= widget.points.length) {
                          return const SizedBox.shrink();
                        }
                        final DateTime t = widget.points[idx].timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('hh:mm a').format(t),
                            style: const TextStyle(
                              fontSize: 9,
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
                  // 1. Filtered Fuel (Cyan blue filled line with gradient underneath)
                  if (widget.showFilteredFuel && filteredFuelSpots.isNotEmpty)
                    LineChartBarData(
                      spots: filteredFuelSpots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: const Color(0xFF0284C7),
                      barWidth: 2.2,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: 0.22),
                            const Color(0xFF0284C7).withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),

                  // 2. Engine Running / Ignition step line
                  if (widget.showEngine && engineSpots.isNotEmpty)
                    LineChartBarData(
                      spots: engineSpots,
                      isCurved: false,
                      color: const Color(0xFFEAB308),
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                    ),

                  // 3. Speed curve (Cyan / Orange line)
                  if (widget.showSpeed && speedSpots.isNotEmpty)
                    LineChartBarData(
                      spots: speedSpots,
                      isCurved: true,
                      curveSmoothness: 0.15,
                      color: const Color(0xFF06B6D4),
                      barWidth: 1.8,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. Callout banner for currently hovered / inspected packet
          if (_hoveredIndex != null &&
              _hoveredIndex! >= 0 &&
              _hoveredIndex! < widget.points.length) ...[
            _HoveredPacketBanner(point: widget.points[_hoveredIndex!]),
          ] else ...[
            // Legend
            const _ChartLegend(),
          ],
        ],
      ),
    );
  }
}

class _HoveredPacketBanner extends StatelessWidget {
  const _HoveredPacketBanner({required this.point});

  final FuelTelemetryPoint point;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Text(
                DateFormat('HH:mm:ss').format(point.timestamp),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            'Fuel: ${point.displayFuel.toStringAsFixed(1)} L',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Speed: ${point.speed.round()} km/h',
            style: const TextStyle(
              color: Color(0xFFFB923C),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: point.ignition
                  ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                  : const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              point.ignition ? 'IGN ON' : 'IGN OFF',
              style: TextStyle(
                color: point.ignition
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFF87171),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Fuel (L)', const Color(0xFF0284C7)),
        const SizedBox(width: 16),
        _legendItem('Speed (km/h)', const Color(0xFFF97316)),
        const SizedBox(width: 16),
        _legendItem('Engine Active', const Color(0xFFFBBF24)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
