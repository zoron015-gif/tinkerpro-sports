import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'messages_service.dart';
import 'messages_ui.dart';
import 'messages_conversation_list.dart';
import 'messages_chat_view.dart';
import 'messages_controller.dart';
import 'profile_dashboard.dart';
import 'saved_dashboard.dart';
import 'news_feed.dart';
import 'customer_bookings_page.dart';

const _messageBackground = Color(0xFFF7F9FC);
const _messageNavy = Color(0xFF192B50);
const _messageMuted = Color(0xFF68748A);
const _messageOrange = Color(0xFFFF8200);
const _messageSoftOrange = Color(0xFFFFE8D2);

class MessagesDashboardPage extends StatefulWidget {
  const MessagesDashboardPage({
    super.key,
    this.owner,
    this.businessTitle,
    this.onFooterNavigate,
  });

  final Map<String, dynamic>? owner;
  final String? businessTitle;
  final ValueChanged<int>? onFooterNavigate;

  @override
  State<MessagesDashboardPage> createState() => _MessagesDashboardPageState();
}

class _MessagesDashboardPageState extends State<MessagesDashboardPage> {
  final _messagesService = MessagesService();
  final _controller = MessagesController();
  final _composer = TextEditingController();
  final _conversationSearch = TextEditingController();
  final _contactSearch = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _pendingImage;
  String? _pendingImageData;
  bool _ownerConversationOpened = false;

  int get _unreadMessageCount => _controller.unreadMessageCount;

  String? get _token => _controller.token;
  String? get _role => _controller.role;
  int? get _currentUserId => _controller.currentUserId;
  int? get _selectedConversation => _controller.selectedConversationId;
  List<Map<String, dynamic>> get _conversations => _controller.conversations;
  List<Map<String, dynamic>> get _contacts => _controller.contacts;
  List<Map<String, dynamic>> get _messages => _controller.messages;
  bool get _loading => _controller.loading;
  bool get _sending => _controller.sending;
  bool get _showChat => _controller.showChat;
  String get _conversationQuery => _controller.conversationQuery;
  bool get _showArchived => _controller.showArchivedConversations;
  bool get _showBlocked => _controller.showBlockedConversations;

  void _setConversationQuery(String value) {
    _controller.setConversationQuery(value);
  }

  void _clearConversationQuery() {
    _controller.clearConversationQuery();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChange);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _controller.disposeController();
    _composer.dispose();
    _conversationSearch.dispose();
    _contactSearch.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load() async {
    try {
      await _controller.load();
      if (!mounted) return;
      if (widget.owner != null && !_ownerConversationOpened) {
        _ownerConversationOpened = true;
        final ownerId = _asInt(widget.owner?['id']);
        if (ownerId == null) return;

        final id = await _controller.openOwnerConversation(
          ownerId: ownerId,
          businessTitle: widget.businessTitle,
        );
        if (!mounted || id == null) return;
        await _select(id);
      }
    } on Exception catch (error) {
      if (mounted) {
        _show(error.toString());
      }
    }
  }

  Future<void> _select(int id) async {
    final token = _token;
    if (token == null) return;
    final requestId = ++_controller.messageRequestId;
    if (!mounted) return;
    _controller.setSelectedConversation(id);
    try {
      final messages = await _messagesService.fetchMessages(
        token: token,
        conversationId: id,
      );
      if (!mounted || requestId != _controller.messageRequestId) return;
      if (_controller.selectedConversationId != id) return;
      _controller.setMessages(messages);
    } on Exception catch (error) {
      if (mounted && requestId == _controller.messageRequestId) {
        _show(error.toString());
      }
    }
  }

  Future<void> _send() async {
    final token = _token;
    final id = _selectedConversation;
    final text = _composer.text.trim();
    if (token == null ||
        id == null ||
        (text.isEmpty && _pendingImageData == null) ||
        _sending) {
      return;
    }
    _controller.setSending(true);
    try {
      await _messagesService.sendMessage(
        token: token,
        conversationId: id,
        body: text,
        attachment: _pendingImageData == null
            ? null
            : {
                'type': 'image',
                'name': _pendingImage?.name ?? 'image',
                'data': _pendingImageData,
              },
      );
      _composer.clear();
      if (mounted) {
        setState(() {
          _pendingImage = null;
          _pendingImageData = null;
        });
      }
      await _select(id);
      await _load();
    } on Exception catch (error) {
      _show(error.toString());
    } finally {
      _controller.setSending(false);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final token = _token;
    final conversationId = _selectedConversation;
    final messageId = _asInt(message['id']);
    if (token == null || conversationId == null || messageId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _messagesService.deleteMessage(
        token: token,
        conversationId: conversationId,
        messageId: messageId,
      );
      if (!mounted || _selectedConversation != conversationId) return;
      setState(() {
        _messages.removeWhere((item) => _asInt(item['id']) == messageId);
      });
      _show('Message deleted.');
    } on Exception catch (error) {
      _show('Could not delete message: $error');
    }
  }

  Future<void> _handleConversationAction(
    Map<String, dynamic> conversation,
    String action,
  ) async {
    final token = _token;
    final conversationId = _asInt(conversation['id']);
    if (token == null || conversationId == null) return;

    try {
      switch (action) {
        case 'archive':
          await _messagesService.setConversationState(
            token: token,
            conversationId: conversationId,
            archived: !(conversation['archived'] == true ||
                conversation['archived'] == 1),
          );
          break;
        case 'unread':
          final markUnread = !(conversation['manuallyUnread'] == true ||
              conversation['manuallyUnread'] == 1);
          await _messagesService.setConversationState(
            token: token,
            conversationId: conversationId,
            unread: markUnread,
          );
          if (markUnread && _selectedConversation == conversationId) {
            _controller.backToInbox();
          }
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Delete conversation for you?'),
              content: const Text(
                'This removes the conversation from your inbox only. '
                'Other participants will still have their messages.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete for me'),
                ),
              ],
            ),
          );
          if (confirmed != true || !mounted) return;
          await _messagesService.deleteConversation(
            token: token,
            conversationId: conversationId,
          );
          if (_selectedConversation == conversationId) {
            _controller.backToInbox();
          }
          break;
        case 'block':
          final members = (conversation['members'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((member) => Map<String, dynamic>.from(member))
              .where((member) => _asInt(member['id']) != _currentUserId)
              .toList();
          if (members.length != 1) return;
          final userId = _asInt(members.first['id']);
          if (userId == null) return;
          final isBlocked = conversation['blockedByMe'] == true ||
              conversation['blockedByMe'] == 1;
          if (isBlocked) {
            await _messagesService.unblockUser(token: token, userId: userId);
          } else {
            await _messagesService.blockUser(token: token, userId: userId);
          }
          break;
        default:
          return;
      }

      if (!mounted) return;
      await _controller.load();
      if (mounted) _show('Conversation updated.');
    } on Exception catch (error) {
      _show('Could not update conversation: $error');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        _show('Please choose an image smaller than 5 MB.');
        return;
      }
      final mime = image.mimeType ?? 'image/jpeg';
      if (!mime.startsWith('image/')) {
        _show('Please choose a valid image file.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _pendingImage = image;
        _pendingImageData = 'data:$mime;base64,${base64Encode(bytes)}';
      });
    } on Exception catch (error) {
      _show('Could not select the image: $error');
    }
  }

  void _removePendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingImageData = null;
    });
  }

  void _backToInbox() {
    FocusScope.of(context).unfocus();
    _controller.backToInbox();
  }

  Future<void> _startConversation() async {
    if (_token == null || _contacts.isEmpty) return;
    final selected = <int>{};
    final titleController = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = _contactSearch.text.trim().toLowerCase();
          final contacts = _contacts.where((contact) {
            final name = _displayName(contact).toLowerCase();
            final email = contact['email'] as String? ?? '';
            return query.isEmpty ||
                name.contains(query) ||
                email.toLowerCase().contains(query);
          }).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New message',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected.isEmpty
                          ? 'Choose who you want to communicate with'
                          : '${selected.length} recipient${selected.length == 1 ? '' : 's'} selected',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _contactSearch,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _contactSearch.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _contactSearch.clear();
                                  setDialogState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (selected.length > 1) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Group name (optional)',
                          prefixIcon: Icon(Icons.group_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (_, index) {
                          final contact = contacts[index];
                          final id = (contact['id'] as num).toInt();
                          final checked = selected.contains(id);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _avatar(contact, radius: 24),
                            title: Text(
                              _displayName(contact),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              (contact['role'] as String? ?? 'user')
                                  .toUpperCase(),
                            ),
                            trailing: Icon(
                              checked
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: checked
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade400,
                            ),
                            onTap: () => setDialogState(() {
                              checked ? selected.remove(id) : selected.add(id);
                            }),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(dialogContext, true),
                            child: Text(
                              selected.length > 1 ? 'Create group' : 'Message',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final title = titleController.text.trim();
    titleController.dispose();
    _contactSearch.clear();
    if (created != true || selected.isEmpty || _token == null) return;
    try {
      final id = await _messagesService.openConversation(
        token: _token!,
        participantIds: selected.toList(),
        title: selected.length > 1
            ? (title.isEmpty ? 'Group conversation' : title)
            : null,
        group: selected.length > 1,
      );
      await _load();
      await _select(id);
    } on Exception catch (error) {
      _show(error.toString());
    }
  }

  String _conversationTitle(Map<String, dynamic> conversation) {
    final title = _safeString(conversation['title']);
    final members = _otherMembers(conversation);
    if (_safeString(conversation['type']) == 'group' && title.isNotEmpty) {
      return title;
    }
    final names = members
        .map(_displayName)
        .where((value) => value.isNotEmpty)
        .toList();
    if (names.isNotEmpty) return names.join(', ');
    if (title.isNotEmpty) return title;
    return 'Conversation';
  }

  List<Map<String, dynamic>> _otherMembers(Map<String, dynamic> conversation) {
    return (conversation['members'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .where((member) => _asInt(member['id']) != _currentUserId)
        .toList();
  }

  String _displayName(Map<String, dynamic> user) => displayName(user);

  int? _asInt(Object? value) => asInt(value);

  String _safeString(Object? value, [String fallback = '']) =>
      safeString(value, fallback);

  Widget _avatar(Map<String, dynamic> user, {double radius = 22}) =>
      MessagesAvatar(user, radius: radius);

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _messageBackground,
      appBar: AppBar(
        backgroundColor: _messageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: _messageNavy,
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: _messageNavy),
        leading: _showChat
            ? IconButton(
                tooltip: 'Back to inbox',
                onPressed: _backToInbox,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(
          _showChat && _selectedConversation != null
              ? _selectedConversationTitle()
              : 'Messages',
        ),
        actions: [
          IconButton(
            tooltip: 'New message',
            onPressed: _startConversation,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: _messageOrange,
              backgroundColor: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  final list = MessagesConversationList(
                    conversations: _conversations,
                    selectedConversationId: _selectedConversation,
                    searchController: _conversationSearch,
                    conversationQuery: _conversationQuery,
                    onSearchChanged: _setConversationQuery,
                    onClearSearch: () {
                      _conversationSearch.clear();
                      _clearConversationQuery();
                    },
                    onNewConversation: _startConversation,
                    onSelectConversation: _select,
                    onOpenContact: (contact) async {
                      if (_token == null) return;
                      try {
                        final id = await _messagesService.openConversation(
                          token: _token!,
                          recipientId: (contact['id'] as num).toInt(),
                        );
                        await _load();
                        await _select(id);
                      } on Exception catch (error) {
                        _show(error.toString());
                      }
                    },
                    onConversationAction: _handleConversationAction,
                    showArchived: _showArchived,
                    showBlocked: _showBlocked,
                    onToggleArchived: () => _controller
                        .setShowArchivedConversations(!_showArchived),
                    onToggleBlocked: () => _controller
                        .setShowBlockedConversations(!_showBlocked),
                    currentUserId: _currentUserId,
                  );
                  final chat = _selectedConversation == null
                      ? const Center(
                          child: Text('Select a conversation to start.'),
                        )
                      : MessagesChatView(
                          messages: _messages,
                          currentUserId: _currentUserId,
                          blocked: _selectedConversationIsBlocked,
                          composer: _composer,
                          pendingImageData: _pendingImageData,
                          sending: _sending,
                          onDeleteMessage: _deleteMessage,
                          onPickImage: _pickImage,
                          onRemovePendingImage: _removePendingImage,
                          onSend: _send,
                        );
                  return wide
                      ? Row(
                          children: [
                            SizedBox(width: 310, child: list),
                            Expanded(child: chat),
                          ],
                        )
                      : _showChat && _selectedConversation != null
                      ? chat
                      : list;
                },
              ),
            ),
      bottomNavigationBar: _role == null ? null : _footer(context),
    );
  }

  Widget _footer(BuildContext context) {
    final isMerchant = _role == 'merchant';
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: const Color(0x14000000),
          elevation: 2,
          indicatorColor: _messageSoftOrange,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? _messageOrange : _messageMuted,
              size: 24,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? const Color(0xFF101B33) : _messageMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            );
          }),
        ),
      ),
      child: NavigationBar(
        height: 72,
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        selectedIndex: 2,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == 2) return;
          if (isMerchant) {
            if (widget.onFooterNavigate != null) {
              widget.onFooterNavigate!(index);
            } else if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          }
          final page = switch (index) {
            0 => NewsFeedPage(onLogout: (_) async {}),
            1 => SavedDashboardPage(onLogout: (_) async {}),
            3 => CustomerBookingsPage(onLogout: (_) async {}),
            4 => ProfileDashboardPage(onLogout: (_) async {}),
            _ => null,
          };
          if (page != null && mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => page),
              (route) => route.isFirst,
            );
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(
              isMerchant
                  ? Icons.storefront_outlined
                  : Icons.location_on_outlined,
            ),
            selectedIcon: Icon(
              isMerchant ? Icons.storefront_rounded : Icons.location_on_rounded,
            ),
            label: isMerchant ? 'Venues' : 'Explore',
          ),
          NavigationDestination(
            icon: Icon(
              isMerchant
                  ? Icons.add_circle_outline
                  : Icons.favorite_border_rounded,
            ),
            selectedIcon: Icon(
              isMerchant ? Icons.add_circle : Icons.favorite_rounded,
            ),
            label: isMerchant ? 'Add' : 'Saved',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text(
                _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
              ),
              child: Icon(Icons.send_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadMessageCount > 0,
              label: Text(
                _unreadMessageCount > 99 ? '99+' : '$_unreadMessageCount',
              ),
              child: Icon(Icons.send_rounded),
            ),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(
              isMerchant
                  ? Icons.payments_outlined
                  : Icons.calendar_today_outlined,
            ),
            selectedIcon: Icon(
              isMerchant
                  ? Icons.payments_rounded
                  : Icons.calendar_today_rounded,
            ),
            label: isMerchant ? 'Payouts' : 'Bookings',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _selectedConversationTitle() {
    for (final conversation in _conversations) {
      if ((conversation['id'] as num?)?.toInt() == _selectedConversation) {
        return _conversationTitle(conversation);
      }
    }
    return 'Chat';
  }

  bool get _selectedConversationIsBlocked {
    for (final conversation in _conversations) {
      if (_asInt(conversation['id']) == _selectedConversation) {
        final value = conversation['blockedByMe'];
        return value == true || value == 1 || value == '1';
      }
    }
    return false;
  }

}
