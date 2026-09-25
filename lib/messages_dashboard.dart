import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_session.dart';
import 'auth_api.dart';
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
  final _api = AuthApi();
  final _composer = TextEditingController();
  final _conversationSearch = TextEditingController();
  final _contactSearch = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _token;
  String? _role;
  int? _currentUserId;
  int? _selectedConversation;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  XFile? _pendingImage;
  String? _pendingImageData;
  bool _ownerConversationOpened = false;
  String _conversationQuery = '';
  bool _showChat = false;
  int _loadRequestId = 0;
  int _messageRequestId = 0;
  Timer? _realtimeTimer;
  bool _realtimeRefreshInFlight = false;

  int get _unreadMessageCount => _conversations.fold<int>(
    0,
    (total, conversation) =>
        total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _composer.dispose();
    _conversationSearch.dispose();
    _contactSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_loadRequestId;
    try {
      final session = await AppSession.load();
      final token = session.apiToken;
      if (token == null || token.isEmpty) {
        throw const AuthApiException('Your session has expired.', 401);
      }
      final conversations = await _api.conversations(token);
      final contacts = await _api.messageContacts(token);
      final currentUser = await _api.me(token);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _token = token;
        _role = session.role;
        _currentUserId =
            ((currentUser['user'] as Map<String, dynamic>?)?['id'] as num?)
                ?.toInt();
        _conversations = conversations;
        _contacts = contacts;
        _loading = false;
      });
      _startRealtimeUpdates();
      if (widget.owner != null && !_ownerConversationOpened) {
        _ownerConversationOpened = true;
        final ownerId = _asInt(widget.owner?['id']);
        if (ownerId == null) {
          return;
        }

        final id = await _api.openConversation(
          token: token,
          recipientId: ownerId,
          title: widget.businessTitle,
        );
        if (!mounted || requestId != _loadRequestId) return;
        await _select(id);
      }
    } on Exception catch (error) {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loading = false);
        _show(error.toString());
      }
    }
  }

  void _startRealtimeUpdates() {
    _realtimeTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshRealtime()),
    );
  }

  Future<void> _refreshRealtime() async {
    final token = _token;
    if (token == null || _realtimeRefreshInFlight) return;

    _realtimeRefreshInFlight = true;
    try {
      final selectedConversation = _selectedConversation;
      final conversationsFuture = _api.conversations(token);
      final messagesFuture = selectedConversation == null
          ? null
          : _api.conversationMessages(
              token: token,
              conversationId: selectedConversation,
            );
      final conversations = await conversationsFuture;
      final messages = messagesFuture == null ? null : await messagesFuture;

      if (!mounted || token != _token) return;
      setState(() {
        _conversations = conversations;
        if (selectedConversation != null &&
            selectedConversation == _selectedConversation &&
            messages != null) {
          _messages = messages;
        }
      });
    } on AuthApiException catch (error) {
      if (mounted && error.statusCode == 401) {
        _show(error.toString());
      }
    } on Exception catch (error) {
      debugPrint('Realtime message refresh failed: $error');
    } finally {
      _realtimeRefreshInFlight = false;
    }
  }

  Future<void> _select(int id) async {
    final token = _token;
    if (token == null) return;
    final requestId = ++_messageRequestId;
    if (!mounted) return;
    setState(() {
      _selectedConversation = id;
      _messages = [];
      _showChat = true;
    });
    try {
      final messages = await _api.conversationMessages(
        token: token,
        conversationId: id,
      );
      if (!mounted || requestId != _messageRequestId) return;
      if (_selectedConversation != id) return;
      setState(() => _messages = messages);
    } on Exception catch (error) {
      if (mounted && requestId == _messageRequestId) {
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
    setState(() => _sending = true);
    try {
      await _api.sendConversationMessage(
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
      if (mounted) setState(() => _sending = false);
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
      await _api.deleteConversationMessage(
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
    setState(() {
      _showChat = false;
      _selectedConversation = null;
      _messages = [];
    });
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
      final id = await _api.openConversation(
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

  String _displayName(Map<String, dynamic> user) {
    final first = _safeString(user['firstName']);
    final last = _safeString(user['lastName']);
    final name = '$first $last'.trim();
    if (name.isNotEmpty) return name;
    final email = _safeString(user['email']);
    if (email.isNotEmpty) return email;
    return 'User';
  }

  String _initials(Map<String, dynamic> user) {
    final name = _displayName(user);
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _safeString(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic>? _attachmentValue(Map<String, dynamic> message) {
    final raw = message['attachment'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  String _messageBody(Map<String, dynamic> message) =>
      _safeString(message['body']);

  Widget _avatar(Map<String, dynamic> user, {double radius = 22}) {
    final image = _safeString(user['avatarUrl']);
    return CircleAvatar(
      radius: radius,
      backgroundColor: _messageSoftOrange,
      backgroundImage: _avatarImage(image),
      child: image.trim().isEmpty || _avatarImage(image) == null
          ? Text(
              _initials(user),
              style: const TextStyle(
                color: _messageOrange,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  ImageProvider<Object>? _avatarImage(String image) {
    final value = image.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      final separator = value.indexOf(',');
      if (separator <= 0 || separator >= value.length - 1) return null;
      try {
        return MemoryImage(base64Decode(value.substring(separator + 1)));
      } on FormatException {
        return null;
      }
    }
    return NetworkImage(value);
  }

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  final list = _conversationList();
                  final chat = _selectedConversation == null
                      ? const Center(
                          child: Text('Select a conversation to start.'),
                        )
                      : _chat();
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

  Widget _conversationList() {
    final query = _conversationQuery.trim().toLowerCase();
    final conversations = _conversations.where((conversation) {
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
            controller: _conversationSearch,
            onChanged: (value) => setState(() => _conversationQuery = value),
            decoration: InputDecoration(
              hintText: 'Search messages',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _conversationQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _conversationSearch.clear();
                        setState(() => _conversationQuery = '');
                      },
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
              _newMessageBubble(),
              ..._contacts.take(12).map(_contactBubble),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.forum_outlined),
          title: const Text(
            'Chats',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: Text(
            '${conversations.length}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Text(
                    _conversations.isEmpty
                        ? 'No conversations yet. Tap the edit icon to start.'
                        : 'No matching conversations.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  children: conversations.map((conversation) {
                    final id = (conversation['id'] as num).toInt();
                    final unread =
                        (conversation['unreadCount'] as num?)?.toInt() ?? 0;
                    final members = _otherMembers(conversation);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: members.isNotEmpty
                          ? _avatar(members.first, radius: 25)
                          : const CircleAvatar(
                              child: Icon(Icons.groups_rounded),
                            ),
                      selected: id == _selectedConversation,
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
                      onTap: () => _select(id),
                    );
                  }).toList(),
                ),
        ),
      ],
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

  Widget _newMessageBubble() => GestureDetector(
    onTap: _startConversation,
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

  Widget _contactBubble(Map<String, dynamic> contact) => GestureDetector(
    onTap: () async {
      if (_token == null) return;
      try {
        final id = await _api.openConversation(
          token: _token!,
          recipientId: (contact['id'] as num).toInt(),
        );
        await _load();
        await _select(id);
      } on Exception catch (error) {
        _show(error.toString());
      }
    },
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(contact, radius: 27),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              _displayName(contact).split(' ').first,
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

  Widget _chat() => Column(
    children: [
      Expanded(
        child: _messages.isEmpty
            ? const Center(child: Text('Write the first message.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final mine = _asInt(message['senderId']) == _currentUserId;
                  final attachment = _attachmentValue(message);
                  final body = _messageBody(message);
                  final bubble = Card(
                    color: mine ? const Color(0xFFFFE8D2) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((attachment != null &&
                              _safeString(attachment['type']) == 'image'))
                            _messageImage(attachment),
                          if (body.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(body),
                            ),
                        ],
                      ),
                    ),
                  );
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: mine
                        ? GestureDetector(
                            onLongPress: () => _deleteMessage(message),
                            child: bubble,
                          )
                        : bubble,
                  );
                },
              ),
      ),
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingImageData != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(_pendingImageData!.split(',').last),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _removePendingImage,
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _messageNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Attach image',
                  onPressed: _sending ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _composer,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _messageImage(dynamic rawAttachment) {
    final attachment = rawAttachment is Map
        ? Map<String, dynamic>.from(rawAttachment)
        : <String, dynamic>{};
    final data = _safeString(attachment['data']);
    if (data.isEmpty || !data.startsWith('data:image/')) {
      return const Text('Image unavailable');
    }
    try {
      final encoded = data.contains(',') ? data.split(',').last : data;
      final bytes = base64Decode(encoded);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 220, height: 220, fit: BoxFit.cover),
      );
    } on FormatException {
      return const Text('Image unavailable');
    }
  }
}
