import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.14:3000',
);

class AuthApiException implements Exception {
  const AuthApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

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

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) =>
      _post('/api/auth/oauth/google', {'idToken': idToken});

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
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) {
        decoded = value;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException(
        decoded['error'] as String? ?? 'The server returned an error.',
        response.statusCode,
      );
    }
    return decoded;
  }
}
