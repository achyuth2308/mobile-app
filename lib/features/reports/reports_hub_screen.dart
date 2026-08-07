import 'package:flutter/material.dart';

import '../../data/models/report_models.dart';
import 'report_detail_screen.dart';

/// Reports screen entry point: displays the web-matching tabular reports hub.
class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportDetailScreen(type: ReportType.trip);
  }
}
