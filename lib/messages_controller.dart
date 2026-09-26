import 'dart:async';

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'messages_service.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({MessagesService? service})
    : _service = service ?? MessagesService();

  static const _realtimeRefreshInterval = Duration(seconds: 15);

  final MessagesService _service;

  String? token;
  String? role;
  int? currentUserId;
  int? selectedConversationId;
  List<Map<String, dynamic>> conversations = const [];
  List<Map<String, dynamic>> contacts = const [];
  List<Map<String, dynamic>> messages = const [];
  bool loading = true;
  bool sending = false;
  bool showChat = false;
  bool showArchivedConversations = false;
  bool showBlockedConversations = false;
  String conversationQuery = '';
  int loadRequestId = 0;
  int messageRequestId = 0;
  Timer? realtimeTimer;
  bool realtimeRefreshInFlight = false;

  int get unreadMessageCount => conversations.fold<int>(
    0,
    (total, conversation) =>
        total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
  );

  Future<void> load() async {
    final requestId = ++loadRequestId;
    try {
      final session = await AppSession.load();
      final sessionToken = session.apiToken;
      if (sessionToken == null || sessionToken.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }

      final loadedConversations = await _service.fetchConversations(
        sessionToken,
      );
      final loadedContacts = await _service.fetchContacts(sessionToken);
      final currentUser = await _service.fetchCurrentUser(sessionToken);

      if (requestId != loadRequestId) return;

      token = sessionToken;
      role = session.role;
      currentUserId =
          ((currentUser['user'] as Map<String, dynamic>?)?['id'] as num?)
              ?.toInt();
      conversations = loadedConversations;
      contacts = loadedContacts;
      loading = false;
      notifyListeners();

      startRealtimeUpdates();
    } on Exception {
      if (requestId == loadRequestId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<int?> openOwnerConversation({
    required int ownerId,
    String? businessTitle,
  }) async {
    final sessionToken = token;
    if (sessionToken == null) return null;

    try {
      final id = await _service.openConversation(
        token: sessionToken,
        recipientId: ownerId,
        title: businessTitle,
      );
      await load();
      return id;
    } catch (_) {
      rethrow;
    }
  }

  void startRealtimeUpdates() {
    realtimeTimer?.cancel();
    realtimeTimer = Timer.periodic(
      _realtimeRefreshInterval,
      (_) => unawaited(refreshRealtime()),
    );
  }

  Future<void> refreshRealtime() async {
    final sessionToken = token;
    if (sessionToken == null || realtimeRefreshInFlight) return;

    realtimeRefreshInFlight = true;
    try {
      final selectedConversation = selectedConversationId;
      final conversationsFuture = _service.fetchConversations(sessionToken);
      final messagesFuture = selectedConversation == null
          ? null
          : _service.fetchMessages(
              token: sessionToken,
              conversationId: selectedConversation,
            );

      final loadedConversations = await conversationsFuture;
      final loadedMessages = messagesFuture == null
          ? null
          : await messagesFuture;

      if (sessionToken != token) return;

      conversations = loadedConversations;
      if (selectedConversation != null &&
          selectedConversation == selectedConversationId &&
          loadedMessages != null) {
        messages = loadedMessages;
      }
      notifyListeners();
    } finally {
      realtimeRefreshInFlight = false;
    }
  }

  Future<void> select(int id) async {
    final sessionToken = token;
    if (sessionToken == null) return;

    final requestId = ++messageRequestId;
    selectedConversationId = id;
    messages = const [];
    showChat = true;
    notifyListeners();

    try {
      final loadedMessages = await _service.fetchMessages(
        token: sessionToken,
        conversationId: id,
      );
      if (requestId != messageRequestId) return;
      if (selectedConversationId != id) return;
      messages = loadedMessages;
      notifyListeners();
    } on Exception {
      if (requestId == messageRequestId) {
        notifyListeners();
      }
    }
  }

  void setConversationQuery(String value) {
    conversationQuery = value;
    notifyListeners();
  }

  void clearConversationQuery() {
    conversationQuery = '';
    notifyListeners();
  }

  void setShowArchivedConversations(bool value) {
    showArchivedConversations = value;
    if (value) showBlockedConversations = false;
    notifyListeners();
  }

  void setShowBlockedConversations(bool value) {
    showBlockedConversations = value;
    if (value) showArchivedConversations = false;
    notifyListeners();
  }

  void setSelectedConversation(int id) {
    selectedConversationId = id;
    messages = const [];
    showChat = true;
    notifyListeners();
  }

  void setMessages(List<Map<String, dynamic>> nextMessages) {
    messages = nextMessages;
    notifyListeners();
  }

  void setSending(bool nextSending) {
    sending = nextSending;
    notifyListeners();
  }

  void backToInbox() {
    showChat = false;
    selectedConversationId = null;
    messages = const [];
    notifyListeners();
  }

  void disposeController() {
    realtimeTimer?.cancel();
    realtimeTimer = null;
  }
}
