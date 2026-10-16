import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_theme.dart';
import 'package:myapp/messages_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('payment ticket shows receipt and pending approval state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_payment_ticket',
            'bookingId': 501,
            'transactionId': 'TP-TXN-00000501',
            'status': 'payment_received',
            'approvalStatus': 'pending',
            'paymentMethod': 'online',
            'paymentStatus': 'paid',
            'venueName': 'Test Basketball Court',
            'sportType': 'Basketball',
            'bookingDate': '2026-10-01',
            'startTime': '09:00:00',
            'durationHours': 2,
            'players': 6,
            'amount': 270,
            'paymentReference': 'pay_test_501',
          }),
        ),
      ),
    );

    expect(find.text('TINKERPRO  ·  COURT PASS'), findsOneWidget);
    expect(find.text('PAYMENT RECEIPT'), findsOneWidget);
    expect(find.text('PAYMENT RECEIVED'), findsOneWidget);
    expect(find.text('PENDING APPROVAL'), findsOneWidget);
    expect(find.text('Test Basketball Court'), findsOneWidget);
    expect(find.text('BK-501'), findsOneWidget);
    expect(find.text('TP-TXN-00000501'), findsOneWidget);
    expect(find.text('\u{20B1} 270.00'), findsOneWidget);
    expect(find.text('TOTAL PAID'), findsOneWidget);
    expect(find.text('Payment ref: pay_test_501'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Request expires in 15 min'), findsNothing);
  });

  testWidgets('approved ticket displays its access code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 501,
            'transactionId': 'TP-TXN-00000501',
            'status': 'approved',
            'ticketCode': 'TP-ACCESS-123',
            'venueName': 'Test Basketball Court',
            'sportType': 'Basketball',
            'bookingDate': '2026-10-01',
            'startTime': '09:00:00',
            'durationHours': 2,
            'players': 6,
          }),
        ),
      ),
    );

    expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('TP-ACCESS-123'), findsOneWidget);
    expect(find.text('TP-TXN-00000501'), findsOneWidget);
    expect(find.text('TICKET CODE'), findsOneWidget);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('messages-booking-ticket-header')),
          )
          .color,
      const Color(0xFF237A43),
    );
  });

  testWidgets('approved online ticket shows amount and payment deadline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 506,
            'transactionId': 'TP-TXN-00000506',
            'status': 'approved',
            'approvalStatus': 'approved',
            'paymentMethod': 'online',
            'paymentStatus': 'unpaid',
            'totalAmount': 500,
            'payableAmount': 500,
            'paymentDueAt': '2026-10-15T10:00:00',
            'ticketCode': 'TP-ACCESS-506',
            'venueName': 'Test Court',
          }),
        ),
      ),
    );

    expect(find.text('PAY ONLINE · 15 MIN'), findsOneWidget);
    expect(find.text('APPROVED · PAYMENT DUE'), findsOneWidget);
    expect(find.text('PAYMENT REQUIRED'), findsOneWidget);
    expect(find.text('PAYMENT DUE'), findsOneWidget);
    expect(find.text('\u{20B1} 500.00'), findsOneWidget);
    expect(find.textContaining('Pay by '), findsOneWidget);
  });

  testWidgets('approved COA ticket shows downpayment deadline and receipt state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 508,
            'transactionId': 'TP-TXN-00000508',
            'status': 'approved',
            'paymentMethod': 'cash_on_arrival',
            'paymentStatus': 'unpaid',
            'totalAmount': 500,
            'payableAmount': 250,
            'paymentDueAt': '2026-10-15T10:00:00',
            'venueName': 'Test Court',
          }),
        ),
      ),
    );

    expect(find.text('DOWNPAYMENT DUE · 15 MIN'), findsOneWidget);
    expect(find.text('APPROVED · PAYMENT DUE'), findsOneWidget);
    expect(find.text('\u{20B1} 250.00'), findsOneWidget);
    expect(find.textContaining('Pay by '), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 508,
            'status': 'approved',
            'approvalStatus': 'approved',
            'paymentMethod': 'cash_on_arrival',
            'paymentStatus': 'partial',
            'paymentProvider': 'maya',
            'totalAmount': 500,
            'payableAmount': 250,
            'paymentReference': 'PROTOTYPE-508-123',
            'venueName': 'Test Court',
          }),
        ),
      ),
    );
    expect(find.text('DOWNPAYMENT RECEIPT'), findsNothing);
    expect(find.text('DOWNPAYMENT RECEIVED'), findsWidgets);
    expect(find.text('APPROVED · DOWNPAYMENT RECEIVED'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('Demo payment method: Maya'), findsOneWidget);
    expect(find.text('Request expires in 15 min'), findsNothing);
    expect(find.text('COA AFTER APPROVAL'), findsNothing);
    expect(find.text('Payment ref: PROTOTYPE-508-123'), findsOneWidget);
  });

  testWidgets('expired online payment renders an identifiable expired ticket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 507,
            'transactionId': 'TP-TXN-00000507',
            'status': 'payment_expired',
            'approvalStatus': 'payment_expired',
            'paymentMethod': 'online',
            'paymentStatus': 'unpaid',
            'totalAmount': 500,
            'payableAmount': 500,
            'venueName': 'Test Court',
          }),
        ),
      ),
    );

    expect(find.text('PAYMENT WINDOW ENDED'), findsWidgets);
    expect(
      find.text(
        'The reservation expired because payment was not received within 15 minutes after approval.',
      ),
      findsOneWidget,
    );
    expect(find.text('TP-TXN-00000507'), findsOneWidget);
    expect(find.text('BK-507'), findsOneWidget);
  });

  testWidgets('request ticket remains separate from the approval ticket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 505,
            'status': 'pending',
            'paymentMethod': 'cash_on_arrival',
            'venueName': 'Test Court',
          }),
        ),
      ),
    );

    expect(find.text('BOOKING SUBMITTED'), findsOneWidget);
    expect(find.text('BOOKING CONFIRMED'), findsNothing);
    expect(find.text('PENDING REVIEW'), findsOneWidget);
    expect(find.text('Request expires in 15 min'), findsOneWidget);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('messages-booking-ticket-header')),
          )
          .color,
      const Color(0xFFB45309),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 505,
            'status': 'expired',
            'approvalStatus': 'expired',
            'paymentMethod': 'online',
            'paymentStatus': 'paid',
            'bookingToken': 'expired-token',
            'venueName': 'Test Court',
          }),
        ),
      ),
    );

    expect(find.text('BOOKING REQUEST EXPIRED'), findsWidgets);
    expect(find.text('EXPIRED'), findsOneWidget);
    expect(find.text('expired-token'), findsNothing);
    expect(find.text('Request expires in 15 min'), findsNothing);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('messages-booking-ticket-header')),
          )
          .color,
      const Color(0xFFB42318),
    );
  });

  testWidgets('legacy request ticket never renders as an approval ticket', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 505,
            'status': 'approved',
            'approvalStatus': 'approved',
            'paymentMethod': 'cash_on_arrival',
            'venueName': 'Test Court',
          }),
        ),
      ),
    );

    expect(find.text('BOOKING REQUEST'), findsOneWidget);
    expect(find.text('BOOKING SUBMITTED'), findsOneWidget);
    expect(find.text('PENDING REVIEW'), findsOneWidget);
    expect(find.text('BOOKING CONFIRMED'), findsNothing);
    expect(find.text('APPROVED'), findsNothing);
  });

  testWidgets('booking request ticket shows its transaction and unique token', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 504,
            'transactionId': 'TP-TXN-00000504',
            'bookingToken': 'TP-BOOKING-TOKEN-504',
            'status': 'pending',
            'businessType': 'Sports',
            'venueName': 'Test Court',
            'sportType': 'Basketball',
            'bookingDate': '2026-10-08',
            'startTime': '09:00:00',
            'durationHours': 1,
            'players': 2,
            'slotNumbers': [2, 3],
            'total': 500,
            'payableAmount': 250,
            'downpayment': 250,
            'paymentMethod': 'cash_on_arrival',
            'paymentStatus': 'unpaid',
          }),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('messages-booking-ticket-TP-TXN-00000504')),
      findsOneWidget,
    );
    expect(find.text('BOOKING REQUEST'), findsOneWidget);
    expect(find.text('PENDING REVIEW'), findsOneWidget);
    expect(find.text('TP-TXN-00000504'), findsOneWidget);
    expect(find.text('TP-BOOKING-TOKEN-504'), findsOneWidget);
    expect(find.text('Slots 2, 3'), findsOneWidget);
    expect(find.text('\u{20B1} 250.00'), findsOneWidget);
    expect(find.text('COA AFTER APPROVAL'), findsOneWidget);
    expect(find.text('Downpayment: \u{20B1} 250.00'), findsOneWidget);
    expect(find.text('Request expires in 15 min'), findsOneWidget);
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('messages-booking-ticket-header')),
          )
          .color,
      const Color(0xFFB45309),
    );
  });

  testWidgets('Fitness ticket displays the selected term and coach', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 502,
            'status': 'approved',
            'ticketCode': 'TP-FITNESS-502',
            'venueName': 'Yoga Studio',
            'sportType': 'Yoga',
            'fitnessPlanType': 'yearly',
            'fitnessCategory': 'Yoga',
            'fitnessCoachName': 'Alex Coach',
            'fitnessCoachDurationMonths': 3,
            'fitnessPlanPrice': 10800,
            'fitnessCoachPrice': 3600,
            'bookingDate': '2026-10-01',
            'startTime': '09:00:00',
            'durationHours': 1,
            'players': 1,
          }),
        ),
      ),
    );

    expect(find.text('TINKERPRO  ·  FITNESS PASS'), findsOneWidget);
    expect(find.text('Yoga · Yearly plan'), findsOneWidget);
    expect(find.textContaining('Alex Coach'), findsOneWidget);
    expect(find.textContaining('3 months'), findsOneWidget);
    expect(find.text('Plan total: \u{20B1} 10800.00'), findsOneWidget);
    expect(find.text('DURATION'), findsNothing);
    expect(find.text('1 hr'), findsNothing);
    expect(find.text('Whole studio'), findsNothing);
  });

  testWidgets('Event ticket uses the Event receipt branding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_payment_ticket',
            'bookingId': 503,
            'transactionId': 'TP-TXN-00000503',
            'businessType': 'Event',
            'status': 'payment_received',
            'venueName': 'Grand Event Hall',
            'bookingDate': '2026-10-01',
            'startTime': '07:00:00',
            'durationHours': 15,
            'players': 120,
            'amount': 25000,
          }),
        ),
      ),
    );

    expect(find.text('TINKERPRO  ·  EVENT PASS'), findsOneWidget);
    expect(find.text('PAYMENT RECEIPT'), findsOneWidget);
    expect(find.text('TP-TXN-00000503'), findsOneWidget);
    expect(find.text('\u{20B1} 25000.00'), findsOneWidget);
    expect(find.text('VENUE HOURS'), findsOneWidget);
    expect(find.text('7:00 AM - 10:00 PM'), findsOneWidget);
    expect(find.text('DURATION'), findsNothing);
    expect(find.text('TINKERPRO  ·  COURT PASS'), findsNothing);
  });

  testWidgets('booking request displays its actual Event venue name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 504,
            'businessType': 'Event',
            'eventType': 'Wedding',
            'status': 'pending',
            'venueName': 'exc wall',
            'bookingDate': '2026-11-04',
            'startTime': '19:00:00',
            'durationHours': 5,
            'players': 500,
            'total': 20000,
            'downpayment': 10000,
          }),
        ),
      ),
    );

    expect(find.text('TINKERPRO  ·  EVENT PASS'), findsOneWidget);
    expect(find.text('exc wall'), findsOneWidget);
    expect(find.text('Wedding'), findsOneWidget);
    expect(find.text('Sports venue'), findsNothing);
  });

  testWidgets('missing venue name is not shown as a fake Sports venue', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 505,
            'businessType': 'Event',
            'status': 'pending',
          }),
        ),
      ),
    );

    expect(find.text('Venue name unavailable'), findsOneWidget);
    expect(find.text('Sports venue'), findsNothing);
  });

  testWidgets('booking ticket header remains readable in dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.orange,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: true,
          accentColor: AppPalette.orange.color,
        ),
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking',
            'bookingId': 601,
            'transactionId': 'TP-TXN-00000601',
            'status': 'pending',
            'venueName': 'Dark Mode Court',
            'sportType': 'Basketball',
            'total': 500,
          }),
        ),
      ),
    );

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('messages-booking-ticket-header')),
    );
    expect(header.color, const Color(0xFFB45309));
    expect(find.text('TINKERPRO  ·  COURT PASS'), findsOneWidget);
    final headerTitle = tester.widget<Text>(
      find.text('TINKERPRO  ·  COURT PASS'),
    );
    expect(headerTitle.style?.color, Colors.white);
  });
}
