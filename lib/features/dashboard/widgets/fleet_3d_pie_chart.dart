import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLEET 3D ISOMETRIC PIE CHART
/// ─────────────────────────────────────────────────────────────────────────
/// A photorealistic 3D isometric pie chart supporting fleet statuses:
/// - OFFLINE (Red)
/// - MOVING (Dark Green)
/// - IDLE (Yellow)
/// - STOPPED (Solid Black)
/// - OVERSPEED (Rose / Crimson)
/// - UNREACHABLE (Purple / Violet)
///
/// Features:
/// - Compact isometric perspective projection with 3D cylinder extrusion.
/// - Dynamic directional face shading (top face, outer rim, radial cut walls).
/// - Interactive exploded slice with soft contact shadow.
/// - Guaranteed non-overlapping callout leader lines (3 on left, 3 on right).
/// - Dynamic bottom inspector badge that reflects the selected category and count.
class Fleet3DPieChart extends ConsumerStatefulWidget {
  const Fleet3DPieChart({
    super.key,
    this.explodedStatus = VehicleStatus.offline,
    this.onStatusSelected,
  });

  /// Status to elevate by default when no filter is active.
  final VehicleStatus? explodedStatus;

  /// Optional callback when a status is tapped.
  final ValueChanged<VehicleStatus?>? onStatusSelected;

  @override
  ConsumerState<Fleet3DPieChart> createState() => _Fleet3DPieChartState();
}

class _Fleet3DPieChartState extends ConsumerState<Fleet3DPieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _entranceAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSliceTapped(PieSliceData slice) {
    final StateController<bool> alertsCtrl =
        ref.read(fleetAlertsOnlyProvider.notifier);
    final StateController<VehicleStatus?> filterCtrl =
        ref.read(fleetFilterProvider.notifier);

    if (slice.id == 'overspeed') {
      if (alertsCtrl.state) {
        alertsCtrl.state = false;
      } else {
        filterCtrl.state = null;
        alertsCtrl.state = true;
      }
      widget.onStatusSelected?.call(null);
      return;
    }

    alertsCtrl.state = false;
    if (slice.status != null) {
      final VehicleStatus? next =
          filterCtrl.state == slice.status ? null : slice.status;
      filterCtrl.state = next;
      widget.onStatusSelected?.call(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final FleetStats stats = ref.watch(fleetStatsProvider);
    final VehicleStatus? activeFilter = ref.watch(fleetFilterProvider);
    final bool isOverspeedActive = ref.watch(fleetAlertsOnlyProvider);

    // 6 categories:
    // Left side: Offline, Moving, Idle
    // Right side: Unreachable, Overspeed, Stopped
    final List<PieSliceData> rawSlices = <PieSliceData>[
      PieSliceData(
        id: 'offline',
        status: VehicleStatus.offline,
        label: 'OFFLINE',
        subLabel: 'no data',
        count: stats.offline,
        icon: Icons.cloud_off_rounded,
        topColor: const Color(0xFFEF4444), // Red
        sideColor: const Color(0xFFB91C1C),
        innerWallColor: const Color(0xFFDC2626),
      ),
      PieSliceData(
        id: 'unreachable',
        status: VehicleStatus.noData,
        label: 'UNREACHABLE',
        subLabel: 'unreachable',
        count: stats.noData,
        icon: Icons.sensors_off_rounded,
        topColor: const Color(0xFF7C3AED), // Purple
        sideColor: const Color(0xFF5B21B6),
        innerWallColor: const Color(0xFF6D28D9),
      ),
      PieSliceData(
        id: 'overspeed',
        status: null,
        label: 'OVERSPEED',
        subLabel: 'speeding',
        count: stats.overspeeding,
        icon: Icons.speed_rounded,
        topColor: const Color(0xFFF43F5E), // Rose / Crimson
        sideColor: const Color(0xFFBE123C),
        innerWallColor: const Color(0xFFE11D48),
      ),
      PieSliceData(
        id: 'stopped',
        status: VehicleStatus.stopped,
        label: 'STOPPED',
        subLabel: 'parked',
        count: stats.stopped,
        icon: Icons.pause_circle_rounded,
        topColor: isDark ? const Color(0xFF27272A) : const Color(0xFF18181B), // Solid Black
        sideColor: const Color(0xFF09090B),
        innerWallColor: const Color(0xFF18181B),
      ),
      PieSliceData(
        id: 'idle',
        status: VehicleStatus.idle,
        label: 'IDLE',
        subLabel: 'idling',
        count: stats.idle,
        icon: Icons.hourglass_top_rounded,
        topColor: const Color(0xFFEAB308), // Yellow
        sideColor: const Color(0xFFA16207),
        innerWallColor: const Color(0xFFCA8A04),
      ),
      PieSliceData(
        id: 'moving',
        status: VehicleStatus.moving,
        label: 'MOVING',
        subLabel: 'driving',
        count: stats.moving,
        icon: Icons.navigation_rounded,
        topColor: const Color(0xFF15803D), // Dark Green
        sideColor: const Color(0xFF14532D),
        innerWallColor: const Color(0xFF166534),
      ),
    ];

    final int total = stats.total;
    final double safeTotal = total > 0 ? total.toDouble() : 6.0;

    // Minimum visible angle per slice so even 0-count statuses have clear 3D representation
    const double minAngle = 0.22; // ~12.6 degrees
    final double remainingSweep = (2 * math.pi) - (rawSlices.length * minAngle);

    final List<PieSliceData> computedSlices = <PieSliceData>[];
    // Start angle calibrated so OFFLINE occupies Top-Left
    double currentAngle = 1.08 * math.pi;

    for (final PieSliceData s in rawSlices) {
      final double fraction = total > 0 ? (s.count / safeTotal) : (1.0 / 6.0);
      final double sweep = minAngle + (fraction * remainingSweep);
      final double percent = total > 0 ? (s.count / total * 100) : (100.0 / 6.0);

      final bool isSelected = s.id == 'overspeed'
          ? isOverspeedActive
          : (activeFilter != null && activeFilter == s.status);

      // Selected slice (or default slice) comes up as a 3D stepped elevation
      final bool isExploded = isSelected ||
          (activeFilter == null &&
              !isOverspeedActive &&
              widget.explodedStatus != null &&
              s.status == widget.explodedStatus);

      computedSlices.add(
        s.copyWith(
          startAngle: currentAngle,
          sweepAngle: sweep,
          percentage: percent,
          isExploded: isExploded,
          isSelected: isSelected,
          isDimmed: false,
        ),
      );

      currentAngle += sweep;
    }

    // Dynamic bottom badge label and color depending on selected category
    String bottomBadgeText = '$total Vehicles Total';
    Color? selectedColor;
    bool hasActiveFilter = false;

    if (isOverspeedActive) {
      bottomBadgeText = '${stats.overspeeding} Overspeed Vehicles';
      selectedColor = const Color(0xFFF43F5E);
      hasActiveFilter = true;
    } else if (activeFilter != null) {
      hasActiveFilter = true;
      switch (activeFilter) {
        case VehicleStatus.moving:
          bottomBadgeText = '${stats.moving} Moving Vehicles';
          selectedColor = const Color(0xFF15803D);
        case VehicleStatus.idle:
          bottomBadgeText = '${stats.idle} Idle Vehicles';
          selectedColor = const Color(0xFFEAB308);
        case VehicleStatus.stopped:
          bottomBadgeText = '${stats.stopped} Stopped Vehicles';
          selectedColor = isDark ? Colors.white : const Color(0xFF18181B);
        case VehicleStatus.offline:
          bottomBadgeText = '${stats.offline} Offline Vehicles';
          selectedColor = const Color(0xFFEF4444);
        case VehicleStatus.noData:
          bottomBadgeText = '${stats.noData} Unreachable Vehicles';
          selectedColor = const Color(0xFF7C3AED);
      }
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // Compact height giving clean breathing room for 3D pie and callouts
        final double height = (width * 0.62).clamp(205.0, 240.0);
        final Size chartSize = Size(width, height);

        // Precompute non-overlapping leader line shelves close to the pie
        final Map<String, _CalloutShelf> shelves =
            _computeCalloutShelves(computedSlices, chartSize);

        return AnimatedBuilder(
          animation: _entranceAnimation,
          builder: (BuildContext context, Widget? child) {
            return SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── 1. The 3D Isometric Canvas Painter ───────────────────
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (TapUpDetails details) {
                        _handleCanvasTap(
                          details.localPosition,
                          chartSize,
                          computedSlices,
                        );
                      },
                      child: CustomPaint(
                        painter: _IsometricPieChartPainter(
                          slices: computedSlices,
                          shelves: shelves,
                          progress: _entranceAnimation.value,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),

                  // ── 2. Interactive Callout Labels on Leader Lines ────────
                  for (final PieSliceData slice in computedSlices)
                    if (shelves.containsKey(slice.id))
                      _buildCalloutLabel(
                        slice: slice,
                        shelf: shelves[slice.id]!,
                        isDark: isDark,
                      ),

                  // ── 3. Bottom Center Dynamic Category / Fleet Badge ──────
                  // Only displayed when an operator clicks on a category (Idle, Moving, etc.)
                  // so the total count is never duplicated between top and bottom.
                  if (hasActiveFilter)
                    Align(
                      alignment: const Alignment(0.0, 0.99),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(fleetFilterProvider.notifier).state = null;
                          ref.read(fleetAlertsOnlyProvider.notifier).state = false;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                                : Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedColor != null
                                  ? selectedColor.withValues(alpha: 0.5)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (selectedColor ?? Colors.black)
                                    .withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selectedColor ?? const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                bottomBadgeText,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Calculates mathematically collision-free shelves for each slice
  Map<String, _CalloutShelf> _computeCalloutShelves(
    List<PieSliceData> slices,
    Size size,
  ) {
    final Offset center = Offset(size.width * 0.50, size.height * 0.46);
    final double rx = size.width * 0.16;
    final double ry = rx * 0.50;
    const double extrusionHeight = 16.0;

    final List<PieSliceData> leftSlices = [];
    final List<PieSliceData> rightSlices = [];

    // Deterministic 3-on-left and 3-on-right partition:
    // Left: OFFLINE, MOVING, IDLE
    // Right: UNREACHABLE, OVERSPEED, STOPPED
    const Set<String> leftIds = {'offline', 'moving', 'idle'};

    for (final PieSliceData s in slices) {
      if (leftIds.contains(s.id)) {
        leftSlices.add(s);
      } else {
        rightSlices.add(s);
      }
    }

    // Fixed vertical order from top to bottom
    const List<String> leftOrder = ['offline', 'moving', 'idle'];
    const List<String> rightOrder = ['unreachable', 'overspeed', 'stopped'];

    leftSlices.sort((a, b) =>
        leftOrder.indexOf(a.id).compareTo(leftOrder.indexOf(b.id)));
    rightSlices.sort((a, b) =>
        rightOrder.indexOf(a.id).compareTo(rightOrder.indexOf(b.id)));

    final Map<String, _CalloutShelf> result = {};

    // Snug bounds kept close to the pie
    final double topBoundY = center.dy - ry - 14.0;
    final double bottomBoundY = center.dy + ry + extrusionHeight + 14.0;

    const double elbowMargin = 8.0;

    // Generate distinct Y coordinates for left side
    final List<double> leftYs = _distributeYs(
      count: leftSlices.length,
      topY: topBoundY,
      bottomY: bottomBoundY,
      centerY: center.dy,
    );

    for (int i = 0; i < leftSlices.length; i++) {
      final PieSliceData s = leftSlices[i];
      final double y = leftYs[i];
      final double elbowX = center.dx - rx - elbowMargin;
      result[s.id] = _CalloutShelf(
        isLeft: true,
        elbowX: elbowX,
        elbowY: y,
        endX: 8.0,
      );
    }

    // Generate distinct Y coordinates for right side
    final List<double> rightYs = _distributeYs(
      count: rightSlices.length,
      topY: topBoundY,
      bottomY: bottomBoundY,
      centerY: center.dy,
    );

    for (int i = 0; i < rightSlices.length; i++) {
      final PieSliceData s = rightSlices[i];
      final double y = rightYs[i];
      final double elbowX = center.dx + rx + elbowMargin;
      result[s.id] = _CalloutShelf(
        isLeft: false,
        elbowX: elbowX,
        elbowY: y,
        endX: size.width - 8.0,
      );
    }

    return result;
  }

  List<double> _distributeYs({
    required int count,
    required double topY,
    required double bottomY,
    required double centerY,
  }) {
    if (count == 0) return [];
    if (count == 1) return [centerY];
    if (count == 2) {
      return [topY + 6.0, bottomY - 6.0];
    }
    final List<double> ys = [];
    final double step = (bottomY - topY) / (count - 1);
    for (int i = 0; i < count; i++) {
      ys.add(topY + (i * step));
    }
    return ys;
  }

  void _handleCanvasTap(
    Offset tapPos,
    Size size,
    List<PieSliceData> slices,
  ) {
    final Offset center = Offset(size.width * 0.50, size.height * 0.46);
    final double rx = size.width * 0.16;
    final double ry = rx * 0.50;

    final double dx = (tapPos.dx - center.dx) / rx;
    final double dy = (tapPos.dy - center.dy) / ry;
    final double dist = math.sqrt(dx * dx + dy * dy);

    if (dist <= 1.45) {
      double angle = math.atan2(dy, dx);
      if (angle < 0) angle += 2 * math.pi;

      for (final PieSliceData s in slices) {
        double start = s.startAngle % (2 * math.pi);
        double end = (s.startAngle + s.sweepAngle) % (2 * math.pi);

        bool hit = false;
        if (start < end) {
          hit = angle >= start && angle <= end;
        } else {
          hit = angle >= start || angle <= end;
        }

        if (hit) {
          _onSliceTapped(s);
          return;
        }
      }
    }
  }

  Widget _buildCalloutLabel({
    required PieSliceData slice,
    required _CalloutShelf shelf,
    required bool isDark,
  }) {
    final bool isLeft = shelf.isLeft;
    final Color accentColor = slice.id == 'stopped'
        ? (isDark ? Colors.white : const Color(0xFF18181B))
        : slice.topColor;
    final Color labelColor = slice.isSelected
        ? accentColor
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    return Positioned(
      left: isLeft ? 8.0 : null,
      right: isLeft ? null : 8.0,
      top: shelf.elbowY - 17.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onSliceTapped(slice),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isLeft && slice.isSelected) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 3),
            ],
            Icon(
              slice.icon,
              size: 12.0,
              color: accentColor,
            ),
            const SizedBox(width: 3),
            Text(
              slice.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                color: labelColor,
              ),
            ),
            const SizedBox(width: 3.5),
            Text(
              '${slice.count}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                color: labelColor,
              ),
            ),
            if (isLeft && slice.isSelected) ...[
              const SizedBox(width: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalloutShelf {
  const _CalloutShelf({
    required this.isLeft,
    required this.elbowX,
    required this.elbowY,
    required this.endX,
  });

  final bool isLeft;
  final double elbowX;
  final double elbowY;
  final double endX;
}

/// ─────────────────────────────────────────────────────────────────────────
///  PIE SLICE DATA MODEL
/// ─────────────────────────────────────────────────────────────────────────
class PieSliceData {
  const PieSliceData({
    required this.id,
    required this.label,
    required this.subLabel,
    required this.count,
    required this.icon,
    required this.topColor,
    required this.sideColor,
    required this.innerWallColor,
    this.status,
    this.startAngle = 0.0,
    this.sweepAngle = 0.0,
    this.percentage = 0.0,
    this.isExploded = false,
    this.isSelected = false,
    this.isDimmed = false,
  });

  final String id;
  final String label;
  final String subLabel;
  final int count;
  final IconData icon;
  final Color topColor;
  final Color sideColor;
  final Color innerWallColor;
  final VehicleStatus? status;
  final double startAngle;
  final double sweepAngle;
  final double percentage;
  final bool isExploded;
  final bool isSelected;
  final bool isDimmed;

  PieSliceData copyWith({
    String? id,
    String? label,
    String? subLabel,
    int? count,
    IconData? icon,
    Color? topColor,
    Color? sideColor,
    Color? innerWallColor,
    VehicleStatus? status,
    double? startAngle,
    double? sweepAngle,
    double? percentage,
    bool? isExploded,
    bool? isSelected,
    bool? isDimmed,
  }) {
    return PieSliceData(
      id: id ?? this.id,
      label: label ?? this.label,
      subLabel: subLabel ?? this.subLabel,
      count: count ?? this.count,
      icon: icon ?? this.icon,
      topColor: topColor ?? this.topColor,
      sideColor: sideColor ?? this.sideColor,
      innerWallColor: innerWallColor ?? this.innerWallColor,
      status: status ?? this.status,
      startAngle: startAngle ?? this.startAngle,
      sweepAngle: sweepAngle ?? this.sweepAngle,
      percentage: percentage ?? this.percentage,
      isExploded: isExploded ?? this.isExploded,
      isSelected: isSelected ?? this.isSelected,
      isDimmed: isDimmed ?? this.isDimmed,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  3D ISOMETRIC PIE CHART PAINTER
/// ─────────────────────────────────────────────────────────────────────────
class _IsometricPieChartPainter extends CustomPainter {
  _IsometricPieChartPainter({
    required this.slices,
    required this.shelves,
    required this.progress,
    required this.isDark,
  });

  final List<PieSliceData> slices;
  final Map<String, _CalloutShelf> shelves;
  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty || progress <= 0) return;

    final Offset center = Offset(size.width * 0.50, size.height * 0.46);
    final double rx = size.width * 0.16 * progress;
    final double ry = rx * 0.50; // Isometric tilt ratio
    const double extrusionHeight = 16.0; // Cylinder thickness
    const double explodeDist = 0.0; // Zero horizontal shift - solid 3D pie
    const double explodeLift = 7.0; // Clean 3D step elevation

    // Sort slices by depth (back to front), drawing elevated slice on top
    final List<PieSliceData> sorted = List<PieSliceData>.from(slices)
      ..sort((a, b) {
        if (a.isExploded && !b.isExploded) return 1;
        if (!a.isExploded && b.isExploded) return -1;
        final double midA = a.startAngle + (a.sweepAngle / 2);
        final double midB = b.startAngle + (b.sweepAngle / 2);
        return math.sin(midA).compareTo(math.sin(midB));
      });

    // ── STEP 1: Ambient Base Drop Shadow ──────────────────────────────────
    final Rect baseOval = Rect.fromCenter(
      center: Offset(center.dx, center.dy + extrusionHeight + 6.0),
      width: rx * 2.12,
      height: ry * 2.12,
    );
    canvas.drawOval(
      baseOval,
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.35 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ── STEP 2: Draw Contact Shadow for Exploded Slice ────────────────────
    for (final PieSliceData slice in sorted) {
      if (slice.isExploded) {
        final double midAngle = slice.startAngle + (slice.sweepAngle / 2);
        final double shadowDx = (explodeDist * 0.95) * math.cos(midAngle);
        final double shadowDy = (explodeDist * 0.95) * math.sin(midAngle) * 0.50;

        final Path shadowPath = Path();
        final Offset sc = Offset(center.dx + shadowDx, center.dy + extrusionHeight + 3.0 + shadowDy);
        shadowPath.moveTo(sc.dx, sc.dy);

        const int steps = 18;
        for (int i = 0; i <= steps; i++) {
          final double t = slice.startAngle + (slice.sweepAngle * (i / steps));
          shadowPath.lineTo(
            sc.dx + (rx * math.cos(t)),
            sc.dy + (ry * math.sin(t)),
          );
        }
        shadowPath.close();

        canvas.drawPath(
          shadowPath,
          Paint()
            ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    // ── STEP 3: Render 3D Cylindrical Geometry (Back-to-Front) ────────────
    for (final PieSliceData slice in sorted) {
      _drawSlice3D(
        canvas: canvas,
        slice: slice,
        center: center,
        rx: rx,
        ry: ry,
        extrusionHeight: extrusionHeight,
        explodeDist: explodeDist,
        explodeLift: explodeLift,
      );
    }

    // ── STEP 4: Draw Leader Lines and Connector Dots ───────────────────────
    _drawLeaderLines(
      canvas: canvas,
      center: center,
      rx: rx,
      ry: ry,
      explodeDist: explodeDist,
      explodeLift: explodeLift,
    );
  }

  void _drawSlice3D({
    required Canvas canvas,
    required PieSliceData slice,
    required Offset center,
    required double rx,
    required double ry,
    required double extrusionHeight,
    required double explodeDist,
    required double explodeLift,
  }) {
    final double midAngle = slice.startAngle + (slice.sweepAngle / 2);

    final Offset cTop = slice.isExploded
        ? Offset(center.dx, center.dy - explodeLift)
        : center;
    final Offset cBot = Offset(center.dx, center.dy + extrusionHeight);

    final double sAngle = slice.startAngle;
    final double eAngle = slice.startAngle + slice.sweepAngle;

    final Offset pStartTop = Offset(
      cTop.dx + (rx * math.cos(sAngle)),
      cTop.dy + (ry * math.sin(sAngle)),
    );
    final Offset pEndTop = Offset(
      cTop.dx + (rx * math.cos(eAngle)),
      cTop.dy + (ry * math.sin(eAngle)),
    );

    final Offset pBaseStartTop = Offset(
      center.dx + (rx * math.cos(sAngle)),
      center.dy + (ry * math.sin(sAngle)),
    );
    final Offset pBaseEndTop = Offset(
      center.dx + (rx * math.cos(eAngle)),
      center.dy + (ry * math.sin(eAngle)),
    );

    final Offset pStartBot = Offset(
      center.dx + (rx * math.cos(sAngle)),
      center.dy + extrusionHeight + (ry * math.sin(sAngle)),
    );
    final Offset pEndBot = Offset(
      center.dx + (rx * math.cos(eAngle)),
      center.dy + extrusionHeight + (ry * math.sin(eAngle)),
    );

    final Color topColor = slice.isDimmed
        ? slice.topColor.withValues(alpha: 0.35)
        : slice.topColor;
    final Color sideColor = slice.isDimmed
        ? slice.sideColor.withValues(alpha: 0.35)
        : slice.sideColor;
    final Color innerWallColor = slice.isDimmed
        ? slice.innerWallColor.withValues(alpha: 0.35)
        : slice.innerWallColor;

    // ── A. Radial Start Cut Wall ─────────────────────────────────────────
    final double sinStart = math.sin(sAngle);
    final double cosStart = math.cos(sAngle);
    final bool showStart = slice.isExploded
        ? (sinStart > 0 || cosStart < -0.1)
        : (sinStart > 0);

    if (showStart) {
      final Path startWall = Path()
        ..moveTo(cTop.dx, cTop.dy)
        ..lineTo(pStartTop.dx, pStartTop.dy)
        ..lineTo(
          slice.isExploded ? pBaseStartTop.dx : pStartBot.dx,
          slice.isExploded ? pBaseStartTop.dy : pStartBot.dy,
        )
        ..lineTo(
          slice.isExploded ? center.dx : cBot.dx,
          slice.isExploded ? center.dy : cBot.dy,
        )
        ..close();

      canvas.drawPath(
        startWall,
        Paint()
          ..color = innerWallColor
          ..style = PaintingStyle.fill,
      );
    }

    // ── B. Radial End Cut Wall ───────────────────────────────────────────
    final double sinEnd = math.sin(eAngle);
    final double cosEnd = math.cos(eAngle);
    final bool showEnd = slice.isExploded
        ? (sinEnd < 0 || cosEnd > 0.1)
        : (sinEnd < 0);

    if (showEnd) {
      final Path endWall = Path()
        ..moveTo(cTop.dx, cTop.dy)
        ..lineTo(pEndTop.dx, pEndTop.dy)
        ..lineTo(
          slice.isExploded ? pBaseEndTop.dx : pEndBot.dx,
          slice.isExploded ? pBaseEndTop.dy : pEndBot.dy,
        )
        ..lineTo(
          slice.isExploded ? center.dx : cBot.dx,
          slice.isExploded ? center.dy : cBot.dy,
        )
        ..close();

      canvas.drawPath(
        endWall,
        Paint()
          ..color = Color.lerp(innerWallColor, Colors.black, 0.18)!
          ..style = PaintingStyle.fill,
      );
    }

    // ── C. Outer Curved Cylinder Rim ─────────────────────────────────────
    final Path rimPath = Path();
    const int rimSteps = 24;
    bool rimVisible = false;

    for (int i = 0; i <= rimSteps; i++) {
      final double t = sAngle + (slice.sweepAngle * (i / rimSteps));
      if (math.sin(t) > -0.05) {
        rimVisible = true;
        break;
      }
    }

    if (rimVisible) {
      rimPath.moveTo(pStartTop.dx, pStartTop.dy);
      for (int i = 1; i <= rimSteps; i++) {
        final double t = sAngle + (slice.sweepAngle * (i / rimSteps));
        rimPath.lineTo(
          cTop.dx + (rx * math.cos(t)),
          cTop.dy + (ry * math.sin(t)),
        );
      }
      rimPath.lineTo(pEndBot.dx, pEndBot.dy);
      for (int i = rimSteps - 1; i >= 0; i--) {
        final double t = sAngle + (slice.sweepAngle * (i / rimSteps));
        rimPath.lineTo(
          center.dx + (rx * math.cos(t)),
          center.dy + extrusionHeight + (ry * math.sin(t)),
        );
      }
      rimPath.close();

      canvas.drawPath(
        rimPath,
        Paint()
          ..color = sideColor
          ..style = PaintingStyle.fill,
      );
    }

    // ── D. Top Elliptical Face ───────────────────────────────────────────
    final Path topPath = Path()..moveTo(cTop.dx, cTop.dy);
    const int topSteps = 26;
    for (int i = 0; i <= topSteps; i++) {
      final double t = sAngle + (slice.sweepAngle * (i / topSteps));
      topPath.lineTo(
        cTop.dx + (rx * math.cos(t)),
        cTop.dy + (ry * math.sin(t)),
      );
    }
    topPath.close();

    final Paint topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(topColor, Colors.white, 0.12)!,
          topColor,
        ],
      ).createShader(
        Rect.fromCenter(center: cTop, width: rx * 2, height: ry * 2),
      );

    canvas.drawPath(topPath, topPaint);

    final Paint edgeStroke = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.20 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(topPath, edgeStroke);
  }

  void _drawLeaderLines({
    required Canvas canvas,
    required Offset center,
    required double rx,
    required double ry,
    required double explodeDist,
    required double explodeLift,
  }) {
    final Paint defaultLinePaint = Paint()
      ..color = isDark
          ? const Color(0xFF64748B).withValues(alpha: 0.85)
          : const Color(0xFF94A3B8).withValues(alpha: 0.90)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint dotPaint = Paint()..style = PaintingStyle.fill;

    for (final PieSliceData slice in slices) {
      if (!shelves.containsKey(slice.id)) continue;
      final _CalloutShelf shelf = shelves[slice.id]!;

      final double midAngle = slice.startAngle + (slice.sweepAngle / 2);

      Offset sliceOffset = Offset.zero;
      if (slice.isExploded) {
        final double dx = explodeDist * math.cos(midAngle);
        final double dy =
            (explodeDist * math.sin(midAngle) * 0.50) - explodeLift;
        sliceOffset = Offset(dx, dy);
      }

      final Offset cTop = center + sliceOffset;

      // Anchor dot resting on slice top surface
      final double dotDx = !shelf.isLeft && math.cos(midAngle) < 0.05
          ? cTop.dx + 2.0
          : cTop.dx + (rx * 0.65 * math.cos(midAngle));
      final Offset anchorDot = Offset(
        dotDx,
        cTop.dy + (ry * 0.65 * math.sin(midAngle)),
      );

      final Color sliceColor = slice.id == 'stopped'
          ? (isDark ? Colors.white : const Color(0xFF18181B))
          : slice.topColor;

      // Draw anchor dot filled with respective slice color
      dotPaint.color = sliceColor;
      canvas.drawCircle(anchorDot, 2.6, dotPaint);

      // Draw angled connector & horizontal shelf
      final Path leaderPath = Path()
        ..moveTo(anchorDot.dx, anchorDot.dy)
        ..lineTo(shelf.elbowX, shelf.elbowY)
        ..lineTo(shelf.endX, shelf.elbowY);

      if (slice.isSelected) {
        final Paint activeLinePaint = Paint()
          ..color = slice.topColor
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(leaderPath, activeLinePaint);
      } else {
        canvas.drawPath(leaderPath, defaultLinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricPieChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.shelves != shelves ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark;
  }
}
