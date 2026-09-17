import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  AppSession._(this._preferences);

  static const _authenticatedKey = 'session_authenticated';
  static const _lastBookingTypeKey = 'session_last_booking_type';
  static const _apiTokenKey = 'session_api_token';

  final SharedPreferences _preferences;

  bool get isAuthenticated => _preferences.getBool(_authenticatedKey) ?? false;

  String? get lastBookingType => _preferences.getString(_lastBookingTypeKey);

  String? get apiToken => _preferences.getString(_apiTokenKey);

  static Future<AppSession> load() async {
    return AppSession._(await SharedPreferences.getInstance());
  }

  Future<void> markAuthenticated() async {
    await _preferences.setBool(_authenticatedKey, true);
  }

  Future<void> setApiToken(String token) async {
    await _preferences.setString(_apiTokenKey, token);
  }

  Future<void> setLastBookingType(String type) async {
    await _preferences.setString(_lastBookingTypeKey, type);
  }

  Future<void> clear() async {
    await _preferences.remove(_authenticatedKey);
    await _preferences.remove(_lastBookingTypeKey);
    await _preferences.remove(_apiTokenKey);
  }
}
