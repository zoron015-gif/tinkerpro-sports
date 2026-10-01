import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/reviews.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const reviewerAvatar =
      'data:image/png;base64,'
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lXcAAAAASUVORK5CYII=';

  setUp(() async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
  });

  testWidgets('review list shows each reviewer profile image', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/reviews')) {
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'customerId': 7,
                'firstName': 'Ziggy',
                'lastName': 'Player',
                'avatarUrl': reviewerAvatar,
                'rating': 5,
                'comment': 'Great court.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/bookings') {
        return http.Response(
          jsonEncode({'bookings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: AuthApi(client: client),
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reviewerImage = tester.widget<Image>(find.byType(Image).first);
    expect(reviewerImage.image, isA<MemoryImage>());
    expect(find.text('Ziggy Player'), findsOneWidget);
    expect(find.text('Great court.'), findsOneWidget);
    final reviewerRating = tester.widget<Row>(
      find.byKey(const ValueKey('review-rating-stars-0')),
    );
    expect(reviewerRating.children, hasLength(5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsNWidgets(5),
    );
    expect(find.text('5/5'), findsNothing);

    client.close();
  });

  testWidgets('review list keeps initials when no profile image is available', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/reviews')) {
        return http.Response(
          jsonEncode({
            'reviews': [
              {
                'customerId': 8,
                'firstName': 'Maya',
                'lastName': 'Player',
                'rating': 4,
                'comment': 'Nice venue.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/bookings') {
        return http.Response(
          jsonEncode({'bookings': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewsSheet(
            api: AuthApi(client: client),
            businessId: 12,
            businessName: 'Test Court',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('M'), findsOneWidget);
    expect(find.text('Maya Player'), findsOneWidget);
    final reviewerRating = tester.widget<Row>(
      find.byKey(const ValueKey('review-rating-stars-0')),
    );
    expect(reviewerRating.children, hasLength(5));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsNWidgets(4),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-rating-stars-0')),
        matching: find.byIcon(Icons.star_outline_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('4/5'), findsNothing);

    client.close();
  });
}
