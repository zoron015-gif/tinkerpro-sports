import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/all_venues_page.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/fitness_dashboard.dart';
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

  testWidgets('venue feed cards use a denser image and post summary', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('news-feed-card-business-42'));
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('news-feed-image-business-42')))
          .height,
      160,
    );
    expect(tester.widget<Text>(find.text('Court updates').first).maxLines, 2);
    expect(tester.takeException(), isNull);
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
    final venue = {...venues.first, 'latitude': 10.3157, 'longitude': 123.8854};
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
      tester
          .widget<MessagesDashboardPage>(find.byType(MessagesDashboardPage))
          .initialUserPosition,
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

  testWidgets('Fitness venue route opens its configured booking plans', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    final post = {
      'businessId': 77,
      'businessName': 'Yoga Studio',
      'businessType': 'Fitness & Wellness',
      'category': 'Yoga',
      'address': 'Cebu City',
      'facilityType': 'Fitness Studio',
      'hours': '7:00 AM - 9:00 PM',
      'availability': 'Open daily',
      'details': 'Yoga studio with beginner and advanced classes.',
      'tags': ['Parking', 'Changing room'],
      'ownerName': 'Alex Merchant',
      'enabled': true,
      'title': 'Yoga classes now open',
      'body': 'Book a visit',
    };
    final business = {
      'id': 77,
      'name': 'Yoga Studio',
      'businessType': 'Fitness & Wellness',
      'category': 'Yoga',
      'address': 'Cebu City',
      'facilityType': 'Fitness Studio',
      'hours': '7:00 AM - 9:00 PM',
      'availability': 'Open daily',
      'details': 'Yoga studio with beginner and advanced classes.',
      'tags': ['Parking', 'Changing room'],
      'ownerName': 'Alex Merchant',
      'enabled': true,
      'fitnessCategories': [
        {
          'category': 'Yoga',
          'sessionPrice': 500,
          'monthlyPrice': 1200,
          'yearlyPrice': 12000,
          'yearlyDiscountType': 'none',
        },
      ],
      'fitnessCoaches': <Map<String, dynamic>>[],
    };
    final testApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [post],
            }),
            200,
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [business],
            }),
            200,
          );
        }
        if (request.url.path == '/api/bookings/availability') {
          return http.Response(jsonEncode({'bookings': []}), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: FitnessDashboardPage(api: testApi)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yoga Studio'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('news-feed-mini-business-77')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sports-venue-title')), findsOneWidget);
    expect(find.text('Yoga Studio'), findsOneWidget);
    expect(find.text('Cebu City'), findsWidgets);
    expect(find.text('7:00 AM - 9:00 PM'), findsOneWidget);
    expect(find.text('Open daily'), findsOneWidget);
    expect(find.text('FITNESS AMENITIES'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('PHP 500.00 / session'), findsWidgets);
    expect(find.text('Hosted by merchant'), findsOneWidget);
    expect(find.text('Alex Merchant'), findsOneWidget);

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    expect(find.text('Book Fitness'), findsOneWidget);
    expect(find.text('FITNESS CONFIGURATION'), findsOneWidget);
    expect(find.textContaining('Session · PHP 500.00'), findsOneWidget);
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

  testWidgets('Sports News Feed retains its default discovery labels', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    expect(find.text('Sports Courts'), findsOneWidget);
    expect(find.text('Most popular'), findsOneWidget);
    expect(find.text('Highest rate'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('All listed courts'),
      180,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('All listed courts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(find.text('SPORT TYPE'), findsOneWidget);
    expect(find.text('COURT TYPE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('news-feed-filter-sport-All sports')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Fitness discovery filters by business type, maps real venues, and reuses feed filters',
    (tester) async {
      final fitnessPosts = [
        {
          'businessId': 71,
          'businessName': 'Pilates Studio',
          'businessType': 'Fitness & Wellness',
          'category': 'Pilates',
          'address': 'Cebu City',
          'facilityType': 'Indoor',
          'pricePerHour': 450,
          'enabled': true,
          'reviewCount': 5,
          'averageRating': 4.8,
          'heartCount': 3,
          'heartedByMe': false,
          'title': 'New reformer classes',
          'body': 'Try a new class this week.',
          'latitude': 10.325,
          'longitude': 123.901,
        },
        {
          'businessId': 72,
          'businessName': 'Yoga Wellness',
          'businessType': 'Wellness',
          'category': 'Yoga',
          'address': 'Mandaue City',
          'facilityType': 'Studio',
          'pricePerHour': 300,
          'enabled': true,
          'reviewCount': 2,
          'averageRating': 4.6,
          'heartCount': 1,
          'heartedByMe': false,
          'title': 'Morning yoga',
          'body': 'Join the sunrise session.',
          'latitude': 10.333,
          'longitude': 123.912,
        },
        {
          ...venues.first,
          'businessId': 73,
          'businessName': 'Basketball court',
          'businessType': 'Sports',
        },
      ];
      String? heartRequestMethod;
      final fitnessApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') {
            return http.Response(
              jsonEncode({'posts': fitnessPosts}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({
                'businesses': [
                  {
                    'id': 71,
                    'name': 'Pilates Studio',
                    'businessType': 'Fitness & Wellness',
                    'enabled': true,
                    'latitude': 10.325,
                    'longitude': 123.901,
                  },
                  {
                    'id': 72,
                    'name': 'Yoga Wellness',
                    'businessType': 'Wellness',
                    'enabled': true,
                    'latitude': 10.333,
                    'longitude': 123.912,
                  },
                  {
                    'id': 73,
                    'name': 'Basketball court',
                    'businessType': 'Sports',
                    'enabled': true,
                    'latitude': 10.3157,
                    'longitude': 123.8854,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/businesses/71/heart') {
            heartRequestMethod = request.method;
            return http.Response(
              jsonEncode({'heartCount': 4, 'heartedByMe': true}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 200);
        }),
      );
      final customerPosition = Position(
        longitude: 123.89,
        latitude: 10.31,
        timestamp: DateTime(2026),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitnessDashboardPage(
            api: fitnessApi,
            initialUserPosition: customerPosition,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
      expect(feed.businessType, 'Fitness');
      expect(feed.savedItemType, 'fitness');
      expect(feed.savedOnly, isFalse);
      expect(find.text('Fitness & Wellness'), findsOneWidget);
      expect(find.text('Most popular'), findsOneWidget);
      expect(find.text('Highest rated'), findsOneWidget);
      expect(find.text('Pilates Studio'), findsWidgets);
      expect(find.text('Yoga Wellness'), findsWidgets);
      expect(find.text('Basketball court'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('news-feed-nav-saved')));
      await tester.pumpAndSettle();
      expect(find.text('Saved venues'), findsOneWidget);
      final savedFeed = tester
          .widgetList<NewsFeedPage>(find.byType(NewsFeedPage))
          .last;
      expect(savedFeed.savedItemType, 'fitness');
      expect(savedFeed.savedOnly, isTrue);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('All venues'),
        180,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('All venues'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('news-feed-toggle-court-map')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 venues on map'), findsOneWidget);
      expect(
        tester
            .widgetList<MarkerLayer>(find.byType(MarkerLayer))
            .expand((layer) => layer.markers),
        hasLength(3),
      );

      await tester.tap(
        find.byKey(const ValueKey('news-feed-toggle-court-map')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('FITNESS TYPE'), findsOneWidget);
      expect(find.text('FACILITY TYPE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('news-feed-filter-sport-Pilates')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('news-feed-filter-sport-Pilates')),
      );
      await tester.tap(find.byKey(const ValueKey('news-feed-filter-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Pilates Studio'), findsWidgets);
      expect(find.text('Yoga Wellness'), findsNothing);

      await tester.drag(
        find.byKey(const ValueKey('news-feed-content-list')),
        const Offset(0, 1200),
      );
      await tester.pumpAndSettle();
      final heart = find
          .byKey(const ValueKey('news-feed-mini-heart-business-71'))
          .first;
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(heartRequestMethod, 'PUT');
      expect(
        find.byKey(const ValueKey('news-feed-mini-heart-count-business-71')),
        findsWidgets,
      );
      final seeAll = find.byKey(
        const ValueKey('news-feed-see-all-most-popular'),
      );
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AllVenuesPage>(find.byType(AllVenuesPage))
            .any(
              (page) => identical(page.initialUserPosition, customerPosition),
            ),
        isTrue,
      );
      expect(
        find.text('Fitness & Wellness venues with the most hearts'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('all-venues-open-filters')));
      await tester.pumpAndSettle();
      expect(find.text('FITNESS TYPE'), findsOneWidget);
      expect(find.text('FACILITY TYPE'), findsOneWidget);
    },
  );
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
    super.didPush(route, previousRoute);
  }
}
