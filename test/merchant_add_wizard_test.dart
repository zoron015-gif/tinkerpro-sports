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

  testWidgets('business setup advances through basics, details, and review', (
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

    expect(find.text('STEP 1 OF 3  ·  Business basics'), findsOneWidget);
    expect(find.text('SPORTS, SLOTS & RATES'), findsNothing);
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('business-setup-next-0')),
    );
    expect(continueButton.style!.foregroundColor!.resolve({}), Colors.white);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter the name customers will see for this venue.'),
      findsOneWidget,
    );
    expect(find.text('STEP 1 OF 3  ·  Business basics'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Sample court');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3  ·  Booking details'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(CheckboxListTile, 'Basketball'),
    );
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Basketball'));
    await tester.pumpAndSettle();

    final priceField = find.ancestor(
      of: find.text('Price per hour (required)'),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(find.text('Price per hour (required)'));
    await tester.enterText(priceField.first, '250');
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 3 OF 3  ·  Schedule & review'), findsOneWidget);
    final scheduleHeadingTop = tester
        .getTopLeft(find.text('SCHEDULE AND PRICING'))
        .dy;
    expect(scheduleHeadingTop, greaterThan(0));
    expect(scheduleHeadingTop, lessThan(800));
    expect(find.text('Venue address (required)'), findsOneWidget);
    await tester.ensureVisible(find.text('Finish required details'));
    expect(find.text('Sample court'), findsWidgets);
    expect(find.text('Finish required details'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('business-setup-publish')));
    await tester.pumpAndSettle();
    expect(find.text('Choose an opening time.'), findsOneWidget);
    expect(find.text('Choose a closing time.'), findsOneWidget);
    expect(
      find.text('Please add the venue’s street address and city.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3  ·  Booking details'), findsOneWidget);
    expect(find.text('Basketball'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing event types are shown inline and brought into view', (
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
            initialBusinessType: 'Event',
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

    await tester.enterText(find.byType(TextFormField).first, 'Community venue');
    await tester.enterText(find.byType(TextFormField).last, 'Community Hall');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose at least one event type to continue.'),
      findsOneWidget,
    );
    expect(find.text('Conference'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
