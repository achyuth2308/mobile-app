import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLEET INFOGRAPHIC WHEEL
/// ─────────────────────────────────────────────────────────────────────────
/// A circular 5-step 3D infographic wheel matching the reference design:
/// - Smooth spiral pinwheel blades with solid, vibrant colored rims.
/// - Clean ~6-8px uniform spacing channels with mathematically guaranteed 0% overlap.
/// - Elevated central hub circle with solid magenta border, fleet count,
///   status indicator dots, and online percentage.
/// - Fluid entrance bloom and interactive selection animations.
class FleetInfographicWheel extends ConsumerStatefulWidget {
  const FleetInfographicWheel({super.key});

  @override
  ConsumerState<FleetInfographicWheel> createState() =>
      _FleetInfographicWheelState();
}

class _FleetInfographicWheelState extends ConsumerState<FleetInfographicWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _centerScale;
  late final List<Animation<double>> _petalAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _centerScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
    );

    // Staggered bloom for the 5 petals (0 -> 4)
    _petalAnimations = List.generate(5, (int i) {
      final double start = 0.10 + (i * 0.10);
      final double end = (start + 0.45).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFilter(VehicleStatus status) {
    final StateController<VehicleStatus?> ctrl =
        ref.read(fleetFilterProvider.notifier);
    ctrl.state = ctrl.state == status ? null : status;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final FleetStats stats = ref.watch(fleetStatsProvider);
    final VehicleStatus? activeFilter = ref.watch(fleetFilterProvider);
    final double thresholdHours = ref.watch(noDataThresholdProvider);

    // 5 status petals matching the colors and layout in reference
    final List<_PetalConfig> configs = <_PetalConfig>[
      _PetalConfig(
        index: 0,
        status: VehicleStatus.moving,
        label: 'MOVING',
        count: stats.moving,
        color: const Color(0xFF10B981), // Emerald Green
        icon: Icons.navigation_rounded,
        subtext: 'driving',
      ),
      _PetalConfig(
        index: 1,
        status: VehicleStatus.idle,
        label: 'IDLE',
        count: stats.idle,
        color: const Color(0xFFEAB308), // Bright Golden Yellow
        icon: Icons.hourglass_top_rounded,
        subtext: 'idling',
      ),
      _PetalConfig(
        index: 2,
        status: VehicleStatus.stopped,
        label: 'STOPPED',
        count: stats.stopped,
        color: const Color(0xFF64748B), // Slate Grey
        icon: Icons.local_parking_rounded,
        subtext: 'parked',
      ),
      _PetalConfig(
        index: 3,
        status: VehicleStatus.offline,
        label: 'NO DATA',
        count: stats.offline,
        color: const Color(0xFFEF4444), // Coral Red
        icon: Icons.cloud_off_rounded,
        subtext: 'offline',
        isNoData: true,
      ),
      _PetalConfig(
        index: 4,
        status: VehicleStatus.noData,
        label: 'OFFLINE',
        count: stats.noData,
        color: const Color(0xFFBE123C), // Deep Crimson / Ruby Red
        icon: Icons.sensors_off_rounded,
        subtext: 'unreachable',
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Base coordinate size for the wheel
        const double baseSize = 350.0;
        final double availableWidth = constraints.maxWidth;
        final double scale = (availableWidth / baseSize).clamp(0.75, 1.05);
        final double wheelSize = baseSize * scale;

        return Center(
          child: SizedBox(
            width: wheelSize,
            height: wheelSize,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: baseSize,
                height: baseSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    // ── 1. The 5 3D Petal Background Shapes (Canvas) ─────
                    for (int i = 0; i < configs.length; i++)
                      _AnimatedPetalShape(
                        key: ValueKey('petal_shape_$i'),
                        config: configs[i],
                        animation: _petalAnimations[i],
                        isSelected: activeFilter == configs[i].status,
                        isDimmed: activeFilter != null &&
                            activeFilter != configs[i].status,
                        isDark: isDark,
                        onTap: () => _toggleFilter(configs[i].status),
                      ),

                    // ── 2. The 5 Interactive Petal Content Pods ──────────
                    for (int i = 0; i < configs.length; i++)
                      _PetalContent(
                        key: ValueKey('petal_content_$i'),
                        config: configs[i],
                        animation: _petalAnimations[i],
                        isSelected: activeFilter == configs[i].status,
                        isDimmed: activeFilter != null &&
                            activeFilter != configs[i].status,
                        isDark: isDark,
                        thresholdHours: thresholdHours,
                        onTap: () => _toggleFilter(configs[i].status),
                      ),

                    // ── 3. Central Hub Circle (3D Raised Disc) ───────────
                    ScaleTransition(
                      scale: _centerScale,
                      child: _CenterHub(
                        stats: stats,
                        activeFilter: activeFilter,
                        isDark: isDark,
                        onResetFilter: () {
                          ref.read(fleetFilterProvider.notifier).state = null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  DATA CONFIG FOR ONE PETAL
/// ─────────────────────────────────────────────────────────────────────────
class _PetalConfig {
  const _PetalConfig({
    required this.index,
    required this.status,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.subtext,
    this.isNoData = false,
  });

  final int index;
  final VehicleStatus status;
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String subtext;
  final bool isNoData;

  /// Centroid placement angle in radians for content
  double get angle => (-75.0 + index * 72.0) * math.pi / 180.0;
}

/// ─────────────────────────────────────────────────────────────────────────
///  ANIMATED PETAL SHAPE
/// ─────────────────────────────────────────────────────────────────────────
class _AnimatedPetalShape extends StatelessWidget {
  const _AnimatedPetalShape({
    super.key,
    required this.config,
    required this.animation,
    required this.isSelected,
    required this.isDimmed,
    required this.isDark,
    required this.onTap,
  });

  final _PetalConfig config;
  final Animation<double> animation;
  final bool isSelected;
  final bool isDimmed;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = animation.value;
        if (animValue <= 0.001) return const SizedBox.shrink();

        // Exact rotation by multiple of 72° around center
        final double rotation = config.index * (2 * math.pi / 5);
        final double scale = animValue * (isSelected ? 1.05 : 1.0);
        final double opacity =
            (isDimmed ? 0.35 : 1.0) * animValue.clamp(0.0, 1.0);

        return Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(
                size: const Size(350, 350),
                painter: _PetalPainter(
                  color: config.color,
                  isSelected: isSelected,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  PETAL CUSTOM PAINTER (Clean, Solid, Non-overlapping Spiral Blade)
/// ─────────────────────────────────────────────────────────────────────────
class _PetalPainter extends CustomPainter {
  const _PetalPainter({
    required this.color,
    required this.isSelected,
    required this.isDark,
  });

  final Color color;
  final bool isSelected;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Path path = _buildSpiralPetalPath(center);

    // 1. Soft Elevation Drop Shadow (Clean 3D depth)
    final Paint shadowPaint = Paint()
      ..color = isSelected
          ? color.withValues(alpha: isDark ? 0.50 : 0.35)
          : Colors.black.withValues(alpha: isDark ? 0.30 : 0.08)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 10 : 6);

    canvas.save();
    canvas.translate(0, isSelected ? 2.5 : 3.5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // 2. Interior Body Fill: Opaque base + soft rich colored tint
    final Paint baseFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white;
    canvas.drawPath(path, baseFillPaint);

    final Paint colorFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.45),
        radius: 0.85,
        colors: isDark
            ? <Color>[
                color.withValues(alpha: isSelected ? 0.36 : 0.22),
                color.withValues(alpha: isSelected ? 0.20 : 0.10),
              ]
            : <Color>[
                color.withValues(alpha: isSelected ? 0.30 : 0.20),
                color.withValues(alpha: isSelected ? 0.16 : 0.08),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: 175));
    canvas.drawPath(path, colorFillPaint);

    // 3. Solid, Bold, Vibrant Outer Rim (Single clean stroke, no doubling)
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 6.2 : 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawPath(path, rimPaint);
  }

  /// Mathematically synchronized spiral pinwheel blade:
  /// Both flanks follow the exact same spiral function separated by 72° minus
  /// a uniform channel gap, forming an elegant pinwheel with 0% overlap.
  Path _buildSpiralPetalPath(Offset center) {
    const double rIn = 61.0;
    const double rOut = 145.0;
    const double halfGap = 2.4; // degrees (total gap = 4.8 deg, ~7-9px channel)
    const double sweep = 34.0;  // spiral sweep degrees

    double spiralAngle(double t) {
      return -54.0 + sweep * math.pow(t, 1.25);
    }

    Offset polarPoint(double deg, double r) {
      final double rad = deg * math.pi / 180.0;
      return Offset(center.dx + r * math.cos(rad), center.dy + r * math.sin(rad));
    }

    final Path path = Path();
    const int flankSteps = 16;
    const int arcSteps = 12;

    // 1. Inner Arc: from left to right along rIn
    final double aInLeft = spiralAngle(0.0) - 72.0 + halfGap;
    final double aInRight = spiralAngle(0.0) - halfGap;
    final Offset pInStart = polarPoint(aInLeft, rIn);
    path.moveTo(pInStart.dx, pInStart.dy);

    for (int i = 1; i <= arcSteps; i++) {
      final double frac = i / arcSteps.toDouble();
      final double a = aInLeft + (aInRight - aInLeft) * frac;
      final Offset pt = polarPoint(a, rIn);
      path.lineTo(pt.dx, pt.dy);
    }

    // 2. Right Flank: spiral outward from t=0 to t=1
    for (int i = 1; i <= flankSteps; i++) {
      final double t = i / flankSteps.toDouble();
      final double r = rIn + t * (rOut - rIn);
      final double a = spiralAngle(t) - halfGap;
      final Offset pt = polarPoint(a, r);
      path.lineTo(pt.dx, pt.dy);
    }

    // 3. Outer Arc: from right to left along rOut (continuous concentric arc)
    final double aOutRight = spiralAngle(1.0) - halfGap;
    final double aOutLeft = spiralAngle(1.0) - 72.0 + halfGap;
    for (int i = 1; i <= arcSteps; i++) {
      final double frac = i / arcSteps.toDouble();
      final double a = aOutRight + (aOutLeft - aOutRight) * frac;
      final Offset pt = polarPoint(a, rOut);
      path.lineTo(pt.dx, pt.dy);
    }

    // 4. Left Flank: spiral inward from t=1 down to t=0
    for (int i = flankSteps; i >= 0; i--) {
      final double t = i / flankSteps.toDouble();
      final double r = rIn + t * (rOut - rIn);
      final double a = spiralAngle(t) - 72.0 + halfGap;
      final Offset pt = polarPoint(a, r);
      path.lineTo(pt.dx, pt.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isDark != isDark;
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  PETAL CONTENT POD (Upright Text, Icon Badge, Count & Actions)
/// ─────────────────────────────────────────────────────────────────────────
class _PetalContent extends ConsumerWidget {
  const _PetalContent({
    super.key,
    required this.config,
    required this.animation,
    required this.isSelected,
    required this.isDimmed,
    required this.isDark,
    required this.thresholdHours,
    required this.onTap,
  });

  final _PetalConfig config;
  final Animation<double> animation;
  final bool isSelected;
  final bool isDimmed;
  final bool isDark;
  final double thresholdHours;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double centerCoord = 175.0; // 350 / 2
    const double rContent = 101.0;    // Centered inside the petal blade

    // Angular placement aligned with petal centroid
    final double rad = config.angle;
    final double posX = centerCoord + (rContent * math.cos(rad));
    final double posY = centerCoord + (rContent * math.sin(rad));

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = animation.value;
        if (animValue <= 0.001) return const SizedBox.shrink();

        final double scale = animValue * (isSelected ? 1.05 : 1.0);
        final double opacity =
            (isDimmed ? 0.35 : 1.0) * animValue.clamp(0.0, 1.0);

        return Positioned(
          left: posX - 43,
          top: posY - 40,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: SizedBox(
                width: 86,
                height: 80,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(16),
                    splashColor: config.color.withValues(alpha: 0.2),
                    highlightColor: config.color.withValues(alpha: 0.1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // 1. Icon Circle Badge (matching reference)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            border: Border.all(
                              color: config.color.withValues(alpha: 0.8),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: config.color.withValues(
                                  alpha: isDark ? 0.3 : 0.15,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            config.icon,
                            size: 13,
                            color: config.color,
                          ),
                        ),
                        const SizedBox(height: 1.5),

                        // 2. Status Label (Bold Uppercase, e.g. "MOVING")
                        Text(
                          config.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: config.color,
                          ),
                        ),

                        // 3. Vehicle Count (Animated interpolation)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: config.count.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (BuildContext _, double val, Widget? __) {
                            return Text(
                              '${val.round()}',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E2432),
                              ),
                            );
                          },
                        ),

                        // 4. Subtext or Threshold dropdown
                        if (config.isNoData)
                          _buildMiniNoDataDropdown(
                            context,
                            ref,
                            thresholdHours,
                            isDark,
                            config.color,
                          )
                        else
                          Text(
                            config.count == 1 ? 'vehicle' : 'vehicles',
                            style: TextStyle(
                              fontSize: 8.0,
                              height: 1.0,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniNoDataDropdown(
    BuildContext context,
    WidgetRef ref,
    double thresholdHours,
    bool isDark,
    Color color,
  ) {
    final String label =
        thresholdHours == 1.0 ? '1 hr' : '${thresholdHours.toInt()} hr';

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<double>(
        initialValue: thresholdHours,
        tooltip: 'No Data Rule: 1hr default, 3hr, 6hr, 24hr',
        padding: EdgeInsets.zero,
        elevation: 8,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        onSelected: (double val) {
          ref.read(noDataThresholdProvider.notifier).setThreshold(val);
          final String optName =
              val == 1.0 ? '1 hr (Default)' : '${val.toInt()} hr';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No Data Rule threshold set to $optName'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        itemBuilder: (BuildContext ctx) =>
            AppConfig.noDataThresholdOptions.map((double opt) {
          final String optLabel =
              opt == 1.0 ? '1 hr (Default)' : '${opt.toInt()} hr';
          final bool isSel = thresholdHours == opt;
          return PopupMenuItem<double>(
            value: opt,
            height: 34,
            child: Row(
              children: [
                Icon(
                  isSel ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 14,
                  color: isSel ? color : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  optLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: color.withValues(alpha: 0.8),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.0,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 12,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  CENTRAL HUB CIRCLE (3D Raised Disc)
/// ─────────────────────────────────────────────────────────────────────────
class _CenterHub extends StatelessWidget {
  const _CenterHub({
    required this.stats,
    required this.activeFilter,
    required this.isDark,
    required this.onResetFilter,
  });

  final FleetStats stats;
  final VehicleStatus? activeFilter;
  final bool isDark;
  final VoidCallback onResetFilter;

  @override
  Widget build(BuildContext context) {
    const double hubDiameter = 114.0;
    final int onlinePct = (stats.onlinePercent * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: activeFilter != null ? onResetFilter : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: hubDiameter,
          height: hubDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            gradient: RadialGradient(
              colors: isDark
                  ? const <Color>[
                      Color(0xFF2E1F36),
                      Color(0xFF1E293B),
                    ]
                  : const <Color>[
                      Colors.white,
                      Color(0xFFFFF1F6),
                    ],
            ),
            border: Border.all(
              color: const Color(0xFFEC4899), // Solid 3D Magenta/Rose rim
              width: 5.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 1),
              Text(
                'TOTAL FLEET',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: stats.total.toDouble()),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                builder: (BuildContext _, double countVal, Widget? __) {
                  return Text(
                    '${countVal.round()}',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  );
                },
              ),
              Text(
                stats.total == 1 ? 'vehicle' : 'vehicles',
                style: TextStyle(
                  fontSize: 8.0,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),

              // 5 Colored Dots (Exact detail from center circle in reference!)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  _MiniDot(color: Color(0xFF10B981)), // Green
                  SizedBox(width: 3.5),
                  _MiniDot(color: Color(0xFFEAB308)), // Yellow
                  SizedBox(width: 3.5),
                  _MiniDot(color: Color(0xFF64748B)), // Grey
                  SizedBox(width: 3.5),
                  _MiniDot(color: Color(0xFFEF4444)), // Red
                  SizedBox(width: 3.5),
                  _MiniDot(color: Color(0xFFBE123C)), // Ruby Red
                ],
              ),
              const SizedBox(height: 3),

              // Online % indicator
              Text(
                '$onlinePct% online',
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  const _MiniDot({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4.5,
      height: 4.5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
