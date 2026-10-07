import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/messages_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opening a booking conversation displays its existing message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    final requests = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'id': 55,
                  'type': 'direct',
                  'title': 'Booking 504',
                  'lastMessage': 'New booking request #504 submitted.',
                  'lastMessageAt': '2026-10-07T08:00:00Z',
                  'createdAt': '2026-10-07T08:00:00Z',
                  'unreadCount': 1,
                  'members': [
                    {'id': 7, 'firstName': 'Marlou', 'lastName': 'Opo'},
                    {'id': 42, 'firstName': 'Customer', 'lastName': 'One'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations/55') {
          return http.Response(
            jsonEncode({
              'messages': [
                {
                  'id': 501,
                  'senderId': 42,
                  'body': 'New booking request #504 submitted.',
                  'createdAt': '2026-10-07T08:00:00Z',
                  'attachment': {
                    'type': 'booking',
                    'bookingId': 504,
                    'transactionId': 'TP-TXN-00000504',
                    'bookingToken': 'TP-BOOKING-TOKEN-504',
                    'status': 'pending',
                    'businessType': 'Sports',
                    'venueName': 'Test Court',
                    'sportType': 'Basketball',
                    'bookingDate': '2026-10-08',
                    'startTime': '09:00:00',
                    'durationHours': 1,
                    'players': 2,
                    'total': 500,
                    'downpayment': 250,
                  },
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/contacts') {
          return http.Response(jsonEncode({'contacts': []}), 200);
        }
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': 42},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesDashboardPage(api: api, businessType: 'Sports'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      requests.any(
        (request) => request.contains('/api/messages/conversations'),
      ),
      isTrue,
    );
    await tester.tap(find.text('Marlou Opo'));
    await tester.pumpAndSettle();

    expect(find.text('Write the first message.'), findsNothing);
    expect(find.text('BOOKING REQUEST'), findsOneWidget);
    expect(find.text('TP-TXN-00000504'), findsOneWidget);
    expect(find.text('TP-BOOKING-TOKEN-504'), findsOneWidget);
  });
}
