import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/event_booking_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Event booking submits event type, schedule, and guest count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'session_api_token': 'test-token',
    });
    Map<String, dynamic>? submittedBooking;
    final api = AuthApi(
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/bookings') {
          submittedBooking = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'booking': {
                'id': 501,
                'businessType': 'Event',
                'eventType': 'Wedding',
              },
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'error': 'Unexpected request'}), 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventBookingPage(
                      api: api,
                      business: {
                        'id': 7,
                        'name': 'Garden Venue',
                        'category': 'Events',
                        'eventTypes': ['Wedding', 'Birthday'],
                        'attendanceMin': 50,
                        'attendanceMax': 250,
                        'eventFee': 10000,
                      },
                    ),
                  ),
                ),
                child: const Text('Open booking'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open booking'));
    await tester.pumpAndSettle();

    expect(find.text('Garden Venue'), findsOneWidget);
    expect(find.text('Wedding'), findsOneWidget);
    final cashOption = find.text('Cash on arrival');
    await tester.ensureVisible(cashOption);
    await tester.tap(cashOption);
    await tester.pumpAndSettle();
    final submitButton = find.text('Request event booking');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(submittedBooking, isNotNull);
    expect(submittedBooking!['venueId'], 7);
    expect(submittedBooking!['eventType'], 'Wedding');
    expect(submittedBooking!['players'], 50);
    expect(submittedBooking!['paymentMethod'], 'cash_on_arrival');
    expect(submittedBooking!['durationHours'], 4);
    expect(find.text('Open booking'), findsOneWidget);
  });
}
