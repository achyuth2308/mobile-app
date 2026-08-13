import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_store.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';
import 'providers/auth_provider.dart';
import 'providers/core_providers.dart';
import 'providers/fleet_provider.dart';
import 'providers/lifecycle_provider.dart';
import 'shared/widgets/connectivity_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only: a fleet map in landscape on a phone is worse, not better,
  // and it doubles the layout surface we have to QA.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // ── Firebase (non-fatal if it fails: the app still works without push) ──
  try {
    if (!kIsWeb) {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    }
  } catch (e) {
    debugPrint('[main] Firebase init failed: $e');
  }

  final SecureStore store = await SecureStore.create();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Hook Crashlytics/Sentry here.
  };

  runApp(
    ProviderScope(
      overrides: <Override>[
        secureStoreProvider.overrideWithValue(store),
      ],
      child: const FuelTracksApp(),
    ),
  );
}

class FuelTracksApp extends ConsumerStatefulWidget {
  const FuelTracksApp({super.key});

  @override
  ConsumerState<FuelTracksApp> createState() => _FuelTracksAppState();
}

class _FuelTracksAppState extends ConsumerState<FuelTracksApp> {
  PushService? _push;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    // 1 ─ Connectivity watcher (drives the offline banner).
    await ref.read(connectivityServiceProvider).initialize();

    // 2 ─ Resolve the session: cached user renders instantly, /auth/me confirms.
    await ref.read(authProvider.notifier).bootstrap();

    // 3 ─ Push notifications — the only channel while backgrounded.
    if (!kIsWeb) {
      unawaited(_initPush());
    }
  }

  Future<void> _initPush() async {
    if (kIsWeb) {
      debugPrint('[main] Skipping push notifications on Web (no Firebase config)');
      return;
    }
    
    try {
      final PushService push = PushService(
        onTokenRefresh: (String token) async {
          await ref.read(secureStoreProvider).writeFcmToken(token);
          if (ref.read(authProvider).isAuthenticated) {
            await ref.read(authRepositoryProvider).registerDevice(
                  fcmToken: token,
                  platform: defaultTargetPlatform == TargetPlatform.iOS
                      ? 'ios'
                      : 'android',
                );
          }
        },
        onNotificationTap: _handleNotificationTap,
        onForegroundMessage: _handleForegroundMessage,
        isNotificationEnabled: (String type) {
          final NotificationPreferences prefs =
              ref.read(notificationPreferencesProvider);
          return switch (type.toLowerCase()) {
            'sos' ||
            'panic' ||
            'crash' ||
            'accident' ||
            'tow' ||
            'power_cut' =>
              prefs.sos,
            'theft' || 'theft_alarm' || 'tamper' => prefs.theft,
            'overspeed' || 'overspeeding' => prefs.overspeed,
            'geofence_enter' ||
            'geofenceenter' ||
            'geofence_exit' ||
            'geofenceexit' =>
              prefs.geofence,
            'ignition_on' ||
            'ignition_off' ||
            'moving' ||
            'start_moving' ||
            'trip_started' ||
            'trip_start' ||
            'trip' ||
            'stopped' ||
            'idle' ||
            'stoppage' =>
              prefs.ignition,
            'harsh_braking' || 'harsh_acceleration' => prefs.harsh,
            _ => true,
          };
        },
      );

      await push.initialize();
      _push = push;

      // Ask for notification permissions so Android 13+ users actually receive them
      final bool hasPerm = await push.requestPermission();
      if (hasPerm) {
        await push.syncToken();
      }

      final String? orgId = ref.read(authProvider).user?.orgId;
      if (orgId != null && orgId.isNotEmpty) {
        await push.subscribeToOrg(orgId);
      }
    } catch (e) {
      debugPrint('[main] push init failed: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final String route = routeForNotification(data);
    try {
      ref.read(routerProvider).go(route);
    } catch (e) {
      debugPrint('[main] deep link failed: $e');
    }
  }

  void _handleForegroundMessage(Map<String, dynamic> data) {
    // Bump the alerts badge; the socket also delivers `alert:new` when
    // foregrounded, so the badge is the cheap common denominator.
    ref.read(unreadAlertsProvider.notifier).state++;

    // A push may indicate state we have not seen yet.
    if (ref.read(authProvider).isAuthenticated) {
      unawaited(ref.read(fleetProvider.notifier).load(silent: true));
    }
  }

  @override
  void dispose() {
    _push?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(routerProvider);
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'FuelTracks',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (BuildContext context, Widget? child) {
        // Order matters:
        //   AppLifecycleObserver  → enforces the socket battery contract
        //   ConnectivityReconnector → resumes real-time when the net returns
        //   ConnectivityBanner    → persistent offline indicator on top
        return AppLifecycleObserver(
          child: ConnectivityReconnector(
            child: ConnectivityBanner(
              child: MediaQuery.withClampedTextScaling(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.35,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}
