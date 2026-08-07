import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geocoder.dart';
import '../../data/models/vehicle.dart';

class LiveAddress extends StatefulWidget {
  const LiveAddress({
    required this.vehicle,
    required this.max,
    this.style,
    super.key,
  });

  final Vehicle vehicle;
  final int max;
  final TextStyle? style;

  @override
  State<LiveAddress> createState() => _LiveAddressState();
}

class _LiveAddressState extends State<LiveAddress> {
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant LiveAddress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicle.latitude != widget.vehicle.latitude ||
        oldWidget.vehicle.longitude != widget.vehicle.longitude ||
        oldWidget.vehicle.address != widget.vehicle.address) {
      _resolve();
    }
  }

  void _resolve() {
    if (widget.vehicle.address != null && widget.vehicle.address!.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _resolvedAddress = widget.vehicle.address;
        });
      }
      return;
    }

    if (!widget.vehicle.hasLocation) {
      if (mounted) {
        setState(() {
          _resolvedAddress = null; 
        });
      }
      return;
    }

    Geocoder.getAddress(widget.vehicle.latitude!, widget.vehicle.longitude!)
        .then((String addr) {
      if (mounted) {
        setState(() {
          _resolvedAddress = addr == 'Location unavailable' ? null : addr;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _resolvedAddress != null
          ? Fmt.address(_resolvedAddress, max: widget.max)
          : (widget.vehicle.hasLocation ? 'Resolving address...' : 'Location unavailable'),
      maxLines: widget.max == 9999 ? null : 2,
      overflow: widget.max == 9999 ? TextOverflow.visible : TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
