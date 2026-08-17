/// Central runtime configuration.
///
/// Values are supplied at build time via `--dart-define`, so no secret or
/// environment-specific URL is ever hard-committed into the binary source.
///
/// Example:
/// ```
/// flutter run \
///   --dart-define=API_BASE_URL=https://api.fueltracks.in \
///   --dart-define=SOCKET_URL=https://api.fueltracks.in \
///   --dart-define=ENV=production
///
/// Maps need no key: tiles come from OpenStreetMap.
/// ```
library;

enum AppEnvironment { development, staging, production }

class AppConfig {
  const AppConfig._();

  // ── Environment ──────────────────────────────────────────────────
  static const String _envRaw =
      String.fromEnvironment('ENV', defaultValue: 'development');

  static AppEnvironment get environment => switch (_envRaw) {
        'production' => AppEnvironment.production,
        'staging' => AppEnvironment.staging,
        _ => AppEnvironment.development,
      };

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDebugLoggingEnabled => !isProduction;

  // ── Endpoints ────────────────────────────────────────────────────
  /// Root of the Node.js REST API. All calls are prefixed with `/api`.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.fueltracks.in',
  );

  /// Socket.io origin (usually identical to [apiBaseUrl]).
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://api.fueltracks.in',
  );

  static String get apiRoot => '$apiBaseUrl/api';

  /// Socket.io is mounted at the server ROOT (`/socket.io/`), NOT under
  /// `/api` — verified against production. Changing this breaks real-time.
  static const String socketPath = '/socket.io';

  /// OSM's tile usage policy requires a descriptive User-Agent; generic or
  /// absent UAs get blocked.
  static const String tileUserAgent = 'in.fueltracks.app';

  // ── Timeouts ─────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // ── Real-time tuning ─────────────────────────────────────────────
  /// Marker positions are re-rendered at most this often to keep the
  /// map at 60fps even when hundreds of `fleet:update` frames arrive.
  static const Duration mapThrottle = Duration(milliseconds: 200);

  /// A vehicle is considered "offline" if its last packet is older than this.
  static const Duration offlineThreshold = Duration(minutes: 10);

  /// Idle = ignition ON but speed ~0 for longer than this.
  static const Duration idleThreshold = Duration(minutes: 5);

  static const double overspeedDefaultKph = 60;

  // ── Socket reconnect policy ──────────────────────────────────────
  static const int socketReconnectAttempts = 12;
  static const Duration socketReconnectDelay = Duration(seconds: 2);
  static const Duration socketReconnectDelayMax = Duration(seconds: 20);

  // ── Legal / compliance links ─────────────────────────────────────
  static const String privacyPolicyUrl = 'https://fueltracks.com/privacy';
  static const String termsUrl = 'https://fueltracks.com/terms';
  static const String supportEmail = 'support@fueltracks.com';

  // ── Pagination ───────────────────────────────────────────────────
  static const int defaultPageSize = 25;
}
