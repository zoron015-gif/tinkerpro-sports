import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_bottom_navigation.dart';

void main() {
  testWidgets(
    'quickly reselecting a customer tab invokes its refresh callback',
    (tester) async {
      var destinationSelections = 0;
      var reselections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: 0,
              onDestinationSelected: (_) => destinationSelections++,
              onDestinationReselected: () => reselections++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Explore'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Explore'));

      expect(destinationSelections, 1);
      expect(reselections, 1);
    },
  );

  testWidgets('selecting a different customer tab remains normal navigation', (
    tester,
  ) async {
    int? selectedDestination;
    var reselections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (index) => selectedDestination = index,
            onDestinationReselected: () => reselections++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Saved'));

    expect(selectedDestination, 1);
    expect(reselections, 0);
  });
}
