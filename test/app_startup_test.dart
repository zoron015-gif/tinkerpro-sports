import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_session.dart';
import 'package:myapp/app_startup.dart';
import 'package:myapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('shows branded loading screen then opens the app', (
    tester,
  ) async {
    final initialization = Completer<AppSession>();
    await tester.pumpWidget(
      AppStartup(initialize: () => initialization.future),
    );

    expect(find.text('TinkerPro'), findsOneWidget);
    expect(find.text('Getting your courts ready...'), findsOneWidget);
    expect(find.byType(OverviewPage), findsNothing);

    initialization.complete(await AppSession.load());
    await tester.pumpAndSettle();

    expect(find.byType(OverviewPage), findsOneWidget);
  });

  testWidgets('shows a retry action if startup initialization fails', (
    tester,
  ) async {
    var attempts = 0;
    final initialAttempt = Completer<AppSession>();
    final retryAttempt = Completer<AppSession>();
    await tester.pumpWidget(
      AppStartup(
        initialize: () {
          attempts++;
          return attempts == 1 ? initialAttempt.future : retryAttempt.future;
        },
      ),
    );
    initialAttempt.completeError(StateError('Initialization failed'));
    await tester.pumpAndSettle();

    expect(find.text('TinkerPro could not start'), findsOneWidget);
    expect(find.textContaining('Initialization failed'), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('Getting your courts ready...'), findsOneWidget);
    retryAttempt.complete(await AppSession.load());
    await tester.pumpAndSettle();
    expect(find.byType(OverviewPage), findsOneWidget);
  });
}
