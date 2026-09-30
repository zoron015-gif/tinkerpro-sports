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

  testWidgets('sports form fits a phone width and uses readable input text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final pageKey = GlobalKey<MerchantAddPageState>();
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
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
    await tester.enterText(
      find.byType(TextFormField).first,
      'Phone width sports venue',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Volleyball'));
    await tester.tap(find.text('Volleyball'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Whole court'));
    await tester.pumpAndSettle();

    final formTheme = tester.widget<Theme>(
      find
          .ancestor(
            of: find.text('Price per hour (required)'),
            matching: find.byType(Theme),
          )
          .first,
    );
    expect(formTheme.data.textTheme.bodyLarge?.color, const Color(0xFF101B33));
    expect(find.text('Whole court'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
