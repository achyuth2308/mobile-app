import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/report_models.dart';
import '../../data/models/vehicle.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import 'services/report_export_service.dart';
import 'widgets/report_filter_bar.dart';
import 'widgets/report_table_views.dart';
import 'widgets/report_top_tabs.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({
    this.type = ReportType.trip,
    this.initialVehicleId,
    super.key,
  });

  final ReportType type;
  final String? initialVehicleId;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  late ReportType _currentType;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _vehicleId;

  ReportResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentType = widget.type;
    _vehicleId = widget.initialVehicleId;

    final DateTime now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentType.requiresVehicle && (_vehicleId == null || _vehicleId!.isEmpty)) {
        final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
        if (vehicles.isNotEmpty) {
          _vehicleId = vehicles.first.id;
        }
      }
      _run();
    });
  }

  @override
  void didUpdateWidget(covariant ReportDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      setState(() {
        _currentType = widget.type;
      });
      _run();
    }
  }

  void _onTabChanged(ReportType newType) {
    if (_currentType == newType) return;
    setState(() {
      _currentType = newType;
      if (newType.requiresVehicle && (_vehicleId == null || _vehicleId!.isEmpty)) {
        final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
        if (vehicles.isNotEmpty) {
          _vehicleId = vehicles.first.id;
        }
      }
      _result = null;
      _error = null;
    });
    _run();
  }

  Future<void> _run() async {
    if (_currentType.requiresVehicle && (_vehicleId == null || _vehicleId!.isEmpty)) {
      setState(() {
        _error = 'Please select a vehicle to generate this report.';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ReportResult res = await ref.read(reportRepositoryProvider).run(
            type: _currentType,
            start: _startDate,
            end: _endDate,
            vehicleId: _vehicleId,
          );

      if (!mounted) return;
      setState(() {
        _result = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load report: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleExport(String format) async {
    final ReportResult? res = _result;
    if (res == null || res.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report records to export.')),
      );
      return;
    }

    try {
      if (format == 'csv') {
        await ReportExportService.exportCsv(type: _currentType, rows: res.rows);
      } else if (format == 'excel') {
        await ReportExportService.exportExcel(type: _currentType, rows: res.rows);
      } else {
        await ReportExportService.exportPdf(type: _currentType, rows: res.rows);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReportResult? res = _result;
    final int recordCount = res?.rows.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Subtle light background like web
      appBar: AppBar(
        title: Text(
          _currentType.label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _run,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            children: <Widget>[
              // Top Horizontal Tabs
              ReportTopTabs(
                selectedType: _currentType,
                onTabSelected: _onTabChanged,
              ),

              const SizedBox(height: 8),

              // Filter Controls Card
              ReportFilterBar(
                type: _currentType,
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeChanged: (DateTime s, DateTime e) {
                  setState(() {
                    _startDate = s;
                    _endDate = e;
                  });
                  _run();
                },
                vehicleId: _vehicleId,
                onVehicleChanged: (String? vId) {
                  setState(() {
                    _vehicleId = vId;
                  });
                  _run();
                },
                onGenerate: _run,
                isLoading: _loading,
                requiresVehicle: _currentType.requiresVehicle,
              ),

              const SizedBox(height: 8),

              // Report Results Card Container
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Table Header Bar: "Report Results (N records)" + Export Buttons
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Text(
                                'Report Results',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '($recordCount records)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),

                          // Export Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _exportButton(
                                label: 'PDF',
                                icon: Icons.picture_as_pdf_rounded,
                                color: const Color(0xFFDC2626),
                                onTap: recordCount > 0 ? () => _handleExport('pdf') : null,
                              ),
                              const SizedBox(width: 6),
                              _exportButton(
                                label: 'Excel',
                                icon: Icons.table_view_rounded,
                                color: const Color(0xFF10B981),
                                onTap: recordCount > 0 ? () => _handleExport('excel') : null,
                              ),
                              const SizedBox(width: 6),
                              _exportButton(
                                label: 'CSV',
                                icon: Icons.download_rounded,
                                color: const Color(0xFF0284C7),
                                onTap: recordCount > 0 ? () => _handleExport('csv') : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Swipe hint banner for wide tables
                    if (recordCount > 0 && !_loading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF64748B)),
                            SizedBox(width: 6),
                            Text(
                              'Swipe left/right on table to view all columns',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Table Body Content
                    if (_loading)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Generating report data...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_error != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 36),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _run,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (res == null || res.rows.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 32),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No records found matching your criteria.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Try adjusting the date range or selecting a different vehicle.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildTableForType(_currentType, res),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableForType(ReportType type, ReportResult res) {
    switch (type) {
      case ReportType.trip:
        return TripReportTable(rows: res.rows);
      case ReportType.distance:
        return DailyDistanceReportTable(rows: res.rows);
      case ReportType.overspeeding:
        return OverspeedingReportTable(
          rows: res.rows,
          startDate: _startDate,
          endDate: _endDate,
        );
      case ReportType.stoppages:
        return StoppageReportTable(
          rows: res.rows,
          startDate: _startDate,
          endDate: _endDate,
        );
      case ReportType.idle:
        return IdleReportTable(
          rows: res.rows,
          startDate: _startDate,
          endDate: _endDate,
        );
      case ReportType.individual:
        return IndividualReportTable(rows: res.rows);
      case ReportType.consolidated:
        return ConsolidatedReportTable(rows: res.rows);
      default:
        return GenericReportTable(result: res);
    }
  }

  Widget _exportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final bool isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isEnabled ? color.withOpacity(0.08) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnabled ? color.withOpacity(0.3) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: isEnabled ? color : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isEnabled ? color : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
