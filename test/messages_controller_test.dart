import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/messages_controller.dart';
import 'package:myapp/messages_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMessagesService extends MessagesService {
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> contacts = [];
  Map<String, dynamic> currentUser = {
    'user': {'id': 7},
  };
  final Map<int, List<Map<String, dynamic>>> messagesByConversation = {};
  final Map<int, Completer<List<Map<String, dynamic>>>> pendingMessages = {};
  int conversationFetches = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchConversations(String token) async {
    conversationFetches++;
    return conversations;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchContacts(String token) async =>
      contacts;

  @override
  Future<Map<String, dynamic>> fetchCurrentUser(String token) async =>
      currentUser;

  @override
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String token,
    required int conversationId,
  }) {
    final pending = pendingMessages[conversationId];
    if (pending != null) return pending.future;
    return Future.value(messagesByConversation[conversationId] ?? []);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeMessagesService service;
  late MessagesController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    service = _FakeMessagesService();
    controller = MessagesController(service: service);
  });

  tearDown(() {
    controller.disposeController();
    controller.dispose();
  });

  test('load populates inbox and starts in loaded state', () async {
    service.conversations = [
      {'id': 3, 'unreadCount': 2},
    ];
    service.contacts = [
      {'id': 8, 'firstName': 'Alex'},
    ];

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.token, 'test-token');
    expect(controller.role, 'customer');
    expect(controller.currentUserId, 7);
    expect(controller.conversations.single['id'], 3);
    expect(controller.contacts.single['id'], 8);
    expect(controller.unreadMessageCount, 2);
    expect(controller.realtimeTimer, isNotNull);
  });

  test(
    'select keeps the newest conversation when older request completes late',
    () async {
      controller.token = 'test-token';
      final olderRequest = Completer<List<Map<String, dynamic>>>();
      service.pendingMessages[1] = olderRequest;
      service.messagesByConversation[2] = [
        {'id': 22, 'body': 'new conversation'},
      ];

      final firstSelection = controller.select(1);
      await controller.select(2);
      olderRequest.complete([
        {'id': 11, 'body': 'stale conversation'},
      ]);
      await firstSelection;

      expect(controller.selectedConversationId, 2);
      expect(controller.messages.single['body'], 'new conversation');
      expect(controller.showChat, isTrue);
    },
  );

  test(
    'realtime refresh updates inbox and selected conversation messages',
    () async {
      controller.token = 'test-token';
      controller.selectedConversationId = 4;
      service.conversations = [
        {'id': 4, 'unreadCount': 1},
      ];
      service.messagesByConversation[4] = [
        {'id': 41, 'body': 'arrived in realtime'},
      ];

      await controller.refreshRealtime();

      expect(service.conversationFetches, 1);
      expect(controller.conversations.single['id'], 4);
      expect(controller.messages.single['body'], 'arrived in realtime');
    },
  );

  test('back to inbox clears selected chat state', () async {
    controller.setSelectedConversation(9);
    controller.setMessages([
      {'id': 91, 'body': 'message'},
    ]);

    controller.backToInbox();

    expect(controller.showChat, isFalse);
    expect(controller.selectedConversationId, isNull);
    expect(controller.messages, isEmpty);
  });
}
