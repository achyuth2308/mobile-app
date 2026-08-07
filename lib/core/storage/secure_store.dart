import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Credential storage.
///
/// * JWT + refresh token → Keychain / EncryptedSharedPreferences.
/// * Non-sensitive UI preferences → SharedPreferences.
class SecureStore {
  SecureStore(this._secure, this._prefs);

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  static const _kToken = 'ft_access_token';
  static const _kRefresh = 'ft_refresh_token';
  static const _kUser = 'ft_cached_user';
  static const _kFcm = 'ft_fcm_token';

  static const _kThemeMode = 'ft_theme_mode';
  static const _kMapType = 'ft_map_type';
  static const _kUnits = 'ft_units';
  static const _kOnboarded = 'ft_onboarded';
  static const _kLastVehicle = 'ft_last_vehicle';
  static const _kNotifPrompted = 'ft_notif_prompted';

  static Future<SecureStore> create() async {
    const FlutterSecureStorage secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return SecureStore(secure, prefs);
  }

  // ── Tokens ───────────────────────────────────────────────────────
  Future<String?> readToken() => _secure.read(key: _kToken);
  Future<void> writeToken(String v) => _secure.write(key: _kToken, value: v);

  Future<String?> readRefreshToken() => _secure.read(key: _kRefresh);
  Future<void> writeRefreshToken(String v) =>
      _secure.write(key: _kRefresh, value: v);

  Future<String?> readFcmToken() => _secure.read(key: _kFcm);
  Future<void> writeFcmToken(String v) => _secure.write(key: _kFcm, value: v);

  // ── Cached user (for instant cold-start render) ──────────────────
  Future<Map<String, dynamic>?> readUser() async {
    final String? raw = await _secure.read(key: _kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeUser(Map<String, dynamic> user) =>
      _secure.write(key: _kUser, value: jsonEncode(user));

  /// Wipes every credential. Called on logout and on hard 401.
  Future<void> clearSession() async {
    await Future.wait<void>(<Future<void>>[
      _secure.delete(key: _kToken),
      _secure.delete(key: _kRefresh),
      _secure.delete(key: _kUser),
    ]);
    await _prefs.remove(_kLastVehicle);
  }

  // ── Preferences ──────────────────────────────────────────────────
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'dark';
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  String get mapType => _prefs.getString(_kMapType) ?? 'normal';
  Future<void> setMapType(String v) => _prefs.setString(_kMapType, v);

  String get units => _prefs.getString(_kUnits) ?? 'metric';
  Future<void> setUnits(String v) => _prefs.setString(_kUnits, v);

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool v) => _prefs.setBool(_kOnboarded, v);

  bool get notificationPrompted => _prefs.getBool(_kNotifPrompted) ?? false;
  Future<void> setNotificationPrompted(bool v) =>
      _prefs.setBool(_kNotifPrompted, v);

  String? get lastVehicleId => _prefs.getString(_kLastVehicle);
  Future<void> setLastVehicleId(String v) => _prefs.setString(_kLastVehicle, v);

  bool get notifSos => _prefs.getBool('ft_notif_sos') ?? true;
  Future<void> setNotifSos(bool v) => _prefs.setBool('ft_notif_sos', v);

  bool get notifTheft => _prefs.getBool('ft_notif_theft') ?? true;
  Future<void> setNotifTheft(bool v) => _prefs.setBool('ft_notif_theft', v);

  bool get notifOverspeed => _prefs.getBool('ft_notif_overspeed') ?? true;
  Future<void> setNotifOverspeed(bool v) =>
      _prefs.setBool('ft_notif_overspeed', v);

  bool get notifGeofence => _prefs.getBool('ft_notif_geofence') ?? true;
  Future<void> setNotifGeofence(bool v) =>
      _prefs.setBool('ft_notif_geofence', v);

  bool get notifIgnition => _prefs.getBool('ft_notif_ignition') ?? true;
  Future<void> setNotifIgnition(bool v) =>
      _prefs.setBool('ft_notif_ignition', v);

  bool get notifHarsh => _prefs.getBool('ft_notif_harsh') ?? true;
  Future<void> setNotifHarsh(bool v) => _prefs.setBool('ft_notif_harsh', v);
}
