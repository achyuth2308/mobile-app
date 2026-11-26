import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';
import '../../../data/models/report_models.dart';

/// Card-based interactive report view for Idle and Stoppage reports.
/// Matches the mobile reference designs:
/// - Screen 1: Vehicle summary cards (Idle: Amber/Yellow, Stoppage: Slate/Gray)
/// - Screen 2: Detailed list of individual event cards (no map) upon tapping a vehicle card.
class EventCardReportView extends StatefulWidget {
  const EventCardReportView({
    required this.rows,
    required this.startDate,
    required this.endDate,
    required this.isIdle,
    super.key,
  });

  final List<ReportRow> rows;
  final DateTime startDate;
  final DateTime endDate;
  final bool isIdle;

  @override
  State<EventCardReportView> createState() => _EventCardReportViewState();
}

class _EventCardReportViewState extends State<EventCardReportView> {
  String? _selectedVehicle;

  // Theming
  Color get _accentColor =>
      widget.isIdle ? const Color(0xFFD97706) : const Color(0xFF475569);
  Color get _badgeBg =>
      widget.isIdle ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9);
  Color get _badgeBorder =>
      widget.isIdle ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0);
  Color get _iconCircleBg =>
      widget.isIdle ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9);
  String get _tag => widget.isIdle ? 'Idle' : 'Stoppage';

  String _formatDurationH(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00 h';
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final String hStr = hours.toString().padLeft(2, '0');
    final String mStr = minutes.toString().padLeft(2, '0');
    return '$hStr:$mStr h';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd-MM-yyyy hh:mm a').format(dt).toLowerCase();
  }

  int _getRowDuration(ReportRow r) {
    int dur = r.durationSecVal ?? 0;
    if (dur <= 0 && r.startTime != null && r.endTime != null) {
      dur = r.endTime!.difference(r.startTime!).inSeconds.abs();
    }
    return dur;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // Group rows by vehicle
    final Map<String, List<ReportRow>> groups = <String, List<ReportRow>>{};
    for (final ReportRow r in widget.rows) {
      final String vName = r.vehicleName ?? r.plate ?? 'Unknown Vehicle';
      groups.putIfAbsent(vName, () => <ReportRow>[]).add(r);
    }

    // Filter events if needed: vehicles with 0 duration or no matching events are excluded
    final Map<String, List<ReportRow>> filteredGroups = <String, List<ReportRow>>{};
    groups.forEach((String key, List<ReportRow> list) {
      final List<ReportRow> matched = list.where((ReportRow r) {
        final int dur = _getRowDuration(r);
        if (dur <= 0) return false;
        if (widget.isIdle) {
          final String st = (r.status ?? '').toLowerCase();
          return st.isEmpty || st.contains('idle');
        } else {
          final String st = (r.status ?? '').toLowerCase();
          return st.isEmpty || (!st.contains('mov') && !st.contains('run') && !st.contains('idle'));
        }
      }).toList();

      final int totalDur = matched.fold<int>(
        0,
        (int sum, ReportRow r) => sum + _getRowDuration(r),
      );
      if (matched.isNotEmpty && totalDur > 0) {
        filteredGroups[key] = matched;
      }
    });

    // If no vehicles have valid duration events, show clean empty state
    if (filteredGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isIdle
                      ? Icons.hourglass_disabled_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 36,
                  color: _accentColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No ${widget.isIdle ? 'Idle' : 'Stoppage'} Records',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Vehicles with zero ${widget.isIdle ? 'idle' : 'stoppage'} duration are excluded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If user clicked a vehicle card, render View 2 (Event Details List)
    if (_selectedVehicle != null) {
      final List<ReportRow> vehicleRows = filteredGroups[_selectedVehicle] ?? <ReportRow>[];
      return _buildVehicleDetailView(context, isDark, _selectedVehicle!, vehicleRows);
    }

    // Otherwise render View 1 (List of Vehicle Summary Cards)
    return _buildVehiclesSummaryView(context, isDark, filteredGroups);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 1: VEHICLE SUMMARY CARDS (IMAGE 1)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildVehiclesSummaryView(
    BuildContext context,
    bool isDark,
    Map<String, List<ReportRow>> groups,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // List of Vehicle Cards
        ...groups.entries.map((MapEntry<String, List<ReportRow>> entry) {
          final String vehicleName = entry.key;
          final List<ReportRow> vehicleRows = entry.value;

          // Calculate total duration
          final int totalDuration = vehicleRows.fold<int>(
            0,
            (int sum, ReportRow r) => sum + _getRowDuration(r),
          );

          // Find longest event
          ReportRow longestRow = vehicleRows.first;
          int longestDuration = _getRowDuration(longestRow);
          for (final ReportRow r in vehicleRows) {
            final int d = _getRowDuration(r);
            if (d > longestDuration) {
              longestDuration = d;
              longestRow = r;
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _selectedVehicle = vehicleName;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Vehicle Name Pill & Chevron
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? _accentColor.withValues(alpha: 0.2)
                                    : _badgeBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? _accentColor.withValues(alpha: 0.35)
                                      : _badgeBorder,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                vehicleName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : _accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Metric Row: Counts & Total Duration
                      Row(
                        children: [
                          // Event count
                          Icon(
                            widget.isIdle
                                ? Icons.directions_car_rounded
                                : Icons.pause_circle_rounded,
                            size: 20,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${vehicleRows.length} $_tag(s)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : _accentColor,
                            ),
                          ),

                          const SizedBox(width: 24),

                          // Total duration
                          Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 20,
                            color: _accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDurationH(totalDuration),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : _accentColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      const SizedBox(height: 12),

                      // Longest Event Row
                      Row(
                        children: [
                          Icon(
                            Icons.watch_later_outlined,
                            size: 18,
                            color: isDark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Longest $_tag ',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _formatDurationH(longestDuration),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Address Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AddressText(
                              row: longestRow,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Time range
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          '${_formatDateTime(longestRow.startTime)} - ${_formatDateTime(longestRow.endTime)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 2: VEHICLE EVENT DETAILS LIST (IMAGE 2 - NO MAP)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildVehicleDetailView(
    BuildContext context,
    bool isDark,
    String vehicleName,
    List<ReportRow> vehicleRows,
  ) {
    final String datePillText = Fmt.dateWeb(widget.startDate) == Fmt.dateWeb(widget.endDate)
        ? Fmt.dateWeb(widget.startDate)
        : '${Fmt.dateWeb(widget.startDate)} - ${Fmt.dateWeb(widget.endDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Back Header
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                onPressed: () {
                  setState(() {
                    _selectedVehicle = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      datePillText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? _accentColor.withValues(alpha: 0.2)
                      : _badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${vehicleRows.length} $_tag(s)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of Events
        ...vehicleRows.asMap().entries.map((MapEntry<int, ReportRow> entry) {
          final int index = entry.key + 1;
          final ReportRow row = entry.value;
          final int rowDuration = _getRowDuration(row);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Header Row: Pill & Duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? _accentColor.withValues(alpha: 0.2)
                              : _badgeBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? _accentColor.withValues(alpha: 0.35)
                                : _badgeBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$_tag $index',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : _accentColor,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDurationH(rowDuration),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : _accentColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Location Row: Location Pin + Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AddressText(
                          row: row,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Start and End Timestamps Row
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      // Start time with red dot
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateTime(row.startTime),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),

                      // End time with green dot
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateTime(row.endTime),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AddressText extends StatefulWidget {
  const _AddressText({
    required this.row,
    required this.isDark,
  });

  final ReportRow row;
  final bool isDark;

  @override
  State<_AddressText> createState() => _AddressTextState();
}

class _AddressTextState extends State<_AddressText> {
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _fetchAddress();
  }

  void _fetchAddress() {
    final String? direct = widget.row.address;
    if (direct != null &&
        direct.trim().isNotEmpty &&
        direct != 'Location unavailable' &&
        !direct.startsWith('http')) {
      _resolvedAddress = direct;
      return;
    }

    final double? lat = widget.row.latitude ?? widget.row.startLat;
    final double? lng = widget.row.longitude ?? widget.row.startLng;
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      final String? cached = Geocoder.getCachedAddress(lat, lng);
      if (cached != null) {
        _resolvedAddress = cached;
        return;
      }
      Geocoder.getAddress(lat, lng).then((String addr) {
        if (mounted && addr.isNotEmpty) {
          setState(() {
            _resolvedAddress = addr;
          });
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = _resolvedAddress ??
        widget.row.address ??
        (widget.row.latitude != null && widget.row.longitude != null
            ? '${widget.row.latitude!.toStringAsFixed(5)}, ${widget.row.longitude!.toStringAsFixed(5)}'
            : 'Address unavailable');

    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: widget.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      ),
    );
  }
}
