import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FleetSummaryHeader extends StatelessWidget {
  const FleetSummaryHeader({
    required this.total,
    required this.moving,
    required this.stopped,
    required this.alerts,
    super.key,
  });

  final int total;
  final int moving;
  final int stopped;
  final int alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night1,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _SummaryCard(
              title: 'Total Vehicles',
              value: total.toString(),
              subtitle: '12',
              subtitleIcon: Icons.arrow_drop_up,
              subtitleColor: AppColors.moving,
              icon: Icons.directions_car_rounded,
              iconColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _SummaryCard(
              title: 'Moving',
              value: moving.toString(),
              subtitle: '67%',
              subtitleColor: AppColors.moving,
              icon: Icons.signal_cellular_alt_rounded,
              iconColor: AppColors.moving,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _SummaryCard(
              title: 'Stopped',
              value: stopped.toString(),
              subtitle: '33%',
              subtitleColor: AppColors.stopped,
              icon: Icons.stop_circle_rounded,
              iconColor: AppColors.stopped,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _SummaryCard(
              title: 'Alerts',
              value: alerts.toString(),
              icon: Icons.warning_rounded,
              iconColor: AppColors.danger,
              isAlert: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.subtitleIcon,
    this.subtitleColor,
    required this.icon,
    required this.iconColor,
    this.isAlert = false,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? subtitleIcon;
  final Color? subtitleColor;
  final IconData icon;
  final Color iconColor;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13171F), // Exact dark card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(width: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (subtitleIcon != null)
                              Icon(subtitleIcon, size: 12, color: subtitleColor),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 20,
                    color: isAlert ? iconColor : iconColor.withOpacity(0.8),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
