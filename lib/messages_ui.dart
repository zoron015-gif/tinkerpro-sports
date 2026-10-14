import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';
import 'core/booking_ticket_view_model.dart';

Color get messageBackground => AppColors.page;
Color get messageNavy => AppColors.ink;
Color get messageMuted => AppColors.muted;
Color get messageOrange => AppColors.accent;
Color get messageSoftOrange => AppColors.softOrange;

String safeString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int? asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _eventHoursLabel(Object? startValue, Object? durationValue) {
  final time = safeString(startValue).split(':');
  final hour = time.isNotEmpty ? int.tryParse(time[0]) : null;
  final minute = time.length > 1 ? int.tryParse(time[1]) : null;
  final duration = durationValue is num
      ? durationValue.toDouble()
      : double.tryParse(safeString(durationValue));
  if (hour == null ||
      hour < 0 ||
      hour > 23 ||
      minute == null ||
      minute < 0 ||
      minute > 59 ||
      duration == null ||
      duration <= 0) {
    return safeString(startValue, '—');
  }
  final end = DateTime(
    2024,
    1,
    1,
    hour,
    minute,
  ).add(Duration(minutes: (duration * 60).round()));
  String clock(int hour, int minute) {
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  return '${clock(hour, minute)} - ${clock(end.hour % 24, end.minute)}';
}

String displayName(Map<String, dynamic> user) {
  final first = safeString(user['firstName']);
  final last = safeString(user['lastName']);
  final name = '$first $last'.trim();
  if (name.isNotEmpty) return name;
  final email = safeString(user['email']);
  if (email.isNotEmpty) return email;
  return 'User';
}

String initials(Map<String, dynamic> user) {
  final name = displayName(user);
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

Map<String, dynamic>? attachmentValue(Map<String, dynamic> message) {
  final raw = message['attachment'];
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

String messageBody(Map<String, dynamic> message) => safeString(message['body']);

ImageProvider<Object>? avatarImageProvider(String image) {
  final value = image.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('data:image/')) {
    final separator = value.indexOf(',');
    if (separator <= 0 || separator >= value.length - 1) return null;
    try {
      return MemoryImage(base64Decode(value.substring(separator + 1)));
    } on FormatException {
      return null;
    }
  }
  return NetworkImage(value);
}

class MessagesAvatar extends StatelessWidget {
  const MessagesAvatar(this.user, {super.key, this.radius = 22});

  final Map<String, dynamic> user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = safeString(user['avatarUrl']);
    final provider = avatarImageProvider(image);
    return CircleAvatar(
      radius: radius,
      backgroundColor: messageSoftOrange,
      backgroundImage: provider,
      child: image.trim().isEmpty || provider == null
          ? AppText(
              initials(user),
              style: TextStyle(
                color: messageOrange,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class MessagesImageAttachment extends StatelessWidget {
  const MessagesImageAttachment(this.rawAttachment, {super.key});

  final dynamic rawAttachment;

  @override
  Widget build(BuildContext context) {
    final attachment = rawAttachment is Map
        ? Map<String, dynamic>.from(rawAttachment)
        : <String, dynamic>{};
    final data = safeString(attachment['data']);
    if (data.isEmpty || !data.startsWith('data:image/')) {
      return const AppText('Image unavailable', localize: true);
    }
    try {
      final encoded = data.contains(',') ? data.split(',').last : data;
      final bytes = base64Decode(encoded);
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 220, height: 220, fit: BoxFit.cover),
      );
    } on FormatException {
      return const AppText('Image unavailable', localize: true);
    }
  }
}

class MessagesBookingTicket extends StatelessWidget {
  const MessagesBookingTicket(this.data, {super.key});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ticket = BookingTicketViewModel.fromMap(data);
    final isBookingRequest = ticket.isBookingRequest;
    final approved = ticket.approved;
    final expired = ticket.expired;
    final bookingId = ticket.bookingId;
    final venueName = ticket.venueName;
    final sportType = ticket.sportType;
    final fitnessPlanType = ticket.fitnessPlanType;
    final fitnessCategory = ticket.fitnessCategory;
    final eventType = ticket.eventType;
    final fitnessCoachName = ticket.fitnessCoachName;
    final fitnessCoachDurationMonths = ticket.fitnessCoachDurationMonths;
    final fitnessPlanPrice = ticket.fitnessPlanPrice;
    final fitnessCoachPrice = ticket.fitnessCoachPrice;
    final isFitnessBooking = ticket.isFitnessBooking;
    final isEventBooking = ticket.isEventBooking;
    final date = ticket.date;
    final time = ticket.time;
    final amount = ticket.amount;
    final downpayment = ticket.downpayment;
    final ticketCode = ticket.ticketCode;
    final bookingToken = ticket.bookingToken;
    final paymentReference = ticket.paymentReference;
    final transactionId = ticket.transactionId;
    final paymentMethod = ticket.paymentMethod;
    final isPaid = ticket.isPaid;
    final ticketHighlight = expired
        ? const Color(0xFFB42318)
        : approved
        ? const Color(0xFF237A43)
        : isBookingRequest
        ? const Color(0xFFB45309)
        : AppColors.navy;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 370),
      child: Container(
        key: ValueKey('messages-booking-ticket-$transactionId'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expired || isBookingRequest || approved
                ? ticketHighlight.withValues(alpha: .55)
                : AppColors.border,
            width: expired || isBookingRequest || approved ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const ValueKey('messages-booking-ticket-header'),
              color: ticketHighlight,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.confirmation_number_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          isFitnessBooking
                              ? 'TINKERPRO  ·  FITNESS PASS'
                              : isEventBooking
                              ? 'TINKERPRO  ·  EVENT PASS'
                              : 'TINKERPRO  ·  COURT PASS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          expired
                              ? 'BOOKING REQUEST EXPIRED'
                              : isBookingRequest
                              ? approved
                                    ? 'BOOKING CONFIRMED'
                                    : 'BOOKING REQUEST'
                              : isPaid
                              ? 'PAYMENT RECEIPT'
                              : 'BOOKING CONFIRMATION',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    approved ? Icons.verified_rounded : Icons.receipt_long,
                    color: Colors.white,
                    size: 19,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          expired
                              ? 'BOOKING REQUEST EXPIRED'
                              : approved
                              ? 'BOOKING CONFIRMED'
                              : isBookingRequest
                              ? 'BOOKING SUBMITTED'
                              : 'PAYMENT RECEIVED',
                          style: TextStyle(
                            color: messageNavy,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      _TicketStatusPill(
                        label: expired
                            ? 'EXPIRED'
                            : approved
                            ? 'APPROVED'
                            : isBookingRequest
                            ? 'PENDING REVIEW'
                            : 'PENDING APPROVAL',
                        approved: approved,
                        expired: expired,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    venueName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (isFitnessBooking) ...[
                    const SizedBox(height: 6),
                    AppText(
                      '$fitnessCategory · '
                      '${fitnessPlanType[0].toUpperCase()}'
                      '${fitnessPlanType.substring(1)} plan',
                      style: TextStyle(
                        color: messageMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      localize: true,
                    ),
                    if (fitnessCoachName.isNotEmpty)
                      AppText(
                        'Coach: $fitnessCoachName'
                        '${fitnessCoachDurationMonths == null ? '' : ' · ${fitnessCoachDurationMonths == 1 ? '1 month' : '$fitnessCoachDurationMonths months'}'}'
                        '${fitnessCoachPrice == null ? '' : ' · \u{20B1} ${fitnessCoachPrice.toStringAsFixed(2)}'}',
                        style: TextStyle(
                          color: messageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      ),
                    if (fitnessPlanPrice != null)
                      AppText(
                        'Plan total: \u{20B1} ${fitnessPlanPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: messageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        localize: true,
                      ),
                  ] else if (isEventBooking && eventType.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    AppText(
                      eventType,
                      style: TextStyle(
                        color: messageMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (sportType.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    AppText(
                      sportType,
                      style: TextStyle(
                        color: messageMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!isFitnessBooking && ticket.hasBookedArea) ...[
                    const SizedBox(height: 6),
                    AppText(
                      ticket.bookedArea,
                      style: TextStyle(
                        color: messageMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _TicketDetail(
                          icon: Icons.calendar_month_outlined,
                          label: 'DATE',
                          value: date,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _TicketDetail(
                          icon: Icons.schedule_rounded,
                          label: isEventBooking ? 'VENUE HOURS' : 'START',
                          value: isEventBooking
                              ? _eventHoursLabel(
                                  data['startTime'],
                                  data['durationHours'],
                                )
                              : time,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _TicketDetail(
                          icon: Icons.group_outlined,
                          label: isEventBooking ? 'GUESTS' : 'PLAYERS',
                          value: safeString(data['players'], '—'),
                        ),
                      ),
                      if (!isFitnessBooking && !isEventBooking) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: _TicketDetail(
                            icon: Icons.timer_outlined,
                            label: 'DURATION',
                            value:
                                '${safeString(data['durationHours'], '—')} hr',
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (paymentMethod.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _TicketDetail(
                      icon: Icons.payments_outlined,
                      label: 'PAYMENT METHOD',
                      value: switch (paymentMethod) {
                        'online' => 'Online',
                        'cash_on_arrival' => 'Cash on arrival',
                        _ => paymentMethod,
                      },
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CustomPaint(
                painter: _TicketPerforationPainter(),
                child: const SizedBox(height: 6, width: double.infinity),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'TRANSACTION ID',
                          style: TextStyle(
                            color: messageMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                          localize: true,
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          transactionId,
                          key: const ValueKey('messages-transaction-id'),
                          style: TextStyle(
                            color: messageNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          'BOOKING REFERENCE',
                          style: TextStyle(
                            color: messageMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                          localize: true,
                        ),
                        AppText(
                          'BK-$bookingId',
                          key: const ValueKey('messages-ticket-reference'),
                          style: TextStyle(
                            color: messageNavy,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          localize: true,
                        ),
                        if (approved && ticketCode.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            'TICKET CODE',
                            style: TextStyle(
                              color: messageMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            localize: true,
                          ),
                          AppText(
                            ticketCode,
                            style: TextStyle(
                              color: messageNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (isBookingRequest &&
                            !expired &&
                            bookingToken.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            'BOOKING TOKEN',
                            style: TextStyle(
                              color: messageMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppText(
                            bookingToken,
                            key: const ValueKey('messages-booking-token'),
                            style: TextStyle(
                              color: messageNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (!approved && !expired)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: AppText(
                              'Request expires in 15 min',
                              style: TextStyle(
                                color: messageMuted,
                                fontSize: 10,
                              ),
                              localize: true,
                            ),
                          ),
                        if (paymentReference.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            'Payment ref: $paymentReference',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: messageMuted, fontSize: 9),
                            localize: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (amount != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          isPaid
                              ? 'TOTAL PAID'
                              : paymentMethod == 'cash_on_arrival'
                              ? 'DUE AT VENUE'
                              : 'BOOKING TOTAL',
                          style: TextStyle(
                            color: messageMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          '\u{20B1} ${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: messageNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (downpayment != null)
                          AppText(
                            'Downpayment: \u{20B1} ${downpayment.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: messageMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetail extends StatelessWidget {
  const _TicketDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: messageOrange, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              label,
              style: TextStyle(
                color: messageMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TicketStatusPill extends StatelessWidget {
  const _TicketStatusPill({
    required this.label,
    required this.approved,
    required this.expired,
  });

  final String label;
  final bool approved;
  final bool expired;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: expired
          ? const Color(0xFFFEE4E2)
          : approved
          ? const Color(0xFFE7F6ED)
          : AppColors.softOrangeAlt,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      label,
      style: TextStyle(
        color: expired
            ? const Color(0xFFB42318)
            : approved
            ? const Color(0xFF247A43)
            : messageOrange,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: .3,
      ),
    ),
  );
}

class _TicketPerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCE3EF)
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dashWidth + gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
