import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/report_models.dart';

class ReportExportService {
  const ReportExportService._();

  static Future<void> exportCsv({
    required ReportType type,
    required List<ReportRow> rows,
  }) async {
    if (rows.isEmpty) return;

    final List<List<dynamic>> csvData = <List<dynamic>>[];

    switch (type) {
      case ReportType.trip:
        csvData.add(<dynamic>[
          'Start Time',
          'Start Lat',
          'Start Lng',
          'End Time',
          'End Lat',
          'End Lng',
          'Duration (HH:MM:SS)',
          'Distance (KM)',
          'Max Speed (km/h)',
          'Avg Speed (km/h)',
          'Vehicle',
        ]);
        for (final ReportRow r in rows) {
          csvData.add(<dynamic>[
            Fmt.dateTimeWeb(r.startTime),
            r.startLat ?? '',
            r.startLng ?? '',
            Fmt.dateTimeWeb(r.endTime),
            r.endLat ?? '',
            r.endLng ?? '',
            Fmt.durationWeb(r.durationSecVal),
            r.distanceTravelled?.toStringAsFixed(2) ?? '',
            r.maxSpeedVal?.toStringAsFixed(0) ?? '',
            r.avgSpeedVal?.toStringAsFixed(0) ?? '',
            r.vehicleName ?? '',
          ]);
        }
        break;

      case ReportType.distance:
        csvData.add(<dynamic>[
          'Vehicle Name',
          'Plate',
          'Org',
          'Date',
          'Start Odometer',
          'End Odometer',
          'Distance Travelled (KM)',
          'Points Logged',
        ]);
        for (final ReportRow r in rows) {
          csvData.add(<dynamic>[
            r.vehicleName ?? '',
            r.plate ?? '-',
            r.orgName ?? 'FuelTracks',
            Fmt.dateWeb(r.date),
            r.startOdometer?.toStringAsFixed(0) ?? '',
            r.endOdometer?.toStringAsFixed(0) ?? '',
            '${r.distanceTravelled?.toStringAsFixed(0) ?? '0'} km',
            r.pointCount,
          ]);
        }
        break;

      case ReportType.overspeeding:
        csvData.add(<dynamic>[
          'Vehicle Name',
          'Date & Time',
          'OverSpeed (km/h)',
          'OverSpeed Duration',
          'Driver Name',
          'Driver Mobile Number',
          'Latitude',
          'Longitude',
          'Distance Covered (KM)',
        ]);
        for (final ReportRow r in rows) {
          csvData.add(<dynamic>[
            r.vehicleName ?? '',
            Fmt.dateTimeWeb(r.startTime),
            r.maxSpeedVal?.toStringAsFixed(0) ?? '',
            Fmt.durationWeb(r.durationSecVal),
            r.driverName ?? '-',
            r.driverPhone ?? '-',
            r.latitude ?? '',
            r.longitude ?? '',
            r.distanceTravelled?.toStringAsFixed(2) ?? '0.00',
          ]);
        }
        break;

      case ReportType.stoppages:
      case ReportType.idle:
        csvData.add(<dynamic>[
          'Vehicle Name',
          'Status',
          'Start Time',
          'End Time',
          'Duration (HH:MM:SS)',
          'Latitude',
          'Longitude',
        ]);
        for (final ReportRow r in rows) {
          csvData.add(<dynamic>[
            r.vehicleName ?? '',
            r.status ?? (type == ReportType.idle ? 'Idle' : 'Parked'),
            Fmt.dateTimeWeb(r.startTime),
            Fmt.dateTimeWeb(r.endTime),
            Fmt.durationWeb(r.durationSecVal),
            r.latitude ?? '',
            r.longitude ?? '',
          ]);
        }
        break;

      case ReportType.individual:
        csvData.add(<dynamic>[
          'Vehicle Name',
          'Plate',
          'Total Distance (km)',
          'Running Time',
          'Idle Time',
          'Trip Count',
          'Stoppages',
          'Overspeeding',
        ]);
        for (final ReportRow r in rows) {
          csvData.add(<dynamic>[
            r.vehicleName ?? '-',
            r.plate ?? '-',
            '${r.distanceTravelled?.toStringAsFixed(0) ?? '0'} km',
            '${r.runningMins} mins',
            '${r.idleMins} mins',
            r.tripCount,
            r.stoppageCount,
            r.overspeedingCount,
          ]);
        }
        break;

      case ReportType.consolidated:
        csvData.add(<dynamic>[
          'Vehicle Name',
          'Plate',
          'Distance Travelled (km)',
          'Running Time (mins)',
          'Stopping Time (mins)',
          'Idle Time (mins)',
          'Engine On Hours',
          'Starting Fuel (L)',
          'Ending Fuel (L)',
          'Consumption (L)',
          'Filling (L)',
          'Theft (L)',
          'KMPL',
          'LPH (L/h)',
          'From Location',
          'To Location',
        ]);
        for (final ReportRow r in rows) {
          csvData.add(<dynamic>[
            r.vehicleName ?? '-',
            r.plate ?? '-',
            r.distanceTravelled?.toStringAsFixed(1) ?? '0',
            r.runningMins,
            r.stoppedMins,
            r.idleMins,
            r.engineOnHours.toStringAsFixed(2),
            r.startFuel?.toStringAsFixed(1) ?? '',
            r.endFuel?.toStringAsFixed(1) ?? '',
            r.consumption?.toStringAsFixed(1) ?? '',
            r.filling?.toStringAsFixed(1) ?? '',
            r.theft?.toStringAsFixed(1) ?? '',
            r.kmpl?.toStringAsFixed(1) ?? '',
            r.lph?.toStringAsFixed(1) ?? '',
            r.fromLocation ?? '',
            r.toLocation ?? '',
          ]);
        }
        break;

      default:
        // Generic CSV dump
        if (rows.isNotEmpty) {
          final List<String> headers = rows.first.cells.keys.toList();
          csvData.add(headers);
          for (final ReportRow r in rows) {
            csvData.add(headers.map((String h) => r.cells[h] ?? '').toList());
          }
        }
        break;
    }

    final String csv = const ListToCsvConverter().convert(csvData);
    final Directory dir = await getTemporaryDirectory();
    final String fileName = '${type.name}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    final File file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      subject: '${type.label} Export',
      text: 'Exported ${type.label} with ${rows.length} records.',
    );
  }

  static Future<void> exportExcel({
    required ReportType type,
    required List<ReportRow> rows,
  }) async {
    // Excel-compatible CSV export with .csv file shared
    return exportCsv(type: type, rows: rows);
  }

  static Future<void> exportPdf({
    required ReportType type,
    required List<ReportRow> rows,
  }) async {
    // Shares structured text / CSV representation for reporting
    return exportCsv(type: type, rows: rows);
  }
}
