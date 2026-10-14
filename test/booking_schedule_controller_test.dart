import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/booking_status.dart';
import 'package:myapp/features/bookings/application/booking_schedule_controller.dart';
import 'package:myapp/features/bookings/domain/booking_schedule.dart';

class _FakeBookingScheduleRepository implements BookingScheduleRepository {
  _FakeBookingScheduleRepository(this.bookings);

  final List<BookingScheduleEntry> bookings;
  final List<int> cancelledBookingIds = [];

  @override
  Future<List<BookingScheduleEntry>> loadCustomerSchedule() async => bookings;

  @override
  Future<void> cancelBookingRequest(int bookingId) async {
    cancelledBookingIds.add(bookingId);
  }
}

BookingScheduleEntry _booking({
  int? id,
  required BookingStatus status,
  required String startTime,
}) => BookingScheduleEntry(
  id: id,
  venueId: 7,
  venueName: 'Sample Venue',
  date: DateTime(2026, 10, 14),
  startAt: DateTime.parse('2026-10-14T$startTime'),
  durationHours: 1,
  status: status,
);

void main() {
  test(
    'loads schedule and returns pending requests only when required',
    () async {
      final repository = _FakeBookingScheduleRepository([
        _booking(id: 11, status: BookingStatus.pending, startTime: '10:00:00'),
        _booking(id: 12, status: BookingStatus.approved, startTime: '11:00:00'),
      ]);
      final controller = BookingScheduleController(repository: repository);

      final withoutPendingRule = await controller.check(
        venueId: 7,
        startsAt: DateTime(2026, 10, 14, 10, 30),
        durationHours: 1,
      );
      expect(withoutPendingRule.pendingRequests, isEmpty);
      expect(withoutPendingRule.conflicts, hasLength(1));
      expect(withoutPendingRule.conflicts.single.id, 12);

      final withPendingRule = await controller.check(
        venueId: 7,
        startsAt: DateTime(2026, 10, 14, 10, 30),
        durationHours: 1,
        requireCancelForPendingRequest: true,
      );
      expect(withPendingRule.pendingRequests.single.id, 11);
      expect(withPendingRule.conflicts.single.id, 12);
    },
  );

  test('cancels pending requests through the repository in order', () async {
    final repository = _FakeBookingScheduleRepository([]);
    final controller = BookingScheduleController(repository: repository);

    await controller.cancelPendingRequests([
      _booking(id: 11, status: BookingStatus.pending, startTime: '10:00:00'),
      _booking(id: 12, status: BookingStatus.pending, startTime: '11:00:00'),
    ]);

    expect(repository.cancelledBookingIds, [11, 12]);
  });

  test('refuses to cancel a request without a booking id', () async {
    final repository = _FakeBookingScheduleRepository([]);
    final controller = BookingScheduleController(repository: repository);

    await expectLater(
      controller.cancelPendingRequests([
        _booking(status: BookingStatus.pending, startTime: '10:00:00'),
      ]),
      throwsA(
        isA<BookingScheduleException>().having(
          (error) => error.message,
          'message',
          contains('could not be identified'),
        ),
      ),
    );
    expect(repository.cancelledBookingIds, isEmpty);
  });
}
