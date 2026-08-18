import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';
import '../../../data/models/report_models.dart';

/// Async cell that fetches and displays the reverse-geocoded address.
class AddressCell extends StatefulWidget {
  const AddressCell({
    this.lat,
    this.lng,
    this.fallback,
    this.maxWidth = 240,
    super.key,
  });

  final double? lat;
  final double? lng;
  final String? fallback;
  final double maxWidth;

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
    if (widget.fallback != null && widget.fallback!.trim().isNotEmpty) {
      _address = widget.fallback;
      return;
    }
    if (widget.lat != null && widget.lng != null) {
      _loading = true;
      Geocoder.getAddress(widget.lat!, widget.lng!).then((String addr) {
        if (mounted) {
          setState(() {
            _address = addr;
            _loading = false;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _address = 'Location unavailable';
            _loading = false;
          });
        }
      });
    } else {
      _address = 'Location unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _address == null) {
      return Container(
        width: widget.maxWidth,
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

    return Container(
      width: widget.maxWidth,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        _address ?? 'Location unavailable',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF334155),
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
  const TripReportTable({required this.rows, super.key});

  final List<ReportRow> rows;

  @override
  Widget build(BuildContext context) {
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
          columnWidths: const <int, TableColumnWidth>{
            0: FixedColumnWidth(170), // START TIME
            1: FixedColumnWidth(230), // START ADDRESS
            2: FixedColumnWidth(170), // END TIME
            3: FixedColumnWidth(230), // END ADDRESS
            4: FixedColumnWidth(160), // DURATION (HH:MM:SS)
            5: FixedColumnWidth(110), // DISTANCE
            6: FixedColumnWidth(110), // MAX SPEED
            7: FixedColumnWidth(110), // AVG SPEED
          },
          children: <TableRow>[
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
              children: <Widget>[
                TableHeaderCell('START TIME'),
                TableHeaderCell('START ADDRESS'),
                TableHeaderCell('END TIME'),
                TableHeaderCell('END ADDRESS'),
                TableHeaderCell('DURATION (HH:MM:SS)'),
                TableHeaderCell('DISTANCE', align: TextAlign.right),
                TableHeaderCell('MAX SPEED', align: TextAlign.right),
                TableHeaderCell('AVG SPEED', align: TextAlign.right),
              ],
            ),
            ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
              final int idx = entry.key;
              final ReportRow r = entry.value;
              final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

              return TableRow(
                decoration: BoxDecoration(color: rowColor),
                children: <Widget>[
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
                    child: AddressCell(
                      lat: r.startLat,
                      lng: r.startLng,
                      fallback: r.address,
                      maxWidth: 220,
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
                    child: AddressCell(
                      lat: r.endLat,
                      lng: r.endLng,
                      maxWidth: 220,
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
                        ? r.distanceTravelled!.toStringAsFixed(r.distanceTravelled! < 10 ? 1 : 0)
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
                    text: r.maxSpeedVal != null ? r.maxSpeedVal!.round().toString() : '-',
                    align: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TableDataCell(
                    text: r.avgSpeedVal != null ? r.avgSpeedVal!.round().toString() : '-',
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
// 1b. MANUAL TRIP REPORT TABLE
// ═════════════════════════════════════════════════════════════════
class ManualTripReportTable extends StatelessWidget {
  const ManualTripReportTable({required this.rows, super.key});

  final List<ReportRow> rows;

  @override
  Widget build(BuildContext context) {
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
          columnWidths: const <int, TableColumnWidth>{
            0: FixedColumnWidth(140), // STATUS
            1: FixedColumnWidth(160), // TRIP NAME
            2: FixedColumnWidth(150), // START TIME
            3: FixedColumnWidth(200), // ORIGIN / START ADDR
            4: FixedColumnWidth(150), // END TIME
            5: FixedColumnWidth(200), // DESTINATION / END ADDR
            6: FixedColumnWidth(160), // DURATION
            7: FixedColumnWidth(100), // DISTANCE
            8: FixedColumnWidth(100), // MAX SPEED
          },
          children: <TableRow>[
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
              children: <Widget>[
                TableHeaderCell('STATUS'),
                TableHeaderCell('TRIP NAME'),
                TableHeaderCell('START TIME'),
                TableHeaderCell('START / ORIGIN'),
                TableHeaderCell('END TIME'),
                TableHeaderCell('END / DESTINATION'),
                TableHeaderCell('DURATION (HH:MM:SS)'),
                TableHeaderCell('DISTANCE', align: TextAlign.right),
                TableHeaderCell('MAX SPEED', align: TextAlign.right),
              ],
            ),
            ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
              final int idx = entry.key;
              final ReportRow r = entry.value;
              final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

              final String tripName = r.raw['name']?.toString() ?? '-';
              final String originStr = r.raw['origin']?.toString() ?? '';
              final String destStr = r.raw['destination']?.toString() ?? '';
              
              final String statusStr = (r.status ?? 'unknown').toUpperCase();
              Color statusColor = const Color(0xFF64748B);
              if (statusStr == 'COMPLETED') statusColor = const Color(0xFF10B981);
              if (statusStr == 'IN_PROGRESS') statusColor = const Color(0xFF3B82F6);
              if (statusStr == 'CANCELLED') statusColor = const Color(0xFFEF4444);

              return TableRow(
                decoration: BoxDecoration(color: rowColor),
                children: <Widget>[
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
                        ? Text(originStr, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))
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
                        ? Text(destStr, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))
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
                        ? r.distanceTravelled!.toStringAsFixed(r.distanceTravelled! < 10 ? 1 : 0)
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
                    text: r.maxSpeedVal != null ? r.maxSpeedVal!.round().toString() : '-',
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(150), // VEHICLE NAME
          1: FixedColumnWidth(130), // PLATE
          2: FixedColumnWidth(120), // ORG
          3: FixedColumnWidth(120), // DATE
          4: FixedColumnWidth(140), // START ODOMETER
          5: FixedColumnWidth(140), // END ODOMETER
          6: FixedColumnWidth(170), // DISTANCE TRAVELLED (KM)
          7: FixedColumnWidth(130), // POINTS LOGGED
        },
        children: <TableRow>[
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
            children: <Widget>[
              TableHeaderCell('VEHICLE NAME'),
              TableHeaderCell('PLATE'),
              TableHeaderCell('ORG'),
              TableHeaderCell('DATE'),
              TableHeaderCell('START ODOMETER', align: TextAlign.right),
              TableHeaderCell('END ODOMETER', align: TextAlign.right),
              TableHeaderCell('DISTANCE TRAVELLED (KM)', align: TextAlign.center),
              TableHeaderCell('POINTS LOGGED', align: TextAlign.center),
            ],
          ),
          ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
            final int idx = entry.key;
            final ReportRow r = entry.value;
            final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

            return TableRow(
              decoration: BoxDecoration(color: rowColor),
              children: <Widget>[
                TableDataCell(
                  text: r.vehicleName ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TableDataCell(
                  text: r.plate ?? '-',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                TableDataCell(
                  text: r.orgName ?? 'FuelTracks',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                TableDataCell(
                  text: Fmt.dateWeb(r.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                TableDataCell(
                  text: r.startOdometer != null ? r.startOdometer!.round().toString() : '-',
                  align: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
                TableDataCell(
                  text: r.endOdometer != null ? r.endOdometer!.round().toString() : '-',
                  align: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
                TableDataCell(
                  text: '${r.distanceTravelled?.toStringAsFixed(0) ?? '0'} km',
                  align: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981), // Green highlight
                  ),
                ),
                TableDataCell(
                  text: r.pointCount > 0 ? r.pointCount.toString() : '-',
                  align: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF475569),
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
// 3. OVERSPEEDING REPORT TABLE (Grouped by Vehicle)
// ═════════════════════════════════════════════════════════════════
class OverspeedingReportTable extends StatelessWidget {
  const OverspeedingReportTable({
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
    // Group rows by vehicle
    final Map<String, List<ReportRow>> groups = <String, List<ReportRow>>{};
    for (final ReportRow r in rows) {
      final String vName = r.vehicleName ?? 'Unknown Vehicle';
      groups.putIfAbsent(vName, () => <ReportRow>[]).add(r);
    }

    return Column(
      children: groups.entries.map((MapEntry<String, List<ReportRow>> entry) {
        final String vehicleName = entry.key;
        final List<ReportRow> vehicleRows = entry.value;

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
              // Sub-header 4-column Info Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      'Vehicle Name : $vehicleName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'Speed Limit : 60',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Start Time : ${Fmt.dateWeb(startDate)} 00:00:00',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Text(
                      'End Time : ${Fmt.dateWeb(endDate)} 23:59:59',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Table for this Vehicle
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const <int, TableColumnWidth>{
                    0: FixedColumnWidth(170), // Date & Time
                    1: FixedColumnWidth(110), // OverSpeed
                    2: FixedColumnWidth(180), // OverSpeed Duration (HH:MM:SS)
                    3: FixedColumnWidth(130), // Driver Name
                    4: FixedColumnWidth(160), // Driver Mobile Number
                    5: FixedColumnWidth(240), // Nearest Location
                    6: FixedColumnWidth(160), // Distance Covered(KMS)
                  },
                  children: <TableRow>[
                    const TableRow(
                      decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: <Widget>[
                        TableHeaderCell('Date & Time'),
                        TableHeaderCell('OverSpeed', align: TextAlign.right),
                        TableHeaderCell('OverSpeed Duration (HH:MM:SS)'),
                        TableHeaderCell('Driver Name'),
                        TableHeaderCell('Driver Mobile Number'),
                        TableHeaderCell('Nearest Location'),
                        TableHeaderCell('Distance Covered(KMS)', align: TextAlign.right),
                      ],
                    ),
                    ...vehicleRows.asMap().entries.map((MapEntry<int, ReportRow> rowEntry) {
                      final int idx = rowEntry.key;
                      final ReportRow r = rowEntry.value;
                      final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

                      return TableRow(
                        decoration: BoxDecoration(color: rowColor),
                        children: <Widget>[
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
                            text: r.maxSpeedVal != null ? r.maxSpeedVal!.round().toString() : '-',
                            align: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TableDataCell(
                            text: Fmt.durationWeb(r.durationSecVal),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          TableDataCell(
                            text: r.driverName ?? '-',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                          TableDataCell(
                            text: r.driverPhone ?? '-',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                          TableDataCell(
                            child: AddressCell(
                              lat: r.startLat,
                              lng: r.startLng,
                              fallback: r.address,
                              maxWidth: 230,
                            ),
                          ),
                          TableDataCell(
                            text: r.distanceTravelled != null
                                ? r.distanceTravelled!.toStringAsFixed(2)
                                : '0.00',
                            align: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Color(0xFF334155),
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
          return !st.contains('mov') && !st.contains('run') && !st.contains('idle');
        }).toList();

        final List<ReportRow> tableRows = parkedRows.isNotEmpty ? parkedRows : vehicleAllRows;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      'Vehicle Name : $vehicleName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'From : ${Fmt.dateWeb(startDate)} 00:00:00 - To : ${Fmt.dateWeb(endDate)} 23:59:59',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Stats Duration Row (Moving | Parked | Idle)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _statBadge('Moving', Fmt.durationWeb(movingSec), const Color(0xFF10B981)),
                    _statBadge('Parked', Fmt.durationWeb(parkedSec), const Color(0xFFEA580C)),
                    _statBadge('Idle', Fmt.durationWeb(idleSec), const Color(0xFFD97706)),
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
                    4: FixedColumnWidth(260), // Location Details
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
                    ...tableRows.asMap().entries.map((MapEntry<int, ReportRow> rowEntry) {
                      final int idx = rowEntry.key;
                      final ReportRow r = rowEntry.value;
                      final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

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
                              maxWidth: 250,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label : ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
        ),
      ],
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

        final List<ReportRow> tableRows = idleRows.isNotEmpty ? idleRows : vehicleAllRows;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE4EF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: <Widget>[
                    Text(
                      'Vehicle Name : $vehicleName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'From : ${Fmt.dateWeb(startDate)} 00:00:00 - To : ${Fmt.dateWeb(endDate)} 23:59:59',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),

              // Summary Stats Duration Row (Moving | Parked | Idle)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _statBadge('Moving', Fmt.durationWeb(movingSec), const Color(0xFF10B981)),
                    _statBadge('Parked', Fmt.durationWeb(parkedSec), const Color(0xFFEA580C)),
                    _statBadge('Idle', Fmt.durationWeb(idleSec), const Color(0xFFD97706)),
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
                    4: FixedColumnWidth(260), // Location Details
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
                    ...tableRows.asMap().entries.map((MapEntry<int, ReportRow> rowEntry) {
                      final int idx = rowEntry.key;
                      final ReportRow r = rowEntry.value;
                      final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

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
                              maxWidth: 250,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label : ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
        ),
      ],
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
          0: FixedColumnWidth(150), // Vehicle Name
          1: FixedColumnWidth(120), // Plate
          2: FixedColumnWidth(140), // Total Distance
          3: FixedColumnWidth(140), // Running Time
          4: FixedColumnWidth(140), // Idle Time
          5: FixedColumnWidth(120), // Trip Count
          6: FixedColumnWidth(120), // Stoppages
          7: FixedColumnWidth(130), // Overspeeding
        },
        children: <TableRow>[
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
            children: <Widget>[
              TableHeaderCell('Vehicle Name'),
              TableHeaderCell('Plate'),
              TableHeaderCell('Total Distance'),
              TableHeaderCell('Running Time'),
              TableHeaderCell('Idle Time'),
              TableHeaderCell('Trip Count'),
              TableHeaderCell('Stoppages'),
              TableHeaderCell('Overspeeding'),
            ],
          ),
          ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
            final int idx = entry.key;
            final ReportRow r = entry.value;
            final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

            return TableRow(
              decoration: BoxDecoration(color: rowColor),
              children: <Widget>[
                TableDataCell(
                  text: r.vehicleName ?? fallbackVehicleName ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                TableDataCell(
                  text: r.plate ?? fallbackPlate ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
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
                  text: '${r.runningMins} mins',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                TableDataCell(
                  text: '${r.idleMins} mins',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
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
  const ConsolidatedReportTable({required this.rows, super.key});

  final List<ReportRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(150), // Vehicle Name
          1: FixedColumnWidth(120), // Plate
          2: FixedColumnWidth(140), // Total Distance
          3: FixedColumnWidth(150), // Running Time (mins)
          4: FixedColumnWidth(150), // Idle Time (mins)
          5: FixedColumnWidth(160), // Stopped Time (mins)
        },
        children: <TableRow>[
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
            children: <Widget>[
              TableHeaderCell('Vehicle Name'),
              TableHeaderCell('Plate'),
              TableHeaderCell('Total Distance'),
              TableHeaderCell('Running Time (mins)'),
              TableHeaderCell('Idle Time (mins)'),
              TableHeaderCell('Stopped Time (mins)'),
            ],
          ),
          ...rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
            final int idx = entry.key;
            final ReportRow r = entry.value;
            final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

            return TableRow(
              decoration: BoxDecoration(color: rowColor),
              children: <Widget>[
                TableDataCell(
                  text: r.vehicleName ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                TableDataCell(
                  text: r.plate ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
                TableDataCell(
                  text: r.distanceTravelled?.toStringAsFixed(0) ?? '0',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
                TableDataCell(
                  text: r.runningMins.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                TableDataCell(
                  text: r.idleMins.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                TableDataCell(
                  text: r.stoppedMins.toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
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
// 8. GENERIC REPORT TABLE (Fallback)
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
          for (int i = 0; i < columns.length; i++) i: const FixedColumnWidth(150),
        },
        children: <TableRow>[
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: columns.map((String col) => TableHeaderCell(col)).toList(),
          ),
          ...result.rows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
            final int idx = entry.key;
            final ReportRow r = entry.value;
            final Color rowColor = idx.isEven ? Colors.white : const Color(0xFFFAFAFA);

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

