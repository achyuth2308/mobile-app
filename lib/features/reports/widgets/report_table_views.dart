import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';
import '../../../data/models/json_utils.dart';
import '../../../data/models/report_models.dart';
import '../../../data/models/vehicle.dart';
import 'engine_on_table.dart';

/// Async cell that fetches and displays the reverse-geocoded address.
class AddressCell extends StatefulWidget {
  const AddressCell({
    this.lat,
    this.lng,
    this.fallback,
    this.maxWidth = 300,
    this.hideCoords = false,
    super.key,
  });

  final double? lat;
  final double? lng;
  final String? fallback;
  final double maxWidth;
  final bool hideCoords;

  @override
  State<AddressCell> createState() => _AddressCellState();
}

class _AddressCellState extends State<AddressCell> {
  String? _address;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AddressCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _resolve();
    }
  }

  void _resolve() {
    double? lat = widget.lat;
    double? lng = widget.lng;

    final String? fb = widget.fallback?.trim();
    final bool isCoords = fb != null &&
        RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(fb);

    if (fb != null &&
        fb.isNotEmpty &&
        !isCoords &&
        fb != 'Location unavailable') {
      _address = fb;
      return;
    }

    if ((lat == null || lng == null) && fb != null && isCoords) {
      final List<String> parts = fb.split(',');
      if (parts.length == 2) {
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }
    }

    if (lat != null && lng != null && (lat != 0 || lng != 0)) {
      final String? cached = Geocoder.getCachedAddress(lat, lng);
      if (cached != null &&
          !RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(cached)) {
        _address = cached;
        return;
      }

      _loading = true;
      Geocoder.getAddress(lat, lng).then((String addr) {
        if (mounted) {
          setState(() {
            if (addr.isNotEmpty && addr != 'Location unavailable') {
              _address = addr;
            } else if (fb != null &&
                !isCoords &&
                fb != 'Location unavailable') {
              _address = fb;
            } else {
              _address = 'Location unavailable';
            }
            _loading = false;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _address = (fb != null && !isCoords && fb != 'Location unavailable')
                ? fb
                : 'Location unavailable';
            _loading = false;
          });
        }
      });
    } else {
      _address = (fb != null && !isCoords && fb != 'Location unavailable')
          ? fb
          : 'Location unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? containerWidth =
        widget.maxWidth == double.infinity ? null : widget.maxWidth;

    if (_loading && _address == null) {
      return Container(
        width: containerWidth,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Fetching address...',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    final bool hasValidCoords = widget.lat != null &&
        widget.lng != null &&
        (widget.lat != 0 || widget.lng != 0);

    final bool isUnavailable =
        _address == null || _address == 'Location unavailable';

    if (isUnavailable && hasValidCoords) {
      if (widget.hideCoords) {
        return InkWell(
          onTap: () {
            setState(() {
              _loading = true;
            });
            _resolve();
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: containerWidth,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    'Loading address...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        );
      }

      return InkWell(
        onTap: () {
          setState(() {
            _loading = true;
          });
          _resolve();
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: containerWidth,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  '${widget.lat!.toStringAsFixed(4)}, ${widget.lng!.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.refresh_rounded,
                  size: 12, color: Color(0xFF2563EB)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: containerWidth,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        _address ?? 'Location unavailable',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF334155),
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        softWrap: true,
      ),
    );
  }
}

// ── Table Header Cell ───────────────────────────────────────────
class TableHeaderCell extends StatelessWidget {
  const TableHeaderCell(
    this.text, {
    this.width,
    this.align = TextAlign.left,
    super.key,
  });

  final String text;
  final double? width;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final Widget child = Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
        letterSpacing: 0.5,
      ),
    );

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: child,
    );
  }
}

// ── Table Data Cell ─────────────────────────────────────────────
class TableDataCell extends StatelessWidget {
  const TableDataCell({
    this.child,
    this.text,
    this.width,
    this.align = TextAlign.left,
    this.style,
    super.key,
  });

  final Widget? child;
  final String? text;
  final double? width;
  final TextAlign align;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final Widget content = child ??
        Text(
          text ?? '-',
          textAlign: align,
          style: style ??
              const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF334155),
              ),
        );

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : align == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
      child: content,
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 1. TRIP REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class TripReportTable extends StatelessWidget {
  const TripReportTable({
    required this.rows,
    this.showVehicle = false,
    super.key,
  });

  final List<ReportRow> rows;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = rows[index];

        // Resolve effective start point and fallback address
        double? startLat = r.startLat;
        double? startLng = r.startLng;
        String? startAddr =
            (r.fromLocation != null && r.fromLocation != 'Location unavailable')
                ? r.fromLocation
                : (r.address != null && r.address != 'Location unavailable'
                    ? r.address
                    : null);

        // If start coordinates or address are not yet known, infer from adjacent trip
        if ((startLat == null ||
                startLng == null ||
                (startLat == 0 && startLng == 0)) &&
            (startAddr == null ||
                startAddr.isEmpty ||
                startAddr == 'Location unavailable')) {
          // For newest-first lists, preceding trip is index + 1
          if (index + 1 < rows.length) {
            final ReportRow prev = rows[index + 1];
            if (prev.endLat != null &&
                prev.endLng != null &&
                (prev.endLat != 0 || prev.endLng != 0)) {
              startLat ??= prev.endLat;
              startLng ??= prev.endLng;
            }
            if ((startAddr == null || startAddr == 'Location unavailable') &&
                prev.toLocation != null &&
                prev.toLocation != 'Location unavailable') {
              startAddr = prev.toLocation;
            }
          }
          // For oldest-first lists, preceding trip is index - 1
          if ((startLat == null || startLng == null) && index > 0) {
            final ReportRow prev = rows[index - 1];
            if (prev.endLat != null &&
                prev.endLng != null &&
                (prev.endLat != 0 || prev.endLng != 0)) {
              startLat ??= prev.endLat;
              startLng ??= prev.endLng;
            }
            if ((startAddr == null || startAddr == 'Location unavailable') &&
                prev.toLocation != null &&
                prev.toLocation != 'Location unavailable') {
              startAddr = prev.toLocation;
            }
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row (Vehicle Name & Duration)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (showVehicle)
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.directions_car_rounded,
                                size: 14, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r.vehicleName ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.electric_bolt_rounded,
                                size: 14, color: Color(0xFF9333EA)),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Automated Trip',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Fmt.durationWeb(r.durationSecVal),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Timeline (Start & End)
                _buildTimelineRow(
                  context: context,
                  isStart: true,
                  time: Fmt.dateTimeWeb(r.startTime),
                  lat: startLat,
                  lng: startLng,
                  fallbackAddress: startAddr,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 7, top: 2, bottom: 2),
                  child: SizedBox(
                    height: 12,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1.5,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                _buildTimelineRow(
                  context: context,
                  isStart: false,
                  time: Fmt.dateTimeWeb(r.endTime),
                  lat: r.endLat,
                  lng: r.endLng,
                  fallbackAddress: r.toLocation,
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Stats Row
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat(
                      label: 'DISTANCE',
                      value: r.distanceTravelled != null
                          ? '${r.distanceTravelled!.toStringAsFixed(r.distanceTravelled! < 10 ? 1 : 0)} km'
                          : '-',
                    ),
                    _buildStat(
                      label: 'MOVING TIME',
                      value: r.movingSeconds != null
                          ? Fmt.durationWeb(r.movingSeconds)
                          : '-',
                    ),
                    _buildStat(
                      label: 'MAX SPEED',
                      value: r.maxSpeedVal != null
                          ? '${r.maxSpeedVal!.round()} km/h'
                          : '-',
                    ),
                    _buildStat(
                      label: 'AVG SPEED',
                      value: r.avgSpeedVal != null
                          ? '${r.avgSpeedVal!.round()} km/h'
                          : '-',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineRow({
    required BuildContext context,
    required bool isStart,
    required String time,
    required double? lat,
    required double? lng,
    String? fallbackAddress,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Marker indicator
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isStart
                ? Icons.radio_button_checked_rounded
                : Icons.location_on_rounded,
            size: 15,
            color: isStart ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              AddressCell(
                lat: lat,
                lng: lng,
                fallback: fallbackAddress,
                maxWidth: double.infinity,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 1b. MANUAL TRIP REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class ManualTripReportTable extends StatelessWidget {
  const ManualTripReportTable({
    required this.rows,
    this.showVehicle = false,
    super.key,
  });

  final List<ReportRow> rows;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final Map<int, TableColumnWidth> widths = {
      if (showVehicle) 0: const FixedColumnWidth(130), // VEHICLE
      for (int i = 0; i < 9; i++)
        (showVehicle ? i + 1 : i): switch (i) {
          0 => const FixedColumnWidth(140), // STATUS
          1 => const FixedColumnWidth(160), // TRIP NAME
          2 => const FixedColumnWidth(150), // START TIME
          3 => const FixedColumnWidth(200), // ORIGIN / START ADDR
          4 => const FixedColumnWidth(150), // END TIME
          5 => const FixedColumnWidth(200), // DESTINATION / END ADDR
          6 => const FixedColumnWidth(160), // DURATION
          7 => const FixedColumnWidth(100), // DISTANCE
          8 => const FixedColumnWidth(100), // MAX SPEED
          _ => const FixedColumnWidth(100),
        },
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: DataTableTheme(
        data: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll<Color>(Color(0xFFF8FAFC)),
          horizontalMargin: 12,
          columnSpacing: 16,
        ),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: widths,
          children: <TableRow>[
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: <Widget>[
                if (showVehicle) const TableHeaderCell('VEHICLE'),
                const TableHeaderCell('STATUS'),
                const TableHeaderCell('TRIP NAME'),
                const TableHeaderCell('START TIME'),
                const TableHeaderCell('START / ORIGIN'),
                const TableHeaderCell('END TIME'),
                const TableHeaderCell('END / DESTINATION'),
                const TableHeaderCell('DURATION (HH:MM:SS)'),
                const TableHeaderCell('DISTANCE', align: TextAlign.right),
                const TableHeaderCell('MAX SPEED', align: TextAlign.right),
              ],
            ),
            ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
              final int idx = entry.key;
              final ReportRow r = entry.value;
              final Color rowColor =
                  idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

              final String tripName = r.raw['name']?.toString() ?? '-';
              final String originStr = (r.fromLocation != null &&
                      r.fromLocation != 'Location unavailable')
                  ? r.fromLocation!
                  : (r.raw['origin']?.toString() ?? '');
              final String destStr = (r.toLocation != null &&
                      r.toLocation != 'Location unavailable')
                  ? r.toLocation!
                  : (r.raw['destination']?.toString() ?? '');

              final String statusStr = (r.status ?? 'unknown').toUpperCase();
              Color statusColor = const Color(0xFF64748B);
              if (statusStr == 'COMPLETED')
                statusColor = const Color(0xFF10B981);
              if (statusStr == 'IN_PROGRESS')
                statusColor = const Color(0xFF3B82F6);
              if (statusStr == 'CANCELLED')
                statusColor = const Color(0xFFEF4444);

              return TableRow(
                decoration: BoxDecoration(color: rowColor),
                children: <Widget>[
                  if (showVehicle)
                    TableDataCell(
                      text: r.vehicleName ?? '-',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  TableDataCell(
                    text: statusStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  TableDataCell(
                    text: tripName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TableDataCell(
                    text: Fmt.dateTimeWeb(r.startTime),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TableDataCell(
                    child: originStr.isNotEmpty
                        ? Text(originStr,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF334155)))
                        : AddressCell(
                            lat: r.startLat,
                            lng: r.startLng,
                            maxWidth: 190,
                          ),
                  ),
                  TableDataCell(
                    text: Fmt.dateTimeWeb(r.endTime),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TableDataCell(
                    child: destStr.isNotEmpty
                        ? Text(destStr,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF334155)))
                        : AddressCell(
                            lat: r.endLat,
                            lng: r.endLng,
                            maxWidth: 190,
                          ),
                  ),
                  TableDataCell(
                    text: Fmt.durationWeb(r.durationSecVal),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  TableDataCell(
                    text: r.distanceTravelled != null
                        ? r.distanceTravelled!
                            .toStringAsFixed(r.distanceTravelled! < 10 ? 1 : 0)
                        : '-',
                    align: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TableDataCell(
                    text: r.maxSpeedVal != null
                        ? r.maxSpeedVal!.round().toString()
                        : '-',
                    align: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 2. DAILY DISTANCE REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class DailyDistanceReportTable extends StatelessWidget {
  const DailyDistanceReportTable({required this.rows, super.key});

  final List<ReportRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = rows[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header (Vehicle Name & Date)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            r.vehicleName ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plate: ${r.plate ?? "-"}  |  Org: ${r.orgName ?? "FuelTracks"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        Fmt.dateWeb(r.date),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat(
                      label: 'START ODOMETER',
                      value: r.startOdometer != null
                          ? '${r.startOdometer!.round()} km'
                          : '-',
                      labelColor: const Color(0xFF059669),
                      valueColor: const Color(0xFF10B981),
                    ),
                    _buildStat(
                      label: 'END ODOMETER',
                      value: r.endOdometer != null
                          ? '${r.endOdometer!.round()} km'
                          : '-',
                      labelColor: const Color(0xFF0284C7),
                      valueColor: const Color(0xFF2563EB),
                    ),
                    _buildStat(
                      label: 'DISTANCE',
                      value:
                          '${r.distanceTravelled?.toStringAsFixed(0) ?? '0'} km',
                      labelColor: const Color(0xFFD95D0B),
                      valueColor: const Color(0xFFEA580C),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
    Color? labelColor,
    Color? valueColor,
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: labelColor ?? const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ??
                (isHighlight ? const Color(0xFF10B981) : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 3. OVERSPEEDING REPORT TABLE (Grouped by Vehicle)
// ═════════════════════════════════════════════════════════════════
class OverspeedingReportTable extends StatelessWidget {
  const OverspeedingReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    this.speedLimit = 60,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final int speedLimit;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group rows by vehicle
    final Map<String, List<ReportRow>> groups = <String, List<ReportRow>>{};
    for (final ReportRow r in rows) {
      final String vName = r.vehicleName ?? 'Unknown Vehicle';
      groups.putIfAbsent(vName, () => <ReportRow>[]).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups.entries.map((MapEntry<String, List<ReportRow>> entry) {
        final String vehicleName = entry.key;
        final List<ReportRow> vehicleRows = entry.value;

        // Peak speed and total duration across this vehicle
        double peakSpeed = 0;
        int totalDuration = 0;
        for (final ReportRow r in vehicleRows) {
          final double s = r.maxSpeedVal ?? 0;
          if (s > peakSpeed) peakSpeed = s;
          totalDuration += (r.durationSecVal ?? 0);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Vehicle Group Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.directions_car_rounded,
                          size: 17,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          vehicleName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                              const SizedBox(width: 3),
                              Text(
                                '${vehicleRows.length} Violation${vehicleRows.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.speed_rounded, size: 12, color: Color(0xFFEA580C)),
                              const SizedBox(width: 3),
                              Text(
                                'Peak: ${peakSpeed.round()} km/h',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.tune_rounded, size: 12, color: Color(0xFF475569)),
                              const SizedBox(width: 3),
                              Text(
                                'Limit: $speedLimit km/h',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Individual Overspeeding Event Cards for this vehicle
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  children: vehicleRows.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final ReportRow r = entry.value;
                    final double maxSpd = r.maxSpeedVal ?? 0;
                    final double excessSpd = (maxSpd - speedLimit).clamp(0, 999);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x060F172A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Event Header Row: Index Pill + Date & Time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.tag_rounded,
                                      size: 11,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    Fmt.dateTimeWeb(r.startTime),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // 4-Metric Grid Row (Max Speed, Over Limit, Duration, Distance)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                _buildMetric(
                                  icon: Icons.speed_rounded,
                                  label: 'MAX SPEED',
                                  value: '${maxSpd.round()} km/h',
                                  labelColor: const Color(0xFFDC2626),
                                  valueColor: const Color(0xFFDC2626),
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                _buildMetric(
                                  icon: Icons.trending_up_rounded,
                                  label: 'OVER LIMIT',
                                  value: '+${excessSpd.round()} km/h',
                                  labelColor: const Color(0xFFD95D0B),
                                  valueColor: const Color(0xFFEA580C),
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                _buildMetric(
                                  icon: Icons.access_time_rounded,
                                  label: 'DURATION',
                                  value: Fmt.durationWeb(r.durationSecVal),
                                  labelColor: const Color(0xFFBE185D),
                                  valueColor: const Color(0xFFBE185D),
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                _buildMetric(
                                  icon: Icons.straighten_rounded,
                                  label: 'DISTANCE',
                                  value: r.distanceTravelled != null
                                      ? '${r.distanceTravelled!.toStringAsFixed(1)} km'
                                      : '0.0 km',
                                  labelColor: const Color(0xFF059669),
                                  valueColor: const Color(0xFF10B981),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Address Row: Dark Green Location Pin + Reverse Geocoded Address (NO Lat/Lng)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 2, right: 6),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  size: 15,
                                  color: Color(0xFF15803D), // Dark Green
                                ),
                              ),
                              Expanded(
                                child: AddressCell(
                                  lat: r.startLat ?? r.latitude,
                                  lng: r.startLng ?? r.longitude,
                                  fallback: r.address,
                                  maxWidth: double.infinity,
                                  hideCoords: true, // NEVER show raw coordinates
                                ),
                              ),
                            ],
                          ),

                          // Optional Driver Row
                          if ((r.driverName != null && r.driverName!.trim().isNotEmpty && r.driverName != '-') ||
                              (r.driverPhone != null && r.driverPhone!.trim().isNotEmpty && r.driverPhone != '-')) ...<Widget>[
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Driver: ${r.driverName ?? '-'} ${r.driverPhone != null && r.driverPhone!.isNotEmpty ? '(${r.driverPhone})' : ''}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 11, color: labelColor),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 4. STOPPAGE REPORT TABLE (Grouped by Vehicle, Filtering Parked)
// ═════════════════════════════════════════════════════════════════
class StoppageReportTable extends StatelessWidget {
  const StoppageReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    // Group all rows by vehicle to calculate summary stats
    final Map<String, List<ReportRow>> groups = <String, List<ReportRow>>{};
    for (final ReportRow r in rows) {
      final String vName = r.vehicleName ?? 'Unknown Vehicle';
      groups.putIfAbsent(vName, () => <ReportRow>[]).add(r);
    }

    return Column(
      children: groups.entries.map((MapEntry<String, List<ReportRow>> entry) {
        final String vehicleName = entry.key;
        final List<ReportRow> vehicleAllRows = entry.value;

        // Calculate moving, parked, idle totals
        int movingSec = 0;
        int parkedSec = 0;
        int idleSec = 0;

        for (final ReportRow r in vehicleAllRows) {
          final int dur = r.durationSecVal ?? 0;
          final String st = (r.status ?? '').toLowerCase();
          if (st.contains('mov') || st.contains('run')) {
            movingSec += dur;
          } else if (st.contains('idle')) {
            idleSec += dur;
          } else {
            parkedSec += dur;
          }
        }

        // Only display Parked / Stoppage rows in the table
        final List<ReportRow> parkedRows = vehicleAllRows.where((ReportRow r) {
          final String st = (r.status ?? '').toLowerCase();
          return !st.contains('mov') &&
              !st.contains('run') &&
              !st.contains('idle');
        }).toList();

        final List<ReportRow> tableRows =
            parkedRows.isNotEmpty ? parkedRows : vehicleAllRows;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top Info Banner: Vehicle Name + Date Range
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      'Vehicle : $vehicleName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'From : ${Fmt.dateWeb(startDate)} 00:00:00 - To : ${Fmt.dateWeb(endDate)} 23:59:59',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Stats Duration Row (Moving | Parked | Idle)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    _statBadge('Moving', Fmt.durationWeb(movingSec),
                        const Color(0xFF10B981)),
                    _statBadge('Parked', Fmt.durationWeb(parkedSec),
                        const Color(0xFFEA580C)),
                    _statBadge('Idle', Fmt.durationWeb(idleSec),
                        const Color(0xFFD97706)),
                  ],
                ),
              ),

              // Stoppage Events Table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const <int, TableColumnWidth>{
                    0: FixedColumnWidth(110), // Status
                    1: FixedColumnWidth(180), // Start Time
                    2: FixedColumnWidth(180), // End Time
                    3: FixedColumnWidth(160), // Duration (HH:MM:SS)
                    4: FixedColumnWidth(300), // Location Details
                  },
                  children: <TableRow>[
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: <Widget>[
                        TableHeaderCell('Status'),
                        TableHeaderCell('Start Time'),
                        TableHeaderCell('End Time'),
                        TableHeaderCell('Duration (HH:MM:SS)'),
                        TableHeaderCell('Location Details'),
                      ],
                    ),
                    ...tableRows
                        .asMap()
                        .entries
                        .map((MapEntry<int, ReportRow> rowEntry) {
                      final int idx = rowEntry.key;
                      final ReportRow r = rowEntry.value;
                      final Color rowColor =
                          idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

                      return TableRow(
                        decoration: BoxDecoration(color: rowColor),
                        children: <Widget>[
                          const TableDataCell(
                            text: 'Parked',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.dateTimeWeb(r.startTime),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.dateTimeWeb(r.endTime),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.durationWeb(r.durationSecVal),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          TableDataCell(
                            child: AddressCell(
                              lat: r.startLat,
                              lng: r.startLng,
                              fallback: r.address,
                              maxWidth: 290,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity( 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '$label : ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 5. IDLE REPORT TABLE (Grouped by Vehicle, Filtering Idle)
// ═════════════════════════════════════════════════════════════════
class IdleReportTable extends StatelessWidget {
  const IdleReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    // Group all rows by vehicle to calculate summary stats
    final Map<String, List<ReportRow>> groups = <String, List<ReportRow>>{};
    for (final ReportRow r in rows) {
      final String vName = r.vehicleName ?? 'Unknown Vehicle';
      groups.putIfAbsent(vName, () => <ReportRow>[]).add(r);
    }

    return Column(
      children: groups.entries.map((MapEntry<String, List<ReportRow>> entry) {
        final String vehicleName = entry.key;
        final List<ReportRow> vehicleAllRows = entry.value;

        // Calculate moving, parked, idle totals
        int movingSec = 0;
        int parkedSec = 0;
        int idleSec = 0;

        for (final ReportRow r in vehicleAllRows) {
          final int dur = r.durationSecVal ?? 0;
          final String st = (r.status ?? '').toLowerCase();
          if (st.contains('mov') || st.contains('run')) {
            movingSec += dur;
          } else if (st.contains('idle')) {
            idleSec += dur;
          } else {
            parkedSec += dur;
          }
        }

        // Only display Idle rows in the table
        final List<ReportRow> idleRows = vehicleAllRows.where((ReportRow r) {
          final String st = (r.status ?? '').toLowerCase();
          return st.contains('idle');
        }).toList();

        final List<ReportRow> tableRows =
            idleRows.isNotEmpty ? idleRows : vehicleAllRows;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top Info Banner: Vehicle Name + Date Range
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      'Vehicle : $vehicleName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'From : ${Fmt.dateWeb(startDate)} 00:00:00 - To : ${Fmt.dateWeb(endDate)} 23:59:59',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Stats Duration Row (Moving | Parked | Idle)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: <Widget>[
                    _statBadge('Moving', Fmt.durationWeb(movingSec),
                        const Color(0xFF10B981)),
                    _statBadge('Parked', Fmt.durationWeb(parkedSec),
                        const Color(0xFFEA580C)),
                    _statBadge('Idle', Fmt.durationWeb(idleSec),
                        const Color(0xFFD97706)),
                  ],
                ),
              ),

              // Idle Events Table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const <int, TableColumnWidth>{
                    0: FixedColumnWidth(110), // Status
                    1: FixedColumnWidth(180), // Start Time
                    2: FixedColumnWidth(180), // End Time
                    3: FixedColumnWidth(160), // Duration (HH:MM:SS)
                    4: FixedColumnWidth(300), // Location Details
                  },
                  children: <TableRow>[
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: <Widget>[
                        TableHeaderCell('Status'),
                        TableHeaderCell('Start Time'),
                        TableHeaderCell('End Time'),
                        TableHeaderCell('Duration (HH:MM:SS)'),
                        TableHeaderCell('Location Details'),
                      ],
                    ),
                    ...tableRows
                        .asMap()
                        .entries
                        .map((MapEntry<int, ReportRow> rowEntry) {
                      final int idx = rowEntry.key;
                      final ReportRow r = rowEntry.value;
                      final Color rowColor =
                          idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

                      return TableRow(
                        decoration: BoxDecoration(color: rowColor),
                        children: <Widget>[
                          const TableDataCell(
                            text: 'Idle',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706), // Amber for Idle
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.dateTimeWeb(r.startTime),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.dateTimeWeb(r.endTime),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.durationWeb(r.durationSecVal),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          TableDataCell(
                            child: AddressCell(
                              lat: r.startLat,
                              lng: r.startLng,
                              fallback: r.address,
                              maxWidth: 290,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity( 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '$label : ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 6. INDIVIDUAL REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class IndividualReportTable extends StatelessWidget {
  const IndividualReportTable({
    required this.rows,
    this.fallbackVehicleName,
    this.fallbackPlate,
    super.key,
  });

  final List<ReportRow> rows;
  final String? fallbackVehicleName;
  final String? fallbackPlate;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(140), // Plate
          1: FixedColumnWidth(140), // Total Distance
          2: FixedColumnWidth(140), // Running Time
          3: FixedColumnWidth(140), // Idle Time
          4: FixedColumnWidth(140), // Stoppage Time
          5: FixedColumnWidth(140), // Total Time
          6: FixedColumnWidth(120), // Trip Count
          7: FixedColumnWidth(120), // Stoppages
          8: FixedColumnWidth(130), // Overspeeding
        },
        children: <TableRow>[
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
            children: <Widget>[
              TableHeaderCell('Plate'),
              TableHeaderCell('Total Distance'),
              TableHeaderCell('Running Time'),
              TableHeaderCell('Idle Time'),
              TableHeaderCell('Stoppage Time'),
              TableHeaderCell('Total Time'),
              TableHeaderCell('Trip Count'),
              TableHeaderCell('Stoppages'),
              TableHeaderCell('Overspeeding'),
            ],
          ),
          ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
            final int idx = entry.key;
            final ReportRow r = entry.value;
            final Color rowColor =
                idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

            return TableRow(
              decoration: BoxDecoration(color: rowColor),
              children: <Widget>[
                TableDataCell(
                  text: r.plate?.isNotEmpty == true
                      ? r.plate!
                      : (r.vehicleName ??
                          fallbackPlate ??
                          fallbackVehicleName ??
                          '-'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                TableDataCell(
                  text: '${r.distanceTravelled?.toStringAsFixed(0) ?? '0'} km',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                TableDataCell(
                  text: Fmt.secsToHms(r.runningSeconds),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                TableDataCell(
                  text: Fmt.secsToHms(r.idleSeconds),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                TableDataCell(
                  text: Fmt.secsToHms(r.stoppedSeconds),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEA580C),
                  ),
                ),
                TableDataCell(
                  text: Fmt.secsToHms(r.totalSeconds),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
                TableDataCell(
                  text: '${r.tripCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                TableDataCell(
                  text: '${r.stoppageCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
                TableDataCell(
                  text: '${r.overspeedingCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 7. CONSOLIDATED REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class ConsolidatedReportTable extends StatelessWidget {
  const ConsolidatedReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final String dateText =
        '${Fmt.dateTimeFilter(startDate)}  →  ${Fmt.dateTimeFilter(endDate)}';

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = rows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header (Vehicle Name & Period)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            vName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plate: $vPlate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Consolidated',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Period: $dateText',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // 1. Operational Times
                const Text(
                  'OPERATIONAL SUMMARY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat('DISTANCE',
                        '${r.distanceTravelled?.toStringAsFixed(0) ?? '0'} km'),
                    _buildStat('RUNNING TIME', Fmt.secsToHms(r.runningSeconds)),
                    _buildStat(
                        'STOPPING TIME', Fmt.secsToHms(r.stoppedSeconds)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat('IDLE TIME', Fmt.secsToHms(r.idleSeconds)),
                    _buildStat(
                        'ENGINE ON',
                        Fmt.secsToHms(
                            (r.runningSeconds ?? 0) + (r.idleSeconds ?? 0))),
                    const SizedBox(width: 100), // spacer alignment
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // 2. Locations
                const Text(
                  'LOCATION BOUNDS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildLocationRow(context, 'From Location', r.fromLocation,
                    r.startLat, r.startLng),
                const SizedBox(height: 8),
                _buildLocationRow(
                    context, 'To Location', r.toLocation, r.endLat, r.endLng),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    BuildContext context,
    String label,
    String? address,
    double? lat,
    double? lng,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: AddressCell(
            lat: lat,
            lng: lng,
            fallback: address,
            maxWidth: double.infinity,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 8. FUEL CONSOLIDATED REPORT TABLE (Mobile Cards & Full Telematics)
// ═════════════════════════════════════════════════════════════════
class FuelConsolidatedReportTable extends StatelessWidget {
  const FuelConsolidatedReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final List<ReportRow> fuelRows = rows.where((ReportRow r) {
      final bool hasFuelData = (r.startFuel != null && r.startFuel! > 0) ||
          (r.endFuel != null && r.endFuel! > 0) ||
          (r.consumption != null && r.consumption! > 0) ||
          (r.filling != null && r.filling! > 0) ||
          (r.theft != null && r.theft! > 0) ||
          (r.kmpl != null && r.kmpl! > 0) ||
          (r.lph != null && r.lph! > 0);
      if (hasFuelData) return true;
      final String? vId = r.vehicleId;
      if (vId != null) {
        final Vehicle? v =
            vehicles.where((Vehicle x) => x.id == vId).firstOrNull;
        if (v != null && v.hasFuel) return true;
      }
      return false;
    }).toList();

    if (fuelRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No fuel records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final String dateText =
        '${Fmt.dateTimeFilter(startDate)}  →  ${Fmt.dateTimeFilter(endDate)}';

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fuelRows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = fuelRows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFED7AA)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header: Vehicle Name, Plate & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            vName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            vPlate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: const Text(
                        'Fuel Consolidated',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Period: $dateText',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFFFF7ED)),
                const SizedBox(height: 10),

                // 1. Fuel Inventory & Usage (3 Expanded Columns - 0 Overflow)
                const Text(
                  'FUEL INVENTORY & USAGE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEA580C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _buildStat(
                      'START FUEL',
                      r.startFuel != null
                          ? '${r.startFuel!.toStringAsFixed(1)} L'
                          : '0 L',
                    ),
                    _buildStat(
                      'END FUEL',
                      r.endFuel != null
                          ? '${r.endFuel!.toStringAsFixed(1)} L'
                          : '0 L',
                    ),
                    _buildStat(
                      'CONSUMPTION',
                      r.consumption != null
                          ? '${r.consumption!.toStringAsFixed(1)} L'
                          : '0 L',
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFFFF7ED)),
                const SizedBox(height: 10),

                // 2. Refuels & Drain Alerts (3 Expanded Columns - 0 Overflow)
                const Text(
                  'REFUELS & THEFT / DRAIN ALERTS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEA580C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _buildStat(
                      'FUEL FILLED',
                      (r.filling != null && r.filling! > 0)
                          ? '+${r.filling!.toStringAsFixed(1)} L'
                          : '0 L',
                      color: (r.filling != null && r.filling! > 0)
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF64748B),
                    ),
                    _buildStat(
                      'THEFT / DRAIN',
                      (r.theft != null && r.theft! > 0)
                          ? '-${r.theft!.toStringAsFixed(1)} L'
                          : '0 L',
                      color: (r.theft != null && r.theft! > 0)
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                    ),
                    _buildStat(
                      'ENGINE RUN',
                      Fmt.secsToHms(
                          (r.runningSeconds ?? 0) + (r.idleSeconds ?? 0)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFFFF7ED)),
                const SizedBox(height: 10),

                // 3. Efficiency & Metrics (3 Expanded Columns - 0 Overflow)
                const Text(
                  'EFFICIENCY & PERFORMANCE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEA580C),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _buildStat(
                      'MILEAGE',
                      r.kmpl != null
                          ? '${r.kmpl!.toStringAsFixed(2)} km/L'
                          : '0 km/L',
                      color: const Color(0xFF0284C7),
                    ),
                    _buildStat(
                      'HOURLY (LPH)',
                      r.lph != null
                          ? '${r.lph!.toStringAsFixed(2)} L/h'
                          : '0 L/h',
                    ),
                    _buildStat(
                      'DISTANCE',
                      '${r.distanceTravelled?.toStringAsFixed(1) ?? '0.0'} km',
                    ),
                  ],
                ),
                if (r.fromLocation != null ||
                    r.toLocation != null ||
                    r.startLat != null) ...<Widget>[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFFFF7ED)),
                  const SizedBox(height: 10),
                  const Text(
                    'LOCATION BOUNDS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEA580C),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (r.fromLocation != null || r.startLat != null)
                    _buildLocationRow(context, 'Start Location', r.fromLocation,
                        r.startLat, r.startLng),
                  if (r.toLocation != null || r.endLat != null) ...<Widget>[
                    const SizedBox(height: 6),
                    _buildLocationRow(context, 'End Location', r.toLocation,
                        r.endLat, r.endLng),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    BuildContext context,
    String label,
    String? address,
    double? lat,
    double? lng,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: AddressCell(
            lat: lat,
            lng: lng,
            fallback: address,
            maxWidth: double.infinity,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 8.1 FUEL REFILL REPORT TABLE (Mobile Cards & Full Web-Matching Fields)
// ═════════════════════════════════════════════════════════════════
class FuelRefillReportTable extends StatelessWidget {
  const FuelRefillReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final List<ReportRow> refillRows = rows.where((ReportRow r) {
      final double rawAmt = r.refillAmount ??
          r.filling ??
          (r.raw['total_refill'] != null
              ? (r.raw['total_refill'] as num).toDouble()
              : 0.0);
      if (rows.length == 1) return true;
      return rawAmt > 0.0;
    }).toList();

    if (refillRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No fuel refill events found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: refillRows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = refillRows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';

        // Direct telematics metrics straight from backend — ZERO client-side recalculations
        final double? startF = r.startFuel ??
            (r.raw['start_fuel'] != null
                ? (r.raw['start_fuel'] as num).toDouble()
                : null);
        final double? endF = r.endFuel ??
            (r.raw['end_fuel'] != null
                ? (r.raw['end_fuel'] as num).toDouble()
                : null);
        final double amount = r.refillAmount ??
            r.filling ??
            (r.raw['total_refill'] != null
                ? (r.raw['total_refill'] as num).toDouble()
                : 0.0);
        final double consumed = r.consumption ??
            (r.raw['consumption'] != null
                ? (r.raw['consumption'] as num).toDouble()
                : 0.0);
        final double dispensed = r.dispensed ??
            (r.raw['total_dispensed'] != null
                ? (r.raw['total_dispensed'] as num).toDouble()
                : 0.0);
        final String category = (r.raw['vehicle_category'] ??
                r.raw['category'] ??
                vehicle?.type ??
                'MACHINERY')
            .toString()
            .toUpperCase();

        final DateTime? eventTime = r.endTime ?? r.startTime ?? r.date;
        final double? lat = r.refillLat ??
            r.latitude ??
            r.endLat ??
            r.startLat ??
            (r.raw['refill_lat'] != null
                ? (r.raw['refill_lat'] as num).toDouble()
                : (r.raw['lat'] != null
                    ? (r.raw['lat'] as num).toDouble()
                    : null));
        final double? lng = r.refillLng ??
            r.longitude ??
            r.endLng ??
            r.startLng ??
            (r.raw['refill_lng'] != null
                ? (r.raw['refill_lng'] as num).toDouble()
                : (r.raw['lng'] != null
                    ? (r.raw['lng'] as num).toDouble()
                    : null));

        final Color catBg = category.contains('GEN')
            ? const Color(0xFFFEF3C7)
            : (category.contains('MACH')
                ? const Color(0xFFE0E7FF)
                : (category.contains('DISP')
                    ? const Color(0xFFCCFBF1)
                    : const Color(0xFFF1F5F9)));
        final Color catColor = category.contains('GEN')
            ? const Color(0xFFB45309)
            : (category.contains('MACH')
                ? const Color(0xFF4338CA)
                : (category.contains('DISP')
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF475569)));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: amount > 0
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: amount > 0
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_gas_station_rounded,
                        size: 18,
                        color: amount > 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  vName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: catBg,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: catColor.withOpacity( 0.2)),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: catColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vPlate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: amount > 0
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: amount > 0
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        amount > 0 ? '+${amount.toStringAsFixed(1)} L' : '0 L',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: amount > 0
                              ? const Color(0xFF15803D)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          eventTime != null
                              ? Fmt.dateTimeFilter(eventTime)
                              : 'Captured Range',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      if (amount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Refilled',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _buildStat(
                        'START FUEL',
                        startF != null
                            ? '${startF.toStringAsFixed(1)} L'
                            : '—'),
                    _buildStat('END FUEL',
                        endF != null ? '${endF.toStringAsFixed(1)} L' : '—'),
                    _buildStat('REFILL',
                        amount > 0 ? '+${amount.toStringAsFixed(1)} L' : '0 L',
                        color: amount > 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _buildStat('CONSUMED',
                        consumed > 0 ? '${consumed.toStringAsFixed(1)} L' : '—',
                        color: const Color(0xFFD97706)),
                    if (dispensed > 0)
                      _buildStat(
                          'DISPENSED', '${dispensed.toStringAsFixed(1)} L',
                          color: const Color(0xFF0284C7)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                _buildLocationRow(
                    context, 'Refill Location', r.fromLocation, lat, lng),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    BuildContext context,
    String label,
    String? address,
    double? lat,
    double? lng,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: AddressCell(
            lat: lat,
            lng: lng,
            fallback: address,
            maxWidth: double.infinity,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 8.2 FUEL THEFT REPORT TABLE (Mobile Cards & Full Web-Matching Fields)
// ═════════════════════════════════════════════════════════════════
class FuelTheftReportTable extends StatelessWidget {
  const FuelTheftReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final List<ReportRow> theftRows = rows.where((ReportRow r) {
      final double rawAmt = r.theftAmount ??
          r.theft ??
          (r.raw['total_theft'] != null
              ? (r.raw['total_theft'] as num).toDouble()
              : 0.0);
      if (rows.length == 1) return true;
      return rawAmt > 0.0;
    }).toList();

    if (theftRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No fuel theft or sudden drain events detected.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: theftRows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = theftRows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';

        // Direct theft metrics straight from backend — ZERO client-side recalculations
        final double? startF = r.startFuel ??
            (r.raw['start_fuel'] != null
                ? (r.raw['start_fuel'] as num).toDouble()
                : null);
        final double? endF = r.endFuel ??
            (r.raw['end_fuel'] != null
                ? (r.raw['end_fuel'] as num).toDouble()
                : null);
        final double amount = r.theftAmount ??
            r.theft ??
            (r.raw['total_theft'] != null
                ? (r.raw['total_theft'] as num).toDouble()
                : 0.0);

        final DateTime? eventTime = r.endTime ?? r.startTime ?? r.date;
        final double? lat = r.latitude ??
            r.endLat ??
            r.startLat ??
            (r.raw['lat'] != null ? (r.raw['lat'] as num).toDouble() : null);
        final double? lng = r.longitude ??
            r.endLng ??
            r.startLng ??
            (r.raw['lng'] != null ? (r.raw['lng'] as num).toDouble() : null);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFECDD3)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            vName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            vPlate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                      ),
                      child: Text(
                        '-${amount.toStringAsFixed(1)} L',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBE123C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        eventTime != null ? Fmt.dateTimeFilter(eventTime) : '—',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _buildStat(
                        'FUEL BEFORE',
                        startF != null
                            ? '${startF.toStringAsFixed(1)} L'
                            : '0 L'),
                    _buildStat('FUEL AFTER',
                        endF != null ? '${endF.toStringAsFixed(1)} L' : '0 L'),
                    _buildStat('DRAINED', '-${amount.toStringAsFixed(1)} L',
                        color: const Color(0xFFE11D48)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                _buildLocationRow(
                    context, 'Drain Location', r.fromLocation, lat, lng),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    BuildContext context,
    String label,
    String? address,
    double? lat,
    double? lng,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: AddressCell(
            lat: lat,
            lng: lng,
            fallback: address,
            maxWidth: double.infinity,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 8.3 FUEL CONSUMPTION REPORT TABLE (Web Matching Telematics & 0 Overflow)
// ═════════════════════════════════════════════════════════════════
class FuelConsumptionReportTable extends StatelessWidget {
  const FuelConsumptionReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final List<ReportRow> fuelRows = rows.where((ReportRow r) {
      final double consumed = r.consumption ??
          (r.raw['consumption'] != null
              ? (r.raw['consumption'] as num).toDouble()
              : 0.0);
      final double? startF = r.startFuel ??
          (r.raw['start_fuel'] != null
              ? (r.raw['start_fuel'] as num).toDouble()
              : null);
      final double? endF = r.endFuel ??
          (r.raw['end_fuel'] != null
              ? (r.raw['end_fuel'] as num).toDouble()
              : null);
      final double dist = r.distanceTravelled ??
          (r.raw['distance_travelled'] != null
              ? (r.raw['distance_travelled'] as num).toDouble()
              : 0.0);
      return consumed > 0 || startF != null || endF != null || dist > 0;
    }).toList();

    if (fuelRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No fuel consumption records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fuelRows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = fuelRows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';
        final double consumed = r.consumption ??
            (r.raw['consumption'] != null
                ? (r.raw['consumption'] as num).toDouble()
                : 0.0);
        final double dist = r.distanceTravelled ??
            (r.raw['distance_travelled'] != null
                ? (r.raw['distance_travelled'] as num).toDouble()
                : 0.0);
        final double refill = r.filling ??
            (r.raw['total_refill'] != null
                ? (r.raw['total_refill'] as num).toDouble()
                : 0.0);
        final double theft = r.theft ??
            (r.raw['total_theft'] != null
                ? (r.raw['total_theft'] as num).toDouble()
                : 0.0);
        final double? startF = r.startFuel ??
            (r.raw['start_fuel'] != null
                ? (r.raw['start_fuel'] as num).toDouble()
                : null);
        final double? endF = r.endFuel ??
            (r.raw['end_fuel'] != null
                ? (r.raw['end_fuel'] as num).toDouble()
                : null);
        final double? kmpl = r.kmpl ??
            (r.raw['kmpl'] != null ? (r.raw['kmpl'] as num).toDouble() : null);
        final int engineSec = (r.runningSeconds ?? 0) +
            (r.idleSeconds ?? 0) +
            (r.raw['engine_on_seconds'] != null
                ? (r.raw['engine_on_seconds'] as num).toInt()
                : 0);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFBAE6FD)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Vehicle Header & Net Consumed Pill
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.water_drop_rounded,
                        size: 18,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            vName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            vPlate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF7DD3FC)),
                      ),
                      child: Text(
                        '${consumed.toStringAsFixed(1)} L Used',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 1: Start Fuel, End Fuel, Net Consumed (Expanded - 0 Overflow)
                Row(
                  children: <Widget>[
                    _buildStat(
                        'START FUEL',
                        startF != null
                            ? '${startF.toStringAsFixed(1)} L'
                            : '0 L'),
                    _buildStat('END FUEL',
                        endF != null ? '${endF.toStringAsFixed(1)} L' : '0 L'),
                    _buildStat(
                        'NET CONSUMED', '${consumed.toStringAsFixed(1)} L',
                        color: const Color(0xFF0284C7)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Row 2: Distance, Engine ON, Mileage (Expanded - 0 Overflow)
                Row(
                  children: <Widget>[
                    _buildStat('DISTANCE', '${dist.toStringAsFixed(1)} km'),
                    _buildStat('ENGINE ON', Fmt.secsToHms(engineSec)),
                    _buildStat('KMPL',
                        kmpl != null ? '${kmpl.toStringAsFixed(2)}' : '0',
                        color: const Color(0xFF15803D)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Row 3: Explicit Refill & Theft columns (shows '0 L' when zero, as requested)
                Row(
                  children: <Widget>[
                    _buildStat(
                      'REFILL',
                      refill > 0 ? '+${refill.toStringAsFixed(1)} L' : '0 L',
                      color: refill > 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF64748B),
                    ),
                    _buildStat(
                      'THEFT',
                      theft > 0 ? '-${theft.toStringAsFixed(1)} L' : '0 L',
                      color: theft > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF64748B),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 8.4 FUEL KMPL REPORT TABLE (Kilometers per Liter - Web Matching Rankings & Ratings)
// ═════════════════════════════════════════════════════════════════
class FuelKmplReportTable extends StatelessWidget {
  const FuelKmplReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final List<ReportRow> fuelRows = rows.where((ReportRow r) {
      final double? k = r.kmpl ??
          (r.raw['kmpl'] != null ? (r.raw['kmpl'] as num).toDouble() : null);
      final double dist = r.distanceTravelled ??
          (r.raw['distance_travelled'] != null
              ? (r.raw['distance_travelled'] as num).toDouble()
              : 0.0);
      final double cons = r.consumption ??
          (r.raw['consumption'] != null
              ? (r.raw['consumption'] as num).toDouble()
              : 0.0);
      return (k != null && k > 0) || dist > 0 || cons > 0;
    }).toList();

    if (fuelRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No KMPL mileage records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Sort by KMPL descending for ranking
    final List<ReportRow> sortedRows = List<ReportRow>.from(fuelRows)
      ..sort((ReportRow a, ReportRow b) {
        final double ka = a.kmpl ??
            (a.raw['kmpl'] != null ? (a.raw['kmpl'] as num).toDouble() : 0.0);
        final double kb = b.kmpl ??
            (b.raw['kmpl'] != null ? (b.raw['kmpl'] as num).toDouble() : 0.0);
        return kb.compareTo(ka);
      });

    // Compute fleet average KMPL
    double sumKmpl = 0.0;
    int validCount = 0;
    for (final ReportRow r in sortedRows) {
      final double? k = r.kmpl ??
          (r.raw['kmpl'] != null ? (r.raw['kmpl'] as num).toDouble() : null);
      if (k != null && k > 0) {
        sumKmpl += k;
        validCount++;
      }
    }
    final double fleetAvg = validCount > 0 ? (sumKmpl / validCount) : 0.0;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedRows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = sortedRows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';
        final double? kmplVal = r.kmpl ??
            (r.raw['kmpl'] != null ? (r.raw['kmpl'] as num).toDouble() : null);
        final double dist = r.distanceTravelled ??
            (r.raw['distance_travelled'] != null
                ? (r.raw['distance_travelled'] as num).toDouble()
                : 0.0);
        final double consumed = r.consumption ??
            (r.raw['consumption'] != null
                ? (r.raw['consumption'] as num).toDouble()
                : 0.0);
        final int rank = index + 1;

        // Web Performance rating badge logic
        String ratingText = 'Standard';
        Color ratingBg = const Color(0xFFF1F5F9);
        Color ratingColor = const Color(0xFF475569);

        if (kmplVal != null && kmplVal > 0 && fleetAvg > 0) {
          if (kmplVal >= fleetAvg * 1.15) {
            final int pct = (((kmplVal - fleetAvg) / fleetAvg) * 100).round();
            ratingText = 'Above Avg (+$pct%)';
            ratingBg = const Color(0xFFD1FAE5);
            ratingColor = const Color(0xFF059669);
          } else if (kmplVal <= fleetAvg * 0.85) {
            final int pct = (((fleetAvg - kmplVal) / fleetAvg) * 100).round();
            ratingText = 'Below Avg (-$pct%)';
            ratingBg = const Color(0xFFFEE2E2);
            ratingColor = const Color(0xFFDC2626);
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFBAE6FD)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                // Rank Badge: 🥇 #1, 🥈 #2, 🥉 #3, #N
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFFEF3C7)
                        : (rank == 2
                            ? const Color(0xFFF1F5F9)
                            : (rank == 3
                                ? const Color(0xFFFFEDD5)
                                : const Color(0xFFF8FAFC))),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rank == 1
                          ? const Color(0xFFFDE68A)
                          : (rank == 2
                              ? const Color(0xFFE2E8F0)
                              : (rank == 3
                                  ? const Color(0xFFFED7AA)
                                  : const Color(0xFFE2E8F0))),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      rank == 1
                          ? '🥇'
                          : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank')),
                      style: TextStyle(
                        fontSize: rank <= 3 ? 16 : 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Vehicle Info & Telematics Subtitle (Expanded - 0 Overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        vName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        vPlate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${dist.toStringAsFixed(1)} km  •  ${consumed.toStringAsFixed(1)} L',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Performance Rating Badge from Web App
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ratingBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ratingText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: ratingColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // KMPL Metric Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        kmplVal != null ? kmplVal.toStringAsFixed(2) : '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      const Text(
                        'km / L',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 8.5 FUEL LPH REPORT TABLE (Liters per Hour - Web Matching Rankings & Ratings)
// ═════════════════════════════════════════════════════════════════
class FuelLphReportTable extends StatelessWidget {
  const FuelLphReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  Widget build(BuildContext context) {
    final List<ReportRow> fuelRows = rows.where((ReportRow r) {
      final double? l = r.lph ??
          (r.raw['lph'] != null ? (r.raw['lph'] as num).toDouble() : null);
      final int engineSec = (r.runningSeconds ?? 0) +
          (r.idleSeconds ?? 0) +
          (r.raw['engine_on_seconds'] != null
              ? (r.raw['engine_on_seconds'] as num).toInt()
              : 0);
      final double cons = r.consumption ??
          (r.raw['consumption'] != null
              ? (r.raw['consumption'] as num).toDouble()
              : 0.0);
      return (l != null && l > 0) || engineSec > 0 || cons > 0;
    }).toList();

    if (fuelRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No LPH rate records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Sort by LPH ascending (lower burn rate = more efficient)
    final List<ReportRow> sortedRows = List<ReportRow>.from(fuelRows)
      ..sort((ReportRow a, ReportRow b) {
        final double la = a.lph ??
            (a.raw['lph'] != null ? (a.raw['lph'] as num).toDouble() : 9999.0);
        final double lb = b.lph ??
            (b.raw['lph'] != null ? (b.raw['lph'] as num).toDouble() : 9999.0);
        return la.compareTo(lb);
      });

    // Compute fleet average LPH
    double sumLph = 0.0;
    int validCount = 0;
    for (final ReportRow r in sortedRows) {
      final double? l = r.lph ??
          (r.raw['lph'] != null ? (r.raw['lph'] as num).toDouble() : null);
      if (l != null && l > 0) {
        sumLph += l;
        validCount++;
      }
    }
    final double fleetAvg = validCount > 0 ? (sumLph / validCount) : 0.0;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedRows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = sortedRows[index];
        final String? vId = r.vehicleId;
        final Vehicle? vehicle =
            vId != null ? vehicles.where((v) => v.id == vId).firstOrNull : null;
        final String vName = r.vehicleName ?? vehicle?.displayName ?? '-';
        final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';
        final double? lphVal = r.lph ??
            (r.raw['lph'] != null ? (r.raw['lph'] as num).toDouble() : null);
        final int engineSec = (r.runningSeconds ?? 0) +
            (r.idleSeconds ?? 0) +
            (r.raw['engine_on_seconds'] != null
                ? (r.raw['engine_on_seconds'] as num).toInt()
                : 0);
        final double consumed = r.consumption ??
            (r.raw['consumption'] != null
                ? (r.raw['consumption'] as num).toDouble()
                : 0.0);
        final int rank = index + 1;

        // Web Efficiency rating badge logic
        String ratingText = 'Standard';
        Color ratingBg = const Color(0xFFFEF3C7);
        Color ratingColor = const Color(0xFFD97706);

        if (lphVal != null && lphVal > 0 && fleetAvg > 0) {
          if (lphVal <= fleetAvg * 0.85) {
            ratingText = 'Economical';
            ratingBg = const Color(0xFFD1FAE5);
            ratingColor = const Color(0xFF059669);
          } else if (lphVal >= fleetAvg * 1.25) {
            ratingText = 'High Burn';
            ratingBg = const Color(0xFFFEE2E2);
            ratingColor = const Color(0xFFDC2626);
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFED7AA)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                // Rank Badge: 🌟 #1, #2, #3, #N
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: rank == 1
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      rank == 1 ? '🌟' : '#$rank',
                      style: TextStyle(
                        fontSize: rank == 1 ? 16 : 12,
                        fontWeight: FontWeight.w800,
                        color: rank == 1
                            ? const Color(0xFF047857)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Vehicle Info & Telematics Subtitle (Expanded - 0 Overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        vName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        vPlate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Fmt.secsToHms(engineSec)}  •  ${consumed.toStringAsFixed(1)} L',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Efficiency Rating Badge from Web App
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ratingBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ratingText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: ratingColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // LPH Metric Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        lphVal != null ? lphVal.toStringAsFixed(2) : '—',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const Text(
                        'L / hr',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 9. GENERIC REPORT TABLE (Fallback)
// ═════════════════════════════════════════════════════════════════
class GenericReportTable extends StatelessWidget {
  const GenericReportTable({required this.result, super.key});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    if (result.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<String> columns = result.columns;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: <int, TableColumnWidth>{
          for (int i = 0; i < columns.length; i++)
            i: const FixedColumnWidth(150),
        },
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children:
                columns.map((String col) => TableHeaderCell(col)).toList(),
          ),
          ...result.rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
            final int idx = entry.key;
            final ReportRow r = entry.value;
            final Color rowColor =
                idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

            return TableRow(
              decoration: BoxDecoration(color: rowColor),
              children: columns.map((String col) {
                return TableDataCell(text: r.cells[col] ?? '-');
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 10. GEOFENCE TRANSIT REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class GeofenceTransitReportTable extends StatelessWidget {
  const GeofenceTransitReportTable({
    required this.rows,
    this.showVehicle = true,
    super.key,
  });

  final List<ReportRow> rows;
  final bool showVehicle;

  Color _badgeColor(String? label) {
    final String l = (label ?? '').toLowerCase();
    if (l.contains('one-way') || l.contains('outbound') || l.contains('➔')) {
      return const Color(0xFF0D9488); // Teal
    }
    if (l.contains('return') || l.contains('two-way') || l.contains('⇄')) {
      return const Color(0xFF0284C7); // Sky blue
    }
    if (l.contains('round') || l.contains('full') || l.contains('same')) {
      return const Color(0xFFD97706); // Amber
    }
    return const Color(0xFF6366F1); // Indigo
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No transit records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = rows[index];
        final String tripLabel = r.tripLabel ??
            (r.fromGeofenceName != null && r.toGeofenceName != null
                ? '${r.fromGeofenceName} ➔ ${r.toGeofenceName}'
                : 'Corridor Transit');
        final Color pillColor = _badgeColor(tripLabel);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: pillColor.withOpacity( 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.sync_alt_rounded,
                                size: 14, color: pillColor),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  r.vehicleName ?? r.plate ?? 'Vehicle',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (r.plate != null &&
                                    r.vehicleName != null &&
                                    r.plate != r.vehicleName)
                                  Text(
                                    r.plate!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Direction badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: pillColor.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: pillColor.withOpacity( 0.3), width: 1),
                      ),
                      child: Text(
                        tripLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pillColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Corridor Origin & Destination Points
                _buildGeofencePoint(
                  badge: 'A',
                  badgeColor: const Color(0xFF10B981),
                  title: r.fromGeofenceName ?? 'Origin Geofence',
                  subtitle:
                      'Departed: ${Fmt.dateTimeWeb(r.departureTime ?? r.startTime)}',
                  icon: Icons.exit_to_app_rounded,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(
                        height: 16,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1.5,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          r.durationFormatted ??
                              (r.durationSecVal != null
                                  ? Fmt.durationWeb(r.durationSecVal)
                                  : 'Transit'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildGeofencePoint(
                  badge: 'B',
                  badgeColor: const Color(0xFF0284C7),
                  title: r.toGeofenceName ?? 'Destination Geofence',
                  subtitle:
                      'Arrived: ${Fmt.dateTimeWeb(r.arrivalTime ?? r.endTime)}',
                  icon: Icons.login_rounded,
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat(
                      label: 'DISTANCE',
                      value: r.distanceTravelled != null
                          ? '${r.distanceTravelled!.toStringAsFixed(r.distanceTravelled! < 10 ? 1 : 0)} km'
                          : '-',
                    ),
                    _buildStat(
                      label: 'DURATION',
                      value: r.durationFormatted ??
                          (r.durationSecVal != null
                              ? Fmt.durationWeb(r.durationSecVal)
                              : '-'),
                    ),
                    _buildStat(
                      label: 'AVG SPEED',
                      value: r.avgSpeedVal != null
                          ? '${r.avgSpeedVal!.round()} km/h'
                          : (r.speed != null
                              ? '${r.speed!.round()} km/h'
                              : '-'),
                    ),
                    _buildStat(
                      label: 'MAX SPEED',
                      value: r.maxSpeedVal != null
                          ? '${r.maxSpeedVal!.round()} km/h'
                          : '-',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeofencePoint({
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 11. GEOFENCE SINGLE PLACE ACTIVITY REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class GeofenceSinglePlaceReportTable extends StatelessWidget {
  const GeofenceSinglePlaceReportTable({
    required this.rows,
    this.showVehicle = true,
    super.key,
  });

  final List<ReportRow> rows;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No place activity records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = rows[index];
        final String placeName =
            r.geofenceName ?? r.address ?? 'Geofenced Zone';
        final bool isStillInside = r.exitTime == null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.fmd_good_rounded,
                                size: 14, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  r.vehicleName ?? r.plate ?? 'Vehicle',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (r.plate != null &&
                                    r.vehicleName != null &&
                                    r.plate != r.vehicleName)
                                  Text(
                                    r.plate!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.place_rounded,
                              size: 11, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(
                            placeName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Entry / Exit timeline
                _buildEventRow(
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Entry Time',
                  time: Fmt.dateTimeWeb(r.entryTime ?? r.startTime),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 10, top: 2, bottom: 2),
                  child: SizedBox(
                    height: 12,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1.5,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                _buildEventRow(
                  icon: Icons.logout_rounded,
                  iconColor: isStillInside
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
                  label: 'Exit Time',
                  time: isStillInside
                      ? 'Currently Inside (Ongoing)'
                      : Fmt.dateTimeWeb(r.exitTime),
                  isSpecial: isStillInside,
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat(
                      label: 'STAY DURATION',
                      value: r.durationFormatted ??
                          (r.durationSecVal != null
                              ? Fmt.durationWeb(r.durationSecVal)
                              : '-'),
                    ),
                    _buildStat(
                      label: 'IDLE INSIDE',
                      value: r.idleSecondsInside != null &&
                              r.idleSecondsInside! > 0
                          ? Fmt.durationWeb(r.idleSecondsInside)
                          : '0m',
                    ),
                    _buildStat(
                      label: 'MAX SPEED INSIDE',
                      value: r.maxSpeedVal != null
                          ? '${r.maxSpeedVal!.round()} km/h'
                          : '-',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
    bool isSpecial = false,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color:
                isSpecial ? const Color(0xFFD97706) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 12. FULL DAY TRIP REPORT TABLE (Consolidated Journey)
// ═════════════════════════════════════════════════════════════════
class DailyTripReportTable extends StatefulWidget {
  const DailyTripReportTable({
    required this.rows,
    this.showVehicle = true,
    super.key,
  });

  final List<ReportRow> rows;
  final bool showVehicle;

  @override
  State<DailyTripReportTable> createState() => _DailyTripReportTableState();
}

class _DailyTripReportTableState extends State<DailyTripReportTable> {
  final Set<int> _expandedIndices = <int>{};

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No full day trip records found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.rows.length,
      itemBuilder: (BuildContext context, int index) {
        final ReportRow r = widget.rows[index];
        final bool isExpanded = _expandedIndices.contains(index);
        final List<Map<String, dynamic>> legs = r.legs;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.route_rounded,
                                size: 14, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  r.vehicleName ?? r.plate ?? 'Vehicle',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  Fmt.dateWeb(r.date ?? r.startTime),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Distance pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        '${(r.totalDistanceVal ?? r.distanceTravelled ?? 0).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Departure & Arrival Timeline
                _buildTimelinePoint(
                  badge: 'Start',
                  badgeColor: const Color(0xFF10B981),
                  title: 'First Departure: ${Fmt.dateTimeWeb(r.startTime)}',
                  lat: r.startLat,
                  lng: r.startLng,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(
                        height: 16,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1.5,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Total Span: ${Fmt.durationWeb(r.totalSpanSeconds ?? r.durationSecVal)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTimelinePoint(
                  badge: 'End',
                  badgeColor: const Color(0xFF0284C7),
                  title: 'Final Arrival: ${Fmt.dateTimeWeb(r.endTime)}',
                  lat: r.endLat,
                  lng: r.endLng,
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Metrics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildStat(
                      label: 'DRIVING TIME',
                      value:
                          Fmt.durationWeb(r.drivingSeconds ?? r.runningSeconds),
                    ),
                    _buildStat(
                      label: 'STOPPAGE TIME',
                      value: Fmt.durationWeb(
                        (r.stoppedSeconds != null && r.stoppedSeconds! > 0)
                            ? r.stoppedSeconds
                            : ((r.totalSpanSeconds != null &&
                                    (r.drivingSeconds ?? r.runningSeconds) !=
                                        null &&
                                    r.totalSpanSeconds! >
                                        (r.drivingSeconds ?? r.runningSeconds)!)
                                ? (r.totalSpanSeconds! -
                                    (r.drivingSeconds ?? r.runningSeconds)!)
                                : r.stoppedSeconds),
                      ),
                    ),
                    _buildStat(
                      label: 'STOPS',
                      value: '${r.stopsCount}',
                    ),
                    _buildStat(
                      label: 'MAX SPEED',
                      value: r.maxSpeedVal != null
                          ? '${r.maxSpeedVal!.round()} km/h'
                          : '-',
                    ),
                    _buildStat(
                      label: 'AVG SPEED',
                      value: r.avgSpeedVal != null
                          ? '${r.avgSpeedVal!.round()} km/h'
                          : '-',
                    ),
                  ],
                ),

                // Expandable intermediate legs
                if (legs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedIndices.remove(index);
                        } else {
                          _expandedIndices.add(index);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            isExpanded
                                ? 'Hide Intermediate Legs (${legs.length})'
                                : 'View Intermediate Legs (${legs.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: legs.asMap().entries.map((entry) {
                          final int legIdx = entry.key;
                          final Map<String, dynamic> leg = entry.value;
                          final double? legDist = asDoubleOrNull(
                              leg, <String>['distance', 'distance_travelled']);
                          final int? legDur = asDoubleOrNull(
                                  leg, <String>['duration_seconds', 'duration'])
                              ?.round();
                          final DateTime? legStart =
                              asDate(leg, <String>['start_time']);
                          final DateTime? legEnd =
                              asDate(leg, <String>['end_time']);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${legIdx + 1}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${Fmt.time(legStart)} → ${Fmt.time(legEnd)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155)),
                                  ),
                                ),
                                Text(
                                  '${legDist?.toStringAsFixed(1) ?? '0'} km • ${Fmt.durationWeb(legDur)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelinePoint({
    required String badge,
    required Color badgeColor,
    required String title,
    required double? lat,
    required double? lng,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              AddressCell(
                lat: lat,
                lng: lng,
                maxWidth: double.infinity,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// 13. IGNITION REPORT TABLE (Engine On / Off Events)
// ═════════════════════════════════════════════════════════════════
class IgnitionReportTable extends StatelessWidget {
  const IgnitionReportTable({
    required this.rows,
    this.showVehicle = true,
    super.key,
  });

  final List<ReportRow> rows;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No ignition events found matching your criteria.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final List<EngineCycle> cycles = parseEngineCycles(rows);
    final int totalSeconds = cycles.fold<int>(
        0, (int sum, EngineCycle c) => sum + c.durationSeconds);

    final String vName =
        rows.first.vehicleName ?? rows.first.plate ?? 'Vehicle';
    final String plate = rows.first.plate ?? '';
    final String vehicleTitle = plate.isNotEmpty && plate != vName
        ? '$vName $plate'.toUpperCase()
        : vName.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Subheader matching screenshot: Vehicle on left, Total Duration on right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  vehicleTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Total Duration',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.secsToHms(totalSeconds),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        EngineOnTableView(cycles: cycles),
      ],
    );
  }
}


// ═════════════════════════════════════════════════════════════════
// 18. NON-SENSOR FUEL REPORT TABLE (Manual Telematics & Analytics)
// ═════════════════════════════════════════════════════════════════
// NON-SENSOR FUEL REPORT TABLE (Backed by Fuel Overview API)
// ═════════════════════════════════════════════════════════════════
class NonSensorFuelReportTable extends StatefulWidget {
  const NonSensorFuelReportTable({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.vehicles,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final List<Vehicle> vehicles;

  @override
  State<NonSensorFuelReportTable> createState() => _NonSensorFuelReportTableState();
}

class _NonSensorFuelReportTableState extends State<NonSensorFuelReportTable> {
  String _selectedFilter = 'ALL';

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No entry yet';
    final String d = dt.day.toString().padLeft(2, '0');
    final String m = dt.month.toString().padLeft(2, '0');
    final String y = dt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F3FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_gas_station_rounded,
                  size: 40,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Non-Sensor Fuel Records Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Configure baseline fuel setup or log fuel refills for your non-sensor vehicles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Calculate Fleet Totals for Overview Summary Cards
    double totalEstimatedFuel = 0.0;
    double totalGpsDistance = 0.0;
    double totalEstimatedConsumption = 0.0;
    int normalCount = 0;
    int lowCount = 0;
    int criticalCount = 0;
    int noDataCount = 0;

    for (final ReportRow r in widget.rows) {
      final double? fuel = r.currentFuel;
      if (fuel != null) {
        totalEstimatedFuel += fuel;
      }
      final double dist = r.distanceFromEntered ?? 0.0;
      totalGpsDistance += dist;

      final double consumed = r.fuelUsedVal ?? 0.0;
      totalEstimatedConsumption += consumed;

      final String s = (r.fuelStatusVal ?? '').toLowerCase();
      if (s.contains('critical')) {
        criticalCount++;
      } else if (s.contains('low')) {
        lowCount++;
      } else if (s.contains('healthy') || s.contains('normal')) {
        normalCount++;
      } else {
        noDataCount++;
      }
    }

    // 2. Filter Rows based on selected pill
    final List<ReportRow> filteredRows = widget.rows.where((ReportRow r) {
      if (_selectedFilter == 'ALL') return true;
      final String s = (r.fuelStatusVal ?? '').toLowerCase();
      if (_selectedFilter == 'Normal') {
        return s.contains('healthy') || s.contains('normal');
      }
      if (_selectedFilter == 'Low Fuel') {
        return s.contains('low');
      }
      if (_selectedFilter == 'Critical Fuel') {
        return s.contains('critical');
      }
      if (_selectedFilter == 'No Fuel Data') {
        return s.contains('no fuel') || s.contains('unconfigured') || r.currentFuel == null;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header Notice Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFFD97706),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text(
                      'Manual Fuel Monitoring & Mileage Prediction',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fuel values are estimated based on driver manual entries and GPS distance calculation (physical fuel sensors not installed).',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 4 Overview Summary Cards
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewSummaryCard(
                title: 'TOTAL ESTIMATED FUEL',
                value: '${totalEstimatedFuel % 1 == 0 ? totalEstimatedFuel.toStringAsFixed(0) : totalEstimatedFuel.toStringAsFixed(1)} Litres',
                subtitle: 'Remaining in fleet tanks',
                icon: Icons.local_gas_station_rounded,
                color: const Color(0xFFEA580C),
                bg: const Color(0xFFFFF7ED),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewSummaryCard(
                title: 'GPS DISTANCE TRACKED',
                value: '${totalGpsDistance.round()} KM',
                subtitle: 'Total fleet distance tracked',
                icon: Icons.near_me_rounded,
                color: const Color(0xFF0284C7),
                bg: const Color(0xFFF0F9FF),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _OverviewSummaryCard(
                title: 'ESTIMATED CONSUMPTION',
                value: '${totalEstimatedConsumption % 1 == 0 ? totalEstimatedConsumption.toStringAsFixed(0) : totalEstimatedConsumption.toStringAsFixed(1)} Litres',
                subtitle: 'Estimated fuel consumed',
                icon: Icons.water_drop_rounded,
                color: const Color(0xFF7C3AED),
                bg: const Color(0xFFFAF5FF),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewSummaryCard(
                title: 'FLEET FUEL STATUS',
                value: '$normalCount Normal',
                subtitle: '$lowCount Low Fuel • $criticalCount Critical',
                icon: Icons.speed_rounded,
                color: const Color(0xFFE11D48),
                bg: const Color(0xFFFFF1F2),
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _FilterChip(
                label: 'ALL (${widget.rows.length})',
                isSelected: _selectedFilter == 'ALL',
                onTap: () => setState(() => _selectedFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Normal ($normalCount)',
                isSelected: _selectedFilter == 'Normal',
                onTap: () => setState(() => _selectedFilter = 'Normal'),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Low Fuel ($lowCount)',
                isSelected: _selectedFilter == 'Low Fuel',
                onTap: () => setState(() => _selectedFilter = 'Low Fuel'),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Critical Fuel ($criticalCount)',
                isSelected: _selectedFilter == 'Critical Fuel',
                onTap: () => setState(() => _selectedFilter = 'Critical Fuel'),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'No Fuel Data ($noDataCount)',
                isSelected: _selectedFilter == 'No Fuel Data',
                onTap: () => setState(() => _selectedFilter = 'No Fuel Data'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Vehicle Cards List
        if (filteredRows.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              'No vehicles found matching "$_selectedFilter"',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredRows.length,
            itemBuilder: (BuildContext context, int index) {
              final ReportRow r = filteredRows[index];
              final String? vId = r.vehicleId;
              final Vehicle? vehicle =
                  vId != null ? widget.vehicles.where((v) => v.id == vId).firstOrNull : null;
              final String vName = r.vehicleName ?? vehicle?.displayName ?? 'Vehicle';
              final String vPlate = r.plate ?? vehicle?.registrationNumber ?? '-';

              final double? currentFuel = r.currentFuel;
              final double fuelUsed = r.fuelUsedVal ?? 0.0;
              final double distanceTracked = r.distanceFromEntered ?? 0.0;
              final double mileage = r.averageMileageVal ?? 16.0;
              final double range = r.estimatedRangeVal ??
                  ((currentFuel != null ? currentFuel : 0.0) * mileage);
              final double? tankCap = r.tankCapacityVal;
              final String fuelType = r.fuelTypeVal ?? 'Diesel';
              final String status = r.fuelStatusVal ?? 'Normal';
              final bool isUnconfigured =
                  currentFuel == null || status.toLowerCase().contains('no fuel');

              final Color statusColor = switch (status.toLowerCase()) {
                'healthy' || 'normal' => const Color(0xFF059669),
                'critical fuel' || 'critical' => const Color(0xFFE11D48),
                'low fuel' || 'low' => const Color(0xFFD97706),
                'no fuel data' || 'unconfigured' => const Color(0xFF64748B),
                _ => const Color(0xFF0284C7),
              };

              final Color statusBg = switch (status.toLowerCase()) {
                'healthy' || 'normal' => const Color(0xFFECFDF5),
                'critical fuel' || 'critical' => const Color(0xFFFFE4E6),
                'low fuel' || 'low' => const Color(0xFFFEF3C7),
                'no fuel data' || 'unconfigured' => const Color(0xFFF1F5F9),
                _ => const Color(0xFFEFF6FF),
              };

              // Determine Last Refill / Entry string
              final String lastRefillOrEntry = () {
                if (r.lastRefillDate != null) {
                  return 'Refill: ${_formatDate(r.lastRefillDate)}';
                }
                if (r.lastEntryDate != null) {
                  return 'Entry: ${_formatDate(r.lastEntryDate)}';
                }
                final DateTime? rawEntry = asDate(r.raw, const <String>['last_refill_date', 'last_entry_date', 'entry_time', 'time']);
                if (rawEntry != null) {
                  return 'Entry: ${_formatDate(rawEntry)}';
                }
                return 'No entry yet';
              }();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Header: Vehicle info + Tank info + Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isUnconfigured
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.local_gas_station_rounded,
                              color: isUnconfigured
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF7C3AED),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  vName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      vPlate,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    if (tankCap != null && tankCap > 0) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${tankCap.toStringAsFixed(0)}L $fuelType',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(height: 12),

                      // If unconfigured (like TEST_EC33) -> Show Unconfigured Banner
                      if (isUnconfigured)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.settings_suggest_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Unconfigured (No fuel baseline entry yet)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...<Widget>[
                        // 4 Requested Metrics Grid
                        Row(
                          children: <Widget>[
                            // 1. Non-Sensor Fuel
                            Expanded(
                              child: _MetricBadge(
                                label: 'Non-Sensor Fuel',
                                value: tankCap != null && tankCap > 0
                                    ? '${currentFuel!.toStringAsFixed(1)} L (${((currentFuel! / tankCap) * 100).round()}%)'
                                    : '${currentFuel!.toStringAsFixed(1)} L',
                                icon: Icons.local_gas_station_rounded,
                                color: const Color(0xFF0284C7), // Blue
                                bg: const Color(0xFFF0F9FF),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 2. Fuel Used (Estimated Consumption)
                            Expanded(
                              child: _MetricBadge(
                                label: 'Fuel Used',
                                value: '${fuelUsed % 1 == 0 ? fuelUsed.toStringAsFixed(0) : fuelUsed.toStringAsFixed(1)} L',
                                icon: Icons.water_drop_rounded,
                                color: const Color(0xFFD97706), // Amber
                                bg: const Color(0xFFFFFBEB),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            // 3. Distance from entered
                            Expanded(
                              child: _MetricBadge(
                                label: 'Dist. from entered',
                                value: '${distanceTracked.toStringAsFixed(1)} km',
                                icon: Icons.near_me_rounded,
                                color: const Color(0xFF059669), // Emerald
                                bg: const Color(0xFFECFDF5),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 4. Range
                            Expanded(
                              child: _MetricBadge(
                                label: 'Range',
                                value: '~ ${range.round()} km',
                                icon: Icons.speed_rounded,
                                color: const Color(0xFF0D9488), // Teal
                                bg: const Color(0xFFF0FDFA),
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 5. Average Mileage (Full Width Banner)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE9D5FF)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Row(
                                children: <Widget>[
                                  Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF7C3AED)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Average Mileage',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF581C87),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${mileage.toStringAsFixed(1)} km/l',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6B21A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Footer: Last Refill / Entry & Driver
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.history_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  lastRefillOrEntry,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            if (r.lastDriverName != null && r.lastDriverName!.isNotEmpty)
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    r.lastDriverName!,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _OverviewSummaryCard extends StatelessWidget {
  const _OverviewSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bg,
    required this.isDark,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
