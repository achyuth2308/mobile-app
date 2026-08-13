import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'dart:math' as math;

class Vehicle3DMarker extends StatefulWidget {
  const Vehicle3DMarker({
    super.key,
    required this.bearing,
    this.useVespa = false,
    this.size = 60.0,
  });

  final double bearing;
  final bool useVespa;
  final double size;

  @override
  State<Vehicle3DMarker> createState() => _Vehicle3DMarkerState();
}

class _Vehicle3DMarkerState extends State<Vehicle3DMarker> {
  Flutter3DController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = Flutter3DController();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Fallback for Web since flutter_3d_controller crashes with HTML renderer 
      // and missing path_provider web implementations.
      return IgnorePointer(
        child: Transform.rotate(
          angle: widget.bearing * math.pi / 180,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.useVespa ? Icons.moped_rounded : Icons.directions_car_rounded,
              size: widget.size * 0.6,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Both vespa and classic_muscle_car .glb files should be in the assets.
    // If not, we fall back to classic_muscle_car.glb.
    final String assetPath = widget.useVespa
        ? 'assets/models/vespa.glb'
        : 'assets/models/classic_muscle_car.glb';

    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Flutter3DViewer(
          src: assetPath,
          controller: _controller,
          // Ensure no background so the map shows through.
          // Some models need specific camera orbits, but we keep it default.
        ),
      ),
    );
  }
}
