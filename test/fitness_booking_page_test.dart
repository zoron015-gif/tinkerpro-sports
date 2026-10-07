import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_theme.dart';
import 'package:myapp/fitness_booking_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Fitness checkout surfaces and actions follow dark palette', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.blue,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );
    final api = AuthApi(
      client: MockClient((request) async => http.Response('{}', 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.configured(
          darkMode: true,
          accentColor: AppPalette.blue.color,
        ),
        home: Scaffold(
          body: FitnessBookingPage(
            api: api,
            business: {
              'id': 7,
              'name': 'Test Fitness',
              'fitnessCategories': [
                {'category': 'Yoga', 'sessionPrice': 500},
              ],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final summary = tester.widget<Container>(
      find.byKey(const ValueKey('fitness-booking-summary-card')),
    );
    expect((summary.decoration! as BoxDecoration).color, AppColors.darkSurface);
    final action = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pay · PHP 500.00'),
    );
    expect(action.style!.backgroundColor!.resolve({}), AppPalette.blue.color);
    expect(
      tester.widget<Text>(find.text('Test Fitness').first).style!.color,
      AppColors.darkInk,
    );
  });

  testWidgets(
    'Fitness booking page shows merchant categories, plans, and coach options',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      FlutterSecureStorage.setMockInitialValues({
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
                  {
                    'category': 'Pilates',
                    'sessionPrice': 600,
                    'monthlyPrice': 1400,
                    'yearlyPrice': 14000,
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
      expect(find.byIcon(Icons.self_improvement_rounded), findsOneWidget);
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
      await tester.tap(find.textContaining('Alex Coach').last);
      await tester.pumpAndSettle();
      expect(find.text('1 month'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('fitness-coach-duration-increase')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 months'), findsOneWidget);
      expect(find.text('Coach · Alex Coach (2 months)'), findsOneWidget);
      expect(find.text('PHP 600.00'), findsWidgets);
      await tester.tap(
        find.byKey(const ValueKey('fitness-coach-duration-decrease')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 month'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('fitness-coach-duration-decrease')),
            )
            .onPressed,
        isNull,
      );

      final categoryDropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField &&
            widget.decoration.labelText == 'Fitness category',
      );
      await tester.ensureVisible(categoryDropdown);
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilates').last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.accessibility_new_rounded), findsOneWidget);
    },
  );
}
