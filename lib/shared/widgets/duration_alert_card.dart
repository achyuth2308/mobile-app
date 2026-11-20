import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class DurationAlertCard extends StatelessWidget {
  const DurationAlertCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.controller,
    required this.duration,
    required this.onDurationChanged,
    this.enabled,
    this.onToggle,
    this.badgeColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;
  final double duration;
  final ValueChanged<double> onDurationChanged;
  final bool? enabled;
  final ValueChanged<bool>? onToggle;
  final Color? badgeColor;

  String get _badgeText {
    final int mins = duration.round();
    if (mins >= 60 && mins % 60 == 0) {
      final int hrs = mins ~/ 60;
      return '$hrs hr${hrs > 1 ? 's' : ''}';
    }
    return '$mins min';
  }

  void _selectPreset(int presetMins) {
    controller.text = '$presetMins';
    onDurationChanged(presetMins.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isEnabled = enabled ?? true;

    final Color cardBg = isDark ? scheme.surfaceContainerHigh : Colors.white;
    final Color borderColor = isDark ? scheme.outlineVariant : const Color(0xFFE2E8F0);
    final Color accent = badgeColor ?? const Color(0xFF2563EB);
    final int roundedVal = duration.round();

    return Container(
      padding: const EdgeInsets.all(Gap.md + 2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: Corners.rLg,
        border: Border.all(
          color: isEnabled ? borderColor : borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Header Row: Icon + Title + Badge + Switch ──
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Gap.xs + 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isEnabled ? 0.12 : 0.05),
                  borderRadius: Corners.rSm,
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? iconColor : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isEnabled ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? accent.withValues(alpha: 0.12)
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _badgeText,
                            style: TextStyle(
                              color: isEnabled ? accent : scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onToggle != null && enabled != null)
                Switch(
                  value: enabled!,
                  thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? const Color(0xFF16A34A)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onToggle,
                ),
            ],
          ),

          if (isEnabled) ...[
            const SizedBox(height: Gap.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _PresetChip(
                      label: '30 min',
                      isSelected: roundedVal == 30,
                      isEnabled: isEnabled,
                      onTap: () => _selectPreset(30),
                    ),
                    _PresetChip(
                      label: '1 hr (Default)',
                      isSelected: roundedVal == 60,
                      isEnabled: isEnabled,
                      onTap: () => _selectPreset(60),
                    ),
                    _PresetChip(
                      label: '2 hrs',
                      isSelected: roundedVal == 120,
                      isEnabled: isEnabled,
                      onTap: () => _selectPreset(120),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? scheme.outlineVariant : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: TextFormField(
                        controller: controller,
                        enabled: isEnabled,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                          border: InputBorder.none,
                        ),
                        onChanged: (String val) {
                          final double? parsed = double.tryParse(val.trim());
                          if (parsed != null && parsed > 0) {
                            onDurationChanged(parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'min',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color activeBg = isDark
        ? const Color(0xFFEA580C).withValues(alpha: 0.25)
        : const Color(0xFFFFEDD5);
    const Color activeBorder = Color(0xFFEA580C);
    final Color activeText = isDark ? const Color(0xFFFFB088) : const Color(0xFFC2410C);

    final Color inactiveBg = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : Colors.white;
    final Color inactiveBorder = isDark
        ? theme.colorScheme.outlineVariant
        : const Color(0xFFCBD5E1);
    final Color inactiveText = theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? activeBorder : inactiveBorder,
              width: isSelected ? 1.2 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeText : inactiveText,
            ),
          ),
        ),
      ),
    );
  }
}
