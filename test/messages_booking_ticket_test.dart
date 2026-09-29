import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/messages_ui.dart';

void main() {
  testWidgets('payment ticket shows receipt and pending approval state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_payment_ticket',
            'bookingId': 501,
            'status': 'payment_received',
            'approvalStatus': 'pending',
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
    expect(find.text('PAYMENT RECEIVED'), findsOneWidget);
    expect(find.text('PENDING APPROVAL'), findsOneWidget);
    expect(find.text('Test Basketball Court'), findsOneWidget);
    expect(find.text('BK-501'), findsOneWidget);
    expect(find.text('PHP 270.00'), findsOneWidget);
    expect(find.text('Valid after venue approval'), findsOneWidget);
  });

  testWidgets('approved ticket displays its access code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagesBookingTicket({
            'type': 'booking_ticket',
            'bookingId': 501,
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
    expect(find.text('TICKET CODE'), findsOneWidget);
  });
}
