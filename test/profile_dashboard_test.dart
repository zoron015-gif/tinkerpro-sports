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

  test('unscoped profile keeps bookings from all business types', () {
    final bookings = [
      {'id': 1, 'businessType': 'Sports'},
      {'id': 2, 'businessType': 'Fitness & Wellness'},
    ];

    expect(bookingsForBusinessType(bookings, null), same(bookings));
    expect(bookingsForBusinessType(bookings, ' '), same(bookings));
  });

  test(
    'customer bookings API sends the requested business type filter',
    () async {
      Uri? requestedUri;
      final api = AuthApi(
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({'bookings': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await api.customerBookings('test-token', businessType: 'Fitness');

      expect(requestedUri?.path, '/api/bookings');
      expect(requestedUri?.queryParameters['businessType'], 'Fitness');
    },
  );
}
