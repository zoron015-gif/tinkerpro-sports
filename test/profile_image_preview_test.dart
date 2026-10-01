import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/profile_image_preview.dart';

void main() {
  testWidgets('tapping a profile avatar opens a zoomable photo preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TappableProfileAvatar(
              radius: 32,
              backgroundColor: Colors.orange,
              image: MemoryImage(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
                ),
              ),
              fallback: const Icon(Icons.person),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('View profile photo'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close profile photo'), findsOneWidget);

    await tester.tap(find.byTooltip('Close profile photo'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('avatar without a photo remains a non-interactive fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: TappableProfileAvatar(
              radius: 32,
              backgroundColor: Colors.orange,
              image: null,
              fallback: Icon(Icons.person),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
