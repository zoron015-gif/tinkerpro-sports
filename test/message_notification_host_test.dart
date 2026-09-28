import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/message_notification_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tapping a message alert opens its conversation', (tester) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_account_email': 'me@example.com',
    });
    var conversations = <Map<String, dynamic>>[
      _conversation(message: 'Existing message', time: '2026-09-28T10:00:00Z'),
    ];
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(
            jsonEncode({'conversations': conversations}),
            200,
          );
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );
    int? openedConversationId;

    await tester.pumpWidget(
      MaterialApp(
        home: MessageNotificationHost(
          api: api,
          pollingInterval: const Duration(milliseconds: 100),
          onOpenConversation: (id) => openedConversationId = id,
          child: const Scaffold(body: Text('Explore page')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    conversations = [
      _conversation(message: 'Ziggy sent a message', time: '2026-09-28T10:01:00Z'),
    ];
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.tap(find.text('Ziggy sent a message'));
    await tester.pump();

    expect(openedConversationId, 4);
    expect(find.text('Ziggy sent a message'), findsNothing);
  });

  testWidgets(
    'shows newest incoming message and dismisses after five seconds',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
        'session_account_email': 'me@example.com',
      });
      var conversations = <Map<String, dynamic>>[
        _conversation(
          message: 'Existing message',
          time: '2026-09-28T10:00:00Z',
        ),
      ];
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/messages/conversations') {
            return http.Response(
              jsonEncode({'conversations': conversations}),
              200,
            );
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected request'}),
            500,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MessageNotificationHost(
            api: api,
            pollingInterval: const Duration(milliseconds: 100),
            child: const Scaffold(body: Text('Explore page')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Existing message'), findsNothing);

      conversations = [
        _conversation(
          message: 'First new message',
          time: '2026-09-28T10:01:00Z',
        ),
      ];
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('First new message'), findsOneWidget);

      conversations = [
        _conversation(message: 'Newest message', time: '2026-09-28T10:02:00Z'),
      ];
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('First new message'), findsNothing);
      expect(find.text('Newest message'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('Newest message'), findsNothing);
      expect(find.text('Explore page'), findsOneWidget);
    },
  );
}

Map<String, dynamic> _conversation({
  required String message,
  required String time,
}) => {
  'id': 4,
  'title': 'Alex Doe',
  'lastMessage': message,
  'lastMessageAt': time,
  'unreadCount': 1,
  'archived': false,
  'blockedByMe': false,
};
