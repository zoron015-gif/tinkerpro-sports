import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'match notification preference is controlled separately per account',
    () async {
      final session = await AppSession.load();

      await session.setAccountEmail('first@example.com');
      expect(session.matchNotificationsEnabled, isFalse);
      await session.setMatchNotificationsEnabled(true);
      expect(session.matchNotificationsEnabled, isTrue);

      await session.setAccountEmail('second@example.com');
      expect(session.matchNotificationsEnabled, isFalse);

      await session.setAccountEmail('first@example.com');
      expect(session.matchNotificationsEnabled, isTrue);
    },
  );

  test('match notification preference can be turned off', () async {
    final session = await AppSession.load();
    await session.setAccountEmail('player@example.com');
    await session.setMatchNotificationsEnabled(true);

    await session.setMatchNotificationsEnabled(false);

    expect(session.matchNotificationsEnabled, isFalse);
  });

  test('api token is kept in secure storage and surfaced on the session',
      () async {
    final session = await AppSession.load();

    await session.setApiToken('secure-session-token');

    final reloaded = await AppSession.load();
    expect(reloaded.apiToken, 'secure-session-token');
  });
}
