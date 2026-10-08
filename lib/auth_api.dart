import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'core/api_response.dart';
import 'models/booking.dart';

part 'features/bookings/data/booking_api.dart';
part 'features/venues/data/venue_api.dart';
part 'features/messaging/data/messaging_api.dart';
part 'features/saved_items/data/saved_items_api.dart';

final Random _idempotencyRandom = Random.secure();

String newBookingIdempotencyKey() => List.generate(
  32,
  (_) => _idempotencyRandom.nextInt(16).toRadixString(16),
).join();

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.50:3000',
);

final _requestIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class AuthApiException implements Exception {
  const AuthApiException(
    this.message,
    this.statusCode, [
    this.data = const {},
    this.requestId,
  ]);

  final String message;
  final int statusCode;
  final Map<String, dynamic> data;
  final String? requestId;

  String get userMessage {
    if (statusCode == 0) {
      return 'Could not connect to the server. Check your connection and try again.';
    }
    if (statusCode == 408) {
      return 'The server took too long to respond. Please try again.';
    }
    if (statusCode >= 500) {
      return 'Something went wrong on our end. Please try again.';
    }
    return message;
  }

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _authHeaders(
    String? token, {
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{};
    if (extra != null) headers.addAll(extra);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

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

  Future<List<Map<String, dynamic>>> customerBusinesses({
    bool includeDisabledEvents = false,
  }) async {
    final response = await _request('GET', '/api/businesses');
    return asMapList(response['businesses']).where((business) {
      final isEvent =
          '${business['businessType'] ?? business['business_type'] ?? ''}'
              .trim()
              .toLowerCase() ==
          'event';
      if (includeDisabledEvents && isEvent) return true;
      final enabled = business['enabled'];
      return enabled != false &&
          enabled != 0 &&
          enabled != '0' &&
          enabled != 'false' &&
          enabled != 'FALSE';
    }).toList();
  }

  Future<Map<String, dynamic>> merchantProfile(String token) =>
      _request('GET', '/api/merchant/profile', headers: _authHeaders(token));

  Future<Map<String, dynamic>> updateCustomerProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required String hobby,
    String? avatarUrl,
  }) => _request(
    'PUT',
    '/api/auth/profile',
    body: {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'address': address,
      'hobby': hobby,
      'avatarUrl': avatarUrl,
    },
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<Map<String, dynamic>> saveMerchantProfile({
    required String token,
    required Map<String, dynamic> profile,
  }) => _request(
    'PUT',
    '/api/merchant/profile',
    body: profile,
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<List<Map<String, dynamic>>> merchantBusinesses(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/businesses',
      headers: _authHeaders(token),
    );
    return asMapList(response['businesses']);
  }

  Future<void> createMerchantBusiness({
    required String token,
    required Map<String, dynamic> business,
  }) async {
    await _request(
      'POST',
      '/api/merchant/businesses',
      body: business,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> updateMerchantBusiness({
    required String token,
    required int id,
    required Map<String, dynamic> business,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/businesses/$id',
      body: business,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> setMerchantBusinessEnabled({
    required String token,
    required int id,
    required bool enabled,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/businesses/$id/status',
      body: {'enabled': enabled},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> deleteMerchantBusiness({
    required String token,
    required int id,
  }) async {
    await _request(
      'DELETE',
      '/api/merchant/businesses/$id',
      headers: _authHeaders(token),
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

  Future<Map<String, dynamic>> loginWithGoogle(String idToken, {String? role}) {
    final payload = <String, dynamic>{'idToken': idToken};
    if (role != null && role.isNotEmpty) {
      payload['role'] = role;
    }
    return _post('/api/auth/oauth/google', payload);
  }

  Future<Map<String, dynamic>> me(String token) =>
      _request('GET', '/api/auth/me', headers: _authHeaders(token));

  Future<List<Map<String, dynamic>>> activityLogs(String token) async {
    final response = await _request(
      'GET',
      '/api/activity-logs',
      headers: _authHeaders(token),
    );
    return (response['activities'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

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
          : method == 'PATCH'
          ? await _client
                .patch(uri, headers: headers, body: jsonEncode(body))
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
        } else if (response.statusCode >= 200 && response.statusCode < 300) {
          throw AuthApiException(
            'The server returned an invalid response.',
            response.statusCode,
            const {},
            _validRequestId(response.headers['x-request-id']),
          );
        }
      } on FormatException {
        throw AuthApiException(
          response.statusCode == 404
              ? path.contains('/merchant/businesses/')
                    ? 'The business management API is unavailable. Restart the backend server and try again.'
                    : path.startsWith('/api/merchant/bookings/') &&
                          path.endsWith('/decline')
                    ? 'Booking decline is unavailable on the connected server. Update or restart the backend server, then try again.'
                    : path.startsWith('/api/saved-items')
                    ? 'The saved-items API is unavailable. Restart the backend server and try again.'
                    : path.startsWith('/api/messages/conversations/')
                    ? 'The messaging API is unavailable. Restart the backend server and try again.'
                    : 'The requested API endpoint was not found.'
              : 'The server returned an invalid response.',
          response.statusCode,
          const {},
          _validRequestId(response.headers['x-request-id']),
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage = decoded['error'];
      throw AuthApiException(
        rawMessage is String && rawMessage.trim().isNotEmpty
            ? rawMessage.trim()
            : 'The server returned an error.',
        response.statusCode,
        decoded,
        _validRequestId(response.headers['x-request-id']),
      );
    }
    return decoded;
  }

  String? _validRequestId(String? value) =>
      value != null && _requestIdPattern.hasMatch(value) ? value : null;
}
