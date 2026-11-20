import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/json_utils.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/fleet_provider.dart';
import '../../../providers/safety_parking_provider.dart';
import '../../../shared/widgets/app_states.dart';

class VehicleSettingsScreen extends ConsumerStatefulWidget {
  const VehicleSettingsScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehicleSettingsScreen> createState() =>
      _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState
    extends ConsumerState<VehicleSettingsScreen> {
  late double _speedLimit;
  late double _overspeedDuration;
  late double _idleDuration;
  late double _parkingDuration;
  late double _movingDuration;
  double _noDataThreshold = 0.5;
  late bool _safetyPark;
  late TextEditingController _idleController;
  late TextEditingController _parkingController;
  late TextEditingController _movingController;
  bool _applyAccountWide = true;
  bool _isSaving = false;

  final Map<String, bool> _alertToggles = {
    'engine_on': true,
    'engine_off': true,
    'moving': true,
    'parking': true,
    'stoppage': true,
    'excessive_idle': true,
    'overspeed': true,
    'geofence': true,
    'main_battery_disconnected': true,
    'main_battery_connected': true,
    'sos': true,
    'trip_started': true,
    'trip_ended': true,
    'route_deviation': true,
  };

  @override
  void initState() {
    super.initState();
    final Vehicle? vehicle = ref.read(vehicleByIdProvider(widget.vehicleId));
    final Map<String, dynamic> metadata = (vehicle?.raw['metadata'] as Map<String, dynamic>?) ?? {};
    _speedLimit = toDouble(metadata['overSpeedLimit']) ??
        toDouble(metadata['speedLimit']) ??
        80.0;
    _overspeedDuration = toDouble(metadata['overspeedDurationAlert']) ?? 3.0;
    _idleDuration = toDouble(metadata['idleDurationAlert']) ?? 60.0;
    _parkingDuration = toDouble(metadata['parkingDurationAlert']) ??
        toDouble(metadata['stoppageThreshold']) ??
        60.0;
    _movingDuration = toDouble(metadata['movingDurationAlert']) ?? 60.0;
    _noDataThreshold = ref.read(noDataThresholdProvider);
    _safetyPark = vehicle?.isSafetyParkActive ?? (metadata['safetyPark'] == 'YES');

    _idleController = TextEditingController(text: '${_idleDuration.round()}');
    _parkingController = TextEditingController(text: '${_parkingDuration.round()}');
    _movingController = TextEditingController(text: '${_movingDuration.round()}');
    
    final alertConfig = metadata['alertConfig'] as Map<String, dynamic>? ?? {};
    for (final key in _alertToggles.keys) {
      if (alertConfig.containsKey(key)) {
        _alertToggles[key] = alertConfig[key] == true;
      }
    }

    // Load account-wide user preferences if available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final Map<String, dynamic>? remote =
            await ref.read(alertRepositoryProvider).getPreferences();
        if (remote != null && mounted) {
          setState(() {
            if (remote['speed_limit'] != null) {
              _speedLimit = toDouble(remote['speed_limit']) ?? _speedLimit;
            }
            if (remote['idle_duration_mins'] != null) {
              _idleDuration = toDouble(remote['idle_duration_mins']) ?? _idleDuration;
              _idleController.text = '${_idleDuration.round()}';
            }
            if (remote['parking_duration_mins'] != null) {
              _parkingDuration = toDouble(remote['parking_duration_mins']) ?? _parkingDuration;
              _parkingController.text = '${_parkingDuration.round()}';
            }
            if (remote['moving_duration_mins'] != null) {
              _movingDuration = toDouble(remote['moving_duration_mins']) ?? _movingDuration;
              _movingController.text = '${_movingDuration.round()}';
            }
            if (remote['nodata_threshold_hours'] != null) {
              _noDataThreshold = toDouble(remote['nodata_threshold_hours']) ?? _noDataThreshold;
            }
            for (final key in _alertToggles.keys) {
              if (remote.containsKey(key) && remote[key] is bool) {
                _alertToggles[key] = remote[key] as bool;
              }
            }
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _idleController.dispose();
    _parkingController.dispose();
    _movingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (_applyAccountWide) {
        // Save user-wide preferences (applies across account and backend auto-syncs all org vehicles)
        final Map<String, dynamic> userPrefs = <String, dynamic>{
          ..._alertToggles,
          'speed_limit': _speedLimit,
          'idle_duration_mins': _idleDuration,
          'parking_duration_mins': _parkingDuration,
          'moving_duration_mins': _movingDuration,
          'nodata_threshold_hours': _noDataThreshold,
        };
        await ref.read(alertRepositoryProvider).updatePreferences(userPrefs);
        await ref.read(noDataThresholdProvider.notifier).setThreshold(_noDataThreshold);
      }

      await ref.read(fleetProvider.notifier).updateSettings(
            widget.vehicleId,
            overSpeedLimit: _speedLimit,
            overspeedDurationAlert: _overspeedDuration,
            idleDurationAlert: _idleDuration,
            stoppageThreshold: _parkingDuration,
            parkingDurationAlert: _parkingDuration,
            movingDurationAlert: _movingDuration,
            alertConfig: _alertToggles,
            safetyPark: _safetyPark,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: <Widget>[
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(_applyAccountWide
                      ? 'Alert configuration saved for your account & applied to all vehicles!'
                      : 'Vehicle settings saved successfully!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(widget.vehicleId));

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Settings')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Vehicle not found',
          message: 'Unable to load vehicle details.',
        ),
      );
    }

    final Color cardBg = isDark
        ? const Color(0xFF0F2138)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alerts & Notifications'),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Alerts Config'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 100),
                      children: <Widget>[
                        // ── SECTION 1: VEHICLE & FLEET SCOPE ──
                        const _SectionHeader(title: 'VEHICLE & FLEET SCOPE'),
                        _GroupedCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                          children: [
                            // Vehicle Identity
                            Padding(
                              padding: const EdgeInsets.all(Gap.md),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.directions_car_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: Gap.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicle.displayName,
                                          maxLines: 2,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            height: 1.25,
                                          ),
                                        ),
                                        if (vehicle.registrationNumber.isNotEmpty &&
                                            vehicle.registrationNumber != vehicle.displayName) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            vehicle.registrationNumber,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _StatusBadge(status: vehicle.status),
                                ],
                              ),
                            ),
                            _buildGroupedDivider(borderColor),
                            // Apply to all vehicles toggle
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _applyAccountWide
                                          ? const Color(0xFF2563EB).withOpacity(0.12)
                                          : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.hub_rounded,
                                      color: _applyAccountWide
                                          ? const Color(0xFF2563EB)
                                          : scheme.onSurfaceVariant,
                                      size: 17,
                                    ),
                                  ),
                                  const SizedBox(width: Gap.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Apply to All Fleet Vehicles',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _applyAccountWide
                                              ? 'Settings sync across all vehicles in fleet'
                                              : 'Apply settings only to ${vehicle.displayName}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _ModernSwitch(
                                    value: _applyAccountWide,
                                    onChanged: (bool val) => setState(() => _applyAccountWide = val),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: Gap.lg),

                        // ── SECTION 2: SECURITY & THEFT ──
                        const _SectionHeader(title: 'SECURITY & THEFT ALARM'),
                        _GroupedCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(Gap.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _safetyPark
                                              ? const Color(0xFFDC2626)
                                              : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _safetyPark ? Icons.security_rounded : Icons.shield_outlined,
                                          color: _safetyPark ? Colors.white : const Color(0xFF64748B),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: Gap.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Parking Guard (Theft Alarm)',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: _safetyPark ? const Color(0xFFDC2626) : null,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              _safetyPark
                                                  ? 'ARMED: Siren active if moved or started'
                                                  : 'Loud siren if vehicle moves while parked',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: _safetyPark ? FontWeight.w600 : FontWeight.normal,
                                                color: _safetyPark
                                                    ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                                    : scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _ModernSwitch(
                                        value: _safetyPark,
                                        activeTrackColor: const Color(0xFFDC2626),
                                        onChanged: (bool val) => setState(() => _safetyPark = val),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () {
                                      ref.read(safetyParkingProvider.notifier).triggerTestAlarm(
                                            vehicleName: vehicle.displayName,
                                            plate: vehicle.registrationNumber,
                                          );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E2838) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.volume_up_rounded, size: 14, color: Color(0xFFDC2626)),
                                          SizedBox(width: 6),
                                          Text(
                                            'Test Siren & Alarm',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFDC2626),
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

                        const SizedBox(height: Gap.lg),

                        // ── SECTION 3: SPEED MONITORING ──
                        const _SectionHeader(title: 'SPEED MONITORING'),
                        _GroupedCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                          children: [
                            // Speed Limit
                            Padding(
                              padding: const EdgeInsets.all(Gap.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.speed_rounded, size: 18, color: Color(0xFFEA580C)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Speed Limit',
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(100),
                                          border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '${_speedLimit.round()} km/h',
                                          style: const TextStyle(
                                            color: Color(0xFFEA580C),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <double>[40, 60, 80, 100, 120]
                                        .map(
                                          (double s) => Expanded(
                                            child: _SegmentTab(
                                              label: '${s.round()}',
                                              isSelected: _speedLimit == s,
                                              activeColor: const Color(0xFFEA580C),
                                              onTap: () => setState(() => _speedLimit = s),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            _buildGroupedDivider(borderColor),
                            // Speeding Duration
                            Padding(
                              padding: const EdgeInsets.all(Gap.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_rounded, size: 18, color: Color(0xFFEA580C)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Speeding Duration',
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(100),
                                          border: Border.all(color: const Color(0xFFEA580C).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          '${_overspeedDuration.round()} min',
                                          style: const TextStyle(
                                            color: Color(0xFFEA580C),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Trigger alert only after vehicle speeds continuously for',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <double>[1, 3, 5, 10]
                                        .map(
                                          (double d) => Expanded(
                                            child: _SegmentTab(
                                              label: '${d.round()} min',
                                              isSelected: _overspeedDuration == d,
                                              activeColor: const Color(0xFFEA580C),
                                              onTap: () => setState(() => _overspeedDuration = d),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: Gap.lg),

                        // ── SECTION 4: ENGINE & CONNECTIVITY ──
                        const _SectionHeader(title: 'ENGINE & CONNECTIVITY'),
                        _GroupedCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          isDark: isDark,
                          children: [
                            // Idle Duration
                            Padding(
                              padding: const EdgeInsets.all(Gap.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.hourglass_empty_rounded, size: 18, color: Color(0xFF7C3AED)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Excessive Idle Alert',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              'Alert if engine is ON while stationary beyond',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontSize: 11,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _ModernSwitch(
                                        value: _alertToggles['excessive_idle'] ?? true,
                                        onChanged: (bool val) => setState(() {
                                          _alertToggles['excessive_idle'] = val;
                                          _alertToggles['idle'] = val;
                                        }),
                                      ),
                                    ],
                                  ),
                                  if (_alertToggles['excessive_idle'] ?? true) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SegmentTab(
                                            label: '15 min',
                                            isSelected: _idleDuration.round() == 15,
                                            activeColor: const Color(0xFF7C3AED),
                                            onTap: () => setState(() => _idleDuration = 15),
                                          ),
                                        ),
                                        Expanded(
                                          child: _SegmentTab(
                                            label: '30 min',
                                            isSelected: _idleDuration.round() == 30,
                                            activeColor: const Color(0xFF7C3AED),
                                            onTap: () => setState(() => _idleDuration = 30),
                                          ),
                                        ),
                                        Expanded(
                                          child: _SegmentTab(
                                            label: '1 hr',
                                            isSelected: _idleDuration.round() == 60,
                                            activeColor: const Color(0xFF7C3AED),
                                            onTap: () => setState(() => _idleDuration = 60),
                                          ),
                                        ),
                                        Expanded(
                                          child: _SegmentTab(
                                            label: '2 hrs',
                                            isSelected: _idleDuration.round() == 120,
                                            activeColor: const Color(0xFF7C3AED),
                                            onTap: () => setState(() => _idleDuration = 120),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            _buildGroupedDivider(borderColor),
                            // Offline Threshold
                            Padding(
                              padding: const EdgeInsets.all(Gap.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFF0D9488)),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Offline Threshold',
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D9488).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(100),
                                          border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          _noDataThreshold == 0.5
                                              ? '30 min'
                                              : '${_noDataThreshold.toInt()} hr${_noDataThreshold == 1.0 ? '' : 's'}',
                                          style: const TextStyle(
                                            color: Color(0xFF0D9488),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mark vehicle offline if GPS stops updating for',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [0.5, 1.0, 3.0]
                                        .map(
                                          (double h) => Expanded(
                                            child: _SegmentTab(
                                              label: h == 0.5 ? '30 min' : '${h.toInt()} hr${h == 1.0 ? '' : 's'}',
                                              isSelected: _noDataThreshold == h,
                                              activeColor: const Color(0xFF0D9488),
                                              onTap: () => setState(() => _noDataThreshold = h),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [6.0, 12.0, 24.0]
                                        .map(
                                          (double h) => Expanded(
                                            child: _SegmentTab(
                                              label: '${h.toInt()} hrs',
                                              isSelected: _noDataThreshold == h,
                                              activeColor: const Color(0xFF0D9488),
                                              onTap: () => setState(() => _noDataThreshold = h),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              
              ListView(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 100),
                children: [
                  // ── SECTION 1: EMERGENCY & TAMPERING ──
                  const _SectionHeader(title: 'EMERGENCY & TAMPERING'),
                  _GroupedCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _AlertTile(
                        title: 'SOS Emergency Alarm',
                        subtitle: 'Alert immediately when driver presses SOS panic button',
                        icon: Icons.emergency_rounded,
                        iconColor: const Color(0xFFDC2626),
                        activeTrackColor: const Color(0xFFDC2626),
                        value: _alertToggles['sos'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['sos'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      _AlertTile(
                        title: 'Main Battery Disconnection',
                        subtitle: 'Alert if vehicle battery or GPS tracker wire is disconnected',
                        icon: Icons.battery_alert_rounded,
                        iconColor: const Color(0xFFEA580C),
                        value: _alertToggles['main_battery_disconnected'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['main_battery_disconnected'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      _AlertTile(
                        title: 'Main Battery Restored',
                        subtitle: 'Notification when main vehicle power source is reconnected',
                        icon: Icons.battery_charging_full_rounded,
                        iconColor: const Color(0xFF16A34A),
                        value: _alertToggles['main_battery_connected'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['main_battery_connected'] = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),

                  // ── SECTION 2: GEOFENCE & NAVIGATION ──
                  const _SectionHeader(title: 'GEOFENCE & NAVIGATION'),
                  _GroupedCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _AlertTile(
                        title: 'Geofence Boundary Alert',
                        subtitle: 'Notify when vehicle enters or exits designated safe zones',
                        icon: Icons.fence_rounded,
                        iconColor: const Color(0xFF2563EB),
                        value: _alertToggles['geofence'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['geofence'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      _AlertTile(
                        title: 'Route Deviation Alert',
                        subtitle: 'Alert if vehicle wanders off scheduled trip route',
                        icon: Icons.alt_route_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        value: _alertToggles['route_deviation'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['route_deviation'] = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),

                  // ── SECTION 3: IGNITION & TRIPS ──
                  const _SectionHeader(title: 'IGNITION & TRIPS'),
                  _GroupedCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _AlertTile(
                        title: 'Engine ON Notification',
                        subtitle: 'Send notification when vehicle ignition is switched ON',
                        icon: Icons.key_rounded,
                        iconColor: const Color(0xFF16A34A),
                        value: _alertToggles['engine_on'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['engine_on'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      _AlertTile(
                        title: 'Engine OFF Notification',
                        subtitle: 'Send notification when vehicle ignition is switched OFF',
                        icon: Icons.power_settings_new_rounded,
                        iconColor: const Color(0xFF64748B),
                        value: _alertToggles['engine_off'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['engine_off'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      _AlertTile(
                        title: 'Trip Started Alert',
                        subtitle: 'Notify when vehicle begins a new trip journey',
                        icon: Icons.play_circle_fill_rounded,
                        iconColor: const Color(0xFF0284C7),
                        value: _alertToggles['trip_started'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['trip_started'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      _AlertTile(
                        title: 'Trip Ended Alert',
                        subtitle: 'Notify when vehicle completes trip and parks at destination',
                        icon: Icons.stop_circle_rounded,
                        iconColor: const Color(0xFF64748B),
                        value: _alertToggles['trip_ended'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['trip_ended'] = val),
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),

                  // ── SECTION 4: MOVEMENT & STOPPAGE ──
                  const _SectionHeader(title: 'MOVEMENT & STOPPAGE'),
                  _GroupedCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    isDark: isDark,
                    children: [
                      _AlertTile(
                        title: 'Overspeed Alert',
                        subtitle: 'Notify when vehicle exceeds configured speed limit',
                        icon: Icons.speed_rounded,
                        iconColor: const Color(0xFFEA580C),
                        value: _alertToggles['overspeed'] ?? true,
                        onChanged: (bool val) => setState(() => _alertToggles['overspeed'] = val),
                      ),
                      _buildGroupedDivider(borderColor),
                      // Extended Parking Alert
                      Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_parking_rounded, color: Color(0xFF2563EB), size: 19),
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Extended Parking Alert',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Alert when parked continuously beyond duration',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Gap.sm),
                                _ModernSwitch(
                                  value: _alertToggles['parking'] ?? true,
                                  onChanged: (bool val) => setState(() {
                                    _alertToggles['parking'] = val;
                                    _alertToggles['stoppage'] = val;
                                  }),
                                ),
                              ],
                            ),
                            if (_alertToggles['parking'] ?? true) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: <double>[30, 60, 120, 180]
                                    .map(
                                      (double d) => Expanded(
                                        child: _SegmentTab(
                                          label: d >= 60 ? '${(d / 60).round()} hr${d > 60 ? 's' : ''}' : '${d.round()} min',
                                          isSelected: _parkingDuration.round() == d.round(),
                                          activeColor: const Color(0xFF2563EB),
                                          onTap: () => setState(() {
                                            _parkingDuration = d;
                                            _parkingController.text = '${d.round()}';
                                          }),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildGroupedDivider(borderColor),
                      // Moving After Stoppage Alert
                      Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.directions_car_rounded, color: Color(0xFF0D9488), size: 19),
                                ),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Moving (After Stoppage)',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Alert when vehicle moves after being stopped for',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Gap.sm),
                                _ModernSwitch(
                                  value: _alertToggles['moving'] ?? true,
                                  onChanged: (bool val) => setState(() => _alertToggles['moving'] = val),
                                ),
                              ],
                            ),
                            if (_alertToggles['moving'] ?? true) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: <double>[15, 30, 60, 120]
                                    .map(
                                      (double d) => Expanded(
                                        child: _SegmentTab(
                                          label: d >= 60 ? '${(d / 60).round()} hr${d > 60 ? 's' : ''}' : '${d.round()} min',
                                          isSelected: _movingDuration.round() == d.round(),
                                          activeColor: const Color(0xFF0D9488),
                                          onTap: () => setState(() {
                                            _movingDuration = d;
                                            _movingController.text = '${d.round()}';
                                          }),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            ],
          ),
        ),

        // ── Save Action Bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: Corners.rLg,
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Settings',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

Widget _buildGroupedDivider(Color borderColor) {
  return Divider(height: 1, thickness: 1, color: borderColor, indent: 16, endIndent: 16);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({
    required this.cardBg,
    required this.borderColor,
    required this.isDark,
    required this.children,
  });

  final Color cardBg;
  final Color borderColor;
  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ModernSwitch extends StatelessWidget {
  const _ModernSwitch({
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeTrackColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color onColor = activeTrackColor ?? const Color(0xFF16A34A);
    final Color offTrack = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return isDark ? const Color(0xFF94A3B8) : Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return onColor;
        }
        return offTrack;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeTrackColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
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
          const SizedBox(width: Gap.sm),
          _ModernSwitch(
            value: value,
            activeTrackColor: activeTrackColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color selectedBg = activeColor ?? const Color(0xFF2563EB);
    final Color unselectedBg = isDark ? const Color(0xFF1E2838) : const Color(0xFFF1F5F9);
    const Color selectedText = Colors.white;
    final Color unselectedText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : unselectedBg,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: selectedBg.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? selectedText : unselectedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      VehicleStatus.moving => (const Color(0xFF2E7D32), 'Moving'),
      VehicleStatus.idle => (const Color(0xFFED6C02), 'Idle'),
      VehicleStatus.stopped => (const Color(0xFF757575), 'Parking'),
      VehicleStatus.offline => (const Color(0xFFD32F2F), 'No Data'),
      VehicleStatus.noData => (const Color(0xFF94A3B8), 'Unreachable'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: Corners.rPill,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

