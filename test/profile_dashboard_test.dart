import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/profile_dashboard.dart';

void main() {
  test('Fitness profile booking selection excludes other business types', () {
    final bookings = [
      {'id': 1, 'businessType': 'Sports'},
      {'id': 2, 'businessType': 'Fitness & Wellness'},
      {'id': 3, 'businessType': 'Event'},
    ];

    expect(
      bookingsForBusinessType(
        bookings,
        ' fitness ',
      ).map((booking) => booking['id']),
      [2],
    );
  });

  test('Sports profile booking selection excludes other business types', () {
    final bookings = [
      {'id': 1, 'businessType': 'Sports'},
      {'id': 2, 'businessType': 'Fitness & Wellness'},
      {'id': 3, 'businessType': 'Event'},
    ];

    expect(
      bookingsForBusinessType(
        bookings,
        'Sports',
      ).map((booking) => booking['id']),
      [1],
    );
  });

  test('unscoped profile keeps bookings from all business types', () {
    final bookings = [
      {'id': 1, 'businessType': 'Sports'},
      {'id': 2, 'businessType': 'Fitness & Wellness'},
    ];

    expect(bookingsForBusinessType(bookings, null), same(bookings));
    expect(bookingsForBusinessType(bookings, ' '), same(bookings));
  });

  test(
    'customer booking model loader sends the requested business type filter',
    () async {
      final requestedBusinessTypes = <String?>[];
      final api = AuthApi(
        client: MockClient((request) async {
          requestedBusinessTypes.add(
            request.url.queryParameters['businessType'],
          );
          return http.Response(
            jsonEncode({'bookings': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await api.customerBookingModels('test-token', businessType: 'Sports');
      await api.customerBookingModels(
        'test-token',
        businessType: 'Fitness & Wellness',
      );

      expect(requestedBusinessTypes, ['Sports', 'Fitness & Wellness']);
    },
  );

  test('message conversation loader filters by business type', () async {
    final requestedBusinessTypes = <String?>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requestedBusinessTypes.add(request.url.queryParameters['businessType']);
        return http.Response(
          jsonEncode({'conversations': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await api.conversations('test-token', businessType: 'Fitness & Wellness');

    expect(requestedBusinessTypes, ['Fitness & Wellness']);
  });

  test(
    'fitness attendance API reads, updates, and clears dated records',
    () async {
      final requests = <http.Request>[];
      final api = AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'attendance': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await api.fitnessBookingAttendance('test-token', 501);
      await api.setFitnessBookingAttendance(
        token: 'test-token',
        bookingId: 501,
        date: '2026-10-01',
        status: 'absent',
      );
      await api.clearFitnessBookingAttendance(
        token: 'test-token',
        bookingId: 501,
        date: '2026-10-01',
      );

      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'GET /api/bookings/501/attendance',
          'PUT /api/bookings/501/attendance/2026-10-01',
          'DELETE /api/bookings/501/attendance/2026-10-01',
        ],
      );
      expect(jsonDecode(requests[1].body), {'status': 'absent'});
    },
  );
}
