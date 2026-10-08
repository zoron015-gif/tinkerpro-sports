import 'dart:async';

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'messages_service.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({MessagesService? service, this.businessType})
    : _service = service ?? MessagesService();

  static const _realtimeRefreshInterval = Duration(seconds: 15);

  final MessagesService _service;
  final String? businessType;

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
  int conversationStateRevision = 0;
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
        businessType: businessType,
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
      final stateRevision = conversationStateRevision;
      final messageRequestIdAtStart = messageRequestId;
      final selectedConversation = selectedConversationId;
      final conversationsFuture = _service.fetchConversations(
        sessionToken,
        businessType: businessType,
      );
      final messagesFuture = selectedConversation == null
          ? null
          : _service.fetchMessages(
              token: sessionToken,
              conversationId: selectedConversation,
              businessType: businessType,
            );

      final loadedConversations = await conversationsFuture;
      final loadedMessages = messagesFuture == null
          ? null
          : await messagesFuture;

      if (sessionToken != token || stateRevision != conversationStateRevision) {
        return;
      }

      conversations = loadedConversations;
      if (selectedConversation != null &&
          selectedConversation == selectedConversationId &&
          messageRequestIdAtStart == messageRequestId &&
          loadedMessages != null) {
        messages = loadedMessages;
        _markConversationRead(selectedConversation);
      }
      notifyListeners();
    } finally {
      realtimeRefreshInFlight = false;
    }
  }

  Future<void> select(int id) async {
    final sessionToken = token;
    if (sessionToken == null) return;

    final requestId = beginSelectingConversation(id);

    try {
      final loadedMessages = await _service.fetchMessages(
        token: sessionToken,
        conversationId: id,
        businessType: businessType,
      );
      if (requestId != messageRequestId) return;
      if (selectedConversationId != id) return;
      messages = loadedMessages;
      _markConversationRead(id);
      notifyListeners();
    } on Exception {
      if (requestId == messageRequestId) {
        notifyListeners();
      }
      rethrow;
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

  int beginSelectingConversation(int id) {
    final requestId = ++messageRequestId;
    if (selectedConversationId != id) {
      messages = const [];
    }
    selectedConversationId = id;
    showChat = true;
    notifyListeners();
    return requestId;
  }

  void setSelectedConversation(int id) {
    beginSelectingConversation(id);
  }

  void setMessages(List<Map<String, dynamic>> nextMessages) {
    messages = nextMessages;
    final selectedId = selectedConversationId;
    if (selectedId != null) _markConversationRead(selectedId);
    notifyListeners();
  }

  void setConversationArchived(int conversationId, bool archived) {
    conversationStateRevision++;
    conversations = conversations
        .map(
          (conversation) =>
              (conversation['id'] as num?)?.toInt() == conversationId
              ? {...conversation, 'archived': archived}
              : conversation,
        )
        .toList();
    notifyListeners();
  }

  void setUserBlocked(int userId, bool blocked) {
    conversationStateRevision++;
    conversations = conversations.map((conversation) {
      final members = conversation['members'] as List<dynamic>? ?? const [];
      final includesUser = members.whereType<Map>().any(
        (member) => (member['id'] as num?)?.toInt() == userId,
      );
      return includesUser
          ? {...conversation, 'blockedByMe': blocked}
          : conversation;
    }).toList();
    notifyListeners();
  }

  void _markConversationRead(int conversationId) {
    conversationStateRevision++;
    Map<String, dynamic>? selectedConversation;
    for (final conversation in conversations) {
      if ((conversation['id'] as num?)?.toInt() == conversationId) {
        selectedConversation = conversation;
        break;
      }
    }
    final selectedPeerId = _directPeerId(selectedConversation);
    final selectedArchived = _isArchived(selectedConversation?['archived']);
    conversations = conversations.map((conversation) {
      final isSelected = (conversation['id'] as num?)?.toInt() == conversationId;
      final isMergedDirectChat =
          selectedPeerId != null &&
          _directPeerId(conversation) == selectedPeerId &&
          _isArchived(conversation['archived']) == selectedArchived;
      if (!isSelected && !isMergedDirectChat) {
        return conversation;
      }
      return {...conversation, 'unreadCount': 0, 'manuallyUnread': false};
    }).toList();
  }

  int? _directPeerId(Map<String, dynamic>? conversation) {
    if (conversation == null || conversation['type'] != 'direct') return null;
    final members = conversation['members'] as List<dynamic>? ?? const [];
    final otherMembers = members.whereType<Map>().where((member) {
      return (member['id'] as num?)?.toInt() != currentUserId;
    });
    if (otherMembers.length != 1) return null;
    return (otherMembers.first['id'] as num?)?.toInt();
  }

  bool _isArchived(dynamic value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  void setSending(bool nextSending) {
    sending = nextSending;
    notifyListeners();
  }

  void backToInbox() {
    messageRequestId++;
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
