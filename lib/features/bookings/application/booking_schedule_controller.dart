import '../domain/booking_schedule.dart';

class BookingScheduleCheck {
  const BookingScheduleCheck({
    required this.pendingRequests,
    required this.conflicts,
  });

  final List<BookingScheduleEntry> pendingRequests;
  final List<BookingScheduleEntry> conflicts;
}

class BookingScheduleException implements Exception {
  const BookingScheduleException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookingScheduleController {
  const BookingScheduleController({required this.repository});

  final BookingScheduleRepository repository;

  Future<BookingScheduleCheck> check({
    required int venueId,
    required DateTime startsAt,
    required double durationHours,
    bool requireCancelForPendingRequest = false,
  }) async {
    final bookings = await repository.loadCustomerSchedule();
    return BookingScheduleCheck(
      pendingRequests: requireCancelForPendingRequest
          ? findPendingBookingRequests(
              bookings: bookings,
              venueId: venueId,
              startsAt: startsAt,
            )
          : const [],
      conflicts: findBookingScheduleConflicts(
        bookings: bookings,
        venueId: venueId,
        startsAt: startsAt,
        durationHours: durationHours,
      ),
    );
  }

  Future<void> cancelPendingRequests(
    Iterable<BookingScheduleEntry> requests,
  ) async {
    for (final request in requests) {
      final bookingId = request.id;
      if (bookingId == null) {
        throw const BookingScheduleException(
          'The existing booking request could not be identified, so it was not cancelled.',
        );
      }
      await repository.cancelBookingRequest(bookingId);
    }
  }
}
