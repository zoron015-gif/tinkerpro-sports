import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
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
    expect(find.text('Valid after venue approval'), findsOneWidget);
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
            'total': 500,
            'downpayment': 250,
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
    expect(find.text('\u{20B1} 500.00'), findsOneWidget);
    expect(find.text('Downpayment: \u{20B1} 250.00'), findsOneWidget);
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
            'startTime': '18:00:00',
            'durationHours': 4,
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
    expect(find.text('TINKERPRO  ·  COURT PASS'), findsNothing);
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
    expect(header.color, AppColors.navy);
    expect(find.text('TINKERPRO  ·  COURT PASS'), findsOneWidget);
    final headerTitle = tester.widget<Text>(
      find.text('TINKERPRO  ·  COURT PASS'),
    );
    expect(headerTitle.style?.color, Colors.white);
  });
}
