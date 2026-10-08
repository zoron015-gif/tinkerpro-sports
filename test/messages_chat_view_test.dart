import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/messages_chat_view.dart';

void main() {
  testWidgets('shows the sent time under an image message', (tester) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {
                'id': 1,
                'senderId': 7,
                'createdAt': '2026-10-08T14:05:00',
                'attachment': {'type': 'image', 'data': 'invalid'},
              },
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    expect(find.text('2:05 PM'), findsOneWidget);
  });

  testWidgets('omits the sent time when a message timestamp is invalid', (
    tester,
  ) async {
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {'id': 1, 'senderId': 7, 'createdAt': 'not-a-date', 'body': 'Hi'},
            ],
            currentUserId: 7,
            blocked: false,
            composer: composer,
            pendingImageData: null,
            sending: false,
            onDeleteMessage: (_) {},
            onPickImage: () {},
            onRemovePendingImage: () {},
            onSend: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Hi'), findsOneWidget);
    expect(find.textContaining('AM'), findsNothing);
    expect(find.textContaining('PM'), findsNothing);
  });
}
