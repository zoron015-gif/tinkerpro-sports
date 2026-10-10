import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/all_venues_page.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/customer_bookings_page.dart';
import 'package:myapp/event_dashboard.dart';
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
    FlutterSecureStorage.setMockInitialValues({'session_api_token': 'test-token'});
  });

  testWidgets('News Feed and Saved skeletons fit a narrow phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> verifyLoadingSkeleton({required bool savedOnly}) async {
      final delayedFeed = Completer<http.Response>();
      final loadingApi = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') return delayedFeed.future;
          if (request.url.path == '/api/businesses') {
            return http.Response(
              jsonEncode({'businesses': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/customer/venue-hearts') {
            return http.Response('{}', 404);
          }
          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewsFeedPage(api: loadingApi, savedOnly: savedOnly),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('news-feed-loading-skeleton')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      delayedFeed.complete(
        http.Response(
          jsonEncode({'posts': []}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    }

    await verifyLoadingSkeleton(savedOnly: false);
    await verifyLoadingSkeleton(savedOnly: true);
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

  testWidgets('empty venue search offers a clear-search action', (tester) async {
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: api())));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('news-feed-search')),
      'no matching venue',
    );
    await tester.pumpAndSettle();
    expect(find.text('No courts match your search.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('news-feed-clear-search-and-filters')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('news-feed-clear-search-and-filters')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basketball court'), findsWidgets);
    expect(find.text('Tennis court'), findsWidgets);
  });

  testWidgets('Event dashboard uses the shared Event-only feed cards', (
    tester,
  ) async {
    final requests = <String>[];
    final submittedReviews = <Map<String, dynamic>>[];
    final eventApi = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/news-feed') {
          fail('Event dashboard must not depend on the News Feed endpoint');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 88,
                  'businessType': 'Event',
                  'name': 'Cebu Event Hall',
                  'category': 'Garden',
                  'eventTypes': ['Wedding', 'Birthday'],
                  'address': 'Cebu City',
                  'facilityType': 'Garden venue',
                  'details': 'Bring your own decorations.',
                  'eventFee': 1200,
                  'enabled': true,
                  'reviewCount': 3,
                  'averageRating': 4.7,
                  'ratingUserCount': 3,
                  'heartCount': 6,
                },
                {
                  'id': 89,
                  'businessType': 'Sports',
                  'name': 'Sports Court',
                  'enabled': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'businessId': 88},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/bookings') {
          return http.Response(
            jsonEncode({
              'bookings': [
                {
                  'id': 180,
                  'venueId': 88,
                  'venueName': 'Cebu Event Hall',
                  'businessType': 'Event',
                  'eventType': 'Wedding',
                  'status': 'finished',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses/88/heart') {
          return http.Response(
            jsonEncode({
              'heartCount': request.method == 'DELETE' ? 5 : 7,
              'heartedByMe': request.method != 'DELETE',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (
          request.url.path == '/api/news-feed/88/reviews' &&
          request.method == 'GET'
        ) {
          return http.Response(
            jsonEncode({'reviews': submittedReviews}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/news-feed/88/reviews' &&
            request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          submittedReviews.add({
            'id': 1,
            'customerId': 42,
            'rating': payload['rating'],
            'comment': payload['comment'],
            'firstName': 'Event',
            'lastName': 'Guest',
          });

          return http.Response(
            jsonEncode({'review': submittedReviews.last}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: EventDashboardPage(api: eventApi)),
    );
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Event');
    expect(feed.savedItemType, 'event');
    expect(feed.pageTitle, 'Event Venues');
    expect(find.text('Cebu Event Hall'), findsWidgets);
    expect(find.text('Wedding, Birthday'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('news-feed-open-filters')));
    await tester.pumpAndSettle();
    expect(find.text('EVENT TYPE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('news-feed-filter-sport-Wedding')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('news-feed-filter-close')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('All listed event venues'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('news-feed-save-business-88')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('news-feed-heart-business-88')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('news-feed-reviews-business-88')),
      findsOneWidget,
    );
    expect(find.text('Review'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('news-feed-heart-business-88')),
          )
          .tooltip,
      'Remove heart',
    );

    await tester.drag(
      find.byKey(const ValueKey('news-feed-content-list')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    final heartButton = find.byKey(
      const ValueKey('news-feed-heart-business-88'),
    );
    await tester.ensureVisible(heartButton);
    await tester.tap(heartButton);
    await tester.pumpAndSettle();
    expect(requests, contains('DELETE /api/businesses/88/heart'));
    expect(
      find.byKey(const ValueKey('news-feed-heart-count-business-88')),
      findsOneWidget,
    );
    expect(find.byTooltip('Heart venue'), findsOneWidget);

    final reviewsButton = find.byKey(
      const ValueKey('news-feed-reviews-business-88'),
    );
    await tester.ensureVisible(reviewsButton);
    await tester.tap(reviewsButton);
    await tester.pumpAndSettle();
    expect(requests, contains('GET /api/news-feed/88/reviews'));
    expect(
      find.text('Cebu Event Hall ratings & reviews'),
      findsOneWidget,
    );
    expect(
      find.text('Rate this event venue after your completed booking'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('review-rating-star-4')));
    await tester.enterText(
      find.widgetWithText(TextField, 'Comment'),
      'Great event venue.',
    );
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(requests, contains('POST /api/news-feed/88/reviews'));
    expect(submittedReviews.single['rating'], 4);
    expect(submittedReviews.single['comment'], 'Great event venue.');
    Navigator.of(
      tester.element(find.text('Cebu Event Hall ratings & reviews')),
    ).pop();
    await tester.pumpAndSettle();
    final eventExploreButton = find.byKey(
      const ValueKey('news-feed-explore-business-88'),
    );
    await tester.ensureVisible(eventExploreButton);
    await tester.tap(eventExploreButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sports-venue-content-panel')),
      findsOneWidget,
    );
    final eventContentPanel = tester.widget<Container>(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(
      (eventContentPanel.decoration! as BoxDecoration).boxShadow,
      isNotEmpty,
    );
    expect(find.text('\u{20B1} 1200.00 / event'), findsWidgets);
    expect(find.text('Bring your own decorations.'), findsOneWidget);
    expect(find.text('Reserve event'), findsOneWidget);
    final eventTitle = tester.widget<Text>(
      find.byKey(const ValueKey('sports-venue-title')),
    );
    expect(eventTitle.style?.fontSize, 24);
    expect(eventTitle.style?.fontWeight, FontWeight.w800);

    await tester.tap(find.text('Reserve event'));
    await tester.pumpAndSettle();
    expect(find.text('Book Event'), findsOneWidget);
    expect(find.text('BOOKING CONFIGURATION'), findsOneWidget);
    expect(find.text('Request event booking'), findsNothing);
  });

  testWidgets('Event bookings return to the Event-only Explore feed', (
    tester,
  ) async {
    final requests = <String>[];
    final eventApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/news-feed') {
          fail('Event Explore must not load the sports news feed');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 91,
                  'businessType': 'Event',
                  'name': 'Cebu Event Hall',
                  'eventTypes': ['Wedding'],
                  'enabled': true,
                },
                {
                  'id': 92,
                  'businessType': 'Sports',
                  'name': 'Sports Court',
                  'enabled': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response('{}', 404);
        }
        return http.Response(
          jsonEncode({'bookings': [], 'conversations': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(api: eventApi, businessType: 'Event'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Event');
    expect(feed.savedItemType, 'event');
    expect(feed.pageTitle, 'Event Venues');
    expect(find.text('Cebu Event Hall'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    expect(requests, isNot(contains('/api/news-feed')));
  });

  testWidgets('Fitness bookings return to a Fitness-only Explore feed', (
    tester,
  ) async {
    final requests = <Uri>[];
    final fitnessApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'businessId': 101,
                  'businessName': 'Cebu Yoga Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Yoga',
                  'address': 'Cebu City',
                  'enabled': true,
                  'title': 'Yoga classes',
                  'body': 'Join a class',
                },
                {
                  'businessId': 102,
                  'businessName': 'Sports Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'address': 'Cebu City',
                  'enabled': true,
                  'title': 'Basketball news',
                  'body': 'Court updates',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'id': 101, 'businessType': 'Fitness & Wellness', 'enabled': true},
                {'id': 102, 'businessType': 'Sports', 'enabled': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'bookings': [], 'conversations': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerBookingsPage(
          api: fitnessApi,
          businessType: 'Fitness & Wellness',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Fitness');
    expect(feed.savedItemType, 'fitness');
    expect(feed.pageTitle, 'Fitness & Wellness');
    expect(find.text('Cebu Yoga Studio'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    expect(
      requests
          .where((uri) => uri.path == '/api/news-feed')
          .map((uri) => uri.queryParameters['businessType']),
      ['Fitness'],
    );
  });

  testWidgets('Fitness messages return to a Fitness-only Explore feed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'session_api_token': 'test-token',
      'session_role': 'customer',
    });
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    final requests = <Uri>[];
    final fitnessApi = AuthApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'businessId': 101,
                  'businessName': 'Cebu Yoga Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Yoga',
                  'enabled': true,
                  'title': 'Yoga classes',
                  'body': 'Join a class',
                },
                {
                  'businessId': 102,
                  'businessName': 'Sports Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'enabled': true,
                  'title': 'Basketball news',
                  'body': 'Court updates',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'id': 101, 'businessType': 'Fitness & Wellness', 'enabled': true},
                {'id': 102, 'businessType': 'Sports', 'enabled': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({'user': {'id': 42}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'conversations': [], 'contacts': [], 'bookings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesDashboardPage(
          api: fitnessApi,
          businessType: 'Fitness & Wellness',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('news-feed-nav-explore')));
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Fitness');
    expect(feed.savedItemType, 'fitness');
    expect(find.text('Cebu Yoga Studio'), findsWidgets);
    expect(find.text('Sports Court'), findsNothing);
    expect(
      requests
          .where((uri) => uri.path == '/api/news-feed')
          .map((uri) => uri.queryParameters['businessType']),
      ['Fitness'],
    );
  });

  testWidgets('Event dashboard lists event businesses without news posts', (
    tester,
  ) async {
    final requests = <String>[];
    final eventApi = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path == '/api/news-feed') {
          fail('Event dashboard must not depend on the News Feed endpoint');
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 91,
                  'name': 'Garden Event Place',
                  'businessType': 'Event',
                  'category': 'Garden',
                  'eventTypes': ['Wedding', 'Birthday'],
                  'address': 'Cebu City',
                  'eventFee': 2500,
                  'pricePerHour': 2500,
                  'enabled': true,
                  'averageRating': 0,
                  'reviewCount': 0,
                  'heartCount': 0,
                  'details': 'Outdoor venue for celebrations.',
                },
                {
                  'id': 92,
                  'name': 'Basketball Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'enabled': true,
                },
                {
                  'id': 93,
                  'name': 'Closed Event Garden',
                  'businessType': 'Event',
                  'category': 'Garden',
                  'eventTypes': ['Wedding'],
                  'address': 'Cebu City',
                  'enabled': false,
                  'eventFee': 900,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response('{}', 404);
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: EventDashboardPage(api: eventApi)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Garden Event Place'), findsWidgets);
    expect(find.text('Wedding, Birthday'), findsWidgets);
    expect(find.text('Closed Event Garden'), findsWidgets);
    expect(find.text('UNAVAILABLE · Booking disabled'), findsWidgets);
    expect(find.text('Basketball Court'), findsNothing);
    expect(find.textContaining('Could not load the news feed'), findsNothing);
    expect(find.text('No event venues match your search.'), findsNothing);
    expect(requests, contains('GET /api/businesses'));
    expect(requests, isNot(contains('GET /api/customer/event-businesses')));
    expect(requests, isNot(contains('GET /api/news-feed')));
    final firstEventCard = find.byKey(
      const ValueKey('news-feed-card-business-91'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      firstEventCard,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(firstEventCard, findsOneWidget);
    final firstEventHeart = find.byKey(
      const ValueKey('news-feed-heart-business-91'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      firstEventHeart,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(firstEventHeart, findsOneWidget);
  });

  testWidgets('Event dashboard remains available when heart-state route is missing', (
    tester,
  ) async {
    final eventApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 94,
                  'name': 'Event Garden',
                  'businessType': 'Event',
                  'eventTypes': ['Wedding'],
                  'enabled': true,
                  'heartCount': 2,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response(
            '<!doctype html><html><body>Not Found</body></html>',
            404,
            headers: {'content-type': 'text/html'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: EventDashboardPage(api: eventApi)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Event Garden'), findsWidgets);
    final eventCard = find.byKey(
      const ValueKey('news-feed-card-business-94'),
    );
    await tester.scrollUntilVisible(
      eventCard,
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('news-feed-content-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(eventCard, findsOneWidget);
    expect(find.textContaining('Could not load the news feed'), findsNothing);
  });

  testWidgets('Event popular and highest-rated lists include event fees over 700', (
    tester,
  ) async {
    final eventApi = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {
                  'id': 95,
                  'name': 'Grand Event Hall',
                  'businessType': 'Event',
                  'category': 'Wedding',
                  'eventTypes': ['Wedding'],
                  'eventFee': 2400,
                  'enabled': true,
                  'heartCount': 12,
                  'reviewCount': 4,
                  'averageRating': 4.8,
                  'ratingUserCount': 4,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/customer/venue-hearts') {
          return http.Response(
            jsonEncode({'businesses': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: EventDashboardPage(api: eventApi)),
    );
    await tester.pumpAndSettle();

    for (final key in const [
      'news-feed-see-all-most-popular',
      'news-feed-see-all-highest-rated',
    ]) {
      final seeAll = find.byKey(ValueKey(key));
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      expect(find.text('Grand Event Hall'), findsOneWidget);
      final allVenuesList = find.byKey(const ValueKey('all-venues-list'));
      expect(allVenuesList, findsOneWidget);
      expect(
        find.descendant(
          of: allVenuesList,
          matching: find.byKey(
            const ValueKey('news-feed-card-business-95'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<AllVenuesPage>(find.byType(AllVenuesPage)).priceFilterLabel,
        'Price (\u{20B1} / event)',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('venue feed cards use a denser image and post summary', (
    tester,
  ) async {
    final venue = {
      ...venues.first,
      'imageUrls': [
        'https://example.com/court.jpg',
        'https://example.com/court-2.jpg',
      ],
    };
    final multiImageApi = AuthApi(
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
                {
                  'id': 42,
                  'enabled': true,
                  'imageUrls': venue['imageUrls'],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: NewsFeedPage(api: multiImageApi)));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final section in ['most-popular', 'highest-rate']) {
      final miniCard = find.byKey(
        ValueKey('news-feed-$section-card-business-42'),
      );
      await tester.ensureVisible(miniCard);
      final miniImages = tester
          .widgetList<Image>(
            find.descendant(of: miniCard, matching: find.byType(Image)),
          )
          .toList();
      expect(
        miniImages.any(
          (image) =>
              image.image is NetworkImage &&
              (image.image as NetworkImage).url ==
                  'https://example.com/court.jpg',
        ),
        isTrue,
        reason: '$section should display the merchant gallery image',
      );
    }

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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('news-feed-image-business-42')),
        matching: find.byType(PageView),
      ),
      findsOneWidget,
    );
    for (final image in tester.widgetList<Image>(
      find.descendant(of: card, matching: find.byType(Image)),
    )) {
      expect(image.filterQuality, FilterQuality.high);
    }
    final address = find.descendant(
      of: card,
      matching: find.text('Cebu City'),
    );
    final price = find.descendant(
      of: card,
      matching: find.text('\u{20B1} 200 / hr'),
    );
    expect(address, findsOneWidget);
    expect(price, findsOneWidget);
    expect(
      tester.getTopLeft(price).dx,
      greaterThan(tester.getTopLeft(address).dx),
    );
    expect(
      find.descendant(of: card, matching: find.text('Basketball news')),
      findsNothing,
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
      'details': 'Bring your own equipments',
      'ratePeriods': [
        {'start': '3:53 PM', 'end': '5:53 AM', 'pricePerHour': 200},
      ],
      'imageUrls': [
        'https://example.com/court.jpg',
        'https://example.com/court-2.jpg',
      ],
      'imageUrl': 'https://example.com/court.jpg',
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
                  'imageUrls': [
                    'https://example.com/court.jpg',
                    'https://example.com/court-2.jpg',
                  ],
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

    final heroImage = tester.getSize(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sports-venue-hero-image')),
        matching: find.byType(PageView),
      ),
      findsOneWidget,
    );
    final backButton = tester.getTopLeft(
      find.byIcon(Icons.arrow_back_ios_new_rounded),
    );
    final saveButton = tester.getTopLeft(
      find.byIcon(Icons.bookmark_border_rounded),
    );
    final shareButton = tester.getTopLeft(find.byIcon(Icons.ios_share_rounded));
    expect(backButton.dy, greaterThanOrEqualTo(32));
    expect(saveButton.dy, greaterThanOrEqualTo(32));
    expect(shareButton.dy, greaterThanOrEqualTo(32));
    expect(
      heroImage.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
    expect(
      heroImage.height,
      closeTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.5,
        0.1,
      ),
    );
    final heroBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    final contentTop = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(contentTop.dy - heroBottom.dy, -26);
    final sportsContentPanel = tester.widget<Container>(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(
      (sportsContentPanel.decoration! as BoxDecoration).boxShadow,
      isNotEmpty,
    );
    final imageCountBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-image-count')),
    );
    expect(contentTop.dy - imageCountBottom.dy, 18);
    expect(find.byKey(const ValueKey('sports-venue-distance')), findsOneWidget);
    expect(find.text('0.0 km away'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sports-venue-heart-count')),
      findsOneWidget,
    );
    expect(find.text('17'), findsOneWidget);
    expect(tester.widget<Text>(find.text('17')).style?.fontSize, 16);
    final ratesHeading = find.text('Rates');
    final venueDescription = find.byKey(
      const ValueKey('sports-venue-description'),
    );
    await tester.ensureVisible(venueDescription);
    expect(
      tester.getTopLeft(ratesHeading).dy,
      lessThan(tester.getTopLeft(venueDescription).dy),
    );
    expect(find.text('Bring your own equipments'), findsOneWidget);
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
      'imageUrls': [
        'https://example.com/yoga-studio.jpg',
        'https://example.com/yoga-studio-2.jpg',
      ],
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
    final heroImage = tester.getSize(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    expect(
      heroImage.height,
      closeTo(
        tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.5,
        0.1,
      ),
    );
    final contentTop = tester.getTopLeft(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    final heroBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-hero-image')),
    );
    expect(contentTop.dy - heroBottom.dy, -26);
    final fitnessContentPanel = tester.widget<Container>(
      find.byKey(const ValueKey('sports-venue-content-panel')),
    );
    expect(
      (fitnessContentPanel.decoration! as BoxDecoration).boxShadow,
      isNotEmpty,
    );
    for (final control in [
      Icons.arrow_back_ios_new_rounded,
      Icons.bookmark_border_rounded,
      Icons.ios_share_rounded,
    ]) {
      expect(
        tester.getTopLeft(find.byIcon(control)).dy,
        greaterThanOrEqualTo(32),
      );
    }
    final imageCountBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('sports-venue-image-count')),
    );
    expect(contentTop.dy - imageCountBottom.dy, 18);
    expect(find.text('Yoga Studio'), findsOneWidget);
    expect(find.text('Cebu City'), findsWidgets);
    expect(find.text('7:00 AM - 9:00 PM'), findsOneWidget);
    expect(find.text('Open daily'), findsOneWidget);
    expect(find.text('FITNESS AMENITIES'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('\u{20B1} 500.00 / session'), findsWidgets);
    expect(find.text('Hosted by merchant'), findsOneWidget);
    expect(find.text('Alex Merchant'), findsOneWidget);

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    expect(find.text('Book Fitness'), findsOneWidget);
    expect(find.text('FITNESS CONFIGURATION'), findsOneWidget);
    expect(find.textContaining('Session · \u{20B1} 500.00'), findsOneWidget);
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
    expect(tester.widget<Text>(find.text('Sports Courts')).style?.fontSize, 20);
    expect(
      tester.widget<Text>(find.text('Discover what’s new')).style?.fontSize,
      16,
    );
    expect(
      tester.widget<Text>(find.text('Most popular')).style?.fontSize,
      16,
    );
    expect(
      tester.getTopLeft(find.text('Discover what’s new')).dx,
      closeTo(tester.getTopLeft(find.text('Most popular')).dx, 1),
    );
    expect(
      find.text('Fresh updates, offers, and stories from local venues.'),
      findsNothing,
    );
    expect(
      tester.getTopLeft(
            find.byKey(const ValueKey('news-feed-search-container')),
          ).dy -
          tester.getBottomLeft(
            find.byKey(const ValueKey('news-feed-intro')),
          ).dy,
      0,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('news-feed-search-container')),
          )
          .padding,
      const EdgeInsets.fromLTRB(16, 6, 16, 0),
    );
    expect(
      tester.widget<ListView>(
        find.byKey(const ValueKey('news-feed-content-list')),
      ).padding!.resolve(TextDirection.ltr).top,
      6,
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(
                  const ValueKey(
                    'news-feed-most-popular-card-business-42',
                  ),
                ),
              )
              .dy -
          tester.getBottomLeft(find.text('Most popular')).dy,
      6,
    );

    await tester.tap(find.byKey(const ValueKey('news-feed-intro-info')));
    await tester.pumpAndSettle();
    expect(
      find.text('Fresh updates, offers, and stories from local venues.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('news-feed-section-info-most-popular')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Most hearts from users'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

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
    final filterLabel = find.byKey(
      const ValueKey('news-feed-filter-label-sport type'),
    );
    final filterLabelText = find.text('SPORT TYPE');
    expect(
      tester.getBottomLeft(filterLabel).dy -
          tester.getBottomLeft(filterLabelText).dy,
      6,
    );
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
                    'category': 'Pilates',
                    'address': 'Cebu City',
                    'pricePerHour': 450,
                    'averageRating': 4.8,
                    'enabled': true,
                    'latitude': 10.325,
                    'longitude': 123.901,
                  },
                  {
                    'id': 72,
                    'name': 'Yoga Wellness',
                    'businessType': 'Wellness',
                    'category': 'Yoga',
                    'address': 'Mandaue City',
                    'pricePerHour': 300,
                    'averageRating': 4.6,
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
      await tester.tap(find.byIcon(Icons.location_on).first);
      await tester.pumpAndSettle();
      expect(find.text('Pilates Studio'), findsOneWidget);
      expect(find.text('Pilates'), findsOneWidget);
      expect(find.text('Cebu City'), findsOneWidget);
      expect(find.text('\u{20B1} 450 / hr'), findsOneWidget);
      expect(find.text('Get directions'), findsOneWidget);
      await tester.tapAt(const Offset(12, 200));
      await tester.pumpAndSettle();

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
