// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('Marketplace overview renders the booking experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Your sport.\nYour event.\nYour place.'), findsOneWidget);
    expect(find.text('Everything in one place'), findsOneWidget);
    await tester.tap(find.text('Explore bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your sport'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Sports and events'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Merchant'), findsOneWidget);
    await tester.tap(find.text('Merchant'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
  });
}
