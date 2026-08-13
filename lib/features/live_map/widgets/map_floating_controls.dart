import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';

class LeftMapControls extends StatelessWidget {
  const LeftMapControls({
    required this.onLayers,
    required this.onRecenter,
    super.key,
  });

  final VoidCallback onLayers;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF13171F).withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              SizedBox(width: 6),
              Text('Live', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        
        // Vertical control stack
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13171F).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SquareButton(
                icon: Icons.layers_outlined,
                onTap: onLayers,
              ),
              _Divider(),
              _SquareButton(
                icon: Icons.my_location_rounded,
                onTap: onRecenter,
              ),
              _Divider(),
              _SquareButton(
                icon: Icons.traffic_outlined,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RightMapControls extends StatelessWidget {
  const RightMapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    super.key,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Compass
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF13171F).withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: const Center(
            child: Icon(Icons.explore_outlined, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 120),
        
        // Zoom Controls
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13171F).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SquareButton(
                icon: Icons.add,
                onTap: onZoomIn,
              ),
              _Divider(),
              _SquareButton(
                icon: Icons.remove,
                onTap: onZoomOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF13171F).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: _SquareButton(
            icon: Icons.layers_clear_outlined,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    this.icon,
    this.text,
    this.isActive = false,
    required this.onTap,
  });

  final IconData? icon;
  final String? text;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: isActive ? Colors.blueAccent : Colors.white70,
                  size: 22,
                )
              : Text(
                  text!,
                  style: TextStyle(
                    color: isActive ? Colors.blueAccent : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 1,
      color: Colors.white10,
    );
  }
}
