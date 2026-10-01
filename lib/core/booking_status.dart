enum BookingStatus {
  pending,
  approved,
  confirmed,
  finished,
  completed,
  done,
  cancelled,
  rejected,
  expired,
  unknown,
}

extension BookingStatusX on BookingStatus {
  String get value => switch (this) {
    BookingStatus.pending => 'pending',
    BookingStatus.approved => 'approved',
    BookingStatus.confirmed => 'confirmed',
    BookingStatus.finished => 'finished',
    BookingStatus.completed => 'completed',
    BookingStatus.done => 'done',
    BookingStatus.cancelled => 'cancelled',
    BookingStatus.rejected => 'rejected',
    BookingStatus.expired => 'expired',
    BookingStatus.unknown => 'unknown',
  };

  bool get isPending => this == BookingStatus.pending;
  bool get isApproved =>
      this == BookingStatus.approved || this == BookingStatus.confirmed;
  bool get isConfirmed =>
      this == BookingStatus.approved ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.finished ||
      this == BookingStatus.completed ||
      this == BookingStatus.done;
  bool get isCancelled =>
      this == BookingStatus.cancelled ||
      this == BookingStatus.rejected ||
      this == BookingStatus.expired;

  String get displayLabel => switch (this) {
    BookingStatus.pending => 'Pending',
    BookingStatus.approved => 'Approved',
    BookingStatus.confirmed => 'Confirmed',
    BookingStatus.finished => 'Finished',
    BookingStatus.completed => 'Completed',
    BookingStatus.done => 'Done',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.rejected => 'Rejected',
    BookingStatus.expired => 'Expired',
    BookingStatus.unknown => 'Unknown',
  };
}

class BookingStatusParser {
  const BookingStatusParser();

  static BookingStatus parse(Object? value) {
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return switch (normalized) {
      'pending' || 'awaiting_approval' => BookingStatus.pending,
      'approved' => BookingStatus.approved,
      'confirmed' => BookingStatus.confirmed,
      'finished' => BookingStatus.finished,
      'completed' => BookingStatus.completed,
      'done' => BookingStatus.done,
      'cancelled' || 'canceled' => BookingStatus.cancelled,
      'rejected' => BookingStatus.rejected,
      'expired' => BookingStatus.expired,
      _ => BookingStatus.unknown,
    };
  }

  static bool isPending(Object? value) => parse(value).isPending;
  static bool isApproved(Object? value) => parse(value).isApproved;
  static bool isConfirmed(Object? value) => parse(value).isConfirmed;
  static bool isCancelled(Object? value) => parse(value).isCancelled;
  static String label(Object? value) => parse(value).displayLabel;
}
