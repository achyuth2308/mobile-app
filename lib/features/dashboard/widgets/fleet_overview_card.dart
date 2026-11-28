import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../providers/fleet_provider.dart';

/// Fleet Overview card featuring Neumorphic (Soft UI) styling,
/// debossed status progress bars, and animated ratios.
class FleetOverviewCard extends ConsumerWidget {
  const FleetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final FleetStats stats = ref.watch(fleetStatsProvider);

    final Color surfaceColor =
        isDark ? const Color(0xFF161C26) : const Color(0xFFE8EEF5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: Gap.xs),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? [
                const BoxShadow(
                  color: Color(0xFF232D3D),
                  offset: Offset(-4, -4),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.60),
                  offset: const Offset(4, 4),
                  blurRadius: 10,
                ),
              ]
            : [
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-5, -5),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFFA6B4C9).withOpacity(0.55),
                  offset: const Offset(5, 5),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      shape: BoxShape.circle,
                      boxShadow: isDark
                          ? [
                              const BoxShadow(
                                color: Color(0xFF232D3D),
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ]
                          : [
                              const BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: const Color(0xFFA6B4C9).withOpacity(0.5),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: Color(0xFF2563EB),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Fleet Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              // Live badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withOpacity(0.35)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xFFA6B4C9).withOpacity(0.3),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6610B981),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Status Rows ────────────────────────────────────────────
          _buildStatusRow(
            label: 'Moving',
            color: const Color(0xFF10B981),
            count: stats.moving,
            total: stats.total,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStatusRow(
            label: 'Idle',
            color: const Color(0xFFF59E0B),
            count: stats.idle,
            total: stats.total,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStatusRow(
            label: 'Stopped',
            color: const Color(0xFF8A99AD),
            count: stats.stopped,
            total: stats.total,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStatusRow(
            label: 'No Data',
            color: const Color(0xFFEF4444),
            count: stats.offline,
            total: stats.total,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _buildStatusRow(
            label: 'Unreachable',
            color: const Color(0xFFA855F7),
            count: stats.noData,
            total: stats.total,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required Color color,
    required int count,
    required int total,
    required bool isDark,
  }) {
    final double ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        // Status indicator dot
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Label
        SizedBox(
          width: 88,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Debossed recessed progress bar well
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF11161F) : const Color(0xFFDCE3ED),
              borderRadius: BorderRadius.circular(7),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        offset: const Offset(1.5, 1.5),
                        blurRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFA3B2C6).withOpacity(0.50),
                        offset: const Offset(1.5, 1.5),
                        blurRadius: 2,
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-1, -1),
                        blurRadius: 1.5,
                      ),
                    ],
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: ratio),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder:
                    (BuildContext context, double animRatio, Widget? child) {
                  return FractionallySizedBox(
                    widthFactor: animRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: count > 0
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Count
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
