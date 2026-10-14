import '../../../app_session.dart';
import '../../../auth_api.dart';

abstract interface class MerchantBookingRepository {
  Future<List<Map<String, dynamic>>> loadBookings();

  Future<void> approveBooking(int bookingId);

  Future<void> declineBooking(int bookingId, {required String reason});

  Future<void> setCashOnArrivalPaymentStatus(
    int bookingId, {
    required String paymentStatus,
  });

  Future<void> deleteCompletedBooking(int bookingId);
}

Future<String?> _loadMerchantApiToken() async =>
    (await AppSession.load()).apiToken;

class AuthApiMerchantBookingRepository implements MerchantBookingRepository {
  const AuthApiMerchantBookingRepository({
    required this.api,
    this.loadToken = _loadMerchantApiToken,
  });

  final AuthApi api;
  final Future<String?> Function() loadToken;

  Future<String> _requireToken() async {
    final token = await loadToken();
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Please sign in again to manage bookings.',
        401,
      );
    }
    return token;
  }

  @override
  Future<List<Map<String, dynamic>>> loadBookings() async =>
      api.merchantBookings(await _requireToken());

  @override
  Future<void> approveBooking(int bookingId) async {
    await api.approveBooking(
      token: await _requireToken(),
      bookingId: bookingId,
    );
  }

  @override
  Future<void> declineBooking(int bookingId, {required String reason}) async {
    await api.declineBooking(
      token: await _requireToken(),
      bookingId: bookingId,
      reason: reason,
    );
  }

  @override
  Future<void> setCashOnArrivalPaymentStatus(
    int bookingId, {
    required String paymentStatus,
  }) async {
    await api.setCashOnArrivalPaymentStatus(
      token: await _requireToken(),
      bookingId: bookingId,
      paymentStatus: paymentStatus,
    );
  }

  @override
  Future<void> deleteCompletedBooking(int bookingId) async {
    await api.deleteCompletedBooking(
      token: await _requireToken(),
      bookingId: bookingId,
    );
  }
}
