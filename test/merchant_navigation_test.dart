import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_bottom_navigation.dart';

void main() {
  testWidgets('merchant navigation includes analytics and business tabs', (
    tester,
  ) async {
    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            merchantMode: true,
            hideMerchantVenues: true,
            selectedIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    final navigationTheme = tester.widget<Theme>(
      find
          .ancestor(
            of: find.byType(NavigationBar),
            matching: find.byType(Theme),
          )
          .first,
    );
    final labelTextStyle =
        navigationTheme.data.navigationBarTheme.labelTextStyle!;
    final unselectedStyle = labelTextStyle.resolve({});
    final selectedStyle = labelTextStyle.resolve({WidgetState.selected});
    expect(unselectedStyle?.fontSize, 12);
    expect(selectedStyle?.fontSize, 12);
    expect(unselectedStyle?.fontWeight, FontWeight.w700);
    expect(selectedStyle?.fontWeight, FontWeight.w700);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).height, 72);

    await tester.tap(find.text('Payouts'));
    expect(selectedIndex, 3);
  });
}
