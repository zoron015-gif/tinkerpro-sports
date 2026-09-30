import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_add_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sports checklist builds per-sport booking configuration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/merchant/news-posts') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            key: pageKey,
            initialBusinessType: 'Sports',
            api: api,
            businesses: const [],
            onBusinessesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    pageKey.currentState!.openAddBusinessForm();
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 3  ·  Business basics'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Example sports venue');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3  ·  Booking details'), findsOneWidget);
    expect(find.text('SPORTS, SLOTS & RATES'), findsOneWidget);
    expect(
      find.text(
        'Choose at least one sport. Each selected sport needs its own rate and slot setup.',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Basketball'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Basketball'));
    await tester.pumpAndSettle();
    expect(find.text('Chosen categories: Basketball'), findsOneWidget);
    expect(find.text('Price per hour (required)'), findsOneWidget);

    await tester.ensureVisible(find.text('Badminton'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Badminton'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chosen categories: Basketball, Badminton'),
      findsOneWidget,
    );
    expect(find.text('Price per hour (required)'), findsNWidgets(2));
    expect(find.text('Included players (optional)'), findsNWidgets(2));
    expect(find.text('Fee / extra player (optional)'), findsNWidgets(2));
    expect(find.text('Number of small slots'), findsOneWidget);
    expect(find.text('OPTIONAL EXTRA-PLAYER FEE'), findsNothing);
    expect(
      find.text('Legacy fallback rate (sports use the rates above)'),
      findsNothing,
    );
    expect(
      tester
          .widgetList<EditableText>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(EditableText),
            ),
          )
          .map((field) => field.style.color)
          .toList(),
      everyElement(const Color(0xFF101B33)),
    );
  });
}
