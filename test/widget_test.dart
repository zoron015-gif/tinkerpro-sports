// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('overview supports native pull-to-refresh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(find.text('Your sport.\nYour event.\nYour place.'), findsOneWidget);
  });

  testWidgets('Marketplace overview renders the booking experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Your sport.\nYour event.\nYour place.'), findsOneWidget);
    final heroCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-hero-card')),
    );
    expect(
      (heroCard.decoration! as BoxDecoration).color,
      const Color(0xFF192B50),
    );
    expect(
      find.byKey(const ValueKey('assets/book-type/sports.jpg')),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Everything in one place'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Everything in one place'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Explore bookings'),
      -200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Explore bookings'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    final background = tester.widget<Image>(
      find.byKey(const ValueKey('auth-background-image')),
    );
    expect((background.image as AssetImage).assetName, 'assets/bg 1.png');
    expect(background.alignment, Alignment.center);
    final panelFinder = find.byKey(const ValueKey('auth-form-panel'));
    final panel = tester.widget<Container>(panelFinder);
    final panelDecoration = panel.decoration! as BoxDecoration;
    expect(
      tester.getSize(panelFinder).width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(panelDecoration.boxShadow, isNotEmpty);
    expect(
      panelDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(18)),
    );
    expect(
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('auth-content-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .maxScrollExtent,
      lessThanOrEqualTo(1),
    );
    final loginEmailSize = tester.getSize(
      find.byKey(const ValueKey('auth-field-email-address')),
    );
    final loginPasswordSize = tester.getSize(
      find.byKey(const ValueKey('auth-field-password')),
    );
    final loginPrimarySize = tester.getSize(
      find.byKey(const ValueKey('auth-primary-button')),
    );
    final loginSocialSize = tester.getSize(
      find.byKey(const ValueKey('auth-social-button')),
    );
    final loginResetSlotSize = tester.getSize(
      find.byKey(const ValueKey('auth-reset-slot')),
    );

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Merchant'), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('auth-content-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .maxScrollExtent,
      lessThan(270),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-field-email-address'))),
      loginEmailSize,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-field-password'))),
      loginPasswordSize,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-primary-button'))),
      loginPrimarySize,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-social-button'))),
      loginSocialSize,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-reset-slot'))),
      loginResetSlotSize,
    );
    expect(find.text('Continue securely with'), findsOneWidget);

    await tester.tap(find.text('Merchant'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('Marketplace dashboard content remains readable in dark mode', (
    tester,
  ) async {
    await AppPreferences.instance.update(darkMode: true);
    addTearDown(() => AppPreferences.instance.update(darkMode: false));

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Made for the way you play'),
      180,
      scrollable: scrollable,
    );
    expect(
      tester.widget<Text>(find.text('Made for the way you play')).style!.color,
      AppColors.darkInk,
    );

    final featureCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-feature-card-Easy discovery')),
    );
    expect(
      (featureCard.decoration! as BoxDecoration).color,
      AppColors.darkSurface,
    );

    await tester.scrollUntilVisible(
      find.text('Ready to make a plan?'),
      180,
      scrollable: scrollable,
    );
    expect(
      tester.widget<Text>(find.text('Ready to make a plan?')).style!.color,
      AppColors.darkInk,
    );
  });
}
