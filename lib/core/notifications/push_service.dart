import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/alert.dart';

/// Top-level background handler — required by FCM to be a static/top-level
/// function. Runs in a separate isolate with no access to app state, so it
/// only does work that is safe there.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[push] background message: ${message.messageId}');

  // If there's no notification payload, this is a data-only message.
  // We must render it manually so the user actually sees the alert.
  if (message.notification == null) {
    final Map<String, dynamic> data = message.data;
    final String type = (data['type'] ?? data['alertType'] ?? data['alert_type'] ?? data['event_type'] ?? '').toString().toLowerCase();

    // Background isolates don't share state with Riverpod, so we read SharedPreferences directly.
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    bool enabled = true;
    switch (type) {
      case 'sos':
      case 'panic':
      case 'crash':
      case 'accident':
      case 'tow':
      case 'power_cut':
        enabled = prefs.getBool('ft_notif_sos') ?? true;
        break;
      case 'theft':
      case 'theft_alarm':
      case 'safety_park':
      case 'tamper':
        enabled = prefs.getBool('ft_notif_theft') ?? true;
        break;
      case 'overspeed':
      case 'overspeeding':
        enabled = prefs.getBool('ft_notif_overspeed') ?? true;
        break;
      case 'geofence_enter':
      case 'geofenceenter':
      case 'geofence_exit':
      case 'geofenceexit':
        enabled = prefs.getBool('ft_notif_geofence') ?? true;
        break;
      case 'ignition_on':
      case 'ignition_off':
      case 'moving':
      case 'start_moving':
      case 'trip_started':
      case 'trip_start':
      case 'trip':
      case 'stopped':
      case 'idle':
      case 'stoppage':
        enabled = prefs.getBool('ft_notif_ignition') ?? true;
        break;
      case 'harsh_braking':
      case 'harsh_acceleration':
        enabled = prefs.getBool('ft_notif_harsh') ?? true;
        break;
    }

    if (!enabled) return;

    final String title = (data['title'] as String?) ?? 
        (data['alert_title'] as String?) ?? 
        (data['alertTitle'] as String?) ?? 
        FleetAlert.titleFor(type);
        
    final String vehicleName = (data['vehicleName'] as String?) ?? 
        (data['vehicle_name'] as String?) ?? 
        (data['vehicleNumber'] as String?) ?? 
        '';

    String body = (data['message'] as String?) ?? 
        (data['body'] as String?) ?? 
        (data['alert_message'] as String?) ?? 
        (data['alertMessage'] as String?) ??
        (data['alertText'] as String?) ??
        (data['alert_text'] as String?) ??
        '';
        
    // If body is empty, we MUST provide some text so the notification is visible.
    if (body.isEmpty) {
      if (vehicleName.isNotEmpty) {
        body = 'Alert for $vehicleName';
      } else {
        body = 'A new $title event has occurred.';
      }
    }

    final bool isTheft = <String>['theft', 'theft_alarm', 'safety_park', 'tamper'].contains(type);
    final bool isCritical =
        <String>['sos', 'panic', 'power_cut', 'crash', 'tow'].contains(type);

    final String channelId = isTheft
        ? 'fueltracks_theft_v3'
        : (isCritical ? 'fueltracks_critical_v3' : 'fueltracks_alerts_v3');
    final String channelName = isTheft
        ? 'Theft Alarms'
        : (isCritical ? 'Critical Fleet Alerts' : 'Fleet Alerts');

    final FlutterLocalNotificationsPlugin local =
        FlutterLocalNotificationsPlugin();

    // Ensure the channel exists before showing, otherwise Android drops the notification
    // if it was never created or the app data was cleared.
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('observation_haki'),
    );
    await local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Basic initialization required to show a notification from the background isolate
    await local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: (isTheft || isCritical) ? Priority.max : Priority.high,
          fullScreenIntent: true, // Forces popup
          color: const Color(0xFF4F6BFF),
          icon: '@drawable/ic_notification',
          styleInformation: BigTextStyleInformation(body),
          groupKey: 'fueltracks_alerts',
          sound: const RawResourceAndroidNotificationSound('observation_haki'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'observation_haki.mp3',
          interruptionLevel: (isTheft || isCritical)
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: jsonEncode(data),
    );

    // Update the group summary notification so they bundle together on Android
    await local.show(
      0,
      'FuelTracker',
      'New fleet alerts',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          color: const Color(0xFF4F6BFF),
          icon: '@drawable/ic_notification',
          groupKey: 'fueltracks_alerts',
          setAsGroupSummary: true,
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────
///  PUSH NOTIFICATIONS
/// ─────────────────────────────────────────────────────────────────────
///
/// Because the socket is deliberately dead in the background, FCM is the
/// *only* channel that can reach a user whose app is closed. This service:
///
///  * requests notification permission at a contextual moment (not at launch)
///  * registers/refreshes the device token with the backend
///  * renders foreground messages through flutter_local_notifications
///    (FCM does not display them itself while the app is visible)
///  * routes taps to the right screen via [onNotificationTap]
class PushService {
  PushService({
    required Future<void> Function(String token) onTokenRefresh,
    required void Function(Map<String, dynamic> data) onNotificationTap,
    required void Function(Map<String, dynamic> data) onForegroundMessage,
    required bool Function(String type) isNotificationEnabled,
  })  : _onTokenRefresh = onTokenRefresh,
        _onNotificationTap = onNotificationTap,
        _onForegroundMessage = onForegroundMessage,
        _isNotificationEnabled = isNotificationEnabled;

  final Future<void> Function(String token) _onTokenRefresh;
  final void Function(Map<String, dynamic> data) _onNotificationTap;
  final void Function(Map<String, dynamic> data) _onForegroundMessage;
  final bool Function(String type) _isNotificationEnabled;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  bool _initialized = false;

  /// High-importance channel so critical alerts (SOS, power cut) can pop
  /// as heads-up notifications on Android 8+.
  static const AndroidNotificationChannel _criticalChannel =
      AndroidNotificationChannel(
    'fueltracks_critical_v3',
    'Critical Fleet Alerts',
    description: 'SOS, power disconnection and tamper alerts.',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('observation_haki'),
  );

  static const AndroidNotificationChannel _theftChannel =
      AndroidNotificationChannel(
    'fueltracks_theft_v3',
    'Theft Alarms',
    description: 'Alerts when unauthorized vehicle movement is detected.',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('observation_haki'),
  );

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
    'fueltracks_alerts_v3',
    'Fleet Alerts',
    description: 'Overspeeding, geofence and ignition notifications.',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('observation_haki'),
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _setupLocalNotifications();

    // Show alerts on iOS while the app is foregrounded.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _fgSub = FirebaseMessaging.onMessage.listen(_handleForeground);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage m) => _onNotificationTap(_dataOf(m)),
    );

    // Cold start from a notification tap.
    final RemoteMessage? initial = await _fcm.getInitialMessage();
    if (initial != null) {
      // Defer so the router is mounted before we navigate.
      Future<void>.delayed(
        const Duration(milliseconds: 900),
        () => _onNotificationTap(_dataOf(initial)),
      );
    }

    _tokenSub = _fcm.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@drawable/ic_notification');

    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        if (r.payload == null || r.payload!.isEmpty) return;
        try {
          _onNotificationTap(
            jsonDecode(r.payload!) as Map<String, dynamic>,
          );
        } catch (_) {/* malformed payload — ignore */}
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
        _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(_criticalChannel);
    await androidImpl?.createNotificationChannel(_theftChannel);
    await androidImpl?.createNotificationChannel(_generalChannel);
  }

  /// Contextual permission request. Call this after the user has seen the
  /// dashboard once — never on the very first frame.
  Future<bool> requestPermission() async {
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final bool granted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (granted) await syncToken();
    return granted;
  }

  Future<bool> hasPermission() async {
    final NotificationSettings s = await _fcm.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Pushes the current device token to the backend so it can target alerts.
  Future<String?> syncToken() async {
    try {
      // APNs must be ready on iOS before an FCM token exists.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final String? apns = await _fcm.getAPNSToken();
        if (apns == null) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      final String? token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _onTokenRefresh(token);
      }
      return token;
    } catch (e) {
      debugPrint('[push] token sync failed: $e');
      return null;
    }
  }

  void _handleForeground(RemoteMessage message) {
    final Map<String, dynamic> data = _dataOf(message);
    final String type = (data['type'] ?? data['alertType'] ?? data['alert_type'] ?? data['event_type'] ?? '').toString().toLowerCase();

    if (!_isNotificationEnabled(type)) {
      debugPrint('[push] notification disabled for type $type, ignoring');
      return;
    }

    _onForegroundMessage(data);

    final RemoteNotification? n = message.notification;
    final String title = n?.title ??
        (data['title'] as String?) ??
        (data['alert_title'] as String?) ??
        (data['alertTitle'] as String?) ??
        FleetAlert.titleFor(type);
        
    final String vehicleName = (data['vehicleName'] as String?) ?? 
        (data['vehicle_name'] as String?) ?? 
        (data['vehicleNumber'] as String?) ?? 
        '';

    String body = n?.body ?? 
        (data['message'] as String?) ?? 
        (data['body'] as String?) ?? 
        (data['alert_message'] as String?) ?? 
        (data['alertMessage'] as String?) ??
        (data['alertText'] as String?) ??
        (data['alert_text'] as String?) ??
        '';
        
    if (body.isEmpty) {
      if (vehicleName.isNotEmpty) {
        body = 'Alert for $vehicleName';
      } else {
        body = 'A new $title event has occurred.';
      }
    }
    final bool isTheft = <String>['theft', 'theft_alarm', 'safety_park', 'tamper'].contains(type);
    final bool isCritical = <String>['sos', 'panic', 'power_cut', 'crash', 'tow']
        .contains(type);

    final AndroidNotificationChannel channel = isTheft
        ? _theftChannel
        : (isCritical ? _criticalChannel : _generalChannel);

    final int notifId = data['alertId'] != null ? data['alertId'].hashCode : message.hashCode;
    _local.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: (isTheft || isCritical) ? Priority.max : Priority.high,
          fullScreenIntent: true,
          color: const Color(0xFF4F6BFF),
          icon: '@drawable/ic_notification',
          styleInformation: BigTextStyleInformation(body),
          groupKey: 'fueltracks_alerts',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: (isTheft || isCritical)
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
      payload: jsonEncode(data),
    );

    // Update the group summary notification so they bundle together on Android
    _local.show(
      0,
      'FuelTracker',
      'New fleet alerts',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          color: const Color(0xFF4F6BFF),
          icon: '@drawable/ic_notification',
          groupKey: 'fueltracks_alerts',
          setAsGroupSummary: true,
        ),
      ),
    );
  }

  Map<String, dynamic> _dataOf(RemoteMessage m) => <String, dynamic>{
        ...m.data,
        if (m.notification?.title != null) 'title': m.notification!.title,
        if (m.notification?.body != null) 'message': m.notification!.body,
      };

  Future<void> subscribeToOrg(String orgId) async {
    if (orgId.isEmpty) return;
    try {
      await _fcm.subscribeToTopic('org_$orgId');
    } catch (e) {
      debugPrint('[push] subscribe failed: $e');
    }
  }

  Future<void> unsubscribeFromOrg(String orgId) async {
    if (orgId.isEmpty) return;
    try {
      await _fcm.unsubscribeFromTopic('org_$orgId');
    } catch (_) {}
  }

  /// On logout we must delete the token, otherwise the next user on this
  /// device keeps receiving the previous customer's fleet alerts.
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[push] delete token failed: $e');
    }
  }

  void dispose() {
    _fgSub?.cancel();
    _openedSub?.cancel();
    _tokenSub?.cancel();
  }
}
