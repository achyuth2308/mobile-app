import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/geocoder.dart';
import '../../data/models/vehicle.dart';

/// Modern, compact elevated map popup card that floats above a vehicle marker
/// with an arrow pointer pointing directly to the marker below.
///
/// Used in both Live Tracking (UniversalLiveMap) and History Tracking (VehiclePlaybackTab).
class VehicleMarkerCalloutCard extends StatefulWidget {
  const VehicleMarkerCalloutCard({
    super.key,
    required this.vehicleName,
    required this.status,
    this.speed = 0.0,
    this.ignition = false,
    this.todayDistanceKm,
    this.odometerKm,
    this.locTime,
    this.commTime,
    this.initialAddress,
    this.lat,
    this.lng,
    this.vehicleType,
    this.onClose,
    this.onTrack,
    this.onHistory,
    this.onReports,
    this.onDetails,
    this.showActions = true,
    this.isPlayback = false,
    this.width = 236.0,
  });

  final String vehicleName;
  final VehicleStatus status;
  final double speed;
  final bool ignition;
  final double? todayDistanceKm;
  final double? odometerKm;
  final DateTime? locTime;
  final DateTime? commTime;
  final String? initialAddress;
  final double? lat;
  final double? lng;
  final String? vehicleType;

  final VoidCallback? onClose;
  final VoidCallback? onTrack;
  final VoidCallback? onHistory;
  final VoidCallback? onReports;
  final VoidCallback? onDetails;

  final bool showActions;
  final bool isPlayback;
  final double width;

  @override
  State<VehicleMarkerCalloutCard> createState() =>
      _VehicleMarkerCalloutCardState();
}

class _VehicleMarkerCalloutCardState extends State<VehicleMarkerCalloutCard> {
  String? _address;
  Timer? _debounce;
  double _lastFetchedLat = 0.0;
  double _lastFetchedLng = 0.0;

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  @override
  void didUpdateWidget(covariant VehicleMarkerCalloutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lat != oldWidget.lat || widget.lng != oldWidget.lng) {
      final double latDiff = ((widget.lat ?? 0) - _lastFetchedLat).abs();
      final double lngDiff = ((widget.lng ?? 0) - _lastFetchedLng).abs();
      // Only re-fetch if moved more than ~25 meters
      if (latDiff > 0.00025 || lngDiff > 0.00025) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          if (mounted) _resolveAddress();
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _resolveAddress() {
    if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty &&
        !widget.initialAddress!.endsWith('...') &&
        !widget.initialAddress!.endsWith('…')) {
      setState(() => _address = widget.initialAddress);
      return;
    }

    if (widget.lat == null || widget.lng == null) return;
    final double lat = widget.lat!;
    final double lng = widget.lng!;

    final String? cached = Geocoder.getCachedAddress(lat, lng);
    if (cached != null && cached.isNotEmpty && cached != 'Location unavailable') {
      setState(() => _address = cached);
      return;
    }

    _lastFetchedLat = lat;
    _lastFetchedLng = lng;

    Geocoder.getAddress(lat, lng).then((String a) {
      if (mounted && a.isNotEmpty && a != 'Location unavailable') {
        setState(() => _address = a);
      }
    });
  }

  String _formatIstTime(DateTime? dt) {
    if (dt == null) return '—';
    final DateTime utc = dt.toUtc();
    final DateTime ist = utc.add(const Duration(hours: 5, minutes: 30));
    final DateFormat formatter = DateFormat('dd-MMM-yy HH:mm');
    return formatter.format(ist);
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case VehicleStatus.moving:
        return AppColors.moving;
      case VehicleStatus.idle:
        return AppColors.idle;
      case VehicleStatus.stopped:
      case VehicleStatus.offline:
      case VehicleStatus.noData:
        return AppColors.stopped;
    }
  }

  Color _getStatusTextColor(bool isDark) {
    switch (widget.status) {
      case VehicleStatus.moving:
        return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      case VehicleStatus.idle:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case VehicleStatus.stopped:
      case VehicleStatus.offline:
      case VehicleStatus.noData:
        return isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    }
  }

  String _getStatusLabel() {
    switch (widget.status) {
      case VehicleStatus.moving:
        return widget.speed > 0
            ? 'Moving • ${widget.speed.round()} km/h'
            : 'Moving';
      case VehicleStatus.idle:
        return 'Idle';
      case VehicleStatus.stopped:
        return 'Parked';
      case VehicleStatus.offline:
        return 'Offline';
      case VehicleStatus.noData:
        return 'No Data';
    }
  }

  IconData _getVehicleIcon() {
    final String t = (widget.vehicleType ?? '').toLowerCase();
    if (t.contains('bike') || t.contains('motorcycle') || t.contains('scooter')) {
      return Icons.two_wheeler_rounded;
    }
    if (t.contains('truck') || t.contains('lorry') || t.contains('tipper')) {
      return Icons.local_shipping_rounded;
    }
    if (t.contains('bus')) {
      return Icons.directions_bus_rounded;
    }
    if (t.contains('tractor') || t.contains('jcb')) {
      return Icons.agriculture_rounded;
    }
    return Icons.directions_car_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color cardBg = isDark ? const Color(0xFF161F36) : Colors.white;
    final Color borderColor =
        isDark ? const Color(0xFF273453) : const Color(0xFFE2E8F0);
    final Color textColorHigh =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textColorMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Color statusColor = _getStatusColor();
    final Color nameColor = _getStatusTextColor(isDark);
    final String statusLabel = _getStatusLabel();

    final String odoText = widget.odometerKm != null && widget.odometerKm! > 0
        ? '${NumberFormat('#,##0.0').format(widget.odometerKm)} km'
        : '—';

    final String distText = widget.todayDistanceKm != null
        ? '${widget.todayDistanceKm!.toStringAsFixed(2)} km'
        : '0.00 km';

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // ── Main Card Body ───────────────────────────────────────────────
          Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 0.8),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Header (Icon + Name + Status subtitle + Close '✕')
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 6, 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Compact Status Circle Icon
                      Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          _getVehicleIcon(),
                          size: 13,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Vehicle Name & Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.vehicleName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: nameColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    statusLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.2,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Close button with generous thumb tap target
                      if (widget.onClose != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onClose!();
                          },
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: Center(
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: textColorMuted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 0.6),

                // 2. Telemetry Rows (Grid / key-value)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Column(
                    children: <Widget>[
                      // Row 1: Today Distance & Odometer
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _MetricItem(
                              label: widget.isPlayback ? 'Dist Cov' : 'Today Dist',
                              value: distText,
                              textColor: textColorHigh,
                              labelColor: textColorMuted,
                            ),
                          ),
                          Container(
                            height: 18,
                            width: 1,
                            color: borderColor,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                          ),
                          Expanded(
                            child: _MetricItem(
                              label: 'Odometer',
                              value: odoText,
                              textColor: textColorHigh,
                              labelColor: textColorMuted,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3.5),

                      // Row 2: ACC Status & Timestamp (Aligned with Columns above)
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Text(
                                  'ACC: ',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: textColorMuted,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (widget.ignition
                                            ? AppColors.moving
                                            : AppColors.danger)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    widget.ignition ? 'ON' : 'OFF',
                                    style: TextStyle(
                                      fontSize: 9.2,
                                      fontWeight: FontWeight.w700,
                                      color: widget.ignition
                                          ? AppColors.moving
                                          : AppColors.danger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Transform.translate(
                              offset: const Offset(-3.5, 0),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 9.5,
                                    color: textColorMuted,
                                  ),
                                  const SizedBox(width: 2.5),
                                  Flexible(
                                    child: Text(
                                      _formatIstTime(widget.locTime),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.2,
                                        fontWeight: FontWeight.w600,
                                        color: textColorHigh,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Row 3: Live Address (Tap to copy)
                      const SizedBox(height: 3.5),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          if (_address != null &&
                              _address!.isNotEmpty &&
                              _address != 'Fetching address...') {
                            Clipboard.setData(ClipboardData(text: _address!));
                            HapticFeedback.selectionClick();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Address copied to clipboard'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.location_on_rounded,
                                  size: 10.5,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  _address ?? 'Fetching address...',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8.8,
                                    height: 1.25,
                                    fontWeight: FontWeight.w500,
                                    color: textColorMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Pointer Downward Triangle Notch ──────────────────────────────
          CustomPaint(
            size: const Size(11, 6),
            painter: _CalloutTrianglePainter(
              color: cardBg,
              borderColor: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.textColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: labelColor,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// Draws an inverted triangle notch connecting the card to the vehicle pin.
class _CalloutTrianglePainter extends CustomPainter {
  const _CalloutTrianglePainter({
    required this.color,
    required this.borderColor,
  });

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final Path borderPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CalloutTrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
