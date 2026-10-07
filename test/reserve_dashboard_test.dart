import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/reserve_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('booking options fit with minimal scrolling on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    final verticalScrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(verticalScrollable).position;
    expect(position.maxScrollExtent, lessThanOrEqualTo(48));
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('reserve-option-fitness')))
          .dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.text('Continue to Fitness & Wellness')).dy,
      ),
    );
  });

  testWidgets('header and benefit footer stay visible while options scroll', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('Reserve experience'), findsOneWidget);
    expect(find.text('Guaranteed slot'), findsOneWidget);
    expect(find.text('VIP concierge'), findsOneWidget);
    expect(find.text('Flexible changes'), findsOneWidget);
    expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);
    expect(find.text('Reserve experience'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Reserve experience')).dy,
      greaterThan(0),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Guaranteed slot'), findsOneWidget);
    expect(find.text('VIP concierge'), findsOneWidget);
    expect(find.text('Flexible changes'), findsOneWidget);
    expect(find.text('Continue to Fitness & Wellness'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('Reserve experience'), findsOneWidget);
  });

  testWidgets('selecting an experience updates the fixed continue action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReserveDashboardPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sports').first);
    await tester.pumpAndSettle();

    expect(find.text('Continue to Sports'), findsOneWidget);
  });

  testWidgets('booking types and fixed footer adapt to dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.update(
      darkMode: true,
      palette: AppPalette.violet,
    );
    addTearDown(
      () => AppPreferences.instance.update(
        darkMode: false,
        palette: AppPalette.orange,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const ReserveDashboardPage(initialSelection: 'Event'),
      ),
    );
    await tester.pumpAndSettle();

    for (final type in ['Sports', 'Event', 'Fitness & Wellness']) {
      final bookingType = find.byKey(
        ValueKey(
          'reserve-option-${type == 'Fitness & Wellness' ? 'fitness' : type.toLowerCase()}',
        ),
      );
      await tester.ensureVisible(bookingType);
      await tester.pumpAndSettle();
      final option = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('reserve-option-surface-$type')),
      );
      expect(
        (option.decoration! as BoxDecoration).color,
        AppColors.darkSurface,
      );
    }
    final selectedEvent = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('reserve-option-surface-Event')),
    );
    expect(
      ((selectedEvent.decoration! as BoxDecoration).border! as Border)
          .top
          .color,
          AppColors.accentForeground,
    );
    expect(
      tester.widget<Text>(find.text('VIP Banquets & Lounges')).style!.color,
      AppColors.accentForeground,
    );
    final continueButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continue to Event'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      continueButton.style!.backgroundColor!.resolve({}),
      AppPalette.violet.color,
    );

    final footer = tester.widget<Container>(
      find.byKey(const ValueKey('reserve-footer')),
    );
    expect((footer.decoration! as BoxDecoration).color, AppColors.darkSurface);

    expect(
      tester
          .widget<Text>(
            find.text('Instant confirmation · No upfront payment required'),
          )
          .style!
          .color,
      AppColors.darkSuccess,
    );
  });
}
