import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';

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
    final type = safeString(data['type']);
    final isBookingRequest = type == 'booking';
    final approved =
        type == 'booking_ticket' ||
        safeString(data['status']) == 'approved';
    final bookingId = safeString(data['bookingId'], '—');
    final venueName = safeString(data['venueName'], 'Sports venue');
    final sportType = safeString(data['sportType']);
    final fitnessPlanType = safeString(data['fitnessPlanType']);
    final fitnessCategory = safeString(data['fitnessCategory'], sportType);
    final businessType = safeString(data['businessType']).toLowerCase();
    final eventType = safeString(data['eventType']);
    final fitnessCoachName = safeString(data['fitnessCoachName']);
    final fitnessCoachDurationMonths = int.tryParse(
      safeString(data['fitnessCoachDurationMonths']),
    );
    final fitnessPlanPrice = num.tryParse(safeString(data['fitnessPlanPrice']));
    final fitnessCoachPrice = num.tryParse(
      safeString(data['fitnessCoachPrice']),
    );
    final isFitnessBooking = fitnessPlanType.isNotEmpty;
    final isEventBooking = businessType == 'event' || eventType.isNotEmpty;
    final fullStudio = data['fullStudio'] == true;
    final slotNumber = safeString(data['slotNumber']);
    final date = safeString(data['bookingDate'], 'Date to be confirmed');
    final time = safeString(data['startTime'], 'Time to be confirmed');
    final amount = num.tryParse(
      safeString(data['amount'], safeString(data['total'])),
    );
    final downpayment = num.tryParse(safeString(data['downpayment']));
    final ticketCode = safeString(data['ticketCode']);
    final bookingToken = safeString(data['bookingToken']);
    final paymentReference = safeString(data['paymentReference']);
    final transactionId = safeString(
      data['transactionId'],
      int.tryParse(bookingId) == null
          ? '—'
          : 'TP-TXN-${int.parse(bookingId).toString().padLeft(8, '0')}',
    );
    final paymentMethod = safeString(data['paymentMethod']);
    final paymentStatus = safeString(data['paymentStatus']);
    final isPaid =
        paymentStatus == 'paid' ||
        safeString(data['type']) == 'booking_payment_ticket';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 370),
      child: Container(
        key: ValueKey('messages-booking-ticket-$transactionId'),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14192B50),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: messageNavy,
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
                          isBookingRequest
                              ? 'BOOKING REQUEST'
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
                          approved
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
                        label: approved
                            ? 'APPROVED'
                            : isBookingRequest
                            ? 'PENDING REVIEW'
                            : 'PENDING APPROVAL',
                        approved: approved,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    venueName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
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
                     localize: true,),
                    if (fitnessCoachName.isNotEmpty)
                      AppText(
                        'Coach: $fitnessCoachName'
                        '${fitnessCoachDurationMonths == null ? '' : ' · ${fitnessCoachDurationMonths == 1 ? '1 month' : '$fitnessCoachDurationMonths months'}'}'
                        '${fitnessCoachPrice == null ? '' : ' · PHP ${fitnessCoachPrice.toStringAsFixed(2)}'}',
                        style: TextStyle(
                          color: messageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                       localize: true,),
                    if (fitnessPlanPrice != null)
                      AppText(
                        'Plan total: PHP ${fitnessPlanPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: messageMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                       localize: true,),
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
                  if (!isFitnessBooking &&
                      (fullStudio || slotNumber.isNotEmpty)) ...[
                    const SizedBox(height: 6),
                    AppText(
                      fullStudio ? 'Whole studio' : 'Slot $slotNumber',
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
                          label: 'START',
                          value: time,
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
                      const SizedBox(width: 6),
                      Expanded(
                        child: _TicketDetail(
                          icon: Icons.timer_outlined,
                          label: 'DURATION',
                          value: '${safeString(data['durationHours'], '—')} hr',
                        ),
                      ),
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
                         localize: true,),
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
                         localize: true,),
                        AppText(
                          'BK-$bookingId',
                          key: const ValueKey('messages-ticket-reference'),
                          style: TextStyle(
                            color: messageNavy,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                         localize: true,),
                        if (approved && ticketCode.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            'TICKET CODE',
                            style: TextStyle(
                              color: messageMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                           localize: true,),
                          AppText(
                            ticketCode,
                            style: TextStyle(
                              color: messageNavy,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (isBookingRequest && bookingToken.isNotEmpty) ...[
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
                        if (!approved)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: AppText(
                              'Valid after venue approval',
                              style: TextStyle(
                                color: messageMuted,
                                fontSize: 10,
                              ),
                             localize: true,),
                          ),
                        if (paymentReference.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          AppText(
                            'Payment ref: $paymentReference',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: messageMuted,
                              fontSize: 9,
                            ),
                           localize: true,),
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
                          'PHP ${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: messageNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (downpayment != null)
                          AppText(
                            'Downpayment: PHP ${downpayment.toStringAsFixed(2)}',
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
  const _TicketStatusPill({required this.label, required this.approved});

  final String label;
  final bool approved;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: approved ? const Color(0xFFE7F6ED) : AppColors.softOrangeAlt,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      label,
      style: TextStyle(
        color: approved ? const Color(0xFF247A43) : messageOrange,
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
