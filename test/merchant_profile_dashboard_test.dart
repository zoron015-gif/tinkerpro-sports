import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/merchant_profile_dashboard.dart';

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'merchant profile filters performance and shows overview and quick tools',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      var destination = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantProfileDashboardPage(
            owner: const {
              'firstName': 'Morgan',
              'lastName': 'Merchant',
              'email': 'morgan@example.com',
              'businessName': 'Morgan Sports',
              'address': 'Manila',
            },
            profileImage: null,
            venueCount: 1,
            bookings: [
              {
                'date': _date(now),
                'status': 'approved',
                'total': 100,
                'paidAmount': 40,
                'paymentStatus': 'partial',
              },
              {
                'date': _date(now.subtract(const Duration(days: 1))),
                'status': 'approved',
                'total': 60,
                'paymentStatus': 'paid',
              },
              {
                'date': _date(now),
                'status': 'pending',
                'total': 500,
                'paymentStatus': 'unpaid',
              },
            ],
            businesses: const [
              {
                'name': 'Morgan Sports',
                'availability': 'open',
                'averageRating': 4.8,
                'imageUrl': 'https://example.com/venue.jpg',
              },
            ],
            onEditProfile: () async => null,
            onLogout: (_) async {},
            onNavigate: (index) => destination = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₱40.00'), findsOneWidget);
      expect(find.text('₱100.00'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('merchant-profile-date-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('All time').last);
      await tester.pumpAndSettle();

      expect(find.text('₱100.00'), findsOneWidget);
      expect(find.text('₱160.00'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Business overview'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Morgan Sports'), findsWidgets);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.textContaining('marked open or available'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Schedule'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(destination, 3);
    },
  );
}
