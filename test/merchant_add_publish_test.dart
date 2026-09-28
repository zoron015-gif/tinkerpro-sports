import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_add_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'publishing a complete News Card labels it and shows its Booking Card',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      final newsPost = <String, dynamic>{
        'id': 100,
        'businessId': 10,
        'title': 'Venue update',
        'body': 'Court details',
        'imageUrl': 'venue-image',
        'status': 'draft',
      };
      var businessesReloaded = false;
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/merchant/news-posts' &&
              request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'posts': [newsPost],
              }),
              200,
            );
          }
          if (request.url.path == '/api/merchant/news-posts/100' &&
              request.method == 'PUT') {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            newsPost['status'] = payload['status'];
            return http.Response(
              jsonEncode({'message': 'News post updated.'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({'error': 'Unexpected request'}),
            404,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MerchantAddPage(
              initialBusinessType: null,
              api: api,
              businesses: [
                {
                  'id': 10,
                  'businessType': 'Sports',
                  'name': 'Example court',
                  'category': 'Basketball',
                  'address': 'Cebu City',
                  'facilityType': 'Indoor',
                  'hours': '8:00 AM - 5:00 PM',
                  'eventFee': 0,
                  'pricePerHour': '200.00',
                  'ratePeriods': [],
                  'tags': [],
                },
                {
                  'id': 11,
                  'businessType': 'Event',
                  'name': 'Example event hall',
                  'category': 'Wedding',
                  'address': 'Cebu City',
                },
              ],
              onBusinessesChanged: () async {
                businessesReloaded = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bookingFilterPosition = tester.getTopLeft(find.text('All'));

      await tester.tap(find.text('News cards'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('All')), bookingFilterPosition);
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(newsPost['status'], 'published');
      expect(businessesReloaded, isTrue);
      expect(find.text('Example court'), findsOneWidget);
      expect(find.text('₱200 / hr'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'event hall');
      await tester.pumpAndSettle();
      expect(find.text('Example court'), findsNothing);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('News cards'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sports · Basketball'), findsOneWidget);
      expect(find.textContaining('Event · Wedding'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event').last);
      await tester.pumpAndSettle();
      expect(find.text('Example event hall'), findsOneWidget);
      expect(find.text('Example court'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sports').last);
      await tester.pumpAndSettle();
      expect(find.text('Venue update'), findsOneWidget);
      expect(find.textContaining('Sports · Basketball'), findsOneWidget);
      expect(find.text('Example event hall'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'example event');
      await tester.pumpAndSettle();
      expect(find.text('Venue update'), findsNothing);
      expect(find.text('Example event hall'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'basketball');
      await tester.pumpAndSettle();
      expect(find.textContaining('Sports · Basketball'), findsOneWidget);
      expect(
        find.textContaining('PUBLISHED · BOOKING CARD AVAILABLE'),
        findsOneWidget,
      );
    },
  );
}
