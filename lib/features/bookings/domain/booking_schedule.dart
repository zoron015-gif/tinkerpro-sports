import '../../../core/booking_status.dart';

abstract interface class BookingScheduleRepository {
  Future<List<BookingScheduleEntry>> loadCustomerSchedule();

  Future<void> cancelBookingRequest(int bookingId);
}

class BookingScheduleEntry {
  const BookingScheduleEntry({
    required this.id,
    required this.venueId,
    required this.venueName,
    required this.date,
    required this.startAt,
    required this.durationHours,
    required this.status,
  });

  factory BookingScheduleEntry.fromApiJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.tryParse('${json['date'] ?? ''}');
    final date = parsedDate == null
        ? null
        : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final startTime = _parseMinutesSinceMidnight(json['startTime']);

    return BookingScheduleEntry(
      id: _integer(json['id']),
      venueId: _integer(json['venueId']),
      venueName: '${json['venueName'] ?? 'Another venue'}',
      date: date,
      startAt: date == null || startTime == null
          ? null
          : DateTime(
              date.year,
              date.month,
              date.day,
              startTime ~/ 60,
              startTime % 60,
            ),
      durationHours: _number(json['durationHours']),
      status: BookingStatusParser.parse(json['status']),
    );
  }

  final int? id;
  final int? venueId;
  final String venueName;
  final DateTime? date;
  final DateTime? startAt;
  final double durationHours;
  final BookingStatus status;

  DateTime? get endAt {
    if (!durationHours.isFinite || durationHours <= 0) return null;
    final start = startAt;
    if (start == null) return null;
    return start.add(Duration(minutes: (durationHours * 60).round()));
  }
}

List<BookingScheduleEntry> findPendingBookingRequests({
  required Iterable<BookingScheduleEntry> bookings,
  required int venueId,
  required DateTime startsAt,
}) {
  final proposedDate = DateTime(startsAt.year, startsAt.month, startsAt.day);

  return bookings
      .where(
        (booking) =>
            booking.status.isPending &&
            booking.venueId == venueId &&
            booking.date == proposedDate,
      )
      .toList(growable: false);
}

List<BookingScheduleEntry> findBookingScheduleConflicts({
  required Iterable<BookingScheduleEntry> bookings,
  required int venueId,
  required DateTime startsAt,
  required double durationHours,
}) {
  if (!durationHours.isFinite || durationHours <= 0) {
    return const [];
  }

  final proposedStart = DateTime(
    startsAt.year,
    startsAt.month,
    startsAt.day,
    startsAt.hour,
    startsAt.minute,
  );
  final proposedEnd = proposedStart.add(
    Duration(minutes: (durationHours * 60).round()),
  );
  if (!proposedEnd.isAfter(proposedStart)) return const [];

  return bookings
      .where((booking) {
        if (!booking.status.isApproved || booking.venueId != venueId) {
          return false;
        }
        final bookedStart = booking.startAt;
        final bookedEnd = booking.endAt;
        if (bookedStart == null || bookedEnd == null) return false;
        return bookedStart.isBefore(proposedEnd) &&
            bookedEnd.isAfter(proposedStart);
      })
      .toList(growable: false);
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return int.tryParse('$value');
}

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int? _parseMinutesSinceMidnight(Object? value) {
  final text = '$value'.trim();
  final twelveHour = RegExp(
    r'^(\d{1,2}):([0-5]\d)(?::[0-5]\d)?\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (twelveHour != null) {
    final hour = int.parse(twelveHour.group(1)!);
    final minute = int.parse(twelveHour.group(2)!);
    if (hour < 1 || hour > 12) return null;
    final period = twelveHour.group(3)!.toUpperCase();
    return ((hour % 12) + (period == 'PM' ? 12 : 0)) * 60 + minute;
  }

  final twentyFourHour = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?$')
      .firstMatch(text);
  if (twentyFourHour == null) return null;
  return int.parse(twentyFourHour.group(1)!) * 60 +
      int.parse(twentyFourHour.group(2)!);
}
