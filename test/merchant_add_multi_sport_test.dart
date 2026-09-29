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
    expect(find.text('CHOOSE SPORT CATEGORIES'), findsOneWidget);
    expect(find.text('No sports selected yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Basketball'));
    await tester.pumpAndSettle();
    expect(find.text('Chosen categories: Basketball'), findsOneWidget);
    expect(find.text('Price per hour'), findsOneWidget);
    expect(find.text('Whole court (1 slot)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Badminton'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chosen categories: Basketball, Badminton'),
      findsOneWidget,
    );
    expect(find.text('Price per hour'), findsNWidgets(2));
    expect(find.text('Included players'), findsNWidgets(2));
    expect(find.text('Fee per extra player'), findsNWidgets(2));
    expect(find.text('Slots available for this sport'), findsOneWidget);
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
