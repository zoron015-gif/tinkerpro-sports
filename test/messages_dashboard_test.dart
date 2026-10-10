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

  testWidgets('long-press delete-for-everyone shows the removal notice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    var removedForEveryone = false;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'DELETE') {
          expect(jsonDecode(request.body), {'scope': 'everyone'});
          removedForEveryone = true;
          return http.Response(
            jsonEncode({'message': 'Message deleted for everyone.'}),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'id': 55,
                  'type': 'direct',
                  'title': 'Chat with Merchant',
                  'lastMessage': 'Please confirm the booking.',
                  'lastMessageAt': '2026-10-10T09:00:00Z',
                  'members': [
                    {'id': 7, 'firstName': 'Merchant', 'lastName': 'Owner'},
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
              'messages': removedForEveryone
                  ? [
                      {
                        'id': 501,
                        'senderId': 42,
                        'body': null,
                        'removedAt': '2026-10-10T10:00:00',
                        'removedByName': 'Customer One',
                      },
                      {
                        'id': 502,
                        'senderId': 7,
                        'body': 'Thanks for the update.',
                        'createdAt': '2026-10-10T09:30:00',
                      },
                    ]
                  : [
                      {
                        'id': 501,
                        'senderId': 42,
                        'senderFirstName': 'Customer',
                        'senderLastName': 'One',
                        'body': 'Please confirm the booking.',
                        'createdAt': '2026-10-10T09:00:00',
                      },
                      {
                        'id': 502,
                        'senderId': 7,
                        'body': 'Thanks for the update.',
                        'createdAt': '2026-10-10T09:30:00',
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

    await tester.pumpWidget(MaterialApp(home: MessagesDashboardPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merchant Owner'));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('message-bubble-502')));
    await tester.pumpAndSettle();

    expect(find.text('Delete for everyone'), findsNothing);
    expect(find.text('Delete for me'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('message-bubble-501')));
    await tester.pumpAndSettle();

    expect(find.text('Delete for everyone'), findsOneWidget);
    expect(find.text('Delete for me'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-message-everyone')));
    await tester.pumpAndSettle();

    expect(removedForEveryone, isTrue);
    expect(find.text('You deleted a message'), findsOneWidget);
  });
}
