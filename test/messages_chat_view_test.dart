import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_theme.dart';
import 'package:myapp/messages_chat_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('incoming message text remains readable in dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.orange,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );
    final composer = TextEditingController();
    addTearDown(composer.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: true,
          accentColor: AppPalette.orange.color,
        ),
        home: Scaffold(
          body: MessagesChatView(
            messages: [
              {'id': 2, 'senderId': 8, 'body': 'Incoming message'},
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

    final bubble = tester.widget<Card>(
      find.byKey(const ValueKey('message-bubble-2')),
    );
    final message = tester.widget<Text>(
      find.byKey(const ValueKey('message-body-2')),
    );
    expect(bubble.color, AppColors.surfaceVariant);
    expect(message.style?.color, AppColors.darkInk);
  });
}
