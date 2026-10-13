import 'booking_status.dart';

class BookingTicketViewModel {
  const BookingTicketViewModel({
    required this.type,
    required this.status,
    required this.approvalStatus,
    required this.paymentStatus,
    required this.bookingId,
    required this.venueName,
    required this.sportType,
    required this.fitnessPlanType,
    required this.fitnessCategory,
    required this.businessType,
    required this.eventType,
    required this.fitnessCoachName,
    required this.fitnessCoachDurationMonths,
    required this.fitnessPlanPrice,
    required this.fitnessCoachPrice,
    required this.fullStudio,
    required this.slotNumber,
    required this.bookedArea,
    required this.hasBookedArea,
    required this.date,
    required this.time,
    required this.amount,
    required this.downpayment,
    required this.ticketCode,
    required this.bookingToken,
    required this.paymentReference,
    required this.transactionId,
    required this.paymentMethod,
  });

  final String type;
  final String status;
  final String approvalStatus;
  final String paymentStatus;
  final String bookingId;
  final String venueName;
  final String sportType;
  final String fitnessPlanType;
  final String fitnessCategory;
  final String businessType;
  final String eventType;
  final String fitnessCoachName;
  final int? fitnessCoachDurationMonths;
  final num? fitnessPlanPrice;
  final num? fitnessCoachPrice;
  final bool fullStudio;
  final String slotNumber;
  final String bookedArea;
  final bool hasBookedArea;
  final String date;
  final String time;
  final num? amount;
  final num? downpayment;
  final String ticketCode;
  final String bookingToken;
  final String paymentReference;
  final String transactionId;
  final String paymentMethod;

  factory BookingTicketViewModel.fromMap(Map<String, dynamic> data) {
    final type = '${data['type'] ?? ''}'.trim().toLowerCase();
    final status = '${data['status'] ?? ''}'.trim().toLowerCase();
    final approvalStatus = '${data['approvalStatus'] ?? ''}'.trim().toLowerCase();
    final paymentStatus = '${data['paymentStatus'] ?? ''}'.trim().toLowerCase();
    final bookingIdValue = data['bookingId'];
    final bookingId = bookingIdValue == null ? '—' : '$bookingIdValue';
    final venueName = '${data['venueName'] ?? ''}'.trim();
    final sportType = '${data['sportType'] ?? ''}'.trim();
    final fitnessCategory = '${data['fitnessCategory'] ?? ''}'.trim().isNotEmpty
        ? '${data['fitnessCategory'] ?? ''}'.trim()
        : sportType;
    final businessType = '${data['businessType'] ?? ''}'.trim().toLowerCase();
    final eventType = '${data['eventType'] ?? ''}'.trim();
    final fitnessCoachName = '${data['fitnessCoachName'] ?? ''}'.trim();
    final fitnessCoachDurationMonths = int.tryParse(
      '${data['fitnessCoachDurationMonths'] ?? ''}',
    );
    final fitnessPlanPrice = num.tryParse('${data['fitnessPlanPrice'] ?? ''}');
    final fitnessCoachPrice = num.tryParse('${data['fitnessCoachPrice'] ?? ''}');
    final fullStudio = data['fullStudio'] == true;
    final slotNumber = '${data['slotNumber'] ?? ''}'.trim();
    final rawSlotNumbers = data['slotNumbers'];
    final slotNumbers = rawSlotNumbers is List
        ? (rawSlotNumbers
              .map((value) => int.tryParse('$value'))
              .whereType<int>()
              .where((value) => value > 0)
              .toSet()
              .toList()
            ..sort())
        : <int>[];
    final bookedArea = fullStudio
        ? 'Whole studio'
        : slotNumbers.length > 1
        ? 'Slots ${slotNumbers.join(', ')}'
        : 'Slot ${slotNumbers.isNotEmpty ? slotNumbers.first : slotNumber}';
    final date = '${data['bookingDate'] ?? 'Date to be confirmed'}'.trim();
    final time = '${data['startTime'] ?? 'Time to be confirmed'}'.trim();
    final amount = num.tryParse(
      '${data['amount'] ?? data['total'] ?? ''}',
    );
    final downpayment = num.tryParse('${data['downpayment'] ?? ''}');
    final ticketCode = '${data['ticketCode'] ?? ''}'.trim();
    final bookingToken = '${data['bookingToken'] ?? ''}'.trim();
    final paymentReference = '${data['paymentReference'] ?? ''}'.trim();
    final transactionId = '${data['transactionId'] ?? ''}'.trim().isNotEmpty
        ? '${data['transactionId'] ?? ''}'.trim()
        : (int.tryParse(bookingId) == null
              ? '—'
              : 'TP-TXN-${int.parse(bookingId).toString().padLeft(8, '0')}');
    final paymentMethod = '${data['paymentMethod'] ?? ''}'.trim();

    return BookingTicketViewModel(
      type: type,
      status: status,
      approvalStatus: approvalStatus,
      paymentStatus: paymentStatus,
      bookingId: bookingId,
      venueName: venueName.isEmpty ? 'Venue name unavailable' : venueName,
      sportType: sportType,
      fitnessPlanType: '${data['fitnessPlanType'] ?? ''}'.trim(),
      fitnessCategory: fitnessCategory,
      businessType: businessType,
      eventType: eventType,
      fitnessCoachName: fitnessCoachName,
      fitnessCoachDurationMonths: fitnessCoachDurationMonths,
      fitnessPlanPrice: fitnessPlanPrice,
      fitnessCoachPrice: fitnessCoachPrice,
      fullStudio: fullStudio,
      slotNumber: slotNumber,
      bookedArea: bookedArea,
      hasBookedArea:
          fullStudio || slotNumber.isNotEmpty || slotNumbers.isNotEmpty,
      date: date,
      time: time,
      amount: amount,
      downpayment: downpayment,
      ticketCode: ticketCode,
      bookingToken: bookingToken,
      paymentReference: paymentReference,
      transactionId: transactionId,
      paymentMethod: paymentMethod,
    );
  }

  bool get isBookingRequest => type == 'booking';

  bool get approved =>
      BookingStatusParser.parse(status).isApproved ||
      BookingStatusParser.parse(approvalStatus).isApproved ||
      (type == 'booking_ticket' && status.isEmpty && approvalStatus.isEmpty);

  bool get isPaid =>
      paymentStatus == 'paid' ||
      paymentStatus == 'payment_received' ||
      (type == 'booking_payment_ticket' && paymentStatus.isEmpty);

  bool get isFitnessBooking => fitnessPlanType.isNotEmpty;

  bool get isEventBooking => businessType == 'event' || eventType.isNotEmpty;

  String get paymentMethodLabel => switch (paymentMethod) {
    'online' => 'Online',
    'cash_on_arrival' => 'Cash on arrival',
    _ => paymentMethod,
  };

  String get bookingReference => 'BK-$bookingId';

  String get detailTitle =>
      approved ? 'BOOKING CONFIRMED' : isBookingRequest ? 'BOOKING SUBMITTED' : 'PAYMENT RECEIVED';

  String get badgeLabel =>
      approved ? 'APPROVED' : isBookingRequest ? 'PENDING REVIEW' : 'PENDING APPROVAL';

  String get totalLabel =>
      isPaid ? 'TOTAL PAID' : paymentMethod == 'cash_on_arrival' ? 'DUE AT VENUE' : 'BOOKING TOTAL';

  String get titleText =>
      isFitnessBooking
          ? 'TINKERPRO  ·  FITNESS PASS'
          : isEventBooking
          ? 'TINKERPRO  ·  EVENT PASS'
          : 'TINKERPRO  ·  COURT PASS';

  String get statusText =>
      isBookingRequest
          ? 'BOOKING REQUEST'
          : isPaid
          ? 'PAYMENT RECEIPT'
          : 'BOOKING CONFIRMATION';

  String get accessLabel =>
      isBookingRequest ? 'BOOKING REQUEST' : approved ? 'BOOKING CONFIRMED' : 'PAYMENT RECEIVED';
}
