import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/report_models.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/billing/renewals_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/geofences/geofences_screen.dart';
import '../../features/live_map/live_map_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reports/report_detail_screen.dart';
import '../../features/reports/reports_hub_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/routes/routes_screen.dart';
import '../../features/trips/trips_screen.dart';
import '../../features/vehicle/vehicle_detail_screen.dart';
import '../../providers/auth_provider.dart';

final GlobalKey<NavigatorState> _rootKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Deep-link target set by a notification tap before the router is ready.
final StateProvider<String?> pendingDeepLinkProvider =
    StateProvider<String?>((Ref ref) => null);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<AuthStage> stage =
      ValueNotifier<AuthStage>(ref.read(authProvider).stage);

  ref.listen<AuthState>(authProvider, (AuthState? _, AuthState next) {
    stage.value = next.stage;
  });

  ref.onDispose(stage.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: stage,

    redirect: (BuildContext context, GoRouterState state) {
      final AuthStage current = ref.read(authProvider).stage;
      final String path = state.matchedLocation;

      const Set<String> publicPaths = <String>{
        '/login',
        '/forgot-password',
        '/reset-password',
      };
      final bool isPublic = publicPaths.any(path.startsWith);

      // Still resolving the token — hold on the splash.
      if (current == AuthStage.unknown) {
        return path == '/splash' ? null : '/splash';
      }

      if (current == AuthStage.unauthenticated) {
        return isPublic ? null : '/login';
      }

      // Authenticated: never leave the user stranded on splash/login.
      if (path == '/splash' || path == '/login') return '/dashboard';

      return null;
    },

    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext c, GoRouterState s) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext c, GoRouterState s) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext c, GoRouterState s) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (BuildContext c, GoRouterState s) => ResetPasswordScreen(
          token: s.uri.queryParameters['token'] ?? (s.extra as String? ?? ''),
        ),
      ),

      // ── Authenticated shell (bottom navigation) ──────────────────
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) =>
            AppShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/dashboard',
                builder: (BuildContext c, GoRouterState s) =>
                    const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/map',
                builder: (BuildContext c, GoRouterState s) => LiveMapScreen(
                  focusVehicleId: s.uri.queryParameters['focus'],
                ),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/reports',
                builder: (BuildContext c, GoRouterState s) =>
                    ReportsHubScreen(
                  initialVehicleId: s.uri.queryParameters['vehicle'],
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':type',
                    parentNavigatorKey: _rootKey,
                    builder: (BuildContext c, GoRouterState s) {
                      final String raw = s.pathParameters['type'] ?? '';
                      final ReportType type = ReportType.values.firstWhere(
                        (ReportType t) => t.name == raw,
                        orElse: () => ReportType.trip,
                      );
                      return ReportDetailScreen(
                        type: type,
                        initialVehicleId: s.uri.queryParameters['vehicle'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/trips',
                builder: (BuildContext c, GoRouterState s) =>
                    const TripsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (BuildContext c, GoRouterState s) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes above the shell ───────────────────────
      GoRoute(
        path: '/vehicle/:id',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext c, GoRouterState s) =>
            VehicleDetailScreen(vehicleId: s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/geofences',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext c, GoRouterState s) => const GeofencesScreen(),
      ),
      GoRoute(
        path: '/renewals',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext c, GoRouterState s) => const RenewalsScreen(),
      ),
      GoRoute(
        path: '/routes',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext c, GoRouterState s) => const RoutesScreen(),
      ),
    ],

    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Back to fleet'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

/// Maps an FCM payload to an in-app destination.
String routeForNotification(Map<String, dynamic> data) {
  final String type = (data['type'] ?? '').toString().toLowerCase();
  final String? vehicleId =
      (data['vehicleId'] ?? data['vehicle_id'])?.toString();

  if (type.contains('renewal') || type.contains('billing')) return '/renewals';
  if (type == 'route_deviation' || type == 'trip_started' || type == 'trip_ended') return '/routes';
  if (vehicleId != null && vehicleId.isNotEmpty) return '/vehicle/$vehicleId';
  return '/alerts';
}
