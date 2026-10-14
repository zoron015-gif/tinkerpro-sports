import 'dart:math';

import 'package:http/http.dart' as http;

import 'core/api_http_client.dart';
import 'core/api_response.dart';
import 'features/venues/domain/venue_models.dart';
import 'features/bookings/domain/booking.dart';
import 'core/business_type.dart';

export 'core/api_http_client.dart' show AuthApiException, apiBaseUrl;
export 'features/activity_log/domain/activity_log_entry.dart';
export 'features/venues/domain/venue_models.dart';

part 'features/bookings/data/booking_api.dart';
part 'features/venues/data/venue_api.dart';
part 'features/messaging/data/messaging_api.dart';
part 'features/saved_items/data/saved_items_api.dart';

final Random _idempotencyRandom = Random.secure();

String newBookingIdempotencyKey() => List.generate(
  32,
  (_) => _idempotencyRandom.nextInt(16).toRadixString(16),
).join();

class AuthApi {
  AuthApi({http.Client? client}) : httpClient = ApiHttpClient(client: client);

  final ApiHttpClient httpClient;

  VenueApi get venues => VenueApi._(
    request: _request,
    authHeaders: _authHeaders,
  );

  Map<String, String> authHeadersForToken(String? token) =>
      _authHeaders(token);

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

  Future<void> updateMerchantBusinessImages({
    required String token,
    required int id,
    required List<String> imageUrls,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/businesses/$id/images',
      body: {'imageUrls': imageUrls},
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
  }) => httpClient.request(method, path, body: body, headers: headers);
}
