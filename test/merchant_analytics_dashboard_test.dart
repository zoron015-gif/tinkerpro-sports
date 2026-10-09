import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_dashboard.dart';
import 'package:myapp/messages_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _managementScrollable(WidgetTester tester) {
  final controller = tester
      .widget<ListView>(find.byKey(const ValueKey('merchant-management-list')))
      .controller;
  return find.byWidgetPredicate(
    (widget) => widget is Scrollable && widget.controller == controller,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('back from merchant Messages restores the dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
      'session_role': 'merchant',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
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
            return http.Response(jsonEncode({'bookings': []}), 200);
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          case '/api/messages/conversations':
            return http.Response(jsonEncode({'conversations': []}), 200);
          case '/api/messages/contacts':
            return http.Response(jsonEncode({'contacts': []}), 200);
          case '/api/auth/me':
            return http.Response(
              jsonEncode({
                'user': {'id': 42},
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

    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-messages')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MessagesDashboardPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(MessagesDashboardPage), findsNothing);
    expect(find.text('Merchant Dashboard'), findsOneWidget);
    expect(find.text('Data analytics'), findsOneWidget);
  });

  testWidgets('completed bookings can be permanently deleted', (tester) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    final bookings = <Map<String, dynamic>>[
      {
        'id': 42,
        'customerName': 'Completed Customer',
        'venueName': 'Sample Court',
        'businessType': 'Sports',
        'date': '2026-10-07',
        'startTime': '09:00:00',
        'durationHours': 1,
        'status': 'finished',
      },
    ];
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/merchant/bookings/42') {
          bookings.clear();
          return http.Response(
            jsonEncode({'message': 'Completed booking permanently deleted.'}),
            200,
          );
        }
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
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-payouts')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Completed Customer'), findsOneWidget);
    final deleteButton = find.byKey(
      const ValueKey('merchant-booking-delete-42'),
    );
    await tester.scrollUntilVisible(
      deleteButton,
      240,
      scrollable: _managementScrollable(tester),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('This action cannot be undone.'), findsNothing);
    expect(
      find.textContaining('permanently deletes the booking'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('No completed bookings'), findsOneWidget);
    expect(find.text('Completed booking permanently deleted.'), findsOneWidget);
  });

  testWidgets('customer management tracks arrival outcomes and new check-ins', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final bookings = <Map<String, dynamic>>[
      {
        'id': 30,
        'customerName': 'Arrived Customer',
        'venueName': 'Sample Court',
        'businessType': 'Sports',
        'date': date,
        'startTime': '09:30:00',
        'durationHours': 2,
        'status': 'approved',
        'checkedInAt': '2026-10-09T10:30:00',
      },
      {
        'id': 31,
        'customerName': 'Waiting Customer',
        'venueName': 'Sample Court',
        'businessType': 'Sports',
        'date': date,
        'startTime': '11:30:00',
        'durationHours': 2,
        'status': 'approved',
      },
      {
        'id': 32,
        'customerName': 'No-show Customer',
        'venueName': 'Sample Court',
        'businessType': 'Sports',
        'date': date,
        'startTime': '07:00:00',
        'durationHours': 1,
        'status': 'finished',
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
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          case '/api/auth/me':
            return http.Response(
              jsonEncode({
                'user': {'id': 42},
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
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-payouts')),
    );
    await tester.pumpAndSettle();
    final mainManagementTabsFinder = find.byKey(
      const ValueKey('merchant-management-tabs'),
    );
    final bookingSubtabsFinder = find.byKey(
      const ValueKey('merchant-booking-management-status-tabs'),
    );
    final bookingSubtabs = tester.widget<SegmentedButton<int>>(
      bookingSubtabsFinder,
    );
    expect(bookingSubtabs.expandedInsets, EdgeInsets.zero);
    expect(
      tester.getSize(bookingSubtabsFinder).width,
      tester.getSize(mainManagementTabsFinder).width,
    );
    expect(
      bookingSubtabs.style?.minimumSize?.resolve({}),
      const Size.fromHeight(40),
    );
    expect(bookingSubtabs.style?.textStyle?.resolve({})?.fontSize, 12);
    expect(
      bookingSubtabs.style?.textStyle?.resolve({})?.fontWeight,
      FontWeight.w800,
    );
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();

    final showVenueQr = tester.widget<FilledButton>(
      find.byKey(const ValueKey('merchant-show-arrival-qr')),
    );
    expect(showVenueQr.style!.foregroundColor!.resolve({}), Colors.white);
    final arrivalTabs = tester.widget<SegmentedButton<int>>(
      find.byKey(const ValueKey('merchant-customer-arrival-tabs')),
    );
    expect(arrivalTabs.expandedInsets, EdgeInsets.zero);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('merchant-customer-arrival-tabs')))
          .width,
      tester.getSize(mainManagementTabsFinder).width,
    );
    expect(
      arrivalTabs.style?.minimumSize?.resolve({}),
      bookingSubtabs.style?.minimumSize?.resolve({}),
    );
    expect(
      arrivalTabs.style?.textStyle?.resolve({})?.fontSize,
      bookingSubtabs.style?.textStyle?.resolve({})?.fontSize,
    );
    expect(
      arrivalTabs.style?.textStyle?.resolve({})?.fontWeight,
      bookingSubtabs.style?.textStyle?.resolve({})?.fontWeight,
    );
    final mainManagementTabs = tester.widget<SegmentedButton<int>>(
      mainManagementTabsFinder,
    );
    expect(
      mainManagementTabs.style?.textStyle?.resolve({})?.fontSize,
      bookingSubtabs.style?.textStyle?.resolve({})?.fontSize,
    );
    expect(
      mainManagementTabs.style?.textStyle?.resolve({})?.fontWeight,
      bookingSubtabs.style?.textStyle?.resolve({})?.fontWeight,
    );
    expect(arrivalTabs.segments.map((segment) => segment.value), [2, 0, 1]);
    expect(find.text('Arrived Customer'), findsOneWidget);
    expect(find.text('2026-10-09T10:30:00'), findsOneWidget);
    expect(find.text('Waiting Customer'), findsNothing);
    expect(find.text('No-show Customer'), findsNothing);

    await tester.tap(find.text('No-show'));
    await tester.pumpAndSettle();
    expect(find.text('No-show Customer'), findsOneWidget);
    expect(find.text('No-show · scheduled time ended'), findsOneWidget);

    await tester.tap(find.text('Awaiting arrival'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting Customer'), findsOneWidget);
    expect(find.text('No-show Customer'), findsNothing);

    bookings[1]['checkedInAt'] = '2026-10-09T11:45:00';
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.byKey(const ValueKey('merchant-customer-arrival-tabs')),
          )
          .selected,
      {0},
    );
    expect(find.text('Arrived Customer'), findsOneWidget);
    expect(find.text('Waiting Customer'), findsOneWidget);
    expect(find.text('2026-10-09T11:45:00'), findsOneWidget);
  });

  testWidgets('merchant dashboard summarizes booking and venue data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    FlutterSecureStorage.setMockInitialValues({
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
        'customerEmail': 'customer.one@example.com',
        'venueName': 'Sample Court',
        'address': '12 Court Road',
        'facilityType': 'Indoor',
        'details': 'Covered basketball court',
        'businessType': 'Sports',
        'date': date,
        'startTime': '09:30:00',
        'durationHours': 2,
        'players': 4,
        'sportType': 'Basketball',
        'slotNumber': 2,
        'paymentMethod': 'cash_on_arrival',
        'paymentStatus': 'unpaid',
        'paidAmount': 0,
        'pricePerHour': 250,
        'total': 500,
        'downpayment': 250,
        'status': 'approved',
        'checkedInAt': '2026-10-09T10:30:00',
      },
      {
        'id': 11,
        'customerId': 51,
        'customerName': 'Customer Two',
        'venueName': 'Sample Court',
        'businessType': 'Event',
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
        'venueName': 'Other Court',
        'businessType': 'Sports',
        'date': previousMonthDate,
        'players': 8,
        'total': 300,
        'downpayment': 150,
        'paymentMethod': 'online',
        'paymentStatus': 'paid',
        'status': 'approved',
      },
    ];
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'PATCH' &&
            (request.url.path.endsWith('/payment') ||
                request.url.path.endsWith('/decline'))) {
          final bookingId = int.parse(request.url.path.split('/').elementAt(4));
          final booking = bookings.singleWhere(
            (item) => item['id'] == bookingId,
          );
          if (request.url.path.endsWith('/payment')) {
            final paymentStatus = (jsonDecode(
              request.body,
            ) as Map<String, dynamic>)['paymentStatus'];
            booking['paymentStatus'] = paymentStatus;
            booking['paidAmount'] = paymentStatus == 'partial'
                ? booking['downpayment']
                : booking['total'];
            return http.Response(
              jsonEncode({'message': 'Payment status updated.'}),
              200,
            );
          }
          booking['status'] = 'cancelled';
          return http.Response(
            jsonEncode({'message': 'Booking declined.'}),
            200,
          );
        }
        switch (request.url.path) {
          case '/api/merchant/businesses/1/check-in-code':
            return http.Response(
              jsonEncode({
                'qrCode': '{"type":"tinkerpro.checkin","venueId":1}',
                'expiresAt': DateTime.now()
                    .add(const Duration(minutes: 2))
                    .millisecondsSinceEpoch,
                'venueName': 'Sample Court',
              }),
              200,
            );
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
                    'businessType': 'Sports',
                    'hasPublishedNewsCard': true,
                    'averageRating': 4.8,
                    'reviewCount': 5,
                  },
                  {'id': 2, 'name': 'Draft Venue', 'businessType': 'Event'},
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
    final bookingsMetric = find.byKey(
      const ValueKey('merchant-analytics-metric-bookings'),
    );
    expect(
      find.descendant(
        of: bookingsMetric,
        matching: find.text('1 confirmed · 1 pending'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bookingsMetric,
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('merchant-review-bookings')));
    await tester.pumpAndSettle();
    expect(find.text('Customer Two'), findsOneWidget);
    final customerTwoView = find.byKey(
      const ValueKey('merchant-booking-view-11'),
    );
    final filteredManagementScroll = _managementScrollable(tester);
    tester
        .state<ScrollableState>(filteredManagementScroll)
        .position
        .jumpTo(400);
    await tester.pumpAndSettle();
    await tester.tap(customerTwoView);
    await tester.pumpAndSettle();
    expect(find.text('Booking details'), findsOneWidget);
    final filteredDetailsScroll = find
        .descendant(
          of: find.byKey(
            const ValueKey('merchant-payout-booking-details-list'),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    final filteredDetailsScrollState = tester.state<ScrollableState>(
      filteredDetailsScroll,
    );
    filteredDetailsScrollState.position.jumpTo(
      filteredDetailsScrollState.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('merchant-booking-approve-11')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-dashboard')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data analytics'), findsOneWidget);
    expect(find.text('\u{20B1} 500.00'), findsOneWidget);
    expect(find.text('\u{20B1} 0.00'), findsOneWidget);
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
    final analyticsTypeFilter = find.byKey(
      const ValueKey('merchant-analytics-booking-type-filter'),
    );
    await tester.ensureVisible(analyticsTypeFilter);
    await tester.tap(analyticsTypeFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Event').last);
    await tester.pumpAndSettle();
    expect(find.text('\u{20B1} 0.00'), findsWidgets);
    expect(
      find.text('\u{20B1} 0.00 confirmed sales · \u{20B1} 0.00 collected'),
      findsOneWidget,
    );
    await tester.tap(analyticsTypeFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All booking types').last);
    await tester.pumpAndSettle();
    expect(find.text('\u{20B1} 500.00'), findsOneWidget);

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
        matching: find.text('\u{20B1} 500.00'),
      ),
      findsNWidgets(2),
    );
    for (final detail in [
      'Collected payments',
      'Bookings',
      'Confirmed bookings',
      'Players',
      'Unique customers',
      'Avg. confirmed booking',
    ]) {
      expect(
        find.descendant(of: selectedSalesPoint, matching: find.text(detail)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: selectedSalesPoint,
        matching: find.text('\u{20B1} 0.00'),
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
    periodFilter.onSelectionChanged!({'Monthly'});
    await tester.pumpAndSettle();
    expect(find.text('Sales report · Monthly'), findsOneWidget);

    periodFilter.onSelectionChanged!({'Annual'});
    await tester.pumpAndSettle();
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
        matching: find.text('2 customers'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectedCustomerPoint,
        matching: find.text('1 customers'),
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
    final venueMetricFilter = find.byKey(
      const ValueKey('merchant-venue-comparison-metric'),
    );
    expect(
      tester.widget<SegmentedButton<String>>(venueMetricFilter).expandedInsets,
      EdgeInsets.zero,
    );
    tester
        .widget<SegmentedButton<String>>(venueMetricFilter)
        .onSelectionChanged!({'Sales'});
    await tester.pumpAndSettle();
    expect(find.text('Sales by venue'), findsOneWidget);
    expect(find.text('\u{20B1} 500.00'), findsOneWidget);
    expect(find.text('\u{20B1} 300.00'), findsWidgets);
    expect(
      find.byKey(const ValueKey('merchant-venue-contribution-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-venue-contribution-total')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-venue-share-Sample Court')),
      findsOneWidget,
    );
    expect(find.text('62.5%'), findsOneWidget);
    expect(find.text('37.5%'), findsOneWidget);
    tester
        .widget<SegmentedButton<String>>(venueMetricFilter)
        .onSelectionChanged!({'Players'});
    await tester.pumpAndSettle();
    expect(find.text('Players by venue'), findsOneWidget);
    expect(find.text('55.6%'), findsOneWidget);
    expect(find.text('44.4%'), findsOneWidget);
    expect(find.text('18 players'), findsOneWidget);
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
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Booking'), findsOneWidget);
    final payoutTypeFilter = find.byKey(
      const ValueKey('merchant-payout-type-filter'),
    );
    final payoutTabsFinder = find.byKey(
      const ValueKey('merchant-management-tabs'),
    );
    final payoutTabs = tester.widget<SegmentedButton<int>>(payoutTabsFinder);
    expect(payoutTabs.segments.map((segment) => segment.value), [0, 1, 2]);
    expect(payoutTabs.selected, {0});
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
      FontWeight.w800,
    );
    expect(tester.getSize(payoutTypeFilter).height, 40);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Management'), findsOneWidget);
    for (final summaryKey in [
      'merchant-management-summary-requests',
      'merchant-management-summary-active',
      'merchant-management-summary-completed',
      'merchant-management-summary-cash-due',
    ]) {
      expect(find.byKey(ValueKey(summaryKey)), findsNothing);
    }
    final searchField = find.byKey(const ValueKey('merchant-payout-search'));
    expect(
      tester.getTopLeft(payoutTypeFilter).dy,
      tester.getTopLeft(searchField).dy,
    );
    expect(
      find.byKey(const ValueKey('merchant-management-result-count')),
      findsNothing,
    );
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Arrived'), findsWidgets);
    expect(find.text('2026-10-09T10:30:00'), findsOneWidget);
    final showVenueQr = find.byKey(const ValueKey('merchant-show-arrival-qr'));
    await tester.ensureVisible(showVenueQr);
    await tester.tap(showVenueQr);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('merchant-checkin-venue-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-check-in-qr-code')),
      findsOneWidget,
    );
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(_managementScrollable(tester))
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Booking type'), findsWidgets);
    expect(find.text('Booking date and time'), findsWidgets);
    expect(find.textContaining('9:30 AM - 11:30 AM'), findsOneWidget);
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);
    tester
        .widget<SegmentedButton<int>>(
          find.byKey(const ValueKey('merchant-management-tabs')),
        )
        .onSelectionChanged!({0});
    await tester.pumpAndSettle();
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Customer Two'), findsOneWidget);
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('Customer Two'), findsNothing);
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('No completed bookings'), findsOneWidget);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Two'), findsOneWidget);
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('merchant-payout-search')),
      'Customer One',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-management-result-count')),
      findsOneWidget,
    );
    expect(find.text('Customer One'), findsWidgets);
    expect(find.text('Customer Two'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('merchant-management-clear-filters')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Awaiting arrival'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Three'), findsOneWidget);
    expect(find.text('Customer One'), findsNothing);
    expect(
      find.byKey(const ValueKey('merchant-management-result-count')),
      findsNothing,
    );
    await tester.tap(find.text('Booking'));
    await tester.pumpAndSettle();
    final pendingBookingView = find.byKey(
      const ValueKey('merchant-booking-view-11'),
    );
    final managementScroll = _managementScrollable(tester);
    tester.state<ScrollableState>(managementScroll).position.jumpTo(400);
    await tester.pumpAndSettle();
    await tester.tap(pendingBookingView);
    await tester.pumpAndSettle();
    final detailsScroll = find
        .descendant(
          of: find.byKey(
            const ValueKey('merchant-payout-booking-details-list'),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    final detailsScrollState = tester.state<ScrollableState>(detailsScroll);
    detailsScrollState.position.jumpTo(
      detailsScrollState.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-booking-approve-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant-booking-decline-11')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('merchant-booking-decline-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline booking'));
    await tester.pumpAndSettle();
    expect(find.text('Booking declined.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(managementScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    final bookingView = find.byKey(const ValueKey('merchant-booking-view-10'));
    final refreshedManagementScroll = _managementScrollable(tester);
    await tester.scrollUntilVisible(
      bookingView,
      240,
      scrollable: refreshedManagementScroll,
    );
    await Scrollable.ensureVisible(tester.element(bookingView), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(bookingView);
    await tester.pumpAndSettle();
    expect(find.text('Booking details'), findsOneWidget);
    expect(find.text('customer.one@example.com'), findsOneWidget);
    expect(find.text('12 Court Road'), findsOneWidget);
    expect(find.text('9:30 AM'), findsOneWidget);
    expect(find.text('Basketball · Slot 2'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Covered basketball court'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Covered basketball court'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cash downpayment due at venue'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cash downpayment due at venue'), findsOneWidget);
    expect(
      find.text('Remaining cash balance after downpayment'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Cash on arrival'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Cash on arrival'), findsOneWidget);
    Navigator.of(tester.element(find.text('Cash on arrival'))).pop();
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(managementScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-payment-management-tabs')),
      findsOneWidget,
    );
    expect(find.text('Payments'), findsOneWidget);
    await tester.tap(find.text('Earnings'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-payment-gross-collected')),
      findsOneWidget,
    );
    expect(find.text('Collected'), findsOneWidget);
    await tester.tap(find.text('Refunds'));
    await tester.pumpAndSettle();
    expect(find.text('No refunds to review'), findsOneWidget);
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Price'), findsWidgets);
    final paymentView = find.byKey(const ValueKey('merchant-payment-view-10'));
    tester.widget<OutlinedButton>(paymentView).onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('Payment details'), findsWidgets);
    expect(find.text('Payment method'), findsWidgets);
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('merchant-payout-booking-details-list')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    final markPaid = find.byKey(const ValueKey('merchant-payment-toggle-10'));
    await tester.scrollUntilVisible(
      markPaid,
      240,
      scrollable: managementScroll,
    );
    await tester.drag(managementScroll, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(find.text('Mark cash downpayment received'), findsOneWidget);
    await tester.tap(markPaid);
    await tester.pumpAndSettle();
    expect(find.text('Cash downpayment recorded.'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text('Cash downpayment received'), findsOneWidget);
    final markBalancePaid = find.byKey(
      const ValueKey('merchant-payment-toggle-10'),
    );
    expect(markBalancePaid, findsOneWidget);
    expect(find.text('Mark remaining balance paid'), findsOneWidget);
    tester.state<ScrollableState>(managementScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      markBalancePaid,
      240,
      scrollable: managementScroll,
    );
    await tester.drag(managementScroll, const Offset(0, 100));
    await tester.pumpAndSettle();
    await tester.tap(markBalancePaid);
    await tester.pumpAndSettle();
    expect(find.text('Remaining balance marked as paid.'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-dashboard')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text("Today's performance"), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);
    expect(find.text('1 booking scheduled today'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('merchant-profile-metric-Players today')),
          )
          .data,
      '4',
    );
    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Activity log'), findsOneWidget);
    expect(find.text('Get alerts when a match starts and ends.'), findsNothing);
    expect(
      find.text('Dark mode, colors, text size, and language'),
      findsNothing,
    );
    expect(find.text('Review activity on your account'), findsNothing);
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

  testWidgets('merchant fitness details show plan and first visit durations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
      'session_role': 'merchant',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
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
                  'businessType': 'Fitness & Wellness',
                },
              }),
              200,
            );
          case '/api/merchant/businesses':
            return http.Response(jsonEncode({'businesses': []}), 200);
          case '/api/merchant/bookings':
            return http.Response(
              jsonEncode({
                'bookings': [
                  {
                    'id': 25,
                    'customerId': 50,
                    'customerName': 'Fitness Customer',
                    'customerEmail': 'fitness@example.com',
                    'venueName': 'Example Gym',
                    'businessType': 'Fitness & Wellness',
                    'date': '2026-10-07',
                    'startTime': '00:00:00',
                    'durationHours': 1,
                    'players': 1,
                    'fitnessPlanType': 'monthly',
                    'fitnessCategory': 'Strength training',
                    'fitnessPlanPrice': 800,
                    'total': 800,
                    'downpayment': 400,
                    'paymentMethod': 'cash_on_arrival',
                    'paymentStatus': 'unpaid',
                    'status': 'approved',
                  },
                ],
              }),
              200,
            );
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          case '/api/auth/me':
            return http.Response(
              jsonEncode({
                'user': {'id': 42},
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
    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-payouts')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Awaiting arrival'));
    await tester.pumpAndSettle();
    expect(find.text('1 month'), findsOneWidget);

    final bookingView = find.byKey(const ValueKey('merchant-booking-view-25'));
    await tester.scrollUntilVisible(
      bookingView,
      240,
      scrollable: _managementScrollable(tester),
    );
    tester
        .state<ScrollableState>(_managementScrollable(tester))
        .position
        .jumpTo(320);
    await tester.pumpAndSettle();
    await tester.tap(bookingView);
    await tester.pumpAndSettle();

    expect(find.text('First visit session'), findsOneWidget);
    expect(find.text('Plan duration'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Payment details'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('merchant-payout-booking-details-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Cash downpayment due at venue'), findsOneWidget);
    expect(
      find.text('Remaining cash balance after downpayment'),
      findsOneWidget,
    );
  });

  testWidgets('reviewed booking notification disappears after approval', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'merchant-token',
    });
    FlutterSecureStorage.setMockInitialValues({
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
    final pendingBookingView = find.byKey(
      const ValueKey('merchant-booking-view-11'),
    );
    final managementScroll = _managementScrollable(tester);
    tester.state<ScrollableState>(managementScroll).position.jumpTo(400);
    await tester.pumpAndSettle();
    await tester.tap(pendingBookingView);
    await tester.pumpAndSettle();
    final detailsScroll = find
        .descendant(
          of: find.byKey(
            const ValueKey('merchant-payout-booking-details-list'),
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    final detailsScrollState = tester.state<ScrollableState>(detailsScroll);
    detailsScrollState.position.jumpTo(
      detailsScrollState.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('merchant-booking-approve-11')));
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
    FlutterSecureStorage.setMockInitialValues({
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
