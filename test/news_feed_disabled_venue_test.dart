import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/news_feed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'disabled venue small cards are unavailable and do not navigate',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/news-feed') {
            return http.Response(
              jsonEncode({
                'posts': [
                  {
                    'businessId': 42,
                    'businessName': 'Disabled venue',
                    'businessType': 'Sports',
                    'category': 'Basketball',
                    'pricePerHour': 200,
                    'enabled': true,
                    'reviewCount': 3,
                    'averageRating': 4.5,
                    'title': 'Venue update',
                    'body': 'Details',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/api/businesses') {
            return http.Response(jsonEncode({'businesses': []}), 200);
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected API request'}),
            500,
          );
        }),
      );
      final observer = _PushObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: NewsFeedPage(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNAVAILABLE · Booking disabled'), findsWidgets);
      final smallCard = find
          .byKey(const ValueKey('news-feed-mini-business-42'))
          .first;
      final smallCardTap = find.descendant(
        of: smallCard,
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(smallCardTap).onTap, isNull);
      final pushesBeforeTap = observer.pushCount;

      await tester.tap(smallCard);
      await tester.pumpAndSettle();

      expect(observer.pushCount, pushesBeforeTap);
      expect(find.text('Sports Courts'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Highest rate'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('news-feed-content-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('UNAVAILABLE · Booking disabled'), findsWidgets);
      final featuredCards = find.byKey(
        const ValueKey('news-feed-mini-business-42'),
      );
      expect(featuredCards, findsWidgets);

      final highestRateCard = featuredCards.first;
      final highestRateTap = find.descendant(
        of: highestRateCard,
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(highestRateTap).onTap, isNull);
      final pushesBeforeHighestRateTap = observer.pushCount;
      await tester.tap(highestRateCard);
      await tester.pumpAndSettle();
      expect(observer.pushCount, pushesBeforeHighestRateTap);
    },
  );
}

class _PushObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}
