import 'dart:async';

import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';

class MessageNotificationHost extends StatefulWidget {
  const MessageNotificationHost({
    super.key,
    required this.child,
    this.onOpenConversation,
    this.api,
    this.pollingInterval = const Duration(seconds: 5),
    this.notificationDuration = const Duration(seconds: 5),
  });

  final Widget child;
  final ValueChanged<int>? onOpenConversation;
  final AuthApi? api;
  final Duration pollingInterval;
  final Duration notificationDuration;

  @override
  State<MessageNotificationHost> createState() =>
      _MessageNotificationHostState();
}

class _MessageNotificationHostState extends State<MessageNotificationHost>
    with WidgetsBindingObserver {
  late final AuthApi _api = widget.api ?? AuthApi();
  Timer? _pollingTimer;
  Timer? _dismissTimer;
  Map<int, _ConversationSnapshot> _snapshots = {};
  _IncomingMessage? _notification;
  bool _hasBaseline = false;
  bool _pollInFlight = false;
  String? _observedToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_poll(showNotifications: false));
    _pollingTimer = Timer.periodic(
      widget.pollingInterval,
      (_) => unawaited(_poll()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_poll(showNotifications: false));
    }
  }

  Future<void> _poll({bool showNotifications = true}) async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        _snapshots = {};
        _hasBaseline = false;
        _observedToken = null;
        return;
      }
      if (_observedToken != token) {
        _snapshots = {};
        _hasBaseline = false;
        _observedToken = token;
      }

      final conversations = await _api.conversations(token);
      final latestById = <int, _ConversationSnapshot>{};
      for (final conversation in conversations) {
        final id = _asInt(conversation['id']);
        if (id == null) continue;
        latestById[id] = _ConversationSnapshot(
          lastMessageAt: '${conversation['lastMessageAt'] ?? ''}',
          lastMessage: '${conversation['lastMessage'] ?? ''}',
          unreadCount: _asInt(conversation['unreadCount']) ?? 0,
          archived: _asBool(conversation['archived']),
          blocked: _asBool(conversation['blockedByMe']),
          title: _conversationTitle(conversation, session.accountEmail),
        );
      }

      if (_hasBaseline && showNotifications) {
        final incoming = <_IncomingMessage>[];
        for (final entry in latestById.entries) {
          final previous = _snapshots[entry.key];
          final current = entry.value;
          if (previous == null ||
              current.archived ||
              current.blocked ||
              current.unreadCount == 0 ||
              current.lastMessageAt == previous.lastMessageAt ||
              current.lastMessage.isEmpty) {
            continue;
          }
          incoming.add(
            _IncomingMessage(
              conversationId: entry.key,
              title: current.title,
              preview: current.lastMessage,
              lastMessageAt: current.lastMessageAt,
            ),
          );
        }
        incoming.sort((a, b) => a.lastMessageAt.compareTo(b.lastMessageAt));
        if (incoming.isNotEmpty && mounted) {
          _showNotification(incoming.last);
        }
      }

      _snapshots = latestById;
      _hasBaseline = true;
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'message notifications',
          context: ErrorDescription('while checking for incoming messages'),
        ),
      );
    } finally {
      _pollInFlight = false;
    }
  }

  void _showNotification(_IncomingMessage notification) {
    _dismissTimer?.cancel();
    setState(() => _notification = notification);
    _dismissTimer = Timer(widget.notificationDuration, () {
      if (mounted) setState(() => _notification = null);
    });
  }

  void _openConversation(int conversationId) {
    _dismissTimer?.cancel();
    setState(() => _notification = null);
    widget.onOpenConversation?.call(conversationId);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_notification case final notification?)
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Material(
              color: Colors.transparent,
              child: Dismissible(
                key: ValueKey(
                  '${notification.conversationId}-${notification.lastMessageAt}-${notification.preview}',
                ),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _dismissTimer?.cancel();
                  setState(() => _notification = null);
                },
                child: Material(
                  elevation: 8,
                  color: const Color(0xFF192B50),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openConversation(notification.conversationId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFFFE8D2),
                            child: Icon(
                              Icons.chat_bubble_rounded,
                              color: Color(0xFFFF8200),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  notification.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notification.preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFDCE4F2),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            label: 'Dismiss message notification',
                            button: true,
                            child: IconButton(
                              onPressed: () {
                                _dismissTimer?.cancel();
                                setState(() => _notification = null);
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }
}

class _ConversationSnapshot {
  const _ConversationSnapshot({
    required this.lastMessageAt,
    required this.lastMessage,
    required this.unreadCount,
    required this.archived,
    required this.blocked,
    required this.title,
  });

  final String lastMessageAt;
  final String lastMessage;
  final int unreadCount;
  final bool archived;
  final bool blocked;
  final String title;
}

class _IncomingMessage {
  const _IncomingMessage({
    required this.conversationId,
    required this.title,
    required this.preview,
    required this.lastMessageAt,
  });

  final int conversationId;
  final String title;
  final String preview;
  final String lastMessageAt;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

String _conversationTitle(
  Map<String, dynamic> conversation,
  String? accountEmail,
) {
  final title = '${conversation['title'] ?? ''}'.trim();
  if (title.isNotEmpty) return title;
  final members = conversation['members'];
  if (members is List) {
    for (final member in members.whereType<Map>()) {
      if ('${member['email'] ?? ''}'.toLowerCase() ==
          accountEmail?.toLowerCase()) {
        continue;
      }
      final name = [
        member['firstName'],
        member['lastName'],
      ].where((part) => '$part'.trim().isNotEmpty).join(' ').trim();
      if (name.isNotEmpty) return name;
    }
  }
  return 'New message';
}
