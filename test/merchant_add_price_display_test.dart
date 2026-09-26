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
    'sports booking card displays hourly price when event fee is zero',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'session_api_token': 'test-token',
      });
      final api = AuthApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/merchant/news-posts') {
            return http.Response(
              jsonEncode({
                'posts': [
                  {
                    'id': 100,
                    'businessId': 10,
                    'title': 'Venue update',
                    'body': 'Court details',
                    'imageUrl': 'data:image/png;base64,AA==',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'posts': []}), 200);
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
              ],
              onBusinessesChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₱200 / hr'), findsOneWidget);
      expect(find.text('Price not set'), findsNothing);
    },
  );
}
