import '../../../core/api_http_client.dart';
import '../../../core/api_response.dart';
import '../domain/booking_schedule.dart';

class HttpBookingScheduleRepository implements BookingScheduleRepository {
  const HttpBookingScheduleRepository({
    required this.client,
    required this.authHeaders,
    required this.token,
  });

  final ApiHttpClient client;
  final Map<String, String> Function(String?) authHeaders;
  final String token;

  @override
  Future<List<BookingScheduleEntry>> loadCustomerSchedule() async {
    final response = await client.request(
      'GET',
      '/api/bookings',
      headers: authHeaders(token),
    );
    return asMapList(response['bookings'])
        .map(BookingScheduleEntry.fromApiJson)
        .toList(growable: false);
  }

  @override
  Future<void> cancelBookingRequest(int bookingId) async {
    await client.request(
      'PATCH',
      '/api/bookings/$bookingId/cancel',
      headers: authHeaders(token),
    );
  }
}
