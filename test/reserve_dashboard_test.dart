import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/reserve_dashboard.dart';

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
}
