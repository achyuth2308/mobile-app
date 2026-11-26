import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows the custom Report Date & Time Picker Dialog matching the reference design.
/// - Top banner colored with the report's specific color (`primaryColor`).
/// - Calendar selection limited to:
///     - No future dates/next months (`lastDate: now`).
///     - Maximum 1 year past (`firstDate: now - 365 days`).
/// - Circular Green checkmark to apply, Red X to cancel.
Future<void> showReportDatePickerDialog({
  required BuildContext context,
  required String title,
  required Color primaryColor,
  required DateTime initialStart,
  required DateTime initialEnd,
  required void Function(DateTime start, DateTime end) onApply,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) => ReportDatePickerDialog(
      title: title,
      primaryColor: primaryColor,
      initialStart: initialStart,
      initialEnd: initialEnd,
      onApply: onApply,
    ),
  );
}

class ReportDatePickerDialog extends StatefulWidget {
  const ReportDatePickerDialog({
    required this.title,
    required this.primaryColor,
    required this.initialStart,
    required this.initialEnd,
    required this.onApply,
    super.key,
  });

  final String title;
  final Color primaryColor;
  final DateTime initialStart;
  final DateTime initialEnd;
  final void Function(DateTime start, DateTime end) onApply;

  @override
  State<ReportDatePickerDialog> createState() => _ReportDatePickerDialogState();
}

class _ReportDatePickerDialogState extends State<ReportDatePickerDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(
      widget.initialStart.year,
      widget.initialStart.month,
      widget.initialStart.day,
    );
    _endDate = DateTime(
      widget.initialEnd.year,
      widget.initialEnd.month,
      widget.initialEnd.day,
    );
    _startTime = TimeOfDay(
      hour: widget.initialStart.hour,
      minute: widget.initialStart.minute,
    );
    _endTime = TimeOfDay(
      hour: widget.initialEnd.hour,
      minute: widget.initialEnd.minute,
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime maxDate = DateTime(now.year, now.month, now.day);
    final DateTime minDate = DateTime(now.year - 1, now.month, now.day);

    final DateTime current = isStart ? _startDate : _endDate;
    final DateTime initialDate = current.isAfter(maxDate)
        ? maxDate
        : (current.isBefore(minDate) ? minDate : current);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (BuildContext ctx, Widget? child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final TimeOfDay current = isStart ? _startTime : _endTime;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (BuildContext ctx, Widget? child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
              onPrimary: Colors.white,
              onSurface: const Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top Header Banner with specific Report Color ───────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: widget.primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Text(
                    widget.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),

                // ── Content Area ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // From Date & Time
                      const Text(
                        'From Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildPickerField(
                              text: DateFormat('dd/MM/yyyy').format(_startDate),
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildPickerField(
                              text:
                                  '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                              onTap: () => _pickTime(isStart: true),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // To Date & Time
                      const Text(
                        'To Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildPickerField(
                              text: DateFormat('dd/MM/yyyy').format(_endDate),
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: _buildPickerField(
                              text:
                                  '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                              onTap: () => _pickTime(isStart: false),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ── Bottom Action Buttons (Green Check & Red Cross) ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Green Checkmark Button
                          InkWell(
                            onTap: () {
                              final DateTime s = DateTime(
                                _startDate.year,
                                _startDate.month,
                                _startDate.day,
                                _startTime.hour,
                                _startTime.minute,
                              );
                              final DateTime e = DateTime(
                                _endDate.year,
                                _endDate.month,
                                _endDate.day,
                                _endTime.hour,
                                _endTime.minute,
                              );
                              Navigator.of(context).pop();
                              widget.onApply(s, e);
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF22C55E),
                                  width: 2.2,
                                ),
                                color: Colors.white,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF22C55E),
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Red Cross Button
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFEF4444),
                                  width: 2.2,
                                ),
                                color: Colors.white,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFEF4444),
                                size: 30,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildPickerField({
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Container(
            height: 1.2,
            color: const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }
}
