import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.21:3000',
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
      return 'We couldn’t connect to the service. Check your internet or Wi-Fi connection and try again.';
    }
    if (statusCode == 408) {
      return 'The service is taking longer than expected to respond. Please try again in a moment.';
    }
    if (statusCode >= 500) {
      return 'Something went wrong on our end. Please try again.';
    }
    return message;
  }

  @override
  String toString() => userMessage;
}

class ApiHttpClient {
  ApiHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> request(
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
                .delete(
                  uri,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body),
                )
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
        'The local API took too long to respond. Check that the backend is running and reachable over your Wi-Fi/LAN, then try again.',
        408,
      );
    } on Exception {
      throw const AuthApiException(
        'Could not reach the local API. Check that the backend is running and that this device can reach the API address over Wi-Fi/LAN.',
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
              ? path.endsWith('/check-in-code')
                    ? 'Venue QR check-in is unavailable on the connected server. Update or restart the backend server, then try again.'
                    : path.contains('/merchant/businesses/')
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
