import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_theme.dart';
import 'package:myapp/event_booking_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Event checkout surfaces and actions follow dark palette', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.violet,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: true,
          accentColor: AppPalette.violet.color,
        ),
        home: EventBookingPage(
          business: {
            'id': 7,
            'name': 'Garden Venue',
            'eventTypes': ['Wedding'],
            'eventFee': 10000,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      AppColors.darkPage,
    );
    final summary = tester.widget<Container>(
      find.byKey(const ValueKey('event-booking-summary-card')),
    );
    expect((summary.decoration! as BoxDecoration).color, AppColors.darkSurface);
    expect(
      tester.widget<Text>(find.text('EVENT')).style!.color,
      AppColors.accentForeground,
    );
    expect(
      tester.widget<Text>(find.text('Garden Venue')).style!.color,
      AppColors.darkInk,
    );
  });

  testWidgets('Event booking submits event type, schedule, and guest count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    Map<String, dynamic>? submittedBooking;
    String? submittedIdempotencyKey;
    Map<String, dynamic>? checkoutPayload;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/payments/paymongo/config') {
          return http.Response(
            jsonEncode({'onlinePaymentsEnabled': true}),
            200,
          );
        }
        if (request.url.path == '/api/payments/paymongo/checkout') {
          checkoutPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'checkoutUrl': 'https://checkout.example.test'}),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path == '/api/bookings') {
          submittedBooking = jsonDecode(request.body) as Map<String, dynamic>;
          submittedIdempotencyKey = request.headers['idempotency-key'];
          return http.Response(
            jsonEncode({
              'booking': {
                'id': 501,
                'businessType': 'Event',
                'eventType': 'Wedding',
              },
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventBookingPage(
                      api: api,
                      business: {
                        'id': 7,
                        'name': 'Garden Venue',
                        'category': 'Events',
                        'ownerName': 'Mara Santos',
                        'address': 'Cebu City',
                        'facilityType': 'Indoor garden hall',
                        'hours': '7:00 AM - 10:00 PM',
                        'availability': 'Monday, Wednesday, Friday',
                        'tags': ['Parking', 'Pet-friendly', 'Restroom'],
                        'eventTypes': ['Wedding', 'Birthday'],
                        'attendanceMin': 50,
                        'attendanceMax': 250,
                        'accessibilityNeeds': ['Wheelchair access'],
                        'parkingNeeds': ['Valet parking'],
                        'securityNeeds': ['Event security'],
                        'details': 'Includes private garden access.',
                        'eventFee': 10000,
                      },
                    ),
                  ),
                ),
                child: const Text('Open booking'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open booking'));
    await tester.pumpAndSettle();

    expect(find.text('Garden Venue'), findsOneWidget);
    expect(find.text('Wedding'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    final eventTypeDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField &&
          widget.decoration.labelText == 'Event type',
    );
    await tester.ensureVisible(eventTypeDropdown);
    await tester.tap(eventTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birthday').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
    await tester.tap(eventTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wedding').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('Owner: Mara Santos'), findsOneWidget);
    expect(find.text('Venue type: Indoor garden hall'), findsOneWidget);
    expect(find.textContaining('Guest capacity: 50–250'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Accessibility: Wheelchair access'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Accessibility: Wheelchair access'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('Includes private garden access.'), findsOneWidget);
    expect(
      find.text('Cash on Arrival is fixed at 50% of the event fee.'),
      findsNothing,
    );
    final cashOption = find.text('COA');
    await tester.ensureVisible(cashOption);
    await tester.pumpAndSettle();
    await tester.tap(cashOption);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Pay \u{20B1} 5000.00 cash as a downpayment at the venue and \u{20B1} 5000.00 cash as the remaining balance.',
      ),
      findsOneWidget,
    );
    expect(find.text('Event total'), findsOneWidget);
    expect(find.text('Cash downpayment due at venue'), findsOneWidget);
    final submitButton = find.byKey(const ValueKey('event-booking-submit'));
    await tester.scrollUntilVisible(
      submitButton,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    expect(find.text('Confirm event booking'), findsOneWidget);
    expect(find.textContaining('starts within 24 hours'), findsOneWidget);
    expect(
      find.textContaining('payment will not be voided or refunded'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(submittedBooking, isNotNull);
    expect(submittedBooking!['venueId'], 7);
    expect(submittedBooking!['eventType'], 'Wedding');
    expect(submittedBooking!['players'], 50);
    expect(submittedBooking!['paymentMethod'], 'cash_on_arrival');
    expect(submittedBooking!['durationHours'], 4);
    expect(submittedBooking!['startTime'], matches(r'^\d{2}:\d{2}:00$'));
    expect(checkoutPayload, isNull);
    expect(submittedIdempotencyKey, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(find.text('Open booking'), findsOneWidget);
  });

  testWidgets(
    'offline COA booking works when online payments are unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      var bookingRequests = 0;
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/payments/paymongo/config') {
            return http.Response(
              jsonEncode({'onlinePaymentsEnabled': false}),
              200,
            );
          }
          if (request.url.path == '/api/bookings') {
            bookingRequests++;
            return http.Response(
              jsonEncode({
                'booking': {'id': 501},
              }),
              201,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EventBookingPage(
            api: api,
            asCheckoutSheet: true,
            business: {
              'id': 7,
              'name': 'Garden Venue',
              'eventTypes': ['Wedding'],
              'attendanceMin': 50,
              'eventFee': 10000,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(const ValueKey('event-booking-submit'));
      expect(find.text('Book Event'), findsOneWidget);
      await tester.scrollUntilVisible(
        submitButton,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(submitButton);
      expect(find.text('Online'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(find.text('Choose online payment'), findsOneWidget);

      await tester.tap(find.text('PayMaya'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Online payments are unavailable right now'),
        findsOneWidget,
      );
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(bookingRequests, 0);
      expect(find.text('Use Cash on Arrival'), findsNothing);

      final coaOption = find.text('COA');
      await tester.scrollUntilVisible(
        coaOption,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(coaOption);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        submitButton,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      expect(find.text('Confirm event booking'), findsOneWidget);
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();
      expect(bookingRequests, 1);
    },
  );
}
