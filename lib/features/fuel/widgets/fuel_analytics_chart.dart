import 'dart:math';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/fuel_telemetry_point.dart';

/// Horizontally scrollable & two-finger pinch-zoomable Fuel & Speed Chart:
/// - Fixed Left Y-Axis: Fuel level (Ltrs)
/// - Fixed Right Y-Axis: Speed (km/h) (when Speed series is active)
/// - Two-finger pinch-to-zoom (1.0x to 6.0x) and 1-finger horizontal pan
/// - Mouse-wheel / trackpad zoom support for web & DevTools testing
/// - Dedicated high-contrast dots & value badge painter when zoomed in
/// - Custom translucent speech-bubble callout tooltip on tap
class FuelAnalyticsChart extends StatefulWidget {
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
  State<FuelAnalyticsChart> createState() => _FuelAnalyticsChartState();
}

class _FuelAnalyticsChartState extends State<FuelAnalyticsChart> {
  int? _selectedPointIdx;
  final ScrollController _scrollController = ScrollController();

  // Multi-touch tracking for 2-finger horizontal zoom & 1-finger horizontal pan
  double _scale = 1.0;
  double _baseContentWidth = 1400.0;
  final Map<int, Offset> _activePointers = <int, Offset>{};
  double _initialPinchDistance = 0.0;
  double _pinchInitialScale = 1.0;
  double _lastPanX = 0.0;
  double _lastPanY = 0.0;
  bool _isPinching = false;
  bool _isHorizontalPanning = false;

  @override
  void didUpdateWidget(covariant FuelAnalyticsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points != oldWidget.points) {
      _selectedPointIdx = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyZoom(double targetScale, double? focalViewportX) {
    if ((targetScale - _scale).abs() < 0.005) return;
    final double oldScale = _scale;
    final double focalX = focalViewportX ?? 160.0;
    final double currentOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final double currentWidth = _baseContentWidth * oldScale;
    final double contentPoint = currentOffset + focalX;
    final double fraction = (contentPoint / currentWidth).clamp(0.0, 1.0);

    setState(() {
      _scale = targetScale;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final double newWidth = _baseContentWidth * _scale;
        final double newOffset = (fraction * newWidth) - focalX;
        final double maxOffset = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(newOffset.clamp(0.0, max(0.0, maxOffset)));
      }
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 1) {
      _lastPanX = event.localPosition.dx;
      _lastPanY = event.localPosition.dy;
      _isPinching = false;
      _isHorizontalPanning = false;
    } else if (_activePointers.length == 2) {
      _isPinching = true;
      _isHorizontalPanning = false;
      final List<Offset> pts = _activePointers.values.toList();
      _initialPinchDistance = (pts[0].dx - pts[1].dx).abs();
      _pinchInitialScale = _scale;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length >= 2) {
      _isPinching = true;
      final List<Offset> pts = _activePointers.values.toList();
      final double currentDistance = (pts[0].dx - pts[1].dx).abs();
      final double focalX = (pts[0].dx + pts[1].dx) / 2;
      if (_initialPinchDistance > 12.0) {
        final double ratio = currentDistance / _initialPinchDistance;
        final double targetScale = (_pinchInitialScale * ratio).clamp(1.0, 6.0);
        _applyZoom(targetScale, focalX);
      }
    } else if (_activePointers.length == 1 && !_isPinching) {
      final double deltaX = event.localPosition.dx - _lastPanX;
      final double deltaY = event.localPosition.dy - _lastPanY;

      if (!_isHorizontalPanning) {
        if (deltaX.abs() > 4.0 && deltaX.abs() > deltaY.abs() * 1.2) {
          _isHorizontalPanning = true;
        }
      }

      if (_isHorizontalPanning && _scrollController.hasClients) {
        _lastPanX = event.localPosition.dx;
        _lastPanY = event.localPosition.dy;
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double target =
            (_scrollController.offset - deltaX).clamp(0.0, maxScroll);
        _scrollController.jumpTo(target);
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _isPinching = false;
      _isHorizontalPanning = false;
    } else if (_activePointers.length == 1) {
      _lastPanX = _activePointers.values.first.dx;
      _lastPanY = _activePointers.values.first.dy;
      _isHorizontalPanning = false;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) {
      _isPinching = false;
      _isHorizontalPanning = false;
    }
  }

  static Widget _emptyTitleWidget(double value, TitleMeta meta) =>
      const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Container(
        height: widget.height,
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

    // 1. Sample dense telemetry to ~160 points for rich, smooth 24h timeline
    final List<FuelTelemetryPoint> displayPoints;
    if (widget.points.length > 180) {
      final double step = (widget.points.length - 1) / 160.0;
      final List<FuelTelemetryPoint> sampled = <FuelTelemetryPoint>[];
      for (int i = 0; i < 160; i++) {
        final int idx = (i * step).round().clamp(0, widget.points.length - 1);
        sampled.add(widget.points[idx]);
      }
      if (sampled.last != widget.points.last) {
        sampled.add(widget.points.last);
      }
      displayPoints = sampled;
    } else {
      displayPoints = widget.points;
    }

    // 2. Find first valid fuel reading to forward-fill overnight parked periods
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
    const double plotMinFuel = 0.0;
    final double plotMaxFuel = max(40.0, ((maxFuel + 20) / 25.0).ceil() * 25.0);
    final double fuelInterval = max(1.0, (plotMaxFuel - plotMinFuel) / 4);

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

      // Fuel (Blue Area) - forward filled so overnight parking stays flat at startFuel
      if (widget.showFilteredFuel) {
        double fVal = pt.filteredFuel > 0 ? pt.filteredFuel : pt.displayFuel;
        if (fVal <= 0.0 && lastKnownFuel > 0.0) {
          fVal = lastKnownFuel;
        } else if (fVal > 0.0) {
          lastKnownFuel = fVal;
        }
        filteredFuelSpots.add(FlSpot(x, fVal.clamp(plotMinFuel, plotMaxFuel)));
      }

      // Speed (Orange line mapped to Right Y-Axis scale)
      if (widget.showSpeed) {
        final double speedFraction = (pt.speed / plotMaxSpeed).clamp(0.0, 1.0);
        final double speedY =
            plotMinFuel + (speedFraction * (plotMaxFuel - plotMinFuel));
        speedSpots.add(FlSpot(x, speedY));
      }

      // Engine Ignition (Yellow bottom step line: elevated when ON, baseline when OFF)
      if (widget.showEngine) {
        final double eY = pt.ignition ? engineOnY : plotMinFuel;
        engineSpots.add(FlSpot(x, eY));
      }
    }

    final double maxX = (displayPoints.length - 1).toDouble();
    // Base width: generous ~12px per spot, minimum 1300px
    _baseContentWidth = max(1300.0, displayPoints.length * 12.0);
    // Dynamic canvas width scaled by horizontal zoom factor (1.0x to 6.0x)
    final double chartContentWidth = _baseContentWidth * _scale;
    final double timeInterval = max(1.0, maxX / (12.0 * min(_scale, 2.5)));
    final double plotAreaHeight = widget.height - 26.0;

    // Construct the bars (dots are painted via dedicated _TimelineDotsAndBadgesPainter)
    final List<LineChartBarData> bars = <LineChartBarData>[];

    if (widget.showEngine && engineSpots.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: engineSpots,
          isCurved: false,
          color: const Color(0xFFEAB308), // Sun Yellow
          barWidth: 2.8,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    if (widget.showFilteredFuel && filteredFuelSpots.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: filteredFuelSpots,
          isCurved: false,
          color: const Color(0xFF38BDF8),
          barWidth: 2.0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF38BDF8).withOpacity(0.65),
                const Color(0xFF0284C7).withOpacity(0.18),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.showSpeed && speedSpots.isNotEmpty) {
      bars.add(
        LineChartBarData(
          spots: speedSpots,
          isCurved: false,
          color: const Color(0xFFEA580C), // Vibrant Orange
          barWidth: 1.8,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    // Compute spot coordinates for the selected point (SpeechBubbleTooltip)
    double? spotX;
    double? spotY;
    FuelTelemetryPoint? selectedPt;
    double? selectedFuel;

    if (_selectedPointIdx != null &&
        _selectedPointIdx! >= 0 &&
        _selectedPointIdx! < displayPoints.length) {
      selectedPt = displayPoints[_selectedPointIdx!];
      final double rawFuel = selectedPt.filteredFuel > 0
          ? selectedPt.filteredFuel
          : selectedPt.displayFuel;
      selectedFuel = rawFuel > 0 ? rawFuel : lastKnownFuel;

      spotX = (_selectedPointIdx! / max(1, displayPoints.length - 1)) *
          chartContentWidth;
      final double fuelFraction =
          ((selectedFuel - plotMinFuel) / (plotMaxFuel - plotMinFuel))
              .clamp(0.0, 1.0);
      spotY = (1.0 - fuelFraction) * plotAreaHeight;
    }

    const double bubbleWidth = 175.0;
    const double bubbleHeight = 116.0;

    double tooltipLeft = 0.0;
    double tooltipTop = 0.0;
    bool arrowPointsDown = true;
    double arrowXFraction = 0.5;

    if (spotX != null && spotY != null) {
      if (spotY < plotAreaHeight * 0.45) {
        arrowPointsDown = false;
        tooltipTop = spotY + 6.0;
      } else {
        arrowPointsDown = true;
        tooltipTop = (spotY - bubbleHeight - 6.0)
            .clamp(2.0, plotAreaHeight - bubbleHeight);
      }

      final double idealLeft = spotX - (bubbleWidth / 2);
      tooltipLeft = idealLeft.clamp(4.0, chartContentWidth - bubbleWidth - 4.0);
      arrowXFraction = ((spotX - tooltipLeft) / bubbleWidth).clamp(0.12, 0.88);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Fixed Left Y-Axis (Fuel Litres) - Tightened width from 34px to 26px
        SizedBox(
          width: 26,
          height: widget.height,
          child: LineChart(
            LineChartData(
              minY: plotMinFuel,
              maxY: plotMaxFuel,
              minX: 0,
              maxX: 1,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  right: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: fuelInterval,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text(
                          '${value.round()}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: _emptyTitleWidget,
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: const [FlSpot(0, 0), FlSpot(1, 0)],
                  color: Colors.transparent,
                  barWidth: 0,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),

        // 2. Horizontally Scrollable & Two-Finger Pinch-Zoomable Graph Canvas
        Expanded(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            onPointerSignal: (PointerSignalEvent event) {
              if (event is PointerScrollEvent) {
                // Mouse wheel / trackpad pinch zoom for web and desktop
                if (event.scrollDelta.dy != 0) {
                  final double zoomFactor =
                      event.scrollDelta.dy < 0 ? 1.15 : 0.87;
                  final double targetScale =
                      (_scale * zoomFactor).clamp(1.0, 6.0);
                  _applyZoom(targetScale, event.localPosition.dx);
                }
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _applyZoom(1.0, null),
              onTapUp: (TapUpDetails details) {
                final double tapX = details.localPosition.dx +
                    (_scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0);
                final double fraction =
                    (tapX / chartContentWidth).clamp(0.0, 1.0);
                final int tappedIdx = (fraction * (displayPoints.length - 1))
                    .round()
                    .clamp(0, displayPoints.length - 1);
                setState(() {
                  _selectedPointIdx =
                      (_selectedPointIdx == tappedIdx) ? null : tappedIdx;
                });
              },
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                  width: chartContentWidth,
                  height: widget.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Base Chart Lines & Area Fill
                      LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: max(1, maxX),
                          minY: plotMinFuel,
                          maxY: plotMaxFuel,
                          lineTouchData: const LineTouchData(enabled: false),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: fuelInterval,
                            verticalInterval: timeInterval,
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
                            border: Border(
                              bottom: const BorderSide(
                                  color: Color(0xFF94A3B8), width: 1.2),
                              top: const BorderSide(
                                  color: Color(0xFFCBD5E1), width: 0.8),
                              right: widget.showSpeed
                                  ? BorderSide.none
                                  : const BorderSide(
                                      color: Color(0xFF94A3B8), width: 1.2),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 26,
                                interval: timeInterval,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                  final int idx = value.round();
                                  if (idx < 0 ||
                                      idx >= displayPoints.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final DateTime t =
                                      displayPoints[idx].timestamp;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      DateFormat('HH:mm').format(t),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: bars,
                        ),
                      ),

                      // Translucent Speech-Bubble Callout & Spot Target Indicators
                      if (spotX != null &&
                          spotY != null &&
                          selectedPt != null &&
                          selectedFuel != null) ...[
                        // 1. Vertical guideline
                        Positioned(
                          left: spotX - 0.75,
                          top: 0,
                          bottom: 26,
                          child: IgnorePointer(
                            child: Container(
                              width: 1.5,
                              color: const Color(0xFF0284C7)
                                  .withOpacity(0.45),
                            ),
                          ),
                        ),

                        // 2. Data spot glow circle
                        Positioned(
                          left: spotX - 4.5,
                          top: spotY - 4.5,
                          child: IgnorePointer(
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7)
                                        .withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 3. Transparent Speech-Bubble Callout Card (Matches Image 1)
                        Positioned(
                          left: tooltipLeft,
                          top: tooltipTop,
                          width: bubbleWidth,
                          child: IgnorePointer(
                            child: SpeechBubbleTooltip(
                              point: selectedPt,
                              fuel: selectedFuel,
                              arrowPointsDown: arrowPointsDown,
                              arrowXOffset: arrowXFraction,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

        // 3. Fixed Right Y-Axis (Speed km/h) - Pinned outside the scrollable canvas
        if (widget.showSpeed) ...[
          SizedBox(
            width: 32,
            height: widget.height,
            child: LineChart(
              LineChartData(
                minY: plotMinFuel,
                maxY: plotMaxFuel,
                minX: 0,
                maxX: 1,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: Color(0xFF94A3B8), width: 1.2),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: fuelInterval,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final double fraction = ((value - plotMinFuel) /
                                (plotMaxFuel - plotMinFuel))
                            .clamp(0.0, 1.0);
                        final int speedVal =
                            (fraction * plotMaxSpeed).round();
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
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: _emptyTitleWidget,
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [FlSpot(0, 0), FlSpot(1, 0)],
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dedicated Canvas painter for Data Point Circles & Zoom-Triggered Value Badges:
/// - Overview Mode (scale <= 1.2x): Crisp, prominent circular dots.
/// - Zoomed Mode (scale > 1.2x):
///   - Fuel: Deep Blue numeric badges (e.g. 138, 75) rendered above each dot with a contrast pill.
///   - Speed: Vibrant Orange numeric badges (e.g. 24, 0) rendered above each dot.
/// - Adaptive stride so numbers never collide or overlap when points are dense.
class _TimelineDotsAndBadgesPainter extends CustomPainter {
  const _TimelineDotsAndBadgesPainter({
    required this.points,
    required this.plotMinFuel,
    required this.plotMaxFuel,
    required this.plotMaxSpeed,
    required this.plotAreaHeight,
    required this.chartContentWidth,
    required this.scale,
    required this.showFuel,
    required this.showSpeed,
    required this.lastKnownFuel,
  });

  final List<FuelTelemetryPoint> points;
  final double plotMinFuel;
  final double plotMaxFuel;
  final double plotMaxSpeed;
  final double plotAreaHeight;
  final double chartContentWidth;
  final double scale;
  final bool showFuel;
  final bool showSpeed;
  final double lastKnownFuel;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Progressive disclosure:
    // 1. Unzoomed (scale <= 1.08x): Clean graph line & area (NO DOTS, NO NUMBERS)
    // 2. Gentle spread (scale > 1.08x): Data points / dots appear on curve
    // 3. Spreading (scale > 1.25x): Exact numbers appear above dots
    if (scale <= 1.08) {
      return;
    }

    final int total = points.length;
    final double stepX = total > 1 ? chartContentWidth / (total - 1) : 0.0;
    final bool showNumbers = scale > 1.25;

    // Adaptive label stride so numbers never collide
    int labelStride = 1;
    if (stepX < 26.0) {
      labelStride = 4;
    } else if (stepX < 40.0) {
      labelStride = 3;
    } else if (stepX < 55.0) {
      labelStride = 2;
    } else {
      labelStride = 1;
    }

    final Paint fuelDotPaint = Paint()
      ..color = const Color(0xFF38BDF8) // Sky Blue
      ..style = PaintingStyle.fill;

    final Paint speedDotPaint = Paint()
      ..color = const Color(0xFFEA580C) // Vibrant Orange
      ..style = PaintingStyle.fill;

    final Paint whiteBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const double dotRadius = 3.8;

    for (int i = 0; i < total; i++) {
      final FuelTelemetryPoint pt = points[i];
      final double px = (i * stepX).clamp(0.0, chartContentWidth);
      double? pySpeed;

      // 1. Draw Speed Dot & Badge (if enabled)
      if (showSpeed) {
        final double speedFraction = (pt.speed / plotMaxSpeed).clamp(0.0, 1.0);
        pySpeed = (1.0 - speedFraction) * plotAreaHeight;
        final Offset speedOffset = Offset(px, pySpeed);

        canvas.drawCircle(speedOffset, dotRadius, speedDotPaint);
        canvas.drawCircle(speedOffset, dotRadius, whiteBorderPaint);

        if (showNumbers && (i % labelStride == 0)) {
          _drawValueBadge(
            canvas: canvas,
            text: '${pt.speed.round()}',
            anchor: speedOffset,
            color: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFEDD5),
            isAbove: true,
          );
        }
      }

      // 2. Draw Fuel Dot & Badge (if enabled)
      if (showFuel) {
        double fVal = pt.filteredFuel > 0 ? pt.filteredFuel : pt.displayFuel;
        if (fVal <= 0.0 && lastKnownFuel > 0.0) {
          fVal = lastKnownFuel;
        }
        final double fuelFraction =
            ((fVal - plotMinFuel) / (plotMaxFuel - plotMinFuel)).clamp(0.0, 1.0);
        final double pyFuel = (1.0 - fuelFraction) * plotAreaHeight;
        final Offset fuelOffset = Offset(px, pyFuel);

        canvas.drawCircle(fuelOffset, dotRadius, fuelDotPaint);
        canvas.drawCircle(fuelOffset, dotRadius, whiteBorderPaint);

        if (showNumbers && (i % labelStride == 0)) {
          final bool placeAbove =
              !showSpeed || pySpeed == null || pyFuel <= pySpeed;
          _drawValueBadge(
            canvas: canvas,
            text: '${fVal.round()}',
            anchor: fuelOffset,
            color: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
            isAbove: placeAbove,
          );
        }
      }
    }
  }

  void _drawValueBadge({
    required Canvas canvas,
    required String text,
    required Offset anchor,
    required Color color,
    required Color bgColor,
    required bool isAbove,
  }) {
    final TextSpan span = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();

    const double hPad = 3.5;
    const double vPad = 1.5;
    final double badgeW = tp.width + (hPad * 2);
    final double badgeH = tp.height + (vPad * 2);

    final double topY = isAbove
        ? anchor.dy - badgeH - 5.0
        : anchor.dy + 5.0;
    final double leftX = anchor.dx - (badgeW / 2);

    final RRect pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftX, topY, badgeW, badgeH),
      const Radius.circular(4.0),
    );

    // Subtle background pill for high contrast against gridlines
    final Paint pillPaint = Paint()
      ..color = bgColor.withOpacity(0.94)
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawRRect(pillRect, pillPaint);
    canvas.drawRRect(pillRect, borderPaint);

    tp.paint(canvas, Offset(leftX + hPad, topY + vPad));
  }

  @override
  bool shouldRepaint(covariant _TimelineDotsAndBadgesPainter old) {
    return old.scale != scale ||
        old.chartContentWidth != chartContentWidth ||
        old.showFuel != showFuel ||
        old.showSpeed != showSpeed ||
        old.points != points;
  }
}

/// Translucent Speech-Bubble Callout Widget matching Image 1:
/// - Distinct callout pointer triangle (▼ or ▲) touching the data spot
/// - Translucent charcoal grey background (55% opacity) letting fuel curve shine through
/// - 5 clean lines of telemetry info
class SpeechBubbleTooltip extends StatelessWidget {
  const SpeechBubbleTooltip({
    required this.point,
    required this.fuel,
    this.arrowPointsDown = true,
    this.arrowXOffset = 0.5,
    super.key,
  });

  final FuelTelemetryPoint point;
  final double fuel;
  final bool arrowPointsDown;
  final double arrowXOffset;

  @override
  Widget build(BuildContext context) {
    final String timeStr =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(point.timestamp);
    final String fuelStr = 'Fuel :${fuel.toStringAsFixed(2)} ltrs';
    final String speedStr = 'Speed : ${point.speed.round()} Kmph';
    final String ignStr = 'Ignition : ${point.ignition ? 'ON' : 'OFF'}';
    final String odoStr = 'Device Odo : ${point.odo.toStringAsFixed(1)}';

    return CustomPaint(
      painter: _SpeechBubblePainter(
        color: const Color(0x942B3441), // Translucent charcoal grey matching Image 1 (~58% opacity)
        borderColor: Colors.white.withOpacity(0.25),
        arrowPointsDown: arrowPointsDown,
        arrowXFraction: arrowXOffset,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          arrowPointsDown ? 9 : 17,
          12,
          arrowPointsDown ? 17 : 9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              fuelStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            Text(
              speedStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            Text(
              ignStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            Text(
              odoStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter that renders a speech-bubble card with a triangular pointer
class _SpeechBubblePainter extends CustomPainter {
  const _SpeechBubblePainter({
    required this.color,
    required this.borderColor,
    this.arrowPointsDown = true,
    this.arrowXFraction = 0.5,
  });

  static const double arrowWidth = 14.0;
  static const double arrowHeight = 9.0;
  static const double radius = 4.0;

  final Color color;
  final Color borderColor;
  final bool arrowPointsDown;
  final double arrowXFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final Path path = Path();
    final double bodyTop = arrowPointsDown ? 0.0 : arrowHeight;
    final double bodyBottom =
        arrowPointsDown ? size.height - arrowHeight : size.height;
    final double arrowCenterX = (size.width * arrowXFraction)
        .clamp(radius + (arrowWidth / 2), size.width - radius - (arrowWidth / 2));

    final Rect bodyRect = Rect.fromLTRB(0, bodyTop, size.width, bodyBottom);
    final RRect bodyRRect =
        RRect.fromRectAndRadius(bodyRect, Radius.circular(radius));

    path.addRRect(bodyRRect);

    // Add arrow triangle
    final Path arrowPath = Path();
    if (arrowPointsDown) {
      arrowPath.moveTo(arrowCenterX - (arrowWidth / 2), bodyBottom);
      arrowPath.lineTo(arrowCenterX, size.height);
      arrowPath.lineTo(arrowCenterX + (arrowWidth / 2), bodyBottom);
      arrowPath.close();
    } else {
      arrowPath.moveTo(arrowCenterX - (arrowWidth / 2), bodyTop);
      arrowPath.lineTo(arrowCenterX, 0.0);
      arrowPath.lineTo(arrowCenterX + (arrowWidth / 2), bodyTop);
      arrowPath.close();
    }

    final Path combined = Path.combine(PathOperation.union, path, arrowPath);

    canvas.drawPath(combined, fillPaint);
    canvas.drawPath(combined, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.arrowPointsDown != arrowPointsDown ||
        oldDelegate.arrowXFraction != arrowXFraction;
  }
}
