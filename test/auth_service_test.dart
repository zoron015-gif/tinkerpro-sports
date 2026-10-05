import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';
import 'package:myapp/features/auth/application/auth_service.dart';

class _MemoryAuthSessionStore implements AuthSessionStore {
  String? email;
  String? token;
  String? role;

  @override
  Future<bool> hasAuthenticatedApiSession() async => token?.isNotEmpty == true;

  @override
  Future<void> save({
    required String email,
    required String token,
    required String role,
  }) async {
    this.email = email;
    this.token = token;
    this.role = role;
  }
}

void main() {
  test(
    'password reset and sign-in use the backend as password authority',
    () async {
      final requests = <http.Request>[];
      final sessions = _MemoryAuthSessionStore();
      final api = AuthApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/api/auth/login')) {
            expect(jsonDecode(request.body)['password'], 'updated-password');
            return http.Response(
              jsonEncode({
                'token': 'api-session-token',
                'user': {'email': 'player@example.test', 'role': 'customer'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'message': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = AuthService(api: api, sessions: sessions);

      await service.resetPassword(
        email: 'player@example.test',
        code: '123456',
        password: 'updated-password',
      );
      await service.login(
        email: 'player@example.test',
        password: 'updated-password',
      );

      expect(requests.map((request) => request.url.path), [
        '/api/auth/reset-password',
        '/api/auth/login',
      ]);
      expect(sessions.email, 'player@example.test');
      expect(sessions.token, 'api-session-token');
      expect(sessions.role, 'customer');
    },
  );

  test(
    'sign-in rejects incomplete API sessions instead of marking authenticated',
    () async {
      final sessions = _MemoryAuthSessionStore();
      final service = AuthService(
        api: AuthApi(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'user': {'email': 'player@example.test'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
        sessions: sessions,
      );

      await expectLater(
        service.login(email: 'player@example.test', password: 'password'),
        throwsA(isA<AuthApiException>()),
      );
      expect(sessions.token, isNull);
    },
  );
}
