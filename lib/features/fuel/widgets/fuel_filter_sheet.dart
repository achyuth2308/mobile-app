import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/fuel_service.dart';

class FuelFilterSheet extends StatefulWidget {
  const FuelFilterSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.initialInterval,
    required this.onApply,
    super.key,
  });

  final DateTime initialStart;
  final DateTime initialEnd;
  final FuelInterval initialInterval;
  final void Function(DateTime start, DateTime end, FuelInterval interval) onApply;

  static Future<void> show(
    BuildContext context, {
    required DateTime initialStart,
    required DateTime initialEnd,
    required FuelInterval initialInterval,
    required void Function(DateTime start, DateTime end, FuelInterval interval)
        onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => FuelFilterSheet(
        initialStart: initialStart,
        initialEnd: initialEnd,
        initialInterval: initialInterval,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FuelFilterSheet> createState() => _FuelFilterSheetState();
}

class _FuelFilterSheetState extends State<FuelFilterSheet> {
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  late FuelInterval _interval;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _startTime = TimeOfDay.fromDateTime(widget.initialStart);
    _endDate = widget.initialEnd;
    _endTime = TimeOfDay.fromDateTime(widget.initialEnd);
    _interval = widget.initialInterval;
  }

  void _applyQuickPreset(String preset) {
    final DateTime now = DateTime.now();
    switch (preset) {
      case 'today':
        setState(() {
          _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endDate = now;
          _endTime = TimeOfDay.fromDateTime(now);
        });
        break;
      case 'yesterday':
        final DateTime y = now.subtract(const Duration(days: 1));
        setState(() {
          _startDate = DateTime(y.year, y.month, y.day, 0, 0, 0);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
          _endTime = const TimeOfDay(hour: 23, minute: 59);
        });
        break;
      case 'week':
        final DateTime w = now.subtract(const Duration(days: 7));
        setState(() {
          _startDate = DateTime(w.year, w.month, w.day, 0, 0, 0);
          _startTime = const TimeOfDay(hour: 0, minute: 0);
          _endDate = now;
          _endTime = TimeOfDay.fromDateTime(now);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar matching Image 4
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Date & Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quick presets
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _presetChip('Today', 'today'),
                      const SizedBox(width: 8),
                      _presetChip('Yesterday', 'yesterday'),
                      const SizedBox(width: 8),
                      _presetChip('Last 7 Days', 'week'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Start & End Columns
                Row(
                  children: [
                    // Start Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Date box
                          _pickerBox(
                            DateFormat('yyyy-MM-dd').format(_startDate),
                            Icons.calendar_today_rounded,
                            () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          // Time box
                          _pickerBox(
                            _startTime.format(context),
                            Icons.access_time_rounded,
                            () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null) {
                                setState(() => _startTime = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // End Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Date box
                          _pickerBox(
                            DateFormat('yyyy-MM-dd').format(_endDate),
                            Icons.calendar_today_rounded,
                            () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          // Time box
                          _pickerBox(
                            _endTime.format(context),
                            Icons.access_time_rounded,
                            () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Interval Dropdown
                const Text(
                  'Interval',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FuelInterval>(
                      value: _interval,
                      isExpanded: true,
                      items: FuelInterval.values.map((FuelInterval i) {
                        return DropdownMenuItem<FuelInterval>(
                          value: i,
                          child: Text(
                            i.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (FuelInterval? val) {
                        if (val != null) setState(() => _interval = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // DONE Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final DateTime fullStart = DateTime(
                        _startDate.year,
                        _startDate.month,
                        _startDate.day,
                        _startTime.hour,
                        _startTime.minute,
                      );
                      final DateTime fullEnd = DateTime(
                        _endDate.year,
                        _endDate.month,
                        _endDate.day,
                        _endTime.hour,
                        _endTime.minute,
                      );

                      widget.onApply(fullStart, fullEnd, _interval);
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, String preset) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0284C7),
      ),
      backgroundColor: const Color(0xFFF0F9FF),
      side: const BorderSide(color: Color(0xFFBAE6FD)),
      onPressed: () => _applyQuickPreset(preset),
    );
  }

  Widget _pickerBox(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
