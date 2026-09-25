import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'models/booking.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.45:3000',
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

  Future<List<Map<String, dynamic>>> customerBusinesses() async {
    final response = await _request('GET', '/api/businesses');
    return (response['businesses'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((business) => Map<String, dynamic>.from(business))
        .where((business) {
          final enabled = business['enabled'];
          return enabled != false &&
              enabled != 0 &&
              enabled != '0' &&
              enabled != 'false' &&
              enabled != 'FALSE';
        })
        .toList();
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

  Future<Map<String, dynamic>> createBooking({
    required String token,
    required int venueId,
    required String date,
    required String startTime,
    required double durationHours,
    required int players,
    required String paymentMethod,
  }) => _request(
    'POST',
    '/api/bookings',
    body: {
      'venueId': venueId,
      'date': date,
      'startTime': startTime,
      'durationHours': durationHours,
      'players': players,
      'paymentMethod': paymentMethod,
    },
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<List<Map<String, dynamic>>> customerBookings(String token) async {
    final response = await _request(
      'GET',
      '/api/bookings',
      headers: _authHeaders(token),
    );
    return (response['bookings'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<List<Booking>> customerBookingModels(String token) async {
    final response = await customerBookings(token);
    return response.map(Booking.fromJson).toList();
  }

  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String token,
    required int bookingId,
    required String paymentMethod,
  }) => _request(
    'POST',
    '/api/payments/paymongo/checkout',
    body: {'bookingId': bookingId, 'paymentMethod': paymentMethod},
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<List<Map<String, dynamic>>> newsFeed(String token) async {
    final response = await _request(
      'GET',
      '/api/news-feed',
      headers: _authHeaders(token),
    );
    return (response['posts'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<List<Map<String, dynamic>>> newsReviews({
    required String token,
    required int businessId,
  }) async {
    final response = await _request(
      'GET',
      '/api/news-feed/$businessId/reviews',
      headers: _authHeaders(token),
    );
    return (response['reviews'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> createNewsReview({
    required String token,
    required int businessId,
    required int rating,
    required String comment,
  }) async {
    await _request(
      'POST',
      '/api/news-feed/$businessId/reviews',
      body: {'rating': rating, 'comment': comment},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> submitCustomerReview({
    required String token,
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    await _request(
      'POST',
      '/api/customer/reviews',
      body: {
        'bookingId': bookingId,
        'rating': rating,
        'comment': comment,
      },
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<List<Map<String, dynamic>>> merchantNewsPosts(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/news-posts',
      headers: _authHeaders(token),
    );
    return (response['posts'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> createMerchantNewsPost({
    required String token,
    required Map<String, dynamic> post,
  }) async {
    await _request(
      'POST',
      '/api/merchant/news-posts',
      body: post,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> updateMerchantNewsPost({
    required String token,
    required int id,
    required Map<String, dynamic> post,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/news-posts/$id',
      body: post,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> deleteMerchantNewsPost({
    required String token,
    required int id,
  }) => _request(
    'DELETE',
    '/api/merchant/news-posts/$id',
    headers: _authHeaders(token),
  );

  Future<List<Map<String, dynamic>>> bookingAvailability({
    required String token,
    required int venueId,
    required String date,
  }) async {
    final response = await _request(
      'GET',
      '/api/bookings/availability?venueId=$venueId&date=${Uri.encodeQueryComponent(date)}',
      headers: _authHeaders(token),
    );
    return (response['bookings'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<List<Map<String, dynamic>>> merchantBookings(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/bookings',
      headers: _authHeaders(token),
    );
    return (response['bookings'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> approveBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/approve',
      headers: _authHeaders(token),
    );
  }

  Future<void> finishBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/finish',
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

  Future<List<Map<String, dynamic>>> savedItems(String token) async {
    final response = await _request(
      'GET',
      '/api/saved-items',
      headers: _authHeaders(token),
    );
    return (response['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, int>> savedItemCounts(String token, String type) async {
    final response = await _request(
      'GET',
      '/api/saved-item-counts?itemType=${Uri.encodeQueryComponent(type)}',
      headers: _authHeaders(token),
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
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> removeSavedItem(String token, String type, String key) async {
    await _request(
      'DELETE',
      '/api/saved-items/${Uri.encodeComponent(type)}/${Uri.encodeComponent(key)}',
      headers: _authHeaders(token),
    );
  }

  Future<Map<String, dynamic>> me(String token) =>
      _request('GET', '/api/auth/me', headers: _authHeaders(token));

  Future<Map<String, dynamic>> messageOwner({
    required String token,
    required String businessKey,
  }) => _request(
    'GET',
    '/api/messages/owner?businessKey=${Uri.encodeQueryComponent(businessKey)}',
    headers: _authHeaders(token),
  );

  Future<List<Map<String, dynamic>>> conversations(String token) async {
    final response = await _request(
      'GET',
      '/api/messages/conversations',
      headers: _authHeaders(token),
    );
    return (response['conversations'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<List<Map<String, dynamic>>> messageContacts(String token) async {
    final response = await _request(
      'GET',
      '/api/messages/contacts',
      headers: _authHeaders(token),
    );
    return (response['contacts'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<int> openConversation({
    required String token,
    int? recipientId,
    List<int>? participantIds,
    String? title,
    bool group = false,
  }) async {
    final ids = [...?participantIds];
    if (recipientId != null) ids.add(recipientId);
    final response = await _request(
      'POST',
      '/api/messages/conversations',
      body: {
        'recipientId': recipientId,
        'participantIds': ids,
        'title': title,
        'type': group ? 'group' : 'direct',
      },
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
    return (response['conversationId'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> conversationMessages({
    required String token,
    required int conversationId,
  }) async {
    final response = await _request(
      'GET',
      '/api/messages/conversations/$conversationId',
      headers: _authHeaders(token),
    );
    return (response['messages'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  Future<void> sendConversationMessage({
    required String token,
    required int conversationId,
    required String body,
    Map<String, dynamic>? attachment,
  }) async {
    await _request(
      'POST',
      '/api/messages/conversations/$conversationId',
      body: {
        'body': body,
        ...?(attachment == null ? null : {'attachment': attachment}),
      },
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> deleteConversationMessage({
    required String token,
    required int conversationId,
    required int messageId,
  }) async {
    await _request(
      'DELETE',
      '/api/messages/conversations/$conversationId/messages/$messageId',
      headers: _authHeaders(token),
    );
  }

  // Compatibility aliases for older messaging-page editor snapshots.
  Future<List<Map<String, dynamic>>> messages({
    required String token,
    required int conversationId,
  }) => conversationMessages(token: token, conversationId: conversationId);

  Future<int> createConversation({
    required String token,
    required List<int> participantIds,
    String? title,
    bool group = false,
  }) => openConversation(
    token: token,
    participantIds: participantIds,
    title: title,
    group: group,
  );

  Future<void> sendMessage({
    required String token,
    required int conversationId,
    String? body,
    Map<String, dynamic>? attachment,
  }) => sendConversationMessage(
    token: token,
    conversationId: conversationId,
    body: body ?? '',
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
        }
      } on FormatException {
        throw AuthApiException(
          response.statusCode == 404
              ? path.contains('/merchant/businesses/')
                    ? 'The business management API is unavailable. Restart the backend server and try again.'
                    : path.startsWith('/api/saved-items')
                    ? 'The saved-items API is unavailable. Restart the backend server and try again.'
                    : 'The requested API endpoint was not found.'
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
