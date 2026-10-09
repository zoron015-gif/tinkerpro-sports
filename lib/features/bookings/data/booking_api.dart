part of '../../../auth_api.dart';

extension AuthApiBookingOperations on AuthApi {
  Future<Map<String, dynamic>> createBooking({
    required String token,
    required String idempotencyKey,
    required int venueId,
    required String date,
    required String startTime,
    required double durationHours,
    required int players,
    required String paymentMethod,
    String sportType = '',
    int slotNumber = 1,
    String fitnessPlanType = '',
    String fitnessCoachName = '',
    int fitnessCoachDurationMonths = 0,
    String eventType = '',
  }) => _request(
    'POST',
    '/api/bookings',
    body: {
      'venueId': venueId,
      'date': date,
      'startTime': startTime,
      'durationHours': durationHours,
      'players': players,
      'paymentMethod': paymentMethod,
      'sportType': sportType,
      'slotNumber': slotNumber,
      'fitnessPlanType': fitnessPlanType,
      'fitnessCoachName': fitnessCoachName,
      'fitnessCoachDurationMonths': fitnessCoachDurationMonths,
      'eventType': eventType,
    },
    headers: _authHeaders(
      token,
      extra: {
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
    ),
  );

  Future<List<Map<String, dynamic>>> customerBookings(
    String token, {
    String? businessType,
  }) async {
    final path = businessType == null || businessType.trim().isEmpty
        ? '/api/bookings'
        : '/api/bookings?businessType=${Uri.encodeQueryComponent(businessType.trim())}';
    final response = await _request('GET', path, headers: _authHeaders(token));
    return asMapList(response['bookings']);
  }

  Future<Map<String, dynamic>> merchantVenueCheckInCode({
    required String token,
    required int venueId,
  }) => _request(
    'GET',
    '/api/merchant/businesses/$venueId/check-in-code',
    headers: _authHeaders(token),
  );

  Future<Map<String, dynamic>> recordBookingCheckIn({
    required String token,
    required String qrCode,
  }) => _request(
    'POST',
    '/api/bookings/check-in',
    body: {'qrCode': qrCode},
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<void> deleteCustomerCompletedBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'DELETE',
      '/api/bookings/$bookingId',
      headers: _authHeaders(token),
    );
  }

  Future<Map<String, dynamic>> cancelCustomerBooking({
    required String token,
    required int bookingId,
  }) => _request(
    'PATCH',
    '/api/bookings/$bookingId/cancel',
    headers: _authHeaders(token),
  );

  Future<List<Map<String, dynamic>>> fitnessBookingAttendance(
    String token,
    int bookingId,
  ) async {
    final response = await _request(
      'GET',
      '/api/bookings/$bookingId/attendance',
      headers: _authHeaders(token),
    );
    return asMapList(response['attendance']);
  }

  Future<void> setFitnessBookingAttendance({
    required String token,
    required int bookingId,
    required String date,
    required String status,
  }) async {
    await _request(
      'PUT',
      '/api/bookings/$bookingId/attendance/${Uri.encodeComponent(date)}',
      body: {'status': status},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> clearFitnessBookingAttendance({
    required String token,
    required int bookingId,
    required String date,
  }) async {
    await _request(
      'DELETE',
      '/api/bookings/$bookingId/attendance/${Uri.encodeComponent(date)}',
      headers: _authHeaders(token),
    );
  }

  Future<List<Booking>> customerBookingModels(
    String token, {
    String? businessType,
  }) async {
    final response = await customerBookings(token, businessType: businessType);
    return response.map(Booking.fromJson).toList();
  }

  Future<Map<String, dynamic>> createPayMongoCheckout({
    required String token,
    required int bookingId,
    required String paymentMethod,
  }) => _request(
    'POST',
    '/api/payments/paymongo/checkout',
    body: {'bookingId': bookingId, 'paymentMethod': paymentMethod},
    headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
  );

  Future<bool> payMongoPaymentsEnabled(String token) async {
    final response = await _request(
      'GET',
      '/api/payments/paymongo/config',
      headers: _authHeaders(token),
    );
    return response['onlinePaymentsEnabled'] == true;
  }

  Future<List<Map<String, dynamic>>> bookingAvailability({
    required String token,
    required int venueId,
    required String date,
  }) async {
    final response = await _request(
      'GET',
      '/api/bookings/availability?venueId=$venueId&date=${Uri.encodeQueryComponent(date)}',
      headers: _authHeaders(token),
    );
    return asMapList(response['bookings']);
  }

  Future<List<Map<String, dynamic>>> merchantBookings(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/bookings',
      headers: _authHeaders(token),
    );
    return asMapList(response['bookings']);
  }

  Future<void> approveBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/approve',
      headers: _authHeaders(token),
    );
  }

  Future<void> declineBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/decline',
      headers: _authHeaders(token),
    );
  }

  Future<void> setCashOnArrivalPaymentStatus({
    required String token,
    required int bookingId,
    required String paymentStatus,
  }) async {
    await _request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/payment',
      body: {'paymentStatus': paymentStatus},
      headers: _authHeaders(
        token,
        extra: const {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<void> finishBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'PATCH',
      '/api/merchant/bookings/$bookingId/finish',
      headers: _authHeaders(token),
    );
  }

  Future<void> deleteCompletedBooking({
    required String token,
    required int bookingId,
  }) async {
    await _request(
      'DELETE',
      '/api/merchant/bookings/$bookingId',
      headers: _authHeaders(token),
    );
  }
}
