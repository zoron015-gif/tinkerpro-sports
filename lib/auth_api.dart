import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.14:3000',
);

class AuthApiException implements Exception {
  const AuthApiException(this.message, this.statusCode, [this.data = const {}]);

  final String message;
  final int statusCode;
  final Map<String, dynamic> data;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String role,
  }) => _post('/api/auth/register', {
    'email': email,
    'password': password,
    'role': role,
  });

  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) => _post('/api/auth/verify-email', {'email': email, 'code': code});

  Future<Map<String, dynamic>> resendVerification(String email) =>
      _post('/api/auth/resend-verification', {'email': email});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _post('/api/auth/login', {'email': email, 'password': password});

  Future<Map<String, dynamic>> merchantProfile(String token) async {
    return _request(
      'GET',
      '/api/merchant/profile',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> saveMerchantProfile({
    required String token,
    required Map<String, dynamic> profile,
  }) => _request(
    'PUT',
    '/api/merchant/profile',
    body: profile,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  Future<List<Map<String, dynamic>>> merchantBusinesses(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/businesses',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response['businesses'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> createMerchantBusiness({
    required String token,
    required Map<String, dynamic> business,
  }) async {
    await _request(
      'POST',
      '/api/merchant/businesses',
      body: business,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<void> deleteMerchantBusiness({
    required String token,
    required int id,
  }) async {
    await _request(
      'DELETE',
      '/api/merchant/businesses/$id',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      _post('/api/auth/forgot-password', {'email': email});

  Future<Map<String, dynamic>> verifyPasswordResetCode({
    required String email,
    required String code,
  }) => _post('/api/auth/verify-password-reset-code', {
    'email': email,
    'code': code,
  });

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String password,
  }) => _post('/api/auth/reset-password', {
    'email': email,
    'code': code,
    'password': password,
  });

  Future<Map<String, dynamic>> loginWithGoogle(
    String idToken, {
    String? role,
  }) => _post('/api/auth/oauth/google', {'idToken': idToken, 'role': ?role});

  Future<List<Map<String, dynamic>>> savedItems(String token) async {
    final response = await _request(
      'GET',
      '/api/saved-items',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, int>> savedItemCounts(String token, String type) async {
    final response = await _request(
      'GET',
      '/api/saved-item-counts?itemType=${Uri.encodeQueryComponent(type)}',
      headers: {'Authorization': 'Bearer $token'},
    );
    final counts = response['counts'];
    if (counts is! Map) return {};
    return counts.map<String, int>(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  Future<void> saveItem({
    required String token,
    required String type,
    required String key,
    required String title,
    required String subtitle,
    String? imageUrl,
  }) async {
    await _request(
      'POST',
      '/api/saved-items',
      body: {
        'itemType': type,
        'itemKey': key,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
      },
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<void> removeSavedItem(String token, String type, String key) async {
    await _request(
      'DELETE',
      '/api/saved-items/${Uri.encodeComponent(type)}/${Uri.encodeComponent(key)}',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> me(String token) => _request(
    'GET',
    '/api/auth/me',
    headers: {'Authorization': 'Bearer $token'},
  );

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _request(
        'POST',
        path,
        body: body,
        headers: {'Content-Type': 'application/json'},
      );

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    late final http.Response response;
    try {
      response = method == 'GET'
          ? await _client
                .get(uri, headers: headers)
                .timeout(const Duration(seconds: 15))
          : method == 'DELETE'
          ? await _client
                .delete(uri, headers: headers)
                .timeout(const Duration(seconds: 15))
          : method == 'PUT'
          ? await _client
                .put(uri, headers: headers, body: jsonEncode(body))
                .timeout(const Duration(seconds: 15))
          : await _client
                .post(uri, headers: headers, body: jsonEncode(body))
                .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthApiException(
        'The server took too long to respond. Check that the backend is running and try again.',
        408,
      );
    } on Exception {
      throw const AuthApiException(
        'Could not connect to the server. Check that the backend is running and the API URL is correct.',
        0,
      );
    }

    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      try {
        final value = jsonDecode(response.body);
        if (value is Map<String, dynamic>) {
          decoded = value;
        }
      } on FormatException {
        throw AuthApiException(
          response.statusCode == 404
              ? 'The saved-items API is unavailable. Restart the backend server and try again.'
              : 'The server returned an invalid response.',
          response.statusCode,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        decoded['error'] as String? ?? 'The server returned an error.',
        response.statusCode,
        decoded,
      );
    }
    return decoded;
  }
}
