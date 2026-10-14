import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/core/api_http_client.dart';
import 'package:myapp/features/bookings/data/http_booking_schedule_repository.dart';
import 'package:myapp/core/booking_status.dart';

void main() {
  test('loads the customer schedule through the shared HTTP client', () async {
    late http.Request receivedRequest;
    final client = ApiHttpClient(
      client: MockClient((request) async {
        receivedRequest = request;
        return http.Response(
          jsonEncode({
            'bookings': [
              {
                'id': 31,
                'venueId': 7,
                'venueName': 'North Gym',
                'date': '2026-10-14',
                'startTime': '10:30:00',
                'durationHours': 1.5,
                'status': 'pending',
              },
            ],
          }),
          200,
        );
      }),
    );
    final repository = HttpBookingScheduleRepository(
      client: client,
      authHeaders: (token) => {'Authorization': token ?? ''},
      token: 'session-token',
    );

    final schedule = await repository.loadCustomerSchedule();

    expect(receivedRequest.method, 'GET');
    expect(receivedRequest.url.path, '/api/bookings');
    expect(receivedRequest.headers['Authorization'], 'session-token');
    expect(schedule, hasLength(1));
    expect(schedule.single.id, 31);
    expect(schedule.single.status, BookingStatus.pending);
  });

  test('cancels a customer request through the shared HTTP client', () async {
    late http.Request receivedRequest;
    final client = ApiHttpClient(
      client: MockClient((request) async {
        receivedRequest = request;
        return http.Response('{}', 200);
      }),
    );
    final repository = HttpBookingScheduleRepository(
      client: client,
      authHeaders: (token) => {'Authorization': token ?? ''},
      token: 'session-token',
    );

    await repository.cancelBookingRequest(31);

    expect(receivedRequest.method, 'PATCH');
    expect(receivedRequest.url.path, '/api/bookings/31/cancel');
    expect(receivedRequest.headers['Authorization'], 'session-token');
  });

  test('preserves shared API errors when loading the schedule', () async {
    final client = ApiHttpClient(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'error': 'Booking access denied.'}), 403),
      ),
    );
    final repository = HttpBookingScheduleRepository(
      client: client,
      authHeaders: (token) => {'Authorization': token ?? ''},
      token: 'session-token',
    );

    await expectLater(
      repository.loadCustomerSchedule(),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.message,
              'message',
              'Booking access denied.',
            ),
      ),
    );
  });
}
