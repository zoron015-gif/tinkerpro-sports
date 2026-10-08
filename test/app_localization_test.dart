import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_localization.dart';
import 'package:myapp/app_text.dart';

void main() {
  test('translates templates containing multiple dynamic values', () {
    expect(
      appLanguageText(
        'Booking at Court 1 is Confirmed.',
        'Booking at Court 1 is Confirmed.',
        languageCode: 'ja',
      ),
      'Court 1の予約は確定しました。',
    );
    expect(
      appLanguageText(
        'Plan: \u{20B1} 500.00\nCoach: Mina · \u{20B1} 200.00',
        'Plan: \u{20B1} 500.00\nCoach: Mina · \u{20B1} 200.00',
        languageCode: 'ko',
      ),
      '플랜: \u{20B1} 500.00\n코치: Mina · \u{20B1} 200.00',
    );
    expect(
      appLanguageText(
        '09:00 - 10:00 · \u{20B1} 250.00 / hr',
        '09:00 - 10:00 · \u{20B1} 250.00 / hr',
        languageCode: 'zh',
      ),
      '09:00 - 10:00 · \u{20B1} 250.00 / 小时',
    );
    expect(
      appLanguageText('4 guests · Cash', '4 guests · Cash', languageCode: 'ja'),
      'ゲスト 4名 · 現金',
    );
    expect(
      appLanguageText(
        'Sports · Basketball',
        'Sports · Basketball',
        languageCode: 'ko',
      ),
      '스포츠 · 농구',
    );
  });

  test(
    'translates booking status and payment labels without changing data',
    () {
      expect(
        appLanguageText(
          'Waiting for the venue to approve your request. Not confirmed yet.',
          'Waiting for the venue to approve your request. Not confirmed yet.',
          languageCode: 'zh',
        ),
        '正在等待场地批准，尚未确认。',
      );
      expect(
        appLanguageText(
          'Payment method',
          'Payment method',
          languageCode: 'fil',
        ),
        'Paraan ng pagbabayad',
      );
      expect(
        appLanguageText(
          'Downpayment received: \u{20B1} 100.00',
          'Downpayment received: \u{20B1} 100.00',
          languageCode: 'ko',
        ),
        '선금 수령: \u{20B1} 100.00',
      );
      expect(
        appLanguageText(
          'Remaining balance: \u{20B1} 250.00',
          'Remaining balance: \u{20B1} 250.00',
          languageCode: 'zh',
        ),
        '剩余金额：\u{20B1} 250.00',
      );
      expect(
        appLanguageText(
          'Harbor Sports Center',
          'Harbor Sports Center',
          languageCode: 'ja',
        ),
        'Harbor Sports Center',
      );
    },
  );

  testWidgets('AppText localizes screen headings by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('ko'),
        supportedLocales: [Locale('en'), Locale('ko')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          appBar: AppBar(title: const AppText('Bookings')),
          body: const AppText('Payment method'),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == '예약',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == '결제 방법',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AppText allows explicit localization opt-out', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ko'),
        supportedLocales: [Locale('en'), Locale('ko')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: AppText('Bookings', localize: false)),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText() == 'Bookings',
      ),
      findsOneWidget,
    );
  });
}
