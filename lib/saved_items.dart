import 'auth_api.dart';
import 'app_session.dart';

class SavedItemStore {
  static Future<List<Map<String, dynamic>>> list({AuthApi? api}) async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Your session has expired. Please log in again.',
        401,
      );
    }
    return (api ?? AuthApi()).savedItems(token);
  }

  static Future<void> save({
    required String type,
    required String key,
    required String title,
    required String subtitle,
    String? imageUrl,
    AuthApi? api,
  }) async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Your session has expired. Please log in again.',
        401,
      );
    }
    await (api ?? AuthApi()).saveItem(
      token: token,
      type: type,
      key: key,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
    );
  }

  static Future<Map<String, int>> counts(
    String type, {
    AuthApi? api,
  }) async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Your session has expired. Please log in again.',
        401,
      );
    }
    return (api ?? AuthApi()).savedItemCounts(token, type);
  }

  static Future<void> remove(
    String type,
    String key, {
    AuthApi? api,
  }) async {
    final token = (await AppSession.load()).apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Your session has expired. Please log in again.',
        401,
      );
    }
    await (api ?? AuthApi()).removeSavedItem(token, type, key);
  }
}
