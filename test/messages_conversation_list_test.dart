import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/messages_conversation_list.dart';

void main() {
  testWidgets('archived view only shows archived conversations', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesConversationList(
            conversations: [
              {..._directConversation(id: 1, unreadCount: 0), 'archived': 0},
              {..._directConversation(id: 2, unreadCount: 0), 'archived': 1},
            ],
            selectedConversationId: null,
            searchController: searchController,
            conversationQuery: '',
            onSearchChanged: (_) {},
            onClearSearch: () {},
            onNewConversation: () {},
            onSelectConversation: (_) {},
            onOpenContact: (_) async {},
            onConversationAction: (_, _) async {},
            showArchived: true,
            showBlocked: false,
            onToggleArchived: () {},
            onToggleBlocked: () {},
            currentUserId: 7,
          ),
        ),
      ),
    );

    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Alex Doe'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('blocked chats are hidden from inbox and available to unblock', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    Widget buildList({required bool showBlocked}) => MaterialApp(
      home: Scaffold(
        body: MessagesConversationList(
          conversations: [
            _directConversation(id: 1, unreadCount: 0),
            {
              ..._directConversation(id: 2, unreadCount: 0),
              'blockedByMe': true,
              'members': [_user(7), _user(13)],
            },
          ],
          selectedConversationId: null,
          searchController: searchController,
          conversationQuery: '',
          onSearchChanged: (_) {},
          onClearSearch: () {},
          onNewConversation: () {},
          onSelectConversation: (_) {},
          onOpenContact: (_) async {},
          onConversationAction: (_, _) async {},
          showArchived: false,
          showBlocked: showBlocked,
          onToggleArchived: () {},
          onToggleBlocked: () {},
          currentUserId: 7,
        ),
      ),
    );

    await tester.pumpWidget(buildList(showBlocked: false));
    expect(find.text('User 13 Doe'), findsNothing);

    await tester.pumpWidget(buildList(showBlocked: true));
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('User 13 Doe'), findsOneWidget);

    await tester.longPress(find.text('User 13 Doe'));
    await tester.pumpAndSettle();
    expect(find.text('Unblock person'), findsOneWidget);
  });

  testWidgets('long press exposes private conversation actions', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesConversationList(
            conversations: [_directConversation(id: 1, unreadCount: 0)],
            selectedConversationId: null,
            searchController: searchController,
            conversationQuery: '',
            onSearchChanged: (_) {},
            onClearSearch: () {},
            onNewConversation: () {},
            onSelectConversation: (_) {},
            onOpenContact: (_) async {},
            onConversationAction: (_, _) async {},
            showArchived: false,
            showBlocked: false,
            onToggleArchived: () {},
            onToggleBlocked: () {},
            currentUserId: 7,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Alex Doe'));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Mark as unread'), findsOneWidget);
    expect(find.text('Block person'), findsOneWidget);
    expect(find.text('Delete for me'), findsOneWidget);
  });

  testWidgets(
    'shows existing conversation participants once and merges duplicate direct chats',
    (tester) async {
      final searchController = TextEditingController();
      addTearDown(searchController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesConversationList(
              conversations: [
                _directConversation(id: 1, unreadCount: 1),
                _directConversation(id: 2, unreadCount: 2),
                {
                  'id': 3,
                  'type': 'group',
                  'title': 'Weekend group',
                  'unreadCount': 0,
                  'lastMessage': 'See you this weekend',
                  'lastMessageAt': '2026-09-25T10:00:00.000Z',
                  'members': [_user(7), _user(12)],
                },
              ],
              selectedConversationId: null,
              searchController: searchController,
              conversationQuery: '',
              onSearchChanged: (_) {},
              onClearSearch: () {},
              onNewConversation: () {},
              onSelectConversation: (_) {},
              onOpenContact: (_) async {},
              onConversationAction: (_, _) async {},
              showArchived: false,
              showBlocked: false,
              onToggleArchived: () {},
              onToggleBlocked: () {},
              currentUserId: 7,
            ),
          ),
        ),
      );

      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Alex Doe'), findsOneWidget);
      expect(find.text('Weekend group'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    },
  );

  testWidgets('does not show empty conversations as chats or quick contacts', (
    tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesConversationList(
            conversations: [
              {
                ..._directConversation(id: 1, unreadCount: 0),
                'members': [_user(7), _user(12)],
              },
              {
                'id': 2,
                'type': 'direct',
                'members': [_user(7), _user(13)],
              },
            ],
            selectedConversationId: null,
            searchController: searchController,
            conversationQuery: '',
            onSearchChanged: (_) {},
            onClearSearch: () {},
            onNewConversation: () {},
            onSelectConversation: (_) {},
            onOpenContact: (_) async {},
            onConversationAction: (_, _) async {},
            showArchived: false,
            showBlocked: false,
            onToggleArchived: () {},
            onToggleBlocked: () {},
            currentUserId: 7,
          ),
        ),
      ),
    );

    expect(find.text('Alex Doe'), findsOneWidget);
    expect(find.text('User 13 Doe'), findsNothing);
    expect(find.text('Start a conversation'), findsNothing);
  });
}

Map<String, dynamic> _directConversation({
  required int id,
  required int unreadCount,
}) => {
  'id': id,
  'type': 'direct',
  'unreadCount': unreadCount,
  'lastMessage': 'Hello',
  'lastMessageAt': '2026-09-25T10:00:00.000Z',
  'members': [_user(7), _user(12)],
};

Map<String, dynamic> _user(int id) => {
  'id': id,
  'firstName': id == 12 ? 'Alex' : 'User $id',
  'lastName': 'Doe',
};
