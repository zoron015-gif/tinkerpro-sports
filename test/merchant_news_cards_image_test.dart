import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_add_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('News Card uses Booking Card images and has no image picker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    final api = AuthApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'posts': []}), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            initialBusinessType: null,
            api: api,
            businesses: const [
              {
                'id': 10,
                'businessType': 'Sports',
                'name': 'Example court',
                'category': 'Badminton',
              },
            ],
            onBusinessesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sectionTabs = find.byKey(const ValueKey('merchant-add-section-tabs'));
    final filter = find.byType(DropdownButtonFormField<String>).first;
    final search = find.byType(TextField).first;
    expect(
      tester.getTopLeft(filter).dy,
      lessThan(tester.getTopLeft(sectionTabs).dy),
    );
    expect(
      tester.getTopLeft(search).dy,
      lessThan(tester.getTopLeft(sectionTabs).dy),
    );
    await tester.tap(find.text('News cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    expect(find.text('News Feed preview'), findsOneWidget);
    expect(find.byKey(const ValueKey('news-card-add-image')), findsNothing);
    expect(
      find.text('Add venue photos by editing the Booking Card.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Add a venue image by editing its Booking Card before saving this News Card.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('News Card publishes using the selected Booking Card photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    Map<String, dynamic>? publishedPost;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/merchant/news-posts' &&
            request.method == 'GET') {
          return http.Response(jsonEncode({'posts': []}), 200);
        }
        if (request.url.path == '/api/merchant/news-posts' &&
            request.method == 'POST') {
          publishedPost = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 21}), 201);
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MerchantAddPage(
            initialBusinessType: null,
            api: api,
            businesses: const [
              {
                'id': 10,
                'businessType': 'Sports',
                'name': 'Example court',
                'category': 'Badminton',
                'imageUrl': 'https://example.test/court.jpg',
                'imageUrls': [
                  'https://example.test/court.jpg',
                  'https://example.test/court-2.jpg',
                ],
              },
            ],
            onBusinessesChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('News cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(
      find.byKey(const ValueKey('news-card-image-preview-10')),
      findsOneWidget,
    );
    expect(find.text('2 venue photos'), findsOneWidget);
    expect(find.byKey(const ValueKey('news-card-add-image')), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated court hours.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(publishedPost?['imageUrl'], 'https://example.test/court.jpg');
    expect(publishedPost?['body'], 'Updated court hours.');
    expect(tester.takeException(), isNull);
  });
}
