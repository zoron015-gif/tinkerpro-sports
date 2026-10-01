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
    final bookings = <Map<String, dynamic>>[
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
    ];
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
            return http.Response(jsonEncode({'bookings': bookings}), 200);
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
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

    final dashboardAppBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(dashboardAppBar.toolbarHeight, 56);
    expect(dashboardAppBar.titleSpacing, 16);
    expect(dashboardAppBar.leadingWidth, 56);
    expect(dashboardAppBar.titleTextStyle?.fontSize, 20);
    expect(dashboardAppBar.titleTextStyle?.fontWeight, FontWeight.w800);

    expect(find.text('Business & facility information'), findsNothing);
    expect(find.text('Save merchant profile'), findsNothing);
    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.textContaining('1 booking awaiting approval'), findsOneWidget);
    expect(
      find.textContaining('2 approved bookings to complete'),
      findsNothing,
    );
    expect(find.text('1 pending'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('merchant-review-bookings')));
    await tester.pumpAndSettle();
    expect(find.text('Customer Two'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-dashboard')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data analytics'), findsOneWidget);
    expect(find.text('PHP 500.00'), findsOneWidget);
    expect(find.text('PHP 250.00'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(
      find.byKey(const ValueKey('merchant-analytics-date-filter')),
      findsOneWidget,
    );
    final periodFilter = tester.widget<SegmentedButton<String>>(
      find.byKey(const ValueKey('merchant-analytics-period')),
    );
    expect(periodFilter.showSelectedIcon, isFalse);
    expect(periodFilter.style?.textStyle?.resolve({})?.fontSize, 12);
    expect(
      periodFilter.style?.textStyle?.resolve({})?.fontWeight,
      FontWeight.w700,
    );
    expect(
      periodFilter.style?.minimumSize?.resolve({}),
      const Size.fromHeight(40),
    );
    expect(
      find.byKey(const ValueKey('merchant-analytics-view-Sales report')),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    final salesPlot = find.byKey(
      const ValueKey('merchant-chart-plot-Confirmed sales'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    final salesPlotRect = tester.getRect(salesPlot);
    await tester.tapAt(
      Offset(
        salesPlotRect.left + salesPlotRect.width * .95,
        salesPlotRect.center.dy,
      ),
    );
    await tester.pumpAndSettle();
    final selectedSalesPoint = find.byKey(
      const ValueKey('merchant-analytics-selected-point'),
    );
    expect(selectedSalesPoint, findsOneWidget);
    expect(
      find.descendant(
        of: selectedSalesPoint,
        matching: find.text('PHP 500.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedSalesPoint,
        matching: find.textContaining(date),
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 420));
    await tester.pumpAndSettle();

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

    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('merchant-analytics-view-Customer count')),
    );
    await tester.tap(
      find.byKey(const ValueKey('merchant-analytics-view-Customer count')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Customers by Annual'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant-analytics-customer-chart')),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Each line shows unique customers per venue for each annual'),
      findsOneWidget,
    );
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('3 unique customers across venues'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-analytics-legend-Sample Court')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-analytics-legend-Draft Venue')),
      findsOneWidget,
    );
    expect(find.text('Sample Court'), findsWidgets);
    expect(find.text('Draft Venue'), findsWidgets);
    final customerPlot = find.byKey(
      const ValueKey('merchant-chart-plot-Customers'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final customerPlotRect = tester.getRect(customerPlot);
    await tester.tapAt(
      Offset(customerPlotRect.right - 2, customerPlotRect.center.dy),
    );
    await tester.pumpAndSettle();
    final selectedCustomerPoint = find.byKey(
      const ValueKey('merchant-analytics-selected-point'),
    );
    expect(selectedCustomerPoint, findsOneWidget);
    expect(
      find.descendant(
        of: selectedCustomerPoint,
        matching: find.text('3 customers'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedCustomerPoint,
        matching: find.text('0 customers'),
      ),
      findsWidgets,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, 260));
    await tester.pumpAndSettle();

    for (final period in ['Daily', 'Weekly', 'Monthly', 'Annual']) {
      await tester.ensureVisible(find.text(period));
      await tester.tap(find.text(period));
      await tester.pumpAndSettle();
      expect(find.text('Customers by $period'), findsOneWidget);
      expect(
        find.text(
          'Each line shows unique customers per venue for each ${period.toLowerCase()}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          period == 'Daily'
              ? '2 unique customers across venues'
              : '3 unique customers across venues',
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
    expect(find.text('Customers by Annual'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-analytics-chart-full')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-analytics-legend-Sample Court')),
      findsOneWidget,
    );
    expect(find.text('3 unique customers across venues'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('merchant-analytics-chart-close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Customers by Annual'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
    final venuePerformanceView = find.byKey(
      const ValueKey('merchant-analytics-view-Venue performance'),
    );
    await tester.ensureVisible(venuePerformanceView);
    await tester.tap(venuePerformanceView);
    await tester.pumpAndSettle();
    expect(find.text('Bookings by venue'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('merchant-venue-comparison-metric')),
      findsOneWidget,
    );
    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();
    expect(find.text('Sales by venue'), findsOneWidget);
    expect(find.text('PHP 800.00'), findsOneWidget);
    await tester.tap(find.text('Players').last);
    await tester.pumpAndSettle();
    expect(find.text('Players by venue'), findsOneWidget);
    expect(find.text('18'), findsWidgets);
    expect(find.text('Draft Venue'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('merchant-analytics-panel-venue-performance')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Sample Court').first);
    await tester.pumpAndSettle();
    expect(find.text('Sample Court'), findsWidgets);
    expect(find.textContaining('18 players'), findsOneWidget);
    expect(find.textContaining('4.8'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-payouts')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Booking requests'), findsWidgets);
    expect(find.text('Active bookings'), findsOneWidget);
    expect(find.text('Payout track'), findsOneWidget);
    final payoutTypeFilter = find.byKey(
      const ValueKey('merchant-payout-type-filter'),
    );
    final payoutTabsFinder = find.byKey(const ValueKey('merchant-payout-tabs'));
    final payoutTabs = tester.widget<SegmentedButton<int>>(payoutTabsFinder);
    expect(payoutTabs.segments.map((segment) => segment.value), [0, 1, 2]);
    expect(
      payoutTabs.style?.minimumSize?.resolve({}),
      const Size.fromHeight(40),
    );
    expect(
      payoutTabs.style?.textStyle?.resolve({})?.fontSize,
      periodFilter.style?.textStyle?.resolve({})?.fontSize,
    );
    expect(
      payoutTabs.style?.textStyle?.resolve({})?.fontWeight,
      periodFilter.style?.textStyle?.resolve({})?.fontWeight,
    );
    expect(tester.getSize(payoutTypeFilter).height, 40);
    expect(find.text('Customer Two'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    await tester.tap(find.text('Active bookings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer One'), findsOneWidget);
    expect(
      find.textContaining('finish automatically at their scheduled end.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Payout track'));
    await tester.pumpAndSettle();
    expect(find.text('No completed bookings'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-dashboard')),
    );
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Activity log'), findsOneWidget);
    await tester.tap(find.text('Activity log'));
    await tester.pumpAndSettle();
    expect(find.text('Activity log'), findsOneWidget);
    final activityAppBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(activityAppBar.toolbarHeight, dashboardAppBar.toolbarHeight);
    expect(activityAppBar.titleSpacing, dashboardAppBar.titleSpacing);
    expect(activityAppBar.leadingWidth, dashboardAppBar.leadingWidth);
    expect(
      activityAppBar.titleTextStyle?.fontSize,
      dashboardAppBar.titleTextStyle?.fontSize,
    );
    expect(
      activityAppBar.titleTextStyle?.fontWeight,
      dashboardAppBar.titleTextStyle?.fontWeight,
    );
  });

  testWidgets('reviewed booking notification disappears after approval', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    final bookings = <Map<String, dynamic>>[
      {
        'id': 11,
        'customerId': 51,
        'customerName': 'Customer Two',
        'venueName': 'Sample Court',
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'startTime': '07:00:00',
        'durationHours': 1,
        'players': 2,
        'total': 200,
        'downpayment': 100,
        'status': 'pending',
      },
    ];
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
            return http.Response(jsonEncode({'businesses': []}), 200);
          case '/api/merchant/bookings':
            return http.Response(jsonEncode({'bookings': bookings}), 200);
          case '/api/merchant/bookings/11/approve':
            bookings.single['status'] = 'approved';
            return http.Response(
              jsonEncode({'status': 'approved', 'ticketCode': 'test-ticket'}),
              200,
            );
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          default:
            return http.Response('{}', 200);
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(home: MerchantDashboardPage(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-action-center')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('merchant-review-bookings')));
    await tester.pumpAndSettle();
    expect(find.text('Customer Two'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-dashboard')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('merchant-action-center')), findsNothing);
  });

  testWidgets('merchant opens dashboard when profile request fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/merchant/profile') {
          return http.Response(
            jsonEncode({'error': 'Merchant profile service unavailable'}),
            503,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: MerchantDashboardPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Merchant Dashboard'), findsOneWidget);
    expect(find.text('Data analytics'), findsOneWidget);
    expect(find.text('Business & facility information'), findsNothing);
    expect(find.text('Save merchant profile'), findsNothing);
    expect(find.text('Select a booking type'), findsNothing);
    expect(find.text('Add'), findsOneWidget);
    expect(
      find.textContaining('Could not load merchant profile'),
      findsOneWidget,
    );
  });
}
