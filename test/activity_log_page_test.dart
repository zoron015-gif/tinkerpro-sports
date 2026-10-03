import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/activity_log_page.dart';
import 'package:myapp/auth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'session_api_token': 'my-token'});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('activity page displays the signed-in account activity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'my-token'});
    String? requestedPath;
    final api = AuthApi(
      client: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 1,
                'activityType': 'booking_requested',
                'title': 'Booking requested',
                'description': 'Booking #12 was requested for 2026-10-01.',
                'actorRole': 'customer',
                'requestId': 'abc12345-0000-4000-8000-000000000001',
                'createdAt': '2026-09-29 08:00:00',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ActivityLogPage(api: api)));
    await tester.pumpAndSettle();

    expect(requestedPath, '/api/activity-logs');
    expect(find.text('Booking requested'), findsOneWidget);
    expect(
      find.text('Booking #12 was requested for 2026-10-01.'),
      findsOneWidget,
    );
    expect(find.textContaining('Performed by customer'), findsOneWidget);
    expect(
      find.textContaining('abc12345-0000-4000-8000-000000000001'),
      findsOneWidget,
    );
  });

  testWidgets('calendar filter shows one date and can be cleared', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'my-token'});
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    String timestamp(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} 09:00:00';
    final api = AuthApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 1,
                'activityType': 'login',
                'title': 'Today activity',
                'description': 'Activity from today.',
                'createdAt': timestamp(today),
              },
              {
                'id': 2,
                'activityType': 'login',
                'title': 'Yesterday activity',
                'description': 'Activity from yesterday.',
                'createdAt': timestamp(yesterday),
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ActivityLogPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('activity-log-date-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Today activity'), findsOneWidget);
    expect(find.text('Yesterday activity'), findsNothing);
    expect(
      find.byKey(const ValueKey('activity-log-clear-date')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('activity-log-clear-date')));
    await tester.pumpAndSettle();
    expect(find.text('Today activity'), findsOneWidget);
    expect(find.text('Yesterday activity'), findsOneWidget);
  });

  testWidgets('search field filters activity by its text', (tester) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'my-token'});
    final api = AuthApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 1,
                'activityType': 'booking_requested',
                'title': 'Booking requested',
                'description': 'A court booking was made.',
                'createdAt': '2026-09-29 08:00:00',
              },
              {
                'id': 2,
                'activityType': 'profile_updated',
                'title': 'Profile updated',
                'description': 'Your profile details were changed.',
                'createdAt': '2026-09-28 08:00:00',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ActivityLogPage(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activity-log-search')),
      'booking',
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking requested'), findsOneWidget);
    expect(find.text('Profile updated'), findsNothing);
  });

  testWidgets('missing activity fields do not crash the search filter', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'my-token'});
    final api = AuthApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 1,
                'activityType': null,
                'title': null,
                'description': 'Booking #99 was requested.',
                'createdAt': '2026-09-29 08:00:00',
              },
              {
                'id': 2,
                'activityType': 'profile_updated',
                'title': 'Profile updated',
                'description': 'Your profile details were changed.',
                'createdAt': '2026-09-28 08:00:00',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ActivityLogPage(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activity-log-search')),
      'booking',
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking #99 was requested.'), findsOneWidget);
    expect(find.text('Profile updated'), findsNothing);
  });

  testWidgets('venue activity groups repeat visits into a detailed timeline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'my-token'});
    final api = AuthApi(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'activities': [
              {
                'id': 2,
                'activityType': 'booking_approved',
                'title': 'Booking approved',
                'description': 'Booking #18 at Riverside Court was approved.',
                'venueId': 42,
                'venueName': 'Riverside Court',
                'sportType': 'Basketball',
                'details': {
                  'bookingId': 18,
                  'bookingDate': '2026-10-03',
                  'startTime': '14:30:00',
                  'durationHours': 2,
                  'players': 8,
                },
                'createdAt': '2026-09-29T08:15:34',
              },
              {
                'id': 1,
                'activityType': 'booking_requested',
                'title': 'Booking requested',
                'description': 'Booking #16 at Riverside Court was requested.',
                'venueId': 42,
                'venueName': 'Riverside Court',
                'sportType': 'Basketball',
                'details': {
                  'bookingId': 16,
                  'bookingDate': '2026-10-01',
                  'startTime': '09:00:00',
                  'durationHours': 1,
                  'players': 4,
                },
                'createdAt': '2026-09-28T11:02:07',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: ActivityLogPage(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Riverside Court'), findsOneWidget);
    expect(
      find.text('2 activities · Last: 2026-09-29 08:15:34'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('activity-log-venue-id:42')));
    await tester.pumpAndSettle();

    expect(find.text('Basketball'), findsNWidgets(2));
    expect(find.text('Booking approved'), findsOneWidget);
    expect(find.text('Booking requested'), findsOneWidget);
    expect(find.text('2026-09-29 08:15:34'), findsOneWidget);
    expect(find.text('2026-09-28 11:02:07'), findsOneWidget);
    expect(
      find.textContaining('Booking: 2026-10-03 at 14:30:00'),
      findsOneWidget,
    );
    expect(find.text('Duration: 2 hours'), findsOneWidget);
    expect(find.text('Players: 8'), findsOneWidget);
  });
}
