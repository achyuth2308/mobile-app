import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/report_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geocoder.dart';

class StoppageDetailCard extends StatelessWidget {
  const StoppageDetailCard({
    required this.stoppage,
    required this.stopNumber,
    super.key,
  });

  final ReportRow stoppage;
  final int stopNumber;

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  void _shareLocation() {
    final lat = stoppage.startLat ?? stoppage.endLat;
    final lng = stoppage.startLng ?? stoppage.endLng;
    if (lat == null || lng == null) return;
    
    final mapUrl = 'https://maps.google.com/?q=$lat,$lng';
    final duration = _formatDuration(stoppage.durationSeconds ?? 0);
    final text = 'Vehicle stopped here for $duration.\\n\\nLocation: $mapUrl';
    Share.share(text, subject: 'Vehicle Stoppage Location');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = stoppage.address ?? 
        stoppage.raw['start_location'] ?? 
        stoppage.raw['location'] ?? 
        stoppage.raw['address'] ?? 
        stoppage.raw['startLocation'] ?? 
        stoppage.raw['start_address'] ?? 
        'Unknown Location';
    final durationStr = _formatDuration(stoppage.durationSeconds ?? 0);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle for sliding
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stop #$stopNumber',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    durationStr,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResolvedAddressText(
                    latitude: stoppage.startLat ?? stoppage.endLat,
                    longitude: stoppage.startLng ?? stoppage.endLng,
                    fallbackAddress: address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Time
            Row(
              children: [
                Icon(Icons.access_time, color: theme.colorScheme.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${Fmt.time(stoppage.startTime)} - ${Fmt.time(stoppage.endTime)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Share Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareLocation,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedAddressText extends StatefulWidget {
  const _ResolvedAddressText({
    required this.latitude,
    required this.longitude,
    required this.fallbackAddress,
    this.style,
  });

  final double? latitude;
  final double? longitude;
  final String fallbackAddress;
  final TextStyle? style;

  @override
  State<_ResolvedAddressText> createState() => _ResolvedAddressTextState();
}

class _ResolvedAddressTextState extends State<_ResolvedAddressText> {
  String? _resolvedAddress;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    if (widget.fallbackAddress != 'Unknown Location' && widget.fallbackAddress.isNotEmpty) {
      _resolvedAddress = widget.fallbackAddress;
      return;
    }

    if (widget.latitude == null || widget.longitude == null) {
      _resolvedAddress = 'Location unavailable';
      return;
    }

    _isResolving = true;
    Geocoder.getAddress(widget.latitude!, widget.longitude!).then((addr) {
      if (mounted) {
        setState(() {
          _resolvedAddress = addr;
          _isResolving = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _resolvedAddress ?? (_isResolving ? 'Resolving address...' : 'Unknown Location'),
      style: widget.style,
    );
  }
}

