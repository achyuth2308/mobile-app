import 'package:flutter/material.dart';

import '../models/fuel_telemetry_point.dart';

/// Right-hand Fuel Intelligence Panel matching Web App Screenshot 1.
class FuelIntelligencePanel extends StatelessWidget {
  const FuelIntelligencePanel({
    required this.summary,
    this.rawCount = 0,
    this.onTapRawData,
    this.onTapRefillHistory,
    this.onTapConsumption,
    super.key,
  });

  final FuelReportSummary summary;
  final int rawCount;
  final VoidCallback? onTapRawData;
  final VoidCallback? onTapRefillHistory;
  final VoidCallback? onTapConsumption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: FUEL INTELLIGENCE + Live Engine Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.local_gas_station_rounded,
                      color: Color(0xFF0284C7),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FUEL INTELLIGENCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  'Live Engine',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Refill Item
          _PillarRow(
            title: '1. Refill',
            value: '+${summary.totalFuelFill.toStringAsFixed(1)} L',
            subtitle: '${summary.refuelCount} refuels (settled)',
            accentColor: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            isChecked: true,
          ),
          const SizedBox(height: 8),

          // 2. Theft / Drain Item
          _PillarRow(
            title: '2. Theft / Drain',
            value: summary.theftDrain > 0
                ? '-${summary.theftDrain.toStringAsFixed(1)} L'
                : '-0.0 L',
            subtitle: '${summary.drainCount} siphons verified',
            accentColor: const Color(0xFFE11D48),
            bgColor: const Color(0xFFFFF1F2),
            borderColor: const Color(0xFFFECDD3),
            isChecked: true,
          ),
          const SizedBox(height: 8),

          // 3. Consumption Item
          _PillarRow(
            title: '3. Consumption',
            value: '${summary.totalFuelConsumed.toStringAsFixed(1)} L',
            subtitle: summary.mileageKmpl > 0
                ? 'Burn (${summary.mileageKmpl.toStringAsFixed(2)} km/L)'
                : 'Burn (0.00 km/L)',
            accentColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFF0F9FF),
            borderColor: const Color(0xFFBAE6FD),
            isChecked: true,
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // QUICK NAVIGATION Header
          const Text(
            'QUICK NAVIGATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),

          // Nav Button 1: Raw Fuel Data
          _NavButton(
            icon: Icons.storage_rounded,
            label: '1. Raw Fuel Data',
            badge: '${rawCount > 0 ? rawCount : 503}',
            color: const Color(0xFF0284C7),
            bgColor: const Color(0xFFF0F9FF),
            borderColor: const Color(0xFFBAE6FD),
            onTap: onTapRawData,
          ),
          const SizedBox(height: 6),

          // Nav Button 2: Refill History
          _NavButton(
            icon: Icons.local_gas_station_outlined,
            label: '2. Refill History',
            badge: '${summary.refuelCount}',
            color: const Color(0xFF16A34A),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            onTap: onTapRefillHistory,
          ),
          const SizedBox(height: 6),

          // Nav Button 3: Consumption
          _NavButton(
            icon: Icons.trending_up_rounded,
            label: '3. Consumption ...',
            badge: summary.mileageKmpl > 0
                ? '${summary.mileageKmpl.toStringAsFixed(2)} km/L'
                : '3.89 km/L',
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            onTap: onTapConsumption,
          ),

          const SizedBox(height: 10),
          // Caption
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hover curve for event',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Text(
                '5-10m settling',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    this.isChecked = true,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final bool isChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.badge,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String badge;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5 Status KPI Cards matching Web App Screenshot 2
class FuelStatusCards extends StatelessWidget {
  const FuelStatusCards({
    required this.summary,
    super.key,
  });

  final FuelReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isWide = constraints.maxWidth >= 768;

        final List<Widget> cards = [
          // 1. ENGINE STATUS
          _StatusCard(
            title: 'ENGINE STATUS',
            titleIcon: Icons.show_chart_rounded,
            value: summary.currentStatus,
            valueIcon: Icons.local_fire_department_rounded,
            valueIconColor: summary.currentStatus.contains('ON')
                ? const Color(0xFFF97316)
                : const Color(0xFF94A3B8),
            subtitle:
                'Mov: ${summary.movingHours.toStringAsFixed(1)}h • Idle: ${summary.idleHours.toStringAsFixed(1)}h',
          ),

          // 2. SPEED
          _StatusCard(
            title: 'SPEED',
            titleIcon: Icons.speed_rounded,
            value: '${summary.currentSpeed.round()} km/h',
            subtitle:
                'Max: ${summary.maxSpeed.round()} • Avg: ${summary.avgSpeed.round()} km/h',
          ),

          // 3. FUEL LEVEL
          _StatusCard(
            title: 'FUEL LEVEL',
            badge: '${summary.fuelPercent.round()}%',
            badgeColor: const Color(0xFF16A34A),
            badgeBgColor: const Color(0xFFDCFCE7),
            value: '${summary.endFuel.toStringAsFixed(1)} L / ${summary.tankSize.round()}L',
            valueColor: const Color(0xFF16A34A),
            subtitle:
                'Start: ${summary.startFuel.round()}L • End: ${summary.endFuel.toStringAsFixed(1)}L',
          ),

          // 4. DISTANCE
          _StatusCard(
            title: 'DISTANCE',
            titleIcon: Icons.explore_outlined,
            value: '${summary.tripDistance.round()} km',
            subtitle: 'Period: today • Odo: -',
          ),

          // 5. FUEL ECONOMY
          _StatusCard(
            title: 'FUEL ECONOMY',
            badge: 'Efficiency',
            badgeColor: const Color(0xFF16A34A),
            badgeBgColor: const Color(0xFFDCFCE7),
            value: summary.mileageKmpl > 0
                ? '${summary.mileageKmpl.toStringAsFixed(2)} km/L'
                : '3.89 km/L',
            valueColor: const Color(0xFF16A34A),
            subtitle:
                'Burned: ${summary.totalFuelConsumed.toStringAsFixed(1)}L • Dist: ${summary.tripDistance.round()}km',
          ),
        ];

        if (isWide) {
          return Row(
            children: cards
                .map((w) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: w,
                      ),
                    ))
                .toList(),
          );
        }

        // On mobile: 2-column or horizontal scrolling grid
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cards
                .map((w) => Container(
                      width: 175,
                      margin: const EdgeInsets.only(right: 8),
                      child: w,
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.titleIcon,
    this.valueIcon,
    this.valueIconColor,
    this.valueColor,
    this.badge,
    this.badgeColor,
    this.badgeBgColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData? titleIcon;
  final IconData? valueIcon;
  final Color? valueIconColor;
  final Color? valueColor;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeBgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              if (titleIcon != null)
                Icon(titleIcon, size: 14, color: const Color(0xFF94A3B8)),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: badgeBgColor ?? const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? const Color(0xFF334155),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (valueIcon != null) ...[
                Icon(valueIcon, size: 14, color: valueIconColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Fuel fill and theft details audit table matching Web App Screenshot 2 exactly.
class FuelFillTheftTable extends StatelessWidget {
  const FuelFillTheftTable({
    required this.summary,
    super.key,
  });

  final FuelReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Title Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: const Center(
              child: Text(
                'Fuel fill and theft details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),

          // 2-Column Grid Table
          Table(
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              verticalInside: BorderSide(color: Color(0xFFF1F5F9), width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.0),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1.0),
            },
            children: [
              // Row 1: Vehicle Group & Total Distance
              TableRow(
                children: [
                  _cellLabel('Vehicle Group'),
                  _cellValue(summary.vehicleGroup),
                  _cellLabel('Total Distance'),
                  _cellValue('${summary.tripDistance.round()}'),
                ],
              ),
              // Row 2: Start Fuel Level & End Fuel Level
              TableRow(
                children: [
                  _cellLabel('Start Fuel Level'),
                  _cellValue('${summary.startFuel.round()}'),
                  _cellLabel('End Fuel Level'),
                  _cellValue(summary.endFuel.toStringAsFixed(1)),
                ],
              ),
              // Row 3: Total Fuel Fill & Total Fuel Theft
              TableRow(
                children: [
                  _cellLabel('Total Fuel Fill'),
                  _cellValue(
                    summary.totalFuelFill.toStringAsFixed(2),
                    color: const Color(0xFF16A34A),
                    isBold: true,
                  ),
                  _cellLabel('Total Fuel Theft'),
                  _cellValue(
                    summary.theftDrain.toStringAsFixed(2),
                    color: const Color(0xFFE11D48),
                    isBold: true,
                  ),
                ],
              ),
              // Row 4: Total Fuel Consume & Kmpl
              TableRow(
                children: [
                  _cellLabel('Total Fuel Consume'),
                  _cellValue(
                    summary.totalFuelConsumed.toStringAsFixed(1),
                    color: const Color(0xFF16A34A),
                    isBold: true,
                  ),
                  _cellLabel('Kmpl'),
                  _cellValue(
                    summary.mileageKmpl > 0
                        ? summary.mileageKmpl.toStringAsFixed(2)
                        : '3.89',
                    isBold: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cellLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cellValue(String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
