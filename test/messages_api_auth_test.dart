import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';

void main() {
  test(
    'message API attaches the session token as a Bearer credential',
    () async {
      String? authorization;
      final api = AuthApi(
        client: MockClient((request) async {
          authorization = request.headers['Authorization'];
          return http.Response(jsonEncode({'conversations': []}), 200);
        }),
      );

      await api.conversations('test-session-token');

      expect(authorization, 'Bearer test-session-token');
    },
  );

  test('message deletion sends its deletion scope to the API', () async {
    late http.Request receivedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        receivedRequest = request;
        return http.Response(jsonEncode({'message': 'Message deleted.'}), 200);
      }),
    );

    await api.deleteConversationMessage(
      token: 'test-session-token',
      conversationId: 12,
      messageId: 34,
      scope: 'me',
    );

    expect(receivedRequest.method, 'DELETE');
    expect(
      receivedRequest.url.path,
      '/api/messages/conversations/12/messages/34',
    );
    expect(jsonDecode(receivedRequest.body), {'scope': 'me'});
  });

  test('message deletion rejects an unsupported scope before requesting', () async {
    var requested = false;
    final api = AuthApi(
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.deleteConversationMessage(
        token: 'test-session-token',
        conversationId: 12,
        messageId: 34,
        scope: 'all',
      ),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test(
    'missing messaging endpoints explain that the backend needs a restart',
    () async {
      final api = AuthApi(
        client: MockClient((_) async => http.Response('<!doctype html>', 404)),
      );

      await expectLater(
        api.setConversationState(
          token: 'test-session-token',
          conversationId: 1,
          archived: true,
        ),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having(
                (error) => error.message,
                'message',
                contains('Restart the backend server'),
              ),
        ),
      );
    },
  );

  test(
    'API errors preserve a valid support request ID and safe status message',
    () async {
      final api = AuthApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'SQL exception: private database details'}),
            500,
            headers: {
              'content-type': 'application/json',
              'x-request-id': 'abc12345-0000-4000-8000-000000000001',
            },
          ),
        ),
      );

      await expectLater(
        api.conversations('test-session-token'),
        throwsA(
          isA<AuthApiException>()
              .having(
                (error) => error.userMessage,
                'userMessage',
                'Something went wrong on our end. Please try again.',
              )
              .having(
                (error) => error.requestId,
                'requestId',
                'abc12345-0000-4000-8000-000000000001',
              ),
        ),
      );
    },
  );

  test('successful API responses must be JSON objects', () async {
    final api = AuthApi(
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    await expectLater(
      api.conversations('test-session-token'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'The server returned an invalid response.',
        ),
      ),
    );
  });

  test('customer venue catalog excludes disabled businesses', () async {
    final api = AuthApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'businesses': [
              {'id': 10, 'businessType': 'sports', 'enabled': true},
              {'id': 11, 'businessType': 'sports', 'enabled': false},
              {'id': 12, 'businessType': 'sports', 'enabled': 0},
            ],
          }),
          200,
        ),
      ),
    );

    final businesses = await VenueCatalogRepository(api).customerBusinesses();

    expect(businesses.map((business) => business.id), [10]);
  });
}
