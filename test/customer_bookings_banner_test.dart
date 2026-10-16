import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/customer_bookings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
  });

  testWidgets('Fitness booking page requests only Fitness bookings', (
    tester,
  ) async {
    final requests = <Uri>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/bookings') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(api: api, businessType: 'Fitness'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests
          .where((uri) => uri.path == '/api/bookings')
          .map((uri) => uri.queryParameters['businessType']),
      ['Fitness'],
    );
    expect(
      requests
          .where((uri) => uri.path == '/api/messages/conversations')
          .map((uri) => uri.queryParameters['businessType']),
      ['Fitness'],
    );
  });

  testWidgets('failed booking load shows friendly guidance and offers retry', (
    tester,
  ) async {
    var bookingRequests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          bookingRequests++;
          if (bookingRequests == 1) {
            return http.Response(
              jsonEncode({
                'error': 'The local API at http://192.168.1.21:3000 took too long to respond.',
              }),
              408,
            );
          }
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'We couldn’t load your bookings right now. Please check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('192.168.1.21'), findsNothing);
    expect(find.textContaining('timed out'), findsNothing);
    expect(
      find.byKey(const ValueKey('customer-bookings-retry')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('customer-bookings-retry')));
    await tester.pumpAndSettle();

    expect(bookingRequests, 2);
    expect(find.text('No pending bookings.'), findsOneWidget);
  });

  testWidgets(
    'opening bookings clears non-expired status notification badges',
    (tester) async {
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/bookings') {
            return http.Response(
              jsonEncode({
                'bookings': [
                  {..._approvedBooking, 'id': 31},
                  {..._approvedBooking, 'id': 32, 'status': 'completed'},
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/messages/conversations') {
            return http.Response(jsonEncode({'conversations': []}), 200);
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected request'}),
            404,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerBookingsPage(api: api)),
      );
      await tester.pumpAndSettle();

      final bookingsDestination = tester.widget<NavigationDestination>(
        find.byKey(const ValueKey('news-feed-nav-bookings')),
      );
      expect((bookingsDestination.icon as Badge).isLabelVisible, isFalse);

      final badges = tester.widgetList<Badge>(find.byType(Badge));
      expect(badges, isNotEmpty);
      expect(badges.every((badge) => !badge.isLabelVisible), isTrue);
    },
  );

  testWidgets('expired booking banner identifies the expired booking', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'id': 45,
                  'status': 'expired',
                  'transactionId': 'TP-TXN-00000045',
                  'paymentMethod': 'online',
                  'paymentStatus': 'paid',
                  'paidAmount': 250,
                },
                {
                  ..._approvedBooking,
                  'id': 46,
                  'status': 'approved',
                  'transactionId': 'TP-TXN-00000046',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    expect(
      find.text('Your booking request at Test Court has expired.'),
      findsOneWidget,
    );
    expect(find.text('TP-TXN-00000045'), findsOneWidget);
    expect(find.text('BK-45'), findsOneWidget);
    expect(find.text('BK-46'), findsNothing);
    expect(
      (tester
                  .widget<NavigationDestination>(
                    find.byKey(const ValueKey('news-feed-nav-bookings')),
                  )
                  .icon
              as Badge)
          .isLabelVisible,
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('booking-status-banner-dismiss')),
    );
    await tester.pumpAndSettle();
    expect(
      (tester
                  .widget<NavigationDestination>(
                    find.byKey(const ValueKey('news-feed-nav-bookings')),
                  )
                  .icon
              as Badge)
          .isLabelVisible,
      isFalse,
    );
  });

  testWidgets('customer booking details show the recorded venue arrival', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {..._approvedBooking, 'checkedInAt': '2026-10-01T09:45:00'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved (1)'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    final detailsButton = find.byKey(
      const ValueKey('customer-booking-details-12'),
    );
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Checked in · 2026-10-01T09:45:00'),
      findsOneWidget,
    );
  });

  testWidgets('approved online bookings notify and accept prototype payment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final booking = <String, dynamic>{
      ..._approvedBooking,
      'paymentMethod': 'online',
      'paymentStatus': 'unpaid',
      'paidAmount': 0,
      'paymentDueAt': '2026-10-15T10:00:00',
      'total': 500,
      'downpayment': 500,
    };
    Map<String, dynamic>? paymentPayload;
    var prototypePaymentRequested = false;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'bookings': [booking],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        if (request.url.path == '/api/bookings/12/prototype-payment' &&
            request.method == 'POST') {
          prototypePaymentRequested = true;
          paymentPayload = jsonDecode(request.body) as Map<String, dynamic>;
          booking['paymentStatus'] = 'paid';
          booking['paidAmount'] = 500;
          return http.Response(
            jsonEncode({
              'received': true,
              'prototype': true,
              'bookingId': 12,
              'amount': 500,
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Approved · payment due'), findsOneWidget);
    expect(
      find.textContaining('The venue approved this booking.'),
      findsOneWidget,
    );

    final details = find.byKey(const ValueKey('customer-booking-details-12'));
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('customer-booking-delete-12')),
      findsNothing,
    );
    final payButton = find.byKey(const ValueKey('customer-booking-pay-12'));
    await tester.ensureVisible(payButton);
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(
      const ValueKey('prototype-payment-provider'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credit/debit card').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('prototype-payment-cardholder')),
      'Test Customer',
    );
    await tester.enterText(
      find.byKey(const ValueKey('prototype-payment-card-number')),
      '4242 4242 4242 4242',
    );
    await tester.enterText(
      find.byKey(const ValueKey('prototype-payment-expiry')),
      '12/30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('prototype-payment-security-code')),
      '123',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('prototype-payment-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('prototype-payment-confirm')));
    await tester.pumpAndSettle();

    expect(prototypePaymentRequested, isTrue);
    expect(paymentPayload, {
      'paymentMethod': 'prototype_card',
      'provider': 'card',
    });
    expect(
      find.textContaining('No real payment was processed'),
      findsOneWidget,
    );
    expect(find.text('Approved (1)'), findsOneWidget);
  });

  testWidgets(
    'approved COA booking shows payment alert and downpayment action',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final booking = <String, dynamic>{
        ..._approvedBooking,
        'id': 58,
        'paymentMethod': 'cash_on_arrival',
        'paymentStatus': 'unpaid',
        'paidAmount': 0,
        'total': 500,
        'downpayment': 250,
        'paymentDueAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      };
      Map<String, dynamic>? paymentPayload;
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/bookings') {
            return http.Response(
              jsonEncode({
                'bookings': [booking],
              }),
              200,
            );
          }
          if (request.url.path == '/api/messages/conversations') {
            return http.Response(jsonEncode({'conversations': []}), 200);
          }
          if (request.url.path == '/api/bookings/58/prototype-payment' &&
              request.method == 'POST') {
            paymentPayload = jsonDecode(request.body) as Map<String, dynamic>;
            booking['paymentStatus'] = 'partial';
            booking['paidAmount'] = 250;
            return http.Response(
              jsonEncode({
                'received': true,
                'prototype': true,
                'bookingId': 58,
                'amount': 250,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected request'}),
            404,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerBookingsPage(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approved (1)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Pay the required amount of ₱ 250.00 within 15 minutes',
        ),
        findsOneWidget,
      );
      expect(find.text('Approved · payment due'), findsOneWidget);
      expect(find.text('Payment due: ₱ 250.00'), findsOneWidget);
      final details = find.byKey(const ValueKey('customer-booking-details-58'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      final pay = find.byKey(const ValueKey('customer-booking-pay-58'));
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      expect(find.text('Test amount: ₱ 250.00'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-booking-delete-58')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('prototype-payment-mobile')),
        '09171234567',
      );
      await tester.enterText(
        find.byKey(const ValueKey('prototype-payment-verification-code')),
        '123456',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('prototype-payment-confirm')),
      );
      await tester.tap(
        find.byKey(const ValueKey('prototype-payment-confirm')),
      );
      await tester.pumpAndSettle();

      expect(paymentPayload, {
        'paymentMethod': 'prototype_card',
        'provider': 'gcash',
      });
      expect(paymentPayload!.containsKey('mobileNumber'), isFalse);
      expect(paymentPayload!.containsKey('verificationCode'), isFalse);
    },
  );

  testWidgets('booking page refreshes to show approval notifications', (
    tester,
  ) async {
    var bookingStatus = 'pending';
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'status': bookingStatus,
                  'paymentMethod': 'online',
                  'paymentStatus': 'unpaid',
                  'paymentDueAt': '2026-10-15T10:00:00',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsNothing,
    );

    bookingStatus = 'approved';
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'The venue approved your booking. Pay the required amount',
      ),
      findsOneWidget,
    );
    expect(find.text('TP-TXN-00000012'), findsOneWidget);
    expect(find.text('BK-12'), findsOneWidget);
  });

  testWidgets('Event booking details show venue hours without duration', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'id': 13,
                  'businessType': 'Event',
                  'eventType': 'Wedding',
                  'startTime': '09:00:00',
                  'durationHours': 8,
                  'players': 100,
                  'paymentMethod': 'cash_on_arrival',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved (1)'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    final detailsButton = find.byKey(
      const ValueKey('customer-booking-details-13'),
    );
    await tester.ensureVisible(detailsButton);
    await tester.pumpAndSettle();
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.text('Venue hours'), findsOneWidget);
    expect(find.text('9:00 AM - 5:00 PM'), findsOneWidget);
    expect(find.text('Duration'), findsNothing);
  });

  testWidgets('customer can permanently delete a completed booking', (
    tester,
  ) async {
    final bookings = <Map<String, dynamic>>[
      {
        'id': 24,
        'venueName': 'Completed Court',
        'status': 'finished',
        'date': '2026-10-01',
        'startTime': '10:00:00',
        'durationHours': 1,
      },
    ];
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings' && request.method == 'GET') {
          return http.Response(jsonEncode({'bookings': bookings}), 200);
        }
        if (request.url.path == '/api/bookings/24' &&
            request.method == 'DELETE') {
          bookings.clear();
          return http.Response(
            jsonEncode({'message': 'Booking permanently deleted.'}),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-booking-details-24')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-booking-details-24')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('customer-booking-delete-24')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-booking-delete-24')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-booking-delete-24')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('permanently deletes the booking'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('Completed Court'), findsNothing);
    expect(find.text('Booking permanently deleted.'), findsOneWidget);
  });

  testWidgets('customer can delete an unpaid cancelled booking', (
    tester,
  ) async {
    final bookings = <Map<String, dynamic>>[
      {
        'id': 25,
        'venueName': 'Cancelled Court',
        'status': 'cancelled',
        'paymentStatus': 'unpaid',
        'paymentRefundStatus': 'not_requested',
        'paidAmount': 0,
        'date': '2026-10-12',
        'startTime': '10:30:00',
        'durationHours': 2,
      },
    ];
    var deleteRequested = false;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings' && request.method == 'GET') {
          return http.Response(jsonEncode({'bookings': bookings}), 200);
        }
        if (request.url.path == '/api/bookings/25' &&
            request.method == 'DELETE') {
          deleteRequested = true;
          bookings.clear();
          return http.Response(
            jsonEncode({'message': 'Booking permanently deleted.'}),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    final bookingDetails = find.byKey(
      const ValueKey('customer-booking-details-25'),
    );
    await tester.ensureVisible(bookingDetails);
    await tester.pumpAndSettle();
    await tester.tap(bookingDetails);
    await tester.pumpAndSettle();
    expect(find.text('Cancelled Court'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    final deleteButton = find.byKey(
      const ValueKey('customer-booking-delete-25'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete cancelled booking?'), findsOneWidget);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(deleteRequested, isTrue);
    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('Booking permanently deleted.'), findsOneWidget);
  });

  testWidgets('customer can cancel an approved booking within six hours', (
    tester,
  ) async {
    final bookingStart = DateTime.now().add(const Duration(hours: 3));
    final bookingDate =
        '${bookingStart.year.toString().padLeft(4, '0')}-'
        '${bookingStart.month.toString().padLeft(2, '0')}-'
        '${bookingStart.day.toString().padLeft(2, '0')}';
    final bookingTime =
        '${bookingStart.hour.toString().padLeft(2, '0')}:'
        '${bookingStart.minute.toString().padLeft(2, '0')}:00';
    final bookings = <Map<String, dynamic>>[
      {
        'id': 25,
        'venueName': 'Paid Court',
        'status': 'approved',
        'paymentStatus': 'paid',
        'paymentMethod': 'online',
        'paidAmount': 500,
        'total': 500,
        'date': bookingDate,
        'startTime': bookingTime,
        'durationHours': 1,
      },
    ];
    var cancellationRequestCount = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings' && request.method == 'GET') {
          return http.Response(jsonEncode({'bookings': bookings}), 200);
        }
        if (request.url.path == '/api/bookings/25/cancel' &&
            request.method == 'PATCH') {
          cancellationRequestCount++;
          bookings.single['status'] = 'cancelled';
          return http.Response(
            jsonEncode({
              'message': 'Booking cancelled. It is within 6 hours of the start time or has started, so the online payment was not refunded.',
              'status': 'cancelled',
              'paymentRefundStatus': 'not_eligible',
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved (1)'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-booking-cancel-25')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-booking-cancel-25')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('starts in less than 6 hours or has already started'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel booking').last);
    await tester.pumpAndSettle();

    expect(cancellationRequestCount, 1);
    expect(bookings.single['paymentStatus'], 'paid');
    expect(bookings.single['paidAmount'], 500);
    expect(bookings.single['status'], 'cancelled');
    expect(
      find.text(
        'Booking cancelled. It is within 6 hours of the start time or has started, so the online payment was not refunded.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('booking tabs and card accents use the selected palette', (
    tester,
  ) async {
    await AppPreferences.instance.update(
      palette: AppPalette.violet,
      darkMode: true,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        palette: AppPalette.orange,
        darkMode: false,
      ),
    );
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'status': 'pending',
                  'category': 'Tennis',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.indicatorColor, AppPalette.violet.color);
    final categoryBadge = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Tennis'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (categoryBadge.decoration as BoxDecoration).color,
      AppPalette.violet.color,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      AppColors.darkPage,
    );
  });

  testWidgets(
    'customer booking search matches venue, transaction, and booking reference',
    (tester) async {
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/bookings') {
            return http.Response(
              jsonEncode({
                'bookings': [
                  {
                    'id': 101,
                    'venueName': 'Alpha Sports Center',
                    'status': 'pending',
                    'transactionId': 'TP-TXN-00000101',
                    'date': '2026-10-20',
                    'startTime': '09:00:00',
                    'durationHours': 1,
                  },
                  {
                    'id': 102,
                    'venueName': 'Beta Fitness Studio',
                    'status': 'pending',
                    'transactionId': 'TP-TXN-00000102',
                    'date': '2026-10-20',
                    'startTime': '10:00:00',
                    'durationHours': 1,
                  },
                  {
                    'id': 103,
                    'venueName': 'Gamma Event Hall',
                    'status': 'pending',
                    'transactionId': 'TP-TXN-00000103',
                    'date': '2026-10-20',
                    'startTime': '11:00:00',
                    'durationHours': 1,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/messages/conversations') {
            return http.Response(jsonEncode({'conversations': []}), 200);
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected request'}),
            404,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: CustomerBookingsPage(api: api)),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('customer-bookings-search'));
      expect(find.text('Alpha Sports Center'), findsOneWidget);

      await tester.enterText(search, 'beta fitness');
      await tester.pumpAndSettle();
      expect(find.text('Alpha Sports Center'), findsNothing);
      expect(find.text('Beta Fitness Studio'), findsOneWidget);
      expect(find.text('Gamma Event Hall'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('customer-bookings-search-clear')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(search, 'TP-TXN-00000101');
      await tester.pumpAndSettle();
      expect(find.text('Alpha Sports Center'), findsOneWidget);
      expect(find.text('Beta Fitness Studio'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('customer-bookings-search-clear')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(search, 'BK-103');
      await tester.pumpAndSettle();
      expect(find.text('Gamma Event Hall'), findsOneWidget);
      expect(find.text('Alpha Sports Center'), findsNothing);
      expect(find.text('Beta Fitness Studio'), findsNothing);
    },
  );

  testWidgets('tapping the booking status banner dismisses it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CustomerBookingsPage(api: _api())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('booking-status-banner-content')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsNothing,
    );
  });

  testWidgets('booking cards explain pending and confirmed states', (
    tester,
  ) async {
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'id': 20,
                  'status': 'pending',
                  'paymentMethod': 'cash_on_arrival',
                  'paidAmount': 0,
                  'approvalExpiresAt': DateTime.now()
                      .add(const Duration(minutes: 5))
                      .toIso8601String(),
                },
                {..._approvedBooking, 'id': 21, 'status': 'approved'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(
      find.text(
        'Waiting for the venue to approve your request. Not confirmed yet.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customer-booking-approval-deadline-20')),
      findsOneWidget,
    );

    await tester.tap(find.text('Approved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(
      find.text('Confirmed by the venue. Your booking is ready.'),
      findsOneWidget,
    );
  });

  testWidgets('approved bookings prioritize and filter unpaid obligations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'id': 31,
                  'venueName': 'Paid Booking',
                  'paymentMethod': 'online',
                  'paymentStatus': 'paid',
                  'paidAmount': 250,
                  'total': 250,
                },
                {
                  ..._approvedBooking,
                  'id': 32,
                  'venueName': 'Payable Booking',
                  'paymentMethod': 'online',
                  'paymentStatus': 'unpaid',
                  'paidAmount': 0,
                  'total': 500,
                  'paymentDueAt': DateTime.now()
                      .add(const Duration(minutes: 10))
                      .toIso8601String(),
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('booking-status-banner-dismiss')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approved (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Payable Booking'), findsOneWidget);
    expect(find.text('Paid Booking'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Payable Booking')).dy,
      lessThan(tester.getTopLeft(find.text('Paid Booking')).dy),
    );
    expect(find.byKey(const ValueKey('customer-booking-pay-32')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('customer-booking-details-32')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('customer-booking-pay-32')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customer-booking-delete-32')),
      findsNothing,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('approved-payment-filter-payable')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Payable Booking'), findsOneWidget);
    expect(find.text('Paid Booking'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('approved-payment-filter-paid')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paid Booking'), findsOneWidget);
    expect(find.text('Payable Booking'), findsNothing);
  });

  testWidgets('refreshing from the banner dismisses it', (tester) async {
    var bookingRequests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          bookingRequests++;
          return http.Response(
            jsonEncode({
              'bookings': [_approvedBooking],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(bookingRequests, 2);
    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsNothing,
    );
  });

  testWidgets('the dismiss action hides the booking status banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CustomerBookingsPage(api: _api())),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('booking-status-banner-dismiss')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsNothing,
    );
  });

  testWidgets('dismissed banner stays hidden when the bookings page reopens', (
    tester,
  ) async {
    final api = _api();
    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('booking-status-banner-dismiss')),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsNothing,
    );
  });

  testWidgets('updated booking status can show a new status banner', (
    tester,
  ) async {
    var bookingStatus = 'approved';
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {..._approvedBooking, 'status': bookingStatus},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('booking-status-banner-dismiss')),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    bookingStatus = 'completed';
    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-status-banner-content')),
      findsOneWidget,
    );
  });

  testWidgets('submitting a completed booking rating closes and refreshes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reviewed = false;
    var reviewSubmitted = false;
    Map<String, dynamic>? submittedPayload;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  ..._approvedBooking,
                  'status': 'finished',
                  'reviewId': reviewed ? 19 : null,
                  'reviewRating': reviewed ? 5 : null,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/messages/conversations') {
          return http.Response(jsonEncode({'conversations': []}), 200);
        }
        if (request.url.path == '/api/customer/reviews' &&
            request.method == 'POST') {
          reviewed = true;
          reviewSubmitted = true;
          submittedPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response(jsonEncode({'id': 19}), 201);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.light(
            primary: AppColors.navy,
            secondary: AppColors.orange,
          ),
        ),
        home: CustomerBookingsPage(api: api),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-booking-details-12')),
    );
    await tester.tap(find.byKey(const ValueKey('customer-booking-details-12')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('5 stars'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-review-add-image')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('booking-review-star-5')))
          .color,
      AppColors.orange,
    );
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pumpAndSettle();
    expect(find.text('Excellent · 5/5'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Great court');
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(reviewSubmitted, isTrue);
    expect(submittedPayload, {
      'bookingId': 12,
      'rating': 5,
      'comment': 'Great court',
    });
    expect(find.text('Your rating was submitted.'), findsOneWidget);
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-booking-details-12')));
    await tester.pumpAndSettle();
    expect(find.text('Reviewed'), findsOneWidget);
  });
}

AuthApi _api() => AuthApi(
  client: MockClient((request) async {
    if (request.url.path == '/api/bookings') {
      return http.Response(
        jsonEncode({
          'bookings': [_approvedBooking],
        }),
        200,
      );
    }
    if (request.url.path == '/api/messages/conversations') {
      return http.Response(jsonEncode({'conversations': []}), 200);
    }
    return http.Response(jsonEncode({'error': 'Unexpected request'}), 500);
  }),
);

const _approvedBooking = {
  'id': 12,
  'venueName': 'Test Court',
  'status': 'approved',
  'date': '2026-10-01',
  'startTime': '10:00',
};
