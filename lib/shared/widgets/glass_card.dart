import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Frosted surface used for map overlays and hero panels.
///
/// A real backdrop blur is expensive, so it is opt-in via [blur]; flat
/// translucent fills are used for long lists where the cost would repeat.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = Gap.card,
    this.borderRadius = Corners.rLg,
    this.blur = 18,
    this.opacity = 0.72,
    this.border = true,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;
  final bool border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withOpacity(opacity),
        borderRadius: borderRadius,
        border: border
            ? Border.all(color: scheme.outlineVariant.withOpacity(0.9))
            : null,
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Standard elevated content surface — the workhorse container.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = Gap.card,
    this.onTap,
    this.borderRadius = Corners.rLg,
    this.color,
    this.borderColor,
    this.elevated = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainer,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
        boxShadow: elevated && !isDark
            ? <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withOpacity(0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
