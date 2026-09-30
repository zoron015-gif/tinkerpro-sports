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

  testWidgets('Fitness form supports category plans and optional coaches', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            initialBusinessType: 'Fitness & Wellness',
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
    await tester.enterText(find.byType(TextFormField).first, 'Example wellness studio');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3  ·  Booking details'), findsOneWidget);
    expect(find.text('FITNESS CATEGORIES & PRICES'), findsOneWidget);
    expect(find.text('Pilates'), findsOneWidget);
    await tester.tap(find.text('Pilates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yoga'));
    await tester.pumpAndSettle();
    expect(find.text('Session price (required)'), findsNWidgets(2));
    expect(find.text('Monthly price (required)'), findsNWidgets(2));
    expect(find.text('Yearly price (required)'), findsNWidgets(2));
    expect(find.text('Yearly offer (optional)'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Add coach'));
    await tester.tap(find.text('Add coach'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add coach'));
    await tester.tap(find.text('Add coach'));
    await tester.pumpAndSettle();
    expect(find.text('Coach name (required)'), findsNWidgets(2));
    expect(find.text('Coach monthly price (required)'), findsNWidgets(2));
    expect(find.text('Coach profile photo (optional)'), findsNWidgets(2));
  });
}
