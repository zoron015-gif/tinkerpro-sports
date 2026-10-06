import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/all_venues_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search filters venues and the result list dismisses keyboard on scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AllVenuesPage(
          title: 'Most popular',
          posts: [
            {'businessName': 'Basketball court', 'tags': 'Parking'},
            {'businessName': 'Tennis court', 'tags': 'Store'},
          ],
          cardBuilder: (post) => SizedBox(
            height: 140,
            child: Card(child: Text('${post['businessName']}')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resultList = tester.widget<ListView>(
      find.byKey(const ValueKey('all-venues-list')),
    );
    expect(
      resultList.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    await tester.enterText(
      find.byKey(const ValueKey('all-venues-search')),
      'basketball',
    );
    await tester.pumpAndSettle();
    expect(find.text('Basketball court'), findsOneWidget);
    expect(find.text('Tennis court'), findsNothing);
  });

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

    expect(find.text('Courts with the most hearts'), findsOneWidget);
    expect(find.byKey(const ValueKey('all-venues-search')), findsOneWidget);
    expect(find.text('Browse every venue in this collection.'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('all-venues-info')));
    await tester.pumpAndSettle();
    expect(find.text('Browse every venue in this collection.'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('all-venues-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courts with the most hearts'), findsNothing);
    expect(find.byKey(const ValueKey('all-venues-search')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('all-venues-list')),
      const Offset(0, 5000),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courts with the most hearts'), findsOneWidget);
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
      await tester.pump();
      final drawerHeader = tester.getTopLeft(find.text('Filter venues'));
      expect(drawerHeader.dx, greaterThan(0));
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
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(find.byTooltip('Filter venues (1 active)'), findsOneWidget);
    });
  }

  testWidgets('All Venues filter slides in from the right for 300ms', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: AllVenuesPage(
          title: 'Most popular',
          posts: const [],
          cardBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('all-venues-open-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filter venues'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('filter-panel-surface'))).width,
      440,
    );
    expect(tester.widget<Text>(find.text('Filter venues')).style?.fontSize, 20);
    final route = observer.lastPushedRoute! as RawDialogRoute<void>;
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, route.transitionDuration);

    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filter venues'), findsNothing);
  });
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}
