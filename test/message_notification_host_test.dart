import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/message_notification_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
  });

  testWidgets(
    'booking message alert uses the other account name and profile image',
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
      await tester.pump(const Duration(milliseconds: 200));

      conversations = [
        {
          ..._conversation(message: 'Hi there', time: '2026-09-28T10:01:00Z'),
          'title': 'Booking 32',
          'members': [
            {
              'id': 7,
              'email': 'merchant@example.com',
              'firstName': 'Alex',
              'lastName': 'Merchant',
              'avatarUrl':
                  'data:image/png;base64,'
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1Pe'
                  'AAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
            },
            {
              'id': 42,
              'email': 'me@example.com',
              'firstName': 'Customer',
              'lastName': 'Account',
            },
          ],
        },
      ];
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Alex Merchant'), findsOneWidget);
      expect(find.text('Booking 32'), findsNothing);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    },
  );

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
        builder: (context, child) => MessageNotificationHost(
          api: api,
          pollingInterval: const Duration(milliseconds: 100),
          onOpenConversation: (id) => openedConversationId = id,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('Explore page')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    conversations = [
      _conversation(
        message: 'Ziggy sent a message',
        time: '2026-09-28T10:01:00Z',
      ),
    ];
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    final dismissButton = find.widgetWithIcon(IconButton, Icons.close_rounded);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(dismissButton));
    await mouse.moveTo(tester.getCenter(dismissButton));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
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
      await tester.pump(const Duration(milliseconds: 200));
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
