import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('merchant dashboard summarizes booking and venue data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final previousMonthDate = DateTime.now()
        .subtract(const Duration(days: 40))
        .toIso8601String()
        .substring(0, 10);
    final api = AuthApi(
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/merchant/profile':
            return http.Response(
              jsonEncode({
                'profile': {
                  'firstName': 'Merchant',
                  'lastName': 'Owner',
                  'email': 'merchant@example.com',
                  'businessType': 'Sports',
                },
              }),
              200,
            );
          case '/api/merchant/businesses':
            return http.Response(
              jsonEncode({
                'businesses': [
                  {
                    'id': 1,
                    'name': 'Sample Court',
                    'hasPublishedNewsCard': true,
                    'averageRating': 4.8,
                    'reviewCount': 5,
                  },
                  {'id': 2, 'name': 'Draft Venue'},
                ],
              }),
              200,
            );
          case '/api/merchant/bookings':
            return http.Response(
              jsonEncode({
                'bookings': [
                  {
                    'id': 10,
                    'customerId': 50,
                    'customerName': 'Customer One',
                    'venueName': 'Sample Court',
                    'date': date,
                    'players': 4,
                    'total': 500,
                    'downpayment': 250,
                    'status': 'approved',
                  },
                  {
                    'id': 11,
                    'customerId': 51,
                    'customerName': 'Customer Two',
                    'venueName': 'Sample Court',
                    'date': date,
                    'players': 6,
                    'total': 200,
                    'downpayment': 100,
                    'status': 'pending',
                  },
                  {
                    'id': 12,
                    'customerId': 52,
                    'customerName': 'Customer Three',
                    'venueName': 'Sample Court',
                    'date': previousMonthDate,
                    'players': 8,
                    'total': 300,
                    'downpayment': 150,
                    'status': 'approved',
                  },
                ],
              }),
              200,
            );
          default:
            return http.Response(
              jsonEncode({'error': 'Unexpected request'}),
              404,
            );
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(home: MerchantDashboardPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Data analytics'), findsOneWidget);
    expect(find.text('PHP 500.00'), findsOneWidget);
    expect(find.text('PHP 250.00'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(
      find.byKey(const ValueKey('merchant-analytics-date-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-analytics-view-Sales report')),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.ensureVisible(find.text('Monthly'));
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sales report · Monthly'));
    expect(find.text('Sales report · Monthly'), findsOneWidget);

    await tester.ensureVisible(find.text('Annual'));
    await tester.tap(find.text('Annual'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sales report · Annual'));
    expect(find.text('Sales report · Annual'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('merchant-analytics-view-Customer count')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Players by Annual'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-analytics-player-chart')),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Each point shows booked players for one annual'),
      findsOneWidget,
    );
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('18 players across 3 customers'), findsOneWidget);

    for (final period in ['Daily', 'Weekly', 'Monthly', 'Annual']) {
      await tester.ensureVisible(find.text(period));
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(find.text('Players by $period'), findsOneWidget);
      expect(
        find.text(
          'Each point shows booked players for one ${period.toLowerCase()}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          period == 'Daily'
              ? '10 players across 2 customers'
              : '18 players across 3 customers',
        ),
        findsOneWidget,
      );
    }

    final fullViewButton = find.byKey(
      const ValueKey('merchant-analytics-chart-full-view'),
    );
    await tester.ensureVisible(fullViewButton);
    await tester.tap(fullViewButton);
    await tester.pumpAndSettle();
    expect(find.text('Players by Annual'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-analytics-chart-full')),
      findsOneWidget,
    );
    expect(find.text('18 players across 3 customers'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('merchant-analytics-chart-close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Players by Annual'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    final venuePerformanceView = find.byKey(
      const ValueKey('merchant-analytics-view-Venue performance'),
    );
    await tester.ensureVisible(venuePerformanceView);
    await tester.tap(venuePerformanceView);
    await tester.pumpAndSettle();
    expect(find.text('Bookings by venue'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('merchant-analytics-panel-venue-performance')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Sample Court'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Court'), findsOneWidget);
    expect(find.textContaining('18 players'), findsOneWidget);
    expect(find.textContaining('4.8'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text("Today's performance"), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);
    expect(find.text('2 bookings scheduled today'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('merchant-profile-metric-Players today')),
          )
          .data,
      '10',
    );
  });
}
