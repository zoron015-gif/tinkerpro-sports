import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/merchant_dashboard.dart';
import 'package:myapp/messages_dashboard.dart';

import 'merchant_dashboard_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('back from merchant Messages restores the dashboard', (
    tester,
  ) async {
    setMerchantDashboardSession();
    final api = AuthApi(
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/merchant/profile':
            return http.Response(
              jsonEncode({
                'profile': {
                  'firstName': 'Merchant',
                  'lastName': 'Owner',
                  'email': 'merchant@example.com',
                  'businessType': 'Sports',
                },
              }),
              200,
            );
          case '/api/merchant/businesses':
            return http.Response(jsonEncode({'businesses': []}), 200);
          case '/api/merchant/bookings':
            return http.Response(jsonEncode({'bookings': []}), 200);
          case '/api/activity-logs':
            return http.Response(jsonEncode({'activities': []}), 200);
          case '/api/messages/conversations':
            return http.Response(jsonEncode({'conversations': []}), 200);
          case '/api/messages/contacts':
            return http.Response(jsonEncode({'contacts': []}), 200);
          case '/api/auth/me':
            return http.Response(
              jsonEncode({
                'user': {'id': 42},
              }),
              200,
            );
          default:
            return http.Response(
              jsonEncode({'error': 'Unexpected request'}),
              404,
            );
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(home: MerchantDashboardPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Data analytics'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('merchant-dashboard-nav-messages')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MessagesDashboardPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(MessagesDashboardPage), findsNothing);
    expect(find.text('Merchant Dashboard'), findsOneWidget);
    expect(find.text('Data analytics'), findsOneWidget);
  });
}
