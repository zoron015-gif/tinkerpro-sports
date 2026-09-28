import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/customer_bookings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
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

    await tester.pumpWidget(MaterialApp(home: CustomerBookingsPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rate this booking'));
    await tester.tap(find.text('Rate this booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 stars'));
    await tester.enterText(find.byType(TextField).last, 'Great court');
    await tester.tap(find.text('Submit rating'));
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
    expect(find.text('You rated this 5/5'), findsOneWidget);
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
