import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'messages_service.dart';
import 'auth_api.dart';
import 'skeleton_loader.dart';
import 'messages_ui.dart';
import 'messages_conversation_list.dart';
import 'messages_chat_view.dart';
import 'messages_controller.dart';
import 'profile_dashboard.dart';
import 'saved_dashboard.dart';
import 'news_feed.dart';
import 'customer_bookings_page.dart';
import 'app_bottom_navigation.dart';
import 'app_design_system.dart';
import 'app_preferences.dart';
import 'core/business_type.dart';
import 'event_dashboard.dart';
import 'fitness_dashboard.dart';

Color get _messageBackground => AppColors.page;
Color get _messageInk => AppColors.ink;
Color get _messageOrange => AppColors.accent;

class MessagesDashboardPage extends StatefulWidget {
  const MessagesDashboardPage({
    super.key,
    this.owner,
    this.businessTitle,
    this.initialConversationId,
    this.onFooterNavigate,
    this.initialUserPosition,
    this.api,
    this.businessType,
  });

  final Map<String, dynamic>? owner;
  final String? businessTitle;
  final int? initialConversationId;
  final ValueChanged<int>? onFooterNavigate;
  final Position? initialUserPosition;
  final AuthApi? api;
  final String? businessType;

  @override
  State<MessagesDashboardPage> createState() => _MessagesDashboardPageState();
}

class _MessagesDashboardPageState extends State<MessagesDashboardPage> {
  late final MessagesService _messagesService;
  late final MessagesController _controller;
  final _composer = TextEditingController();
  final _conversationSearch = TextEditingController();
  final _contactSearch = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _pendingImage;
  String? _pendingImageData;
  bool _ownerConversationOpened = false;
  bool _initialConversationOpened = false;

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
    _messagesService = MessagesService(api: widget.api);
    _controller = MessagesController(
      service: _messagesService,
      businessType: widget.businessType,
    );
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
      } else if (widget.initialConversationId case final conversationId?
          when !_initialConversationOpened) {
        _initialConversationOpened = true;
        await _select(conversationId);
      }
    } on Exception catch (error) {
      if (mounted) {
        _show(error.toString());
      }
    }
  }

  Future<void> _select(int id) async {
    try {
      await _controller.select(id);
    } on Exception catch (error) {
      _show(error.toString());
    }
  }

  String? _composerError;

  void _onComposerChanged(String _) {
    if (_composerError == null) return;
    setState(() => _composerError = null);
  }

  Future<void> _send() async {
    final token = _token;
    final id = _selectedConversation;
    final text = _composer.text.trim();
    if (token == null || id == null || _sending) {
      return;
    }
    if (text.isEmpty && _pendingImageData == null) {
      setState(() => _composerError = 'Write a message or attach an image.');
      return;
    }
    setState(() => _composerError = null);
    _controller.setSending(true);
    try {
      await _messagesService.sendMessage(
        token: token,
        conversationId: id,
        body: text,
        businessType: widget.businessType,
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

    final isOwnMessage =
        _currentUserId != null &&
        _asInt(message['senderId']) == _currentUserId;
    final scope = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: false,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      appLanguageText(
                        'Delete 1 message?',
                        'Delete 1 message?',
                      ),
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: appLanguageText('Close', 'Close'),
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (isOwnMessage)
                ListTile(
                  key: const ValueKey('delete-message-everyone'),
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: AppText(
                    appLanguageText(
                      'Delete for everyone',
                      'Delete for everyone',
                    ),
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'everyone'),
                ),
              ListTile(
                key: const ValueKey('delete-message-me'),
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: AppText(
                  appLanguageText('Delete for me', 'Delete for me'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(sheetContext, 'me'),
              ),
            ],
          ),
        ),
      ),
    );
    if (scope == null || !mounted) return;

    try {
      await _messagesService.deleteMessage(
        token: token,
        conversationId: conversationId,
        messageId: messageId,
        scope: scope,
      );
      if (!mounted || _selectedConversation != conversationId) return;
      if (scope == 'everyone') {
        final senderFirstName = '${message['senderFirstName'] ?? ''}'.trim();
        final senderLastName = '${message['senderLastName'] ?? ''}'.trim();
        final removedByName = '$senderFirstName $senderLastName'.trim();
        _controller.setMessages(
          _messages
              .map(
                (item) => _asInt(item['id']) == messageId
                    ? {
                        ...item,
                        'body': null,
                        'attachment': null,
                        'removedAt': DateTime.now().toIso8601String(),
                        'removedByName': removedByName.isEmpty
                            ? 'You'
                            : removedByName,
                      }
                    : item,
              )
              .toList(),
        );
        try {
          final refreshedMessages = await _messagesService.fetchMessages(
            token: token,
            conversationId: conversationId,
            businessType: widget.businessType,
          );
          if (!mounted || _selectedConversation != conversationId) return;
          _controller.setMessages(refreshedMessages);
        } on Exception catch (error) {
          _show(
            'Message removed for everyone, but chat refresh failed: $error',
          );
          return;
        }
        _show('Message deleted for everyone.');
      } else {
        _controller.setMessages(
          _messages
              .where((item) => _asInt(item['id']) != messageId)
              .toList(),
        );
        _show('Message deleted for you.');
      }
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
          final archived =
              !(conversation['archived'] == true ||
                  conversation['archived'] == 1 ||
                  conversation['archived'] == '1' ||
                  conversation['archived'] == 'true');
          await _messagesService.setConversationState(
            token: token,
            conversationId: conversationId,
            archived: archived,
          );
          _controller.setConversationArchived(conversationId, archived);
          break;
        case 'unread':
          final markUnread =
              !(conversation['manuallyUnread'] == true ||
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
              title: const AppText(
                'Delete conversation for you?',
                localize: true,
              ),
              content: const AppText(
                'This removes the conversation from your inbox only. '
                'Other participants will still have their messages.',
                localize: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const AppText('Cancel', localize: true),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const AppText('Delete for me', localize: true),
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
          final isBlocked =
              conversation['blockedByMe'] == true ||
              conversation['blockedByMe'] == 1;
          if (isBlocked) {
            await _messagesService.unblockUser(token: token, userId: userId);
          } else {
            await _messagesService.blockUser(token: token, userId: userId);
          }
          _controller.setUserBlocked(userId, !isBlocked);
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
    var showRecipientError = false;
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
                    const AppText(
                      'New message',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                      localize: true,
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      selected.isEmpty
                          ? 'Choose who you want to communicate with'
                          : '${selected.length} recipient${selected.length == 1 ? '' : 's'} selected',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (showRecipientError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: AppText(
                          'Select at least one recipient to continue.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          localize: true,
                        ),
                      ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _contactSearch,
                      onChanged: (_) => setDialogState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: appLanguageText(
                          'Search people',
                          'Search people',
                        ),
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
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: appLanguageText(
                            'Group name (optional)',
                            'Group name (optional)',
                          ),
                          prefixIcon: Icon(Icons.group_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: contacts.length,
                        itemBuilder: (_, index) {
                          final contact = contacts[index];
                          final id = (contact['id'] as num).toInt();
                          final checked = selected.contains(id);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _avatar(contact, radius: 24),
                            title: AppText(
                              _displayName(contact),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: AppText(
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
                              showRecipientError = false;
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
                            child: const AppText('Cancel', localize: true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              if (selected.isEmpty) {
                                setDialogState(() => showRecipientError = true);
                                return;
                              }
                              Navigator.pop(dialogContext, true);
                            },
                            child: AppText(
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
      SnackBar(content: AppText(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _messageBackground,
      appBar: AppBar(
        toolbarHeight: _role == 'merchant' ? 56 : null,
        titleSpacing: _role == 'merchant' ? 16 : null,
        leadingWidth: _role == 'merchant' ? 56 : null,
        backgroundColor: _messageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.pageTitle.copyWith(color: _messageInk),
        iconTheme: IconThemeData(color: _messageInk),
        leading: _showChat
            ? IconButton(
                tooltip: appLanguageText('Back to inbox', 'Back to inbox'),
                onPressed: _backToInbox,
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: AppText(
          _showChat && _selectedConversation != null
              ? _selectedConversationTitle()
              : 'Messages',
        ),
        actions: [
          if (!_showChat)
            PopupMenuButton<String>(
              tooltip: appLanguageText(
                'Conversation settings',
                'Conversation settings',
              ),
              icon: const Icon(Icons.settings_outlined),
              onSelected: (value) {
                switch (value) {
                  case 'chats':
                    _controller.setShowArchivedConversations(false);
                    _controller.setShowBlockedConversations(false);
                  case 'archived':
                    _controller.setShowArchivedConversations(true);
                  case 'blocked':
                    _controller.setShowBlockedConversations(true);
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'chats',
                  checked: !_showArchived && !_showBlocked,
                  child: const Row(
                    children: [
                      Icon(Icons.forum_outlined, size: 20),
                      SizedBox(width: 6),
                      AppText('Chats', localize: true),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'archived',
                  checked: _showArchived,
                  child: const Row(
                    children: [
                      Icon(Icons.archive_outlined, size: 20),
                      SizedBox(width: 6),
                      AppText('Archive', localize: true),
                    ],
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'blocked',
                  checked: _showBlocked,
                  child: const Row(
                    children: [
                      Icon(Icons.block_outlined, size: 20),
                      SizedBox(width: 6),
                      AppText('Blocked', localize: true),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: appLanguageText('New conversation', 'New conversation'),
            onPressed: _startConversation,
            icon: const Icon(Icons.people_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? ListView(
              key: const ValueKey('messages-loading-skeleton'),
              padding: const EdgeInsets.all(16),
              children: [
                const SkeletonBlock(height: 46, borderRadius: 14),
                const SizedBox(height: 6),
                for (var index = 0; index < 6; index++) ...[
                  const Row(
                    children: [
                      SkeletonBlock(width: 46, height: 46, borderRadius: 23),
                      SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBlock(width: 155, height: 15),
                            SizedBox(height: 6),
                            SkeletonBlock(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (index < 5) const SizedBox(height: 6),
                ],
              ],
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: _messageOrange,
              backgroundColor: AppColors.surface,
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
                    currentUserId: _currentUserId,
                  );
                  final chat = _selectedConversation == null
                      ? const Center(
                          child: AppText(
                            'Select a conversation to start.',
                            localize: true,
                          ),
                        )
                      : MessagesChatView(
                          messages: _messages,
                          currentUserId: _currentUserId,
                          blocked: _selectedConversationIsBlocked,
                          composer: _composer,
                          pendingImageData: _pendingImageData,
                          sending: _sending,
                          composerError: _composerError,
                          onComposerChanged: _onComposerChanged,
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
    return AppBottomNavigation(
      selectedIndex: 2,
      unreadMessageCount: _unreadMessageCount,
      merchantMode: isMerchant,
      hideMerchantVenues: isMerchant,
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
          0 => switch (BusinessTypeParser.parse(widget.businessType)) {
            BusinessType.event => EventDashboardPage(
              onLogout: (_) async {},
              api: widget.api,
              initialUserPosition: widget.initialUserPosition,
            ),
            BusinessType.fitness => FitnessDashboardPage(
              onLogout: (_) async {},
              api: widget.api,
              initialUserPosition: widget.initialUserPosition,
            ),
            _ => NewsFeedPage(
              onLogout: (_) async {},
              api: widget.api,
              initialUserPosition: widget.initialUserPosition,
              businessType: widget.businessType ?? 'Sports',
            ),
          },
          1 => SavedDashboardPage(
            onLogout: (_) async {},
            itemType: SavedDashboardPage.itemTypeForBusinessType(
              widget.businessType,
            ),
            initialUserPosition: widget.initialUserPosition,
          ),
          3 => CustomerBookingsPage(
            onLogout: (_) async {},
            initialUserPosition: widget.initialUserPosition,
            businessType: widget.businessType,
          ),
          4 => ProfileDashboardPage(
            onLogout: (_) async {},
            initialUserPosition: widget.initialUserPosition,
            businessType: widget.businessType,
          ),
          _ => null,
        };
        if (page != null && mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => page),
            (route) => route.isFirst,
          );
        }
      },
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
