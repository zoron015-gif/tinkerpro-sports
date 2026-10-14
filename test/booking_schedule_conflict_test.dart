import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/features/bookings/data/http_booking_schedule_repository.dart';
import 'package:myapp/features/bookings/application/booking_schedule_controller.dart';
import 'package:myapp/features/bookings/domain/booking_schedule.dart';
import 'package:myapp/features/bookings/presentation/booking_schedule_conflict.dart';

List<BookingScheduleEntry> _entries(List<Map<String, dynamic>> bookings) =>
    bookings.map(BookingScheduleEntry.fromApiJson).toList(growable: false);

void main() {
  test('schedule conflict ignores approved bookings at a different venue', () {
    final conflicts = findBookingScheduleConflicts(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 10),
      durationHours: 2,
      bookings: _entries([
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
      ]),
    );

    expect(conflicts, isEmpty);
  });

  test('pending same-date request blocks a rebooking on the same venue', () {
    final pending = findPendingBookingRequests(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 10),
      bookings: _entries([
        {
          'venueId': 4,
          'venueName': 'Current Venue',
          'date': '2026-10-13',
          'startTime': '10:00:00',
          'durationHours': 2,
          'status': 'pending',
        },
      ]),
    );

    expect(pending, hasLength(1));
    expect(pending.single.venueName, 'Current Venue');
  });

  test('schedule conflict detects overlaps at the same active venue', () {
    final conflicts = findBookingScheduleConflicts(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 10),
      durationHours: 2,
      bookings: _entries([
        {
          'venueId': 4,
          'venueName': 'Current Venue',
          'date': '2026-10-13',
          'startTime': '11:00:00',
          'durationHours': 1,
          'status': 'approved',
        },
      ]),
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single.venueName, 'Current Venue');
  });

  test(
    'schedule conflict detects an approved booking that crosses midnight',
    () {
      final conflicts = findBookingScheduleConflicts(
        venueId: 4,
        startsAt: DateTime(2026, 10, 13, 0, 15),
        durationHours: 1,
        bookings: _entries([
          {
            'venueId': 4,
            'venueName': 'Previous-day booking',
            'date': '2026-10-12',
            'startTime': '23:30:00',
            'durationHours': 1,
            'status': 'approved',
          },
        ]),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.venueName, 'Previous-day booking');
    },
  );

  test('schedule conflict ignores pending bookings but still checks approved bookings', () {
    final conflicts = findBookingScheduleConflicts(
      venueId: 4,
      startsAt: DateTime(2026, 10, 13, 10),
      durationHours: 2,
      bookings: _entries([
        {
          'venueId': 4,
          'venueName': 'Pending same venue',
          'date': '2026-10-13',
          'startTime': '10:00:00',
          'durationHours': 2,
          'status': 'pending',
        },
        {
          'venueId': 4,
          'venueName': 'Approved same venue',
          'date': '2026-10-13',
          'startTime': '11:00:00',
          'durationHours': 2,
          'status': 'approved',
        },
        {
          'venueId': 9,
          'venueName': 'Pending other venue',
          'date': '2026-10-13',
          'startTime': '12:00:00',
          'durationHours': 1,
          'status': 'pending',
        },
      ]),
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single.venueName, 'Approved same venue');
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
                'status': 'approved',
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
                controller: BookingScheduleController(
                  repository: HttpBookingScheduleRepository(
                    client: api.httpClient,
                    authHeaders: api.authHeadersForToken,
                    token: 'test-token',
                  ),
                ),
                venueId: 12,
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

  testWidgets('cancels pending request before allowing rebooking', (
    tester,
  ) async {
    late Future<bool> result;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/api/bookings');
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  'id': 21,
                  'venueId': 12,
                  'venueName': 'North Gym',
                  'date': '2026-10-13',
                  'startTime': '10:00:00',
                  'durationHours': 2,
                  'status': 'pending',
                },
              ],
            }),
            200,
          );
        }
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/bookings/21/cancel');
        return http.Response(
          jsonEncode({'message': 'Booking cancelled.'}),
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
                controller: BookingScheduleController(
                  repository: HttpBookingScheduleRepository(
                    client: api.httpClient,
                    authHeaders: api.authHeadersForToken,
                    token: 'test-token',
                  ),
                ),
                venueId: 12,
                venueName: 'North Gym',
                startsAt: DateTime(2026, 10, 13, 11),
                durationHours: 1,
                requireCancelForPendingRequest: true,
              );
            },
            child: const Text('Check schedule'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Pending booking request already exists'), findsOneWidget);
    expect(
      find.textContaining('cancel the existing request first'),
      findsOneWidget,
    );
    expect(find.text('Cancel request and continue'), findsOneWidget);
    await tester.tap(find.text('Cancel request and continue'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('pending request check is opt-in for non-fitness bookings', (
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
                'id': 21,
                'venueId': 12,
                'venueName': 'North Gym',
                'date': '2026-10-13',
                'startTime': '10:00:00',
                'durationHours': 2,
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
                controller: BookingScheduleController(
                  repository: HttpBookingScheduleRepository(
                    client: api.httpClient,
                    authHeaders: api.authHeadersForToken,
                    token: 'test-token',
                  ),
                ),
                venueId: 12,
                venueName: 'North Gym',
                startsAt: DateTime(2026, 10, 13, 11),
                durationHours: 1,
              );
            },
            child: const Text('Check schedule'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Pending booking request already exists'), findsNothing);
    expect(await result, isTrue);
  });
}
