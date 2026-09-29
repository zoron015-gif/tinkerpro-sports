import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/all_venues_page.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/messages_dashboard.dart';
import 'package:myapp/news_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final venues = [
    {
      'businessId': 42,
      'businessName': 'Basketball court',
      'businessType': 'Sports',
      'category': 'Basketball',
      'address': 'Cebu City',
      'facilityType': 'Indoor',
      'pricePerHour': 200,
      'enabled': true,
      'reviewCount': 5,
      'averageRating': 4.6,
      'heartCount': 9,
      'heartedByMe': false,
      'title': 'Basketball news',
      'body': 'Court updates',
    },
    {
      'businessId': 43,
      'businessName': 'Tennis court',
      'businessType': 'Sports',
      'category': 'Tennis',
      'address': 'Manila',
      'facilityType': 'Outdoor',
      'pricePerHour': 500,
      'enabled': true,
      'reviewCount': 2,
      'averageRating': 4.9,
      'heartCount': 2,
      'heartedByMe': false,
      'title': 'Tennis news',
      'body': 'Court updates',
    },
  ];

  AuthApi api() => AuthApi(
    client: MockClient((request) async {
      if (request.url.path == '/api/news-feed') {
        return http.Response(
          jsonEncode({'posts': venues}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/businesses') {
        return http.Response(
          jsonEncode({
            'businesses': [
              {'id': 42, 'enabled': true},
              {'id': 43, 'enabled': true},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    }),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
  });

  testWidgets('News Feed filters open from the right and show active count', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Filter venues'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('filter-panel-surface'))).width,
      440,
    );
    expect(tester.widget<Text>(find.text('Filter venues')).style?.fontSize, 20);
    expect(
      find.byKey(const ValueKey('news-feed-filter-sport-Basketball')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('news-feed-filter-sport-Basketball')),
    );
    await tester.tap(find.byKey(const ValueKey('news-feed-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.text('Basketball court'), findsWidgets);
    expect(find.text('Tennis court'), findsNothing);
    final filterBadge = tester.widget<Badge>(find.byType(Badge).first);
    expect(filterBadge.isLabelVisible, isTrue);
    expect(find.byTooltip('Filter venues (1 active)'), findsOneWidget);
  });

  testWidgets(
    'location filter remains enabled when switching to Saved and back',
    (tester) async {
      final position = Position(
        longitude: 123.8854,
        latitude: 10.3157,
        timestamp: DateTime(2026),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NewsFeedPage(api: api(), initialUserPosition: position),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('news-feed-nav-saved')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Using my location · nearest first'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('news-feed-filter-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Using my location · nearest first'), findsOneWidget);
    },
  );

  testWidgets('location remains enabled when switching to Messages and back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    final venue = {
      ...venues.first,
      'latitude': 10.3157,
      'longitude': 123.8854,
    };
    final testApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({'posts': [venue]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'id': 42, 'enabled': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final position = Position(
      longitude: 123.8854,
      latitude: 10.3157,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedPage(api: testApi, initialUserPosition: position),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesDashboardPage), findsOneWidget);
    expect(
      tester.widget<MessagesDashboardPage>(
        find.byType(MessagesDashboardPage),
      ).initialUserPosition,
      position,
    );

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();
    expect(find.text('0.0 km away'), findsWidgets);
  });

  testWidgets(
    'venue hearts update counts and separate popularity from rating',
    (tester) async {
      String? heartMethod;
      String? heartPath;
      final heartApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') {
            return http.Response(
              jsonEncode({'posts': venues}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({
                'businesses': [
                  {'id': 42, 'enabled': true},
                  {'id': 43, 'enabled': true},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          heartMethod = request.method;
          heartPath = request.url.path;
          return http.Response(
            jsonEncode({'heartCount': 10, 'heartedByMe': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: heartApi)));
      await tester.pumpAndSettle();

      final popularBasketball = find.byKey(
        const ValueKey('news-feed-most-popular-card-business-42'),
      );
      final highestTennis = find.byKey(
        const ValueKey('news-feed-highest-rate-card-business-43'),
      );
      final popularTennis = find.byKey(
        const ValueKey('news-feed-most-popular-card-business-43'),
      );
      final highestBasketball = find.byKey(
        const ValueKey('news-feed-highest-rate-card-business-42'),
      );
      expect(popularBasketball, findsOneWidget);
      expect(highestTennis, findsOneWidget);
      expect(
        tester.getTopLeft(popularBasketball).dx,
        lessThan(tester.getTopLeft(popularTennis).dx),
      );
      expect(
        tester.getTopLeft(highestTennis).dx,
        lessThan(tester.getTopLeft(highestBasketball).dx),
      );

      final miniHeart = find
          .byKey(const ValueKey('news-feed-mini-heart-business-42'))
          .first;
      await tester.ensureVisible(miniHeart);
      await tester.tap(miniHeart);
      await tester.pumpAndSettle();

      expect(heartMethod, 'PUT');
      expect(heartPath, '/api/businesses/42/heart');
      expect(
        find.byKey(const ValueKey('news-feed-mini-heart-count-business-42')),
        findsWidgets,
      );
      expect(find.text('10'), findsWidgets);
    },
  );

  testWidgets('opened venue booking card shows location distance and hearts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    final venue = {
      ...venues.first,
      'latitude': 10.3157,
      'longitude': 123.8854,
      'heartCount': 17,
      'heartedByMe': false,
    };
    final testApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [venue],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 42,
                  'enabled': true,
                  'businessType': 'Sports',
                  'pricePerHour': 200,
                  'latitude': 10.3157,
                  'longitude': 123.8854,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final userPosition = Position(
      longitude: 123.8854,
      latitude: 10.3157,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NewsFeedPage(api: testApi, initialUserPosition: userPosition),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('news-feed-mini-business-42')).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sports-venue-distance')), findsOneWidget);
    expect(find.text('0.0 km away'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sports-venue-heart-count')),
      findsOneWidget,
    );
    expect(find.text('17'), findsOneWidget);
    expect(tester.widget<Text>(find.text('17')).style?.fontSize, 16);
    final venueTitle = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-title')),
    );
    final heartCount = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-heart-count')),
    );
    expect((venueTitle.dy - heartCount.dy).abs(), lessThan(8));
  });

  testWidgets('See all slides in from the right and reverses in equal time', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: NewsFeedPage(api: api()),
      ),
    );
    await tester.pumpAndSettle();

    final seeAll = find.byKey(const ValueKey('news-feed-see-all-most-popular'));
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.byType(AllVenuesPage), findsOneWidget);
    final route = observer.lastPushedRoute! as PageRoute<void>;
    expect(route, isA<PageRouteBuilder<void>>());
    expect(route.transitionDuration, const Duration(milliseconds: 320));
    expect(route.reverseTransitionDuration, route.transitionDuration);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sports Courts'), findsOneWidget);
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
