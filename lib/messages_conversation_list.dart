import 'package:flutter/material.dart';

import 'messages_ui.dart';

class MessagesConversationList extends StatelessWidget {
  const MessagesConversationList({
    super.key,
    required this.conversations,
    required this.selectedConversationId,
    required this.searchController,
    required this.conversationQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onNewConversation,
    required this.onSelectConversation,
    required this.onOpenContact,
    required this.onConversationAction,
    required this.showArchived,
    required this.showBlocked,
    required this.onToggleArchived,
    required this.onToggleBlocked,
    required this.currentUserId,
  });

  final List<Map<String, dynamic>> conversations;
  final int? selectedConversationId;
  final TextEditingController searchController;
  final String conversationQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onNewConversation;
  final ValueChanged<int> onSelectConversation;
  final Future<void> Function(Map<String, dynamic> contact) onOpenContact;
  final Future<void> Function(
    Map<String, dynamic> conversation,
    String action,
  ) onConversationAction;
  final bool showArchived;
  final bool showBlocked;
  final VoidCallback onToggleArchived;
  final VoidCallback onToggleBlocked;
  final int? currentUserId;

  @override
  Widget build(BuildContext context) {
    final query = conversationQuery.trim().toLowerCase();
    final conversationContacts = _conversationContacts();
    final uniqueConversations = _uniqueDirectConversations()
        .where((conversation) {
          if (!_hasMessages(conversation)) return false;
          final blocked = _asBool(conversation['blockedByMe']);
          if (showBlocked) return blocked;
          if (blocked) return false;
          return _asBool(conversation['archived']) == showArchived;
        })
        .toList();
    final filtered = uniqueConversations.where((conversation) {
      final title = _conversationTitle(conversation).toLowerCase();
      final latest = (conversation['lastMessage'] as String? ?? '')
          .toLowerCase();
      return query.isEmpty || title.contains(query) || latest.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search messages',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: conversationQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: [
              _newMessageBubble(onNewConversation),
              ...conversationContacts
                  .take(12)
                  .map((contact) => _contactBubble(contact, onOpenContact)),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.forum_outlined),
          title: Text(
            showBlocked
                ? 'Blocked'
                : showArchived
                ? 'Archived'
                : 'Chats',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${filtered.length}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              IconButton(
                tooltip: showArchived ? 'Show chats' : 'Show archived chats',
                onPressed: onToggleArchived,
                icon: Icon(
                  showArchived
                      ? Icons.forum_outlined
                      : Icons.archive_outlined,
                ),
              ),
              IconButton(
                tooltip: showBlocked ? 'Show chats' : 'Show blocked people',
                onPressed: onToggleBlocked,
                icon: Icon(
                  showBlocked ? Icons.forum_outlined : Icons.block_outlined,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    conversations.isEmpty
                        ? 'No conversations yet. Tap the edit icon to start.'
                        : showBlocked
                        ? 'No blocked conversations.'
                        : 'No matching conversations.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  children: filtered.map((conversation) {
                    final id = (conversation['id'] as num).toInt();
                    final unread =
                        (conversation['unreadCount'] as num?)?.toInt() ?? 0;
                    final members = _otherMembers(conversation, currentUserId);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: members.isNotEmpty
                          ? MessagesAvatar(members.first, radius: 25)
                          : const CircleAvatar(
                              child: Icon(Icons.groups_rounded),
                            ),
                      selected: id == selectedConversationId,
                      title: Text(
                        _conversationTitle(conversation),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        conversation['lastMessage'] as String? ??
                            'Start a conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: unread > 0
                          ? CircleAvatar(
                              radius: 11,
                              child: Text(
                                '$unread',
                                style: const TextStyle(fontSize: 11),
                              ),
                            )
                          : null,
                      onTap: () => onSelectConversation(id),
                      onLongPress: () =>
                          _showConversationActions(context, conversation),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _showConversationActions(
    BuildContext context,
    Map<String, dynamic> conversation,
  ) async {
    final archived = _asBool(conversation['archived']);
    final unread = _asBool(conversation['manuallyUnread']);
    final direct = safeString(conversation['type']) == 'direct' &&
        _otherMembers(conversation, currentUserId).length == 1;
    final blocked = _asBool(conversation['blockedByMe']);

    final actions = <(String, String, IconData)>[
      (archived ? 'Unarchive' : 'Archive', 'archive', Icons.archive_outlined),
      (
        unread ? 'Mark as read' : 'Mark as unread',
        'unread',
        unread ? Icons.drafts_outlined : Icons.markunread_outlined,
      ),
      if (direct)
        (
          blocked ? 'Unblock person' : 'Block person',
          'block',
          blocked ? Icons.lock_open_outlined : Icons.block_outlined,
        ),
      ('Delete for me', 'delete', Icons.delete_outline_rounded),
    ];

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in actions)
              ListTile(
                leading: Icon(item.$3),
                title: Text(item.$1),
                onTap: () => Navigator.pop(sheetContext, item.$2),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null) return;
    await onConversationAction(conversation, action);
  }

  bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  List<Map<String, dynamic>> _conversationContacts() {
    final contactsById = <int, Map<String, dynamic>>{};
    for (final conversation in conversations) {
      if (!_hasMessages(conversation) ||
          _asBool(conversation['blockedByMe'])) {
        continue;
      }
      for (final member in _otherMembers(conversation, currentUserId)) {
        final id = asInt(member['id']);
        if (id != null) {
          contactsById.putIfAbsent(id, () => member);
        }
      }
    }
    return contactsById.values.toList();
  }

  bool _hasMessages(Map<String, dynamic> conversation) {
    final lastMessageAt = conversation['lastMessageAt'];
    return lastMessageAt != null && lastMessageAt.toString().isNotEmpty;
  }

  List<Map<String, dynamic>> _uniqueDirectConversations() {
    final unique = <String, Map<String, dynamic>>{};
    final unreadCounts = <String, int>{};

    for (final conversation in conversations) {
      final members = _otherMembers(conversation, currentUserId);
      final id = asInt(conversation['id']);
      final archived = _asBool(conversation['archived']);
      final key =
          safeString(conversation['type']) == 'direct' &&
              members.length == 1 &&
              asInt(members.first['id']) != null
          ? 'direct:${asInt(members.first['id'])}:$archived'
          : 'conversation:$id';

      unreadCounts.update(
        key,
        (count) =>
            count + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
        ifAbsent: () => (conversation['unreadCount'] as num?)?.toInt() ?? 0,
      );

      final existing = unique[key];
      if (existing == null || id == selectedConversationId) {
        unique[key] = conversation;
      }
    }

    return unique.entries
        .map(
          (entry) => {
            ...entry.value,
            'unreadCount': unreadCounts[entry.key] ?? 0,
          },
        )
        .toList();
  }

  Widget _newMessageBubble(VoidCallback onNewConversation) => GestureDetector(
    onTap: onNewConversation,
    child: Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          const CircleAvatar(radius: 27, child: Icon(Icons.add_rounded)),
          const SizedBox(height: 5),
          Text('New', style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    ),
  );

  Widget _contactBubble(
    Map<String, dynamic> contact,
    Future<void> Function(Map<String, dynamic> contact) onOpenContact,
  ) => GestureDetector(
    onTap: () => onOpenContact(contact),
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MessagesAvatar(contact, radius: 27),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              displayName(contact).split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );

  String _conversationTitle(Map<String, dynamic> conversation) {
    final title = safeString(conversation['title']);
    final members = _otherMembers(conversation, currentUserId);
    if (safeString(conversation['type']) == 'group' && title.isNotEmpty) {
      return title;
    }
    final names = members
        .map(displayName)
        .where((value) => value.isNotEmpty)
        .toList();
    if (names.isNotEmpty) return names.join(', ');
    if (title.isNotEmpty) return title;
    return 'Conversation';
  }

  List<Map<String, dynamic>> _otherMembers(
    Map<String, dynamic> conversation,
    int? currentUserId,
  ) {
    return (conversation['members'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .where((member) => asInt(member['id']) != currentUserId)
        .toList();
  }
}
