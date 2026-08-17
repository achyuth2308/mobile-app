import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/backend_capabilities.dart';
import '../../core/network/api_exception.dart';
import '../../core/realtime/socket_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/vehicle_icons.dart';
import '../../data/models/alert.dart';
import '../../providers/core_providers.dart';
import '../../providers/fleet_provider.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/connectivity_banner.dart';
import '../shell/app_shell.dart';

/// Paginated historical alerts, grouped by day.
///
/// Foreground `alert:new` socket events prepend to the list; while the app is
/// backgrounded the same events arrive as FCM push instead.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  final ScrollController _scroll = ScrollController();

  final List<FleetAlert> _alerts = <FleetAlert>[];
  String? _typeFilter;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  StreamSubscription<SocketEvent>? _socketSub;

  static const List<(String?, String)> _filters = <(String?, String)>[
    (null, 'All'),
    ('geofence', 'Geofence'),
    ('overspeed', 'Overspeed'),
    ('ignition', 'Ignition & Movement'),
    ('sos', 'Safety & Theft'),
    ('power', 'Power & Battery'),
    ('harsh', 'Harsh Events'),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true);
      _listenToSocket();
    });
  }

  bool _matchesFilter(FleetAlert alert, String? filter) {
    if (filter == null || filter.isEmpty) return true;
    final String type = alert.type.toLowerCase().trim();
    final String title = alert.title.toLowerCase();
    final String message = alert.message.toLowerCase();

    return switch (filter) {
      'geofence' || 'geofence_enter' || 'geofence_exit' || 'geofenceenter' || 'geofenceexit' =>
        type.contains('geofence') ||
            title.contains('geofence') ||
            message.contains('geofence') ||
            message.contains('fence'),
      'overspeed' || 'overspeeding' =>
        type.contains('overspeed') ||
            title.contains('overspeed') ||
            message.contains('overspeed') ||
            message.contains('speed limit') ||
            message.contains('speeding'),
      'sos' || 'safety' =>
        type == 'sos' ||
            type == 'panic' ||
            type == 'theft' ||
            type == 'theft_alarm' ||
            type == 'tamper' ||
            type == 'tow' ||
            type == 'crash' ||
            type == 'accident' ||
            title.contains('sos') ||
            title.contains('panic') ||
            title.contains('theft') ||
            title.contains('tamper') ||
            title.contains('crash') ||
            title.contains('tow') ||
            message.contains('sos') ||
            message.contains('theft'),
      'ignition' || 'ignition_on' || 'movement' =>
        type.contains('ignition') ||
            type.contains('trip') ||
            type == 'moving' ||
            type == 'start_moving' ||
            type == 'trip_started' ||
            type == 'trip_start' ||
            type == 'stopped' ||
            type == 'idle' ||
            type == 'stoppage' ||
            title.contains('ignition') ||
            title.contains('trip') ||
            title.contains('moving') ||
            title.contains('stopped') ||
            title.contains('idle') ||
            title.contains('stoppage') ||
            message.contains('trip') ||
            message.contains('started'),
      'power' || 'power_cut' || 'battery' =>
        type == 'power_cut' ||
            type == 'power_disconnected' ||
            type == 'low_battery' ||
            type.contains('power') ||
            type.contains('battery') ||
            title.contains('power') ||
            title.contains('battery') ||
            message.contains('battery') ||
            message.contains('power'),
      'harsh' || 'harsh_braking' =>
        type.contains('harsh') ||
            type == 'harsh_braking' ||
            type == 'harsh_acceleration' ||
            title.contains('harsh') ||
            title.contains('braking') ||
            title.contains('acceleration'),
      _ =>
        type == filter.toLowerCase() ||
            type.contains(filter.toLowerCase()) ||
            title.contains(filter.toLowerCase()) ||
            message.contains(filter.toLowerCase()),
    };
  }

  void _listenToSocket() {
    _socketSub = ref.read(socketServiceProvider).events$.listen((SocketEvent event) {
      if (event.name == 'alert:new' || event.name == 'geofence:event') {
        try {
          FleetAlert newAlert = FleetAlert.fromJson(event.payload);
          
          if (newAlert.vehicleName == null && newAlert.vehicleId != null) {
            final vehicle = ref.read(fleetProvider).vehicles.where((v) => v.id == newAlert.vehicleId).firstOrNull;
            if (vehicle != null) {
              newAlert = newAlert.copyWith(vehicleName: vehicle.name);
            }
          }
          
          final String type = newAlert.type.toLowerCase();

          final NotificationPreferences prefs = ref.read(notificationPreferencesProvider);
          final bool isCategoryEnabled = switch (type) {
            'sos' || 'panic' || 'crash' || 'accident' || 'tow' || 'power_cut' => prefs.sos,
            'theft' || 'theft_alarm' || 'tamper' => prefs.theft,
            'overspeed' || 'overspeeding' => prefs.overspeed,
            'geofence' || 'geofence_enter' || 'geofenceenter' || 'geofence_exit' || 'geofenceexit' => prefs.geofence,
            'ignition_on' || 'ignition_off' || 'moving' || 'start_moving' || 'stopped' || 'idle' || 'stoppage' => prefs.ignition,
            'harsh_braking' || 'harsh_acceleration' => prefs.harsh,
            _ => true,
          };

          if (!isCategoryEnabled) return;

          if (!mounted) return;
          if (_matchesFilter(newAlert, _typeFilter)) {
            setState(() {
              _alerts.insert(0, newAlert);
            });
          }
        } catch (e) {
          debugPrint('Error parsing live socket alert: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _socketSub?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    }

    try {
      final List<FleetAlert> data =
          await ref.read(alertRepositoryProvider).getAlerts(
                page: _page,
                type: _typeFilter,
              );

      if (!mounted) return;
      setState(() {
        if (reset) _alerts.clear();
        _alerts.addAll(data);
        _hasMore = data.length >= 30;
        _loading = false;
        _loadingMore = false;
      });

      // Clear the tab badge once alerts have been seen.
      ref.read(unreadAlertsProvider.notifier).state = 0;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() {
      _loadingMore = true;
      _page++;
    });
    await _load();
  }

  bool _markingRead = false;

  Future<void> _markAllAsRead() async {
    final List<FleetAlert> visibleAlerts = _typeFilter == null
        ? _alerts
        : _alerts.where((FleetAlert a) => _matchesFilter(a, _typeFilter)).toList();
    final int countToMark = visibleAlerts.where((FleetAlert a) => !a.isRead).length;
    if (countToMark == 0) return;

    unawaited(HapticFeedback.mediumImpact());
    setState(() => _markingRead = true);

    try {
      await ref.read(alertRepositoryProvider).markAllAsRead();
      if (!mounted) return;

      setState(() {
        for (int i = 0; i < _alerts.length; i++) {
          if (_matchesFilter(_alerts[i], _typeFilter)) {
            _alerts[i] = _alerts[i].copyWith(isRead: true);
          }
        }
        _markingRead = false;
      });

      ref.read(unreadAlertsProvider.notifier).state = 0;
      FlutterLocalNotificationsPlugin().cancelAll();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: Gap.sm),
              Text('$countToMark alert${countToMark > 1 ? 's' : ''} marked as read'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  void _markSingleAsRead(FleetAlert alert) {
    if (alert.isRead) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(ref.read(alertRepositoryProvider).markAsRead(alert.id));
    setState(() {
      final int i = _alerts.indexWhere((FleetAlert a) => a.id == alert.id);
      if (i != -1) _alerts[i] = alert.copyWith(isRead: true);
    });
    final int remainingUnread = _alerts.where((FleetAlert a) => !a.isRead).length;
    ref.read(unreadAlertsProvider.notifier).state = remainingUnread;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<FleetAlert> visibleAlerts = _typeFilter == null
        ? _alerts
        : _alerts.where((FleetAlert a) => _matchesFilter(a, _typeFilter)).toList(growable: false);
    final Map<String, List<FleetAlert>> grouped = _groupByDay(visibleAlerts);
    final int unreadCount = visibleAlerts.where((FleetAlert a) => !a.isRead).length;

    final String currentFilterLabel = _filters.firstWhere(
      ((String?, String) f) => f.$1 == _typeFilter,
      orElse: () => (null, 'All'),
    ).$2;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // ── Header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.sm),
              child: Row(
                children: <Widget>[
                  Text('Alerts', style: theme.textTheme.headlineMedium),
                  const Spacer(),
                  if (visibleAlerts.isNotEmpty)
                    if (unreadCount > 0)
                      FilledButton.tonalIcon(
                        onPressed: _markingRead ? null : _markAllAsRead,
                        icon: _markingRead
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.done_all_rounded, size: 16),
                        label: Text('Mark all read ($unreadCount)'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.check_circle_outline_rounded,
                                size: 15,
                                color: theme.colorScheme.outline
                                    .withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'All read',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.outline
                                    .withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),

            // ── Filters ──────────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
                itemBuilder: (BuildContext context, int i) {
                  final (String?, String) f = _filters[i];
                  final bool selected = _typeFilter == f.$1;

                  return FilterChip(
                    label: Text(f.$2),
                    selected: selected,
                    showCheckmark: false,
                    avatar: f.$1 == null
                        ? null
                        : Icon(
                            switch (f.$1) {
                              'geofence' => Icons.fence_rounded,
                              'overspeed' => Icons.speed_rounded,
                              'ignition' => Icons.power_settings_new_rounded,
                              'sos' => Icons.warning_amber_rounded,
                              'power' => Icons.battery_alert_rounded,
                              'harsh' => Icons.emergency_rounded,
                              _ => Icons.notifications_active_rounded,
                            },
                            size: 16,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    selectedColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onSelected: (_) {
                      if (_typeFilter == f.$1) return;
                      setState(() => _typeFilter = f.$1);
                      _load(reset: true);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: Gap.sm),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Gap.lg),
              child: OfflineNotice(),
            ),

            // ── List ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const ListSkeleton(count: 5)
                  : _error != null && visibleAlerts.isEmpty
                      ? ErrorState(
                          message: _error!,
                          onRetry: () => _load(reset: true),
                        )
                      : visibleAlerts.isEmpty
                          ? EmptyState(
                              icon: _typeFilter != null
                                  ? Icons.filter_alt_off_outlined
                                  : (BackendCapabilities.alertsHistory
                                      ? Icons.notifications_off_outlined
                                      : Icons.cloud_sync_outlined),
                              title: _typeFilter != null
                                  ? 'No $currentFilterLabel alerts'
                                  : (BackendCapabilities.alertsHistory
                                      ? 'No alerts'
                                      : 'Alert history coming soon'),
                              message: _typeFilter != null
                                  ? 'No $currentFilterLabel alerts have been recorded.'
                                  : (BackendCapabilities.alertsHistory
                                      ? 'When your vehicles trigger an event — '
                                          'overspeeding, a geofence breach or an '
                                          'SOS — it will appear here.'
                                      : 'Your account is not yet enabled for stored '
                                          'alert history. Live alerts still arrive as '
                                          'push notifications and appear here while '
                                          'the app is open.'),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _load(reset: true),
                              child: ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                    Gap.lg, Gap.sm, Gap.lg, Gap.navClearance),
                                itemCount: _flatCount(grouped, visibleAlerts.length) +
                                    (_hasMore ? 1 : 0),
                                itemBuilder: (BuildContext context, int index) =>
                                    _buildItem(grouped, index),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  int _flatCount(Map<String, List<FleetAlert>> grouped, int visibleCount) =>
      grouped.length + visibleCount;

  Widget _buildItem(Map<String, List<FleetAlert>> grouped, int index) {
    int cursor = 0;

    for (final MapEntry<String, List<FleetAlert>> entry in grouped.entries) {
      if (index == cursor) return _DayHeader(label: entry.key);
      cursor++;

      if (index < cursor + entry.value.length) {
        final FleetAlert alert = entry.value[index - cursor];
        return AlertTile(
          alert: alert,
          onTap: () => _openAlert(alert),
          onMarkRead: alert.isRead ? null : () => _markSingleAsRead(alert),
        );
      }
      cursor += entry.value.length;
    }

    return const Padding(
      padding: EdgeInsets.all(Gap.xl),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  void _openAlert(FleetAlert alert) {
    if (!alert.isRead) {
      ref.read(alertRepositoryProvider).markAsRead(alert.id);
      setState(() {
        final int i = _alerts.indexWhere((FleetAlert a) => a.id == alert.id);
        if (i != -1) _alerts[i] = alert.copyWith(isRead: true);
      });
      final int remainingUnread = _alerts.where((FleetAlert a) => !a.isRead).length;
      ref.read(unreadAlertsProvider.notifier).state = remainingUnread;
    }

    if (alert.vehicleId != null) {
      context.push('/vehicle/${alert.vehicleId}');
    }
  }

  Map<String, List<FleetAlert>> _groupByDay(List<FleetAlert> alerts) {
    final Map<String, List<FleetAlert>> out = <String, List<FleetAlert>>{};
    final DateTime now = DateTime.now();

    for (final FleetAlert a in alerts) {
      final DateTime? t = a.createdAt;
      String key;

      if (t == null) {
        key = 'Earlier';
      } else {
        final int diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(t.year, t.month, t.day))
            .inDays;
        key = switch (diff) {
          0 => 'Today',
          1 => 'Yesterday',
          < 7 => '$diff days ago',
          _ => Fmt.date(t),
        };
      }

      out.putIfAbsent(key, () => <FleetAlert>[]).add(a);
    }
    return out;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, Gap.lg, 0, Gap.sm),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class AlertTile extends StatelessWidget {
  const AlertTile({
    required this.alert,
    required this.onTap,
    this.onMarkRead,
    super.key,
  });

  final FleetAlert alert;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color color = switch (alert.severity) {
      AlertSeverity.critical => AppColors.danger,
      AlertSeverity.warning => AppColors.idle,
      AlertSeverity.info => AppColors.signal,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      decoration: BoxDecoration(
        color: alert.isRead
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: Corners.rMd,
        border: Border.all(
          color: !alert.isRead
              ? color.withOpacity(alert.severity == AlertSeverity.critical ? 0.5 : 0.25)
              : theme.colorScheme.outlineVariant.withOpacity(0.4),
          width: !alert.isRead ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: Corners.rMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: Corners.rMd,
          child: Padding(
            padding: Gap.cardTight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: Corners.rXs,
                  ),
                  child: Icon(
                    VehicleIcons.forAlert(alert.type),
                    size: 19,
                    color: color,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              alert.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: alert.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!alert.isRead) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        alert.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: alert.isRead
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                      Row(
                        children: <Widget>[
                          if (alert.vehicleName != null) ...<Widget>[
                            Icon(Icons.directions_car_rounded,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                alert.vehicleName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(letterSpacing: 0),
                              ),
                            ),
                            const SizedBox(width: Gap.md),
                          ],
                          Icon(Icons.schedule_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            Fmt.relative(alert.createdAt),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(letterSpacing: 0),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!alert.isRead && onMarkRead != null) ...<Widget>[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Mark as read',
                    icon: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onMarkRead,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
