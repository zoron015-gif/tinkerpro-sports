import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_bottom_navigation.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_settings_page.dart';
import 'package:myapp/app_theme.dart';
import 'package:myapp/merchant_profile_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configured light theme applies shared page and surface styles', () {
    final theme = AppTheme.configured(
      darkMode: false,
      accentColor: AppPalette.orange.color,
    );

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.lightPage);
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.dialogTheme.backgroundColor, Colors.white);
    expect(theme.bottomSheetTheme.backgroundColor, Colors.white);
    expect(theme.inputDecorationTheme.fillColor, Colors.white);
  });

  testWidgets('appearance and language choices apply and persist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.instance.load();

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: AppPreferences.instance,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.configured(
            darkMode: AppPreferences.instance.darkMode,
            accentColor: AppPreferences.instance.palette.color,
          ),
          locale: AppLanguage.fromCode(AppPreferences.instance.languageCode)
              .locale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppSettingsPage(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('app-settings-dark-mode')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness,
      Brightness.dark,
    );
    expect(AppColors.page, AppColors.darkPage);
    expect(AppColors.surface, AppColors.darkSurface);
    expect(AppColors.ink, AppColors.darkInk);
    expect(AppColors.muted, AppColors.darkMuted);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .scaffoldBackgroundColor,
      AppColors.darkPage,
    );
    final darkTheme = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!;
    expect(darkTheme.cardTheme.color, AppColors.darkSurface);
    expect(darkTheme.dialogTheme.backgroundColor, AppColors.darkSurface);
    expect(darkTheme.bottomSheetTheme.backgroundColor, AppColors.darkSurface);
    expect(darkTheme.inputDecorationTheme.fillColor, AppColors.darkSurface);
    expect(darkTheme.colorScheme.onSurface, AppColors.darkInk);
    expect(darkTheme.colorScheme.onSurfaceVariant, AppColors.darkMuted);
    expect(darkTheme.colorScheme.error, AppColors.darkError);
    expect(darkTheme.iconTheme.color, AppColors.darkMuted);
    expect(darkTheme.listTileTheme.textColor, AppColors.darkInk);
    expect(darkTheme.chipTheme.labelStyle?.color, AppColors.darkInk);
    expect(darkTheme.tabBarTheme.unselectedLabelColor, AppColors.darkMuted);
    expect(darkTheme.datePickerTheme.backgroundColor, AppColors.darkSurface);
    expect(darkTheme.timePickerTheme.backgroundColor, AppColors.darkSurface);
    expect(
      darkTheme.segmentedButtonTheme.style!.backgroundColor!.resolve(const {}),
      AppColors.darkSurface,
    );
    expect(
      darkTheme.segmentedButtonTheme.style!.foregroundColor!.resolve(const {}),
      AppColors.darkInk,
    );
    expect(AppGradients.warmSurface.colors.first, const Color(0xFF191B22));

    await tester.tap(find.byKey(const ValueKey('app-settings-color-blue')));
    await tester.pumpAndSettle();
    expect(AppPreferences.instance.palette, AppPalette.blue);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .colorScheme
          .primary,
      AppPalette.blue.color,
    );

    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(AppPreferences.instance.textScale, 1.1);

    final filipinoChoice = find.byKey(
      const ValueKey('app-settings-language-filipino'),
    );
    await tester.ensureVisible(filipinoChoice);
    await tester.pumpAndSettle();
    await tester.tap(filipinoChoice);
    await tester.pumpAndSettle();
    expect(AppPreferences.instance.languageCode, 'fil');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale?.languageCode,
      'fil',
    );
    expect(find.text('Mga Setting'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    final stored = jsonDecode(
      preferences.getString('app_preferences_guest')!,
    ) as Map<String, dynamic>;
    expect(stored, {
      'darkMode': true,
      'palette': 'blue',
      'textScale': 1.1,
      'languageCode': 'fil',
    });
  });

  test('Korean, Japanese, and Chinese languages apply and persist', () async {
    SharedPreferences.setMockInitialValues({});

    for (final language in [
      AppLanguage.korean,
      AppLanguage.japanese,
      AppLanguage.chinese,
    ]) {
      await AppPreferences.instance.update(languageCode: language.code);
      expect(AppPreferences.instance.languageCode, language.code);
      expect(AppLanguage.supportedLocales, contains(language.locale));
      expect(AppLanguage.fromCode(language.code), language);
    }
    expect(appLanguageText('Settings', 'Mga Setting'), '设置');

    final preferences = await SharedPreferences.getInstance();
    final stored = jsonDecode(
      preferences.getString('app_preferences_guest')!,
    ) as Map<String, dynamic>;
    expect(stored['languageCode'], 'zh');
  });

  test(
    'appearance and language preferences stay isolated by account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = AppPreferences.instance;

      await preferences.load(accountEmail: 'alice@example.com');
      await preferences.update(
        darkMode: true,
        palette: AppPalette.violet,
        languageCode: 'ko',
      );

      await preferences.load(accountEmail: 'bob@example.com');
      expect(preferences.darkMode, isFalse);
      expect(preferences.palette, AppPalette.orange);
      expect(preferences.languageCode, 'en');
      await preferences.update(palette: AppPalette.blue, languageCode: 'ja');

      await preferences.load(accountEmail: 'ALICE@example.com');
      expect(preferences.darkMode, isTrue);
      expect(preferences.palette, AppPalette.violet);
      expect(preferences.languageCode, 'ko');

      await preferences.load();
      expect(preferences.darkMode, isFalse);
      expect(preferences.palette, AppPalette.orange);
      expect(preferences.languageCode, 'en');
      await preferences.update(languageCode: 'fil');

      await preferences.load(accountEmail: 'bob@example.com');
      expect(preferences.palette, AppPalette.blue);
      expect(preferences.languageCode, 'ja');
      await preferences.load();
      expect(preferences.languageCode, 'fil');

      final storage = await SharedPreferences.getInstance();
      expect(storage.containsKey('app_preferences'), isFalse);
      expect(
        storage.getKeys().where((key) => key.startsWith('app_preferences_')),
        hasLength(3),
      );
    },
  );

  testWidgets('language updates shared customer and merchant navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences.instance;
    await preferences.load(accountEmail: 'customer@example.com');

    Widget buildNavigation({bool merchantMode = false}) => AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            merchantMode: merchantMode,
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildNavigation());
    expect(find.text('Explore'), findsOneWidget);
    await preferences.update(languageCode: 'ko');
    await tester.pumpAndSettle();
    expect(find.text('둘러보기'), findsOneWidget);

    await tester.pumpWidget(buildNavigation(merchantMode: true));
    expect(find.text('대시보드'), findsOneWidget);

    await preferences.load(accountEmail: 'merchant@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('대시보드'), findsNothing);
  });

  testWidgets('static system copy translates without altering user content', (
    tester,
  ) async {
    Finder renderedText(String value) => find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == value,
    );

    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences.instance;
    await preferences.load(accountEmail: 'player@example.com');

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: preferences,
        builder: (context, _) => MaterialApp(
          locale: AppLanguage.fromCode(preferences.languageCode).locale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Column(
              children: [
                AppText('Cancel', localize: true),
                AppText('Sports'),
                AppText('Rate 3 out of 5 stars', localize: true),
                AppText(
                  'Could not load bookings: Network error',
                  localize: true,
                ),
                AppText('2 hours', localize: true),
                AppText('"TinkerPro Venue" was deleted.', localize: true),
                AppText(
                  'Fitness & Wellness dashboard is not available yet.',
                  localize: true,
                ),
                AppText(
                  'Google sign in will be connected soon.',
                  localize: true,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: appLanguageText('Event type', 'Event type'),
                  ),
                ),
                AppText.rich(TextSpan(text: 'Confirm booking'), localize: true),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Confirm booking'), findsOneWidget);

    await preferences.update(languageCode: 'ko');
    await tester.pumpAndSettle();

    expect(preferences.languageCode, 'ko');
    expect(
      Localizations.localeOf(tester.element(find.byType(AppText).first))
          .languageCode,
      'ko',
    );
    expect(renderedText('취소'), findsOneWidget);
    expect(renderedText('Sports'), findsOneWidget);
    expect(renderedText('별점 5점 만점에 3점'), findsOneWidget);
    expect(renderedText('예약을 불러올 수 없습니다: Network error'), findsOneWidget);
    expect(renderedText('2시간'), findsOneWidget);
    expect(renderedText('"TinkerPro Venue" 항목을 삭제했습니다.'), findsOneWidget);
    expect(
      renderedText('Fitness & Wellness 대시보드는 아직 사용할 수 없습니다.'),
      findsOneWidget,
    );
    expect(renderedText('Google 로그인 기능이 곧 제공됩니다.'), findsOneWidget);
    expect(renderedText('이벤트 유형'), findsOneWidget);
    expect(renderedText('예약 확인'), findsOneWidget);
    expect(renderedText('Cancel'), findsNothing);

    for (final language in [
      AppLanguage.filipino,
      AppLanguage.japanese,
      AppLanguage.chinese,
    ]) {
      await preferences.update(languageCode: language.code);
      await tester.pumpAndSettle();
      expect(
        renderedText(
          language == AppLanguage.filipino
              ? 'Kanselahin'
              : language == AppLanguage.japanese
              ? 'キャンセル'
              : '取消',
        ),
        findsOneWidget,
      );
      expect(renderedText('Sports'), findsOneWidget);
    }
  });

  testWidgets('merchant settings opens shared appearance settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileDashboardPage(
          owner: const {'firstName': 'Merchant'},
          profileImage: null,
          venueCount: 0,
          onLogout: (_) async {},
          onEditProfile: () async => null,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('merchant-profile-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('merchant-settings-appearance')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('merchant-settings-appearance')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app-settings-dark-mode')),
      findsOneWidget,
    );
  });
}
