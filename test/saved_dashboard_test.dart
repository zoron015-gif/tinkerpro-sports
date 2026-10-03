import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/news_feed.dart';
import 'package:myapp/saved_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'session_api_token': 'test-token'});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('maps fitness business type to the fitness saved-item category', () {
    expect(
      SavedDashboardPage.itemTypeForBusinessType('Fitness & Wellness'),
      'fitness',
    );
  });

  testWidgets('fitness saved page shows fitness venues only', (tester) async {
    final session = await AppSession.load();
    await session.setApiToken('test-token');
    final requests = <String>[];
    final api = AuthApi(
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        if (request.url.path == '/api/news-feed') {
          return http.Response(
            jsonEncode({
              'posts': [
                {
                  'businessId': 1,
                  'businessName': 'Basketball Court',
                  'businessType': 'Sports',
                  'category': 'Basketball',
                  'title': 'Basketball Court',
                  'enabled': true,
                },
                {
                  'businessId': 2,
                  'businessName': 'Pilates Studio',
                  'businessType': 'Fitness & Wellness',
                  'category': 'Pilates',
                  'title': 'Pilates Studio',
                  'enabled': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/businesses') {
          return http.Response(
            jsonEncode({
              'businesses': [
                {'id': 1, 'enabled': true},
                {'id': 2, 'enabled': true},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/saved-items') {
          return http.Response(
            jsonEncode({
              'items': [
                {'itemType': 'fitness', 'itemKey': '2'},
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SavedDashboardPage(
          itemType: SavedDashboardPage.itemTypeForBusinessType(
            'Fitness & Wellness',
          ),
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final feed = tester.widget<NewsFeedPage>(find.byType(NewsFeedPage));
    expect(feed.businessType, 'Fitness');
    expect(feed.savedItemType, 'fitness');
    expect(feed.savedOnly, isTrue);
    expect(
      find.text('Pilates Studio'),
      findsWidgets,
      reason:
          '${requests.join(' | ')}; ${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data ?? widget.textSpan?.toPlainText()).join(' | ')}',
    );
    expect(find.text('Basketball Court'), findsNothing);
  });
}
