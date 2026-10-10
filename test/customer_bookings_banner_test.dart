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

  testWidgets('failed booking load offers retry', (tester) async {
    var bookingRequests = 0;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/bookings') {
          bookingRequests++;
          if (bookingRequests == 1) {
            return http.Response(
              jsonEncode({'error': 'Temporary service issue'}),
              503,
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
    expect(find.textContaining('Could not load bookings'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-bookings-retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('customer-bookings-retry')));
    await tester.pumpAndSettle();

    expect(bookingRequests, 2);
    expect(find.text('No pending bookings.'), findsOneWidget);
  });

  testWidgets('viewing bookings clears status notification badges', (
    tester,
  ) async {
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
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();

    final badges = tester.widgetList<Badge>(find.byType(Badge));
    expect(badges, isNotEmpty);
    expect(badges.every((badge) => !badge.isLabelVisible), isTrue);
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
            jsonEncode({'message': 'Completed booking permanently deleted.'}),
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
    expect(find.text('Completed booking permanently deleted.'), findsOneWidget);
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
                {..._approvedBooking, 'id': 20, 'status': 'pending'},
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

    await tester.tap(find.text('Approved (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
    expect(
      find.text('Confirmed by the venue. Your booking is ready.'),
      findsOneWidget,
    );
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
