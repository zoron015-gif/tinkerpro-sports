import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/all_venues_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('All Venues header collapses while search stays pinned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AllVenuesPage(
          title: 'Most popular',
          posts: [
            for (var index = 0; index < 12; index++)
              {'businessName': 'Venue $index'},
          ],
          cardBuilder: (post) => SizedBox(
            height: 140,
            child: Card(child: Text('${post['businessName']}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Popular courts near you'), findsOneWidget);
    expect(find.byKey(const ValueKey('all-venues-search')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('all-venues-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Popular courts near you'), findsNothing);
    expect(find.byKey(const ValueKey('all-venues-search')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('all-venues-list')),
      const Offset(0, 5000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Popular courts near you'), findsOneWidget);
    expect(find.byKey(const ValueKey('all-venues-search')), findsOneWidget);
  });

  for (final title in ['Most popular', 'Highest rate']) {
    testWidgets('$title See all page applies News Feed filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AllVenuesPage(
            title: title,
            posts: [
              {
                'businessName': 'Basketball court',
                'category': 'Basketball',
                'address': 'Cebu City',
                'facilityType': 'Indoor',
                'pricePerHour': 200,
                'tags': 'Parking, Restroom',
                'hours': 'Open 24 hours',
              },
              {
                'businessName': 'Tennis court',
                'category': 'Tennis',
                'address': 'Manila',
                'facilityType': 'Outdoor',
                'pricePerHour': 500,
                'tags': 'Store',
                'hours': '9:00 AM - 5:00 PM',
              },
            ],
            cardBuilder: (post) => SizedBox(
              height: 120,
              child: Card(child: Text('${post['businessName']}')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Basketball court'), findsOneWidget);
      expect(find.text('Tennis court'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('all-venues-open-filters')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('all-venues-filter-sport-Basketball')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('all-venues-filter-court-Indoor')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('all-venues-filter-sport-Basketball')),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('all-venues-filter-amenity-Parking')),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('all-venues-filter-amenity-Parking')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('all-venues-filter-price')),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('all-venues-filter-price')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('all-venues-filter-apply')));
      await tester.pumpAndSettle();

      expect(find.text('Basketball court'), findsOneWidget);
      expect(find.text('Tennis court'), findsNothing);
    });
  }
}
