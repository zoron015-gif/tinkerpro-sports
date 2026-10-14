import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/features/merchant_management/data/merchant_booking_repository.dart';

void main() {
  test('rejects booking operations when there is no signed-in token', () async {
    var requestsSent = 0;
    final repository = AuthApiMerchantBookingRepository(
      api: AuthApi(
        client: MockClient((request) async {
          requestsSent++;
          return http.Response('{}', 200);
        }),
      ),
      loadToken: () async => null,
    );

    await expectLater(
      repository.loadBookings(),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(requestsSent, 0);
  });

  test('routes merchant booking operations through the API client', () async {
    final requests = <http.Request>[];
    final repository = AuthApiMerchantBookingRepository(
      api: AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'bookings': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
      loadToken: () async => 'merchant-token',
    );

    expect(await repository.loadBookings(), isEmpty);
    await repository.approveBooking(12);
    await repository.declineBooking(13, reason: 'Unavailable.');
    await repository.setCashOnArrivalPaymentStatus(14, paymentStatus: 'paid');
    await repository.deleteCompletedBooking(15);

    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'GET /api/merchant/bookings',
      'PATCH /api/merchant/bookings/12/approve',
      'PATCH /api/merchant/bookings/13/decline',
      'PATCH /api/merchant/bookings/14/payment',
      'DELETE /api/merchant/bookings/15',
    ]);
    expect(
      requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer merchant-token',
      ),
      isTrue,
    );
  });
}
