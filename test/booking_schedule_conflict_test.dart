import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/booking_schedule_conflict.dart';

void main() {
  test('schedule conflict detects overlaps at another active venue', () {
    final conflicts = findBookingScheduleConflicts(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 10),
      durationHours: 2,
      bookings: [
        {
          'venueId': 8,
          'venueName': 'North Gym',
          'date': '2026-10-13',
          'startTime': '11:00:00',
          'durationHours': 1,
          'status': 'approved',
        },
        {
          'venueId': 9,
          'venueName': 'Cancelled Hall',
          'date': '2026-10-13',
          'startTime': '10:00:00',
          'durationHours': 2,
          'status': 'cancelled',
        },
        {
          'venueId': 4,
          'venueName': 'Current Venue',
          'date': '2026-10-13',
          'startTime': '10:00:00',
          'durationHours': 2,
          'status': 'pending',
        },
        {
          'venueId': 10,
          'venueName': 'Previous-day booking',
          'date': '2026-10-12',
          'startTime': '23:30:00',
          'durationHours': 1,
          'status': 'pending',
        },
      ],
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single['venueName'], 'North Gym');
  });

  test('schedule conflict detects a booking that crosses midnight', () {
    final conflicts = findBookingScheduleConflicts(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 0, 15),
      durationHours: 1,
      bookings: [
        {
          'venueId': 10,
          'venueName': 'Previous-day booking',
          'date': '2026-10-12',
          'startTime': '23:30:00',
          'durationHours': 1,
          'status': 'pending',
        },
      ],
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single['venueName'], 'Previous-day booking');
  });

  test('schedule conflict does not count adjacent non-overlapping times', () {
    final conflicts = findBookingScheduleConflicts(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 10),
      durationHours: 2,
      bookings: [
        {
          'venueId': 8,
          'venueName': 'Earlier booking',
          'date': '2026-10-13',
          'startTime': '08:00:00',
          'durationHours': 2,
          'status': 'approved',
        },
        {
          'venueId': 9,
          'venueName': 'Later booking',
          'date': '2026-10-13',
          'startTime': '12:00:00',
          'durationHours': 1,
          'status': 'pending',
        },
      ],
    );

    expect(conflicts, isEmpty);
  });

  testWidgets('schedule conflict asks before allowing a second booking', (
    tester,
  ) async {
    late Future<bool> result;
    final api = AuthApi(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/bookings');
        return http.Response(
          jsonEncode({
            'bookings': [
              {
                'venueId': 12,
                'venueName': 'North Gym',
                'date': '2026-10-13',
                'startTime': '11:00:00',
                'durationHours': 1,
                'status': 'pending',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              result = confirmBookingScheduleConflict(
                context: context,
                api: api,
                token: 'test-token',
                venueId: 13,
                venueName: 'South Studio',
                startsAt: DateTime(2026, 10, 13, 10),
                durationHours: 2,
              );
            },
            child: const Text('Check schedule'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check schedule'));
    await tester.pumpAndSettle();
    expect(
      find.text('You already have a booking at this time'),
      findsOneWidget,
    );
    expect(find.textContaining('North Gym'), findsOneWidget);
    expect(find.textContaining('Oct 13'), findsNWidgets(2));
    expect(find.textContaining('11:00 AM'), findsOneWidget);
    expect(find.textContaining('South Studio'), findsOneWidget);
    expect(find.text('Choose another time'), findsOneWidget);
    expect(find.text('Continue booking'), findsOneWidget);
    await tester.tap(find.text('Continue booking'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
