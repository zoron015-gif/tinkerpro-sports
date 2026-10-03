import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  AppSession._(this._preferences) : _apiToken = null;

  static const _authenticatedKey = 'session_authenticated';
  static const _lastBookingTypeKey = 'session_last_booking_type';
  static const _apiTokenKey = 'session_api_token';
  static const _roleKey = 'session_role';
  static const _accountEmailKey = 'session_account_email';
  static const _merchantProfileEmailKey = 'merchant_profile_email';
  static const _bookingStatusBannerDismissedPrefix =
      'booking_status_banner_dismissed_';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final SharedPreferences _preferences;
  String? _apiToken;

  bool get isAuthenticated => _preferences.getBool(_authenticatedKey) ?? false;

  bool get matchNotificationsEnabled =>
      _preferences.getBool(_matchNotificationsEnabledKey) ?? false;

  String? get lastBookingType => _preferences.getString(_lastBookingTypeKey);

  String? get apiToken => _apiToken;
  String? get role => _preferences.getString(_roleKey);
  String? get accountEmail => _preferences.getString(_accountEmailKey);

  static Future<AppSession> load() async {
    final preferences = await SharedPreferences.getInstance();
    final session = AppSession._(preferences);
    session._apiToken =
        await _secureStorage.read(key: _apiTokenKey) ??
        preferences.getString(_apiTokenKey);
    if (session._apiToken != null && session._apiToken!.isNotEmpty) {
      await preferences.remove(_apiTokenKey);
    }
    return session;
  }

  Future<void> markAuthenticated() async {
    await _preferences.setBool(_authenticatedKey, true);
  }

  Future<void> setApiToken(String token) async {
    _apiToken = token;
    await _secureStorage.write(key: _apiTokenKey, value: token);
    await _preferences.remove(_apiTokenKey);
  }

  Future<void> setRole(String role) async {
    await _preferences.setString(_roleKey, role);
  }

  Future<void> setAccountEmail(String email) async {
    await _preferences.setString(_accountEmailKey, email.toLowerCase());
  }

  bool merchantProfileCompletedFor(String email) =>
      _preferences.getString(_merchantProfileEmailKey) == email.toLowerCase();

  Future<void> markMerchantProfileCompleted(String email) async {
    await _preferences.setString(_merchantProfileEmailKey, email.toLowerCase());
  }

  Future<void> setLastBookingType(String type) async {
    await _preferences.setString(_lastBookingTypeKey, type);
  }

  Future<void> setMatchNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(_matchNotificationsEnabledKey, enabled);
  }

  bool bookingStatusBannerDismissed(String bookingKey) =>
      _preferences.getBool(_bookingStatusBannerDismissedKey(bookingKey)) ??
      false;

  Future<void> dismissBookingStatusBanner(String bookingKey) async {
    await _preferences.setBool(
      _bookingStatusBannerDismissedKey(bookingKey),
      true,
    );
  }

  String _bookingStatusBannerDismissedKey(String bookingKey) {
    final account = Uri.encodeComponent(accountEmail ?? 'anonymous');
    return '$_bookingStatusBannerDismissedPrefix${account}_$bookingKey';
  }

  String get _matchNotificationsEnabledKey =>
      'match_notifications_enabled_${Uri.encodeComponent(accountEmail ?? 'anonymous')}';

  Future<void> clear() async {
    _apiToken = null;
    await _preferences.remove(_authenticatedKey);
    await _preferences.remove(_lastBookingTypeKey);
    await _preferences.remove(_apiTokenKey);
    await _preferences.remove(_roleKey);
    await _preferences.remove(_accountEmailKey);
    await _preferences.remove(_merchantProfileEmailKey);
    await _secureStorage.delete(key: _apiTokenKey);
  }
}
