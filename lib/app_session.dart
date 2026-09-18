import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  AppSession._(this._preferences);

  static const _authenticatedKey = 'session_authenticated';
  static const _lastBookingTypeKey = 'session_last_booking_type';
  static const _apiTokenKey = 'session_api_token';
  static const _roleKey = 'session_role';
  static const _accountEmailKey = 'session_account_email';
  static const _merchantProfileEmailKey = 'merchant_profile_email';

  final SharedPreferences _preferences;

  bool get isAuthenticated => _preferences.getBool(_authenticatedKey) ?? false;

  String? get lastBookingType => _preferences.getString(_lastBookingTypeKey);

  String? get apiToken => _preferences.getString(_apiTokenKey);
  String? get role => _preferences.getString(_roleKey);
  String? get accountEmail => _preferences.getString(_accountEmailKey);

  static Future<AppSession> load() async {
    return AppSession._(await SharedPreferences.getInstance());
  }

  Future<void> markAuthenticated() async {
    await _preferences.setBool(_authenticatedKey, true);
  }

  Future<void> setApiToken(String token) async {
    await _preferences.setString(_apiTokenKey, token);
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
    await _preferences.setString(
      _merchantProfileEmailKey,
      email.toLowerCase(),
    );
  }

  Future<void> setLastBookingType(String type) async {
    await _preferences.setString(_lastBookingTypeKey, type);
  }

  Future<void> clear() async {
    await _preferences.remove(_authenticatedKey);
    await _preferences.remove(_lastBookingTypeKey);
    await _preferences.remove(_apiTokenKey);
    await _preferences.remove(_roleKey);
    await _preferences.remove(_accountEmailKey);
  }
}
