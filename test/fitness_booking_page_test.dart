import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/fitness_booking_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Fitness booking page shows merchant categories, plans, and coach options',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/bookings/availability') {
            return http.Response(jsonEncode({'bookings': []}), 200);
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected request'}),
            404,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FitnessBookingPage(
              api: api,
              business: {
                'id': 7,
                'name': 'Test Fitness',
                'address': '123 Main Street',
                'fitnessCategories': [
                  {
                    'category': 'Yoga',
                    'sessionPrice': 500,
                    'monthlyPrice': 1200,
                    'yearlyPrice': 12000,
                    'yearlyDiscountType': 'percentage',
                    'yearlyDiscountValue': 10,
                  },
                ],
                'fitnessCoaches': [
                  {'name': 'Alex Coach', 'monthlyPrice': 300},
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Fitness'), findsOneWidget);
      expect(find.text('Book Fitness'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsNothing);
      expect(find.text('Yoga'), findsOneWidget);
      final bookingCard = tester.widget<Container>(
        find.byKey(const ValueKey('fitness-booking-summary-card')),
      );
      expect(bookingCard.padding, const EdgeInsets.all(16));
      final bookingCardDecoration = bookingCard.decoration! as BoxDecoration;
      expect(bookingCardDecoration.borderRadius, BorderRadius.circular(18));
      final venueTitle = tester.widget<Text>(find.text('Test Fitness'));
      expect(venueTitle.style?.fontSize, 19);
      expect(venueTitle.style?.fontWeight, FontWeight.w900);
      expect(find.textContaining('Session · PHP 500.00'), findsOneWidget);
      expect(find.textContaining('Monthly · PHP 1200.00'), findsOneWidget);
      expect(find.textContaining('Yearly · PHP 10800.00'), findsOneWidget);
      expect(find.textContaining('Pay · PHP 500.00'), findsOneWidget);
      final yearlyPlan = find.textContaining('Yearly · PHP 10800.00');
      await tester.ensureVisible(yearlyPlan);
      await tester.tap(yearlyPlan);
      await tester.pumpAndSettle();
      expect(find.text('Yearly offer: 10% off'), findsOneWidget);
      expect(find.text('PHP 10800.00'), findsWidgets);
      final coachDropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField &&
            widget.decoration.labelText == 'Coach (optional)',
      );
      await tester.ensureVisible(coachDropdown);
      await tester.tap(coachDropdown);
      await tester.pumpAndSettle();
      expect(find.textContaining('Alex Coach'), findsOneWidget);
    },
  );
}
