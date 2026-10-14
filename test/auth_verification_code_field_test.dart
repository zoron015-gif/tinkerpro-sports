import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/features/auth/application/auth_service.dart';
import 'package:myapp/features/auth/presentation/auth_dashboard.dart';

void main() {
  testWidgets('verification code boxes distribute pasted digits', (
    tester,
  ) async {
    Map<String, dynamic>? submittedPayload;
    final api = AuthApi(
      client: MockClient((request) async {
        submittedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'error': 'Invalid code.'}), 400);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationPage(
          email: 'customer@example.com',
          service: AuthService(api: api),
        ),
      ),
    );

    final digitFields = find.byType(TextField);
    expect(digitFields, findsNWidgets(6));
    await tester.enterText(digitFields.first, '12a3456');
    await tester.pump();
    final verifyButton = find.byType(FilledButton);
    expect(verifyButton, findsOneWidget);
    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(submittedPayload, {
      'email': 'customer@example.com',
      'code': '123456',
    });
  });
}
