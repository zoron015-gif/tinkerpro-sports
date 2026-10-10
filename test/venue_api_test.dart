import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myapp/auth_api.dart';

void main() {
  test('completed booking review includes an optional customer photo', () async {
    http.Request? submittedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        submittedRequest = request;
        return http.Response('{}', 201);
      }),
    );
    const imageData = 'data:image/png;base64,aGVsbG8=';

    await api.venues.submitCustomerReview(
      token: 'session-token',
      bookingId: 12,
      rating: 5,
      comment: 'Great court.',
      imageData: imageData,
    );

    expect(submittedRequest, isNotNull);
    expect(jsonDecode(submittedRequest!.body), {
      'bookingId': 12,
      'rating': 5,
      'comment': 'Great court.',
      'imageData': imageData,
    });
  });

  test('review input is validated before making a request', () async {
    var requestCount = 0;
    final api = AuthApi(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      api.venues.createNewsReview(
        token: 'session-token',
        businessId: 12,
        rating: 6,
        comment: 'Too many stars',
      ),
      throwsA(
        isA<VenueApiException>().having(
          (error) => error.kind,
          'kind',
          VenueApiErrorKind.invalidInput,
        ),
      ),
    );
    expect(requestCount, 0);
  });

  test(
    'venue collection responses reject missing or malformed lists',
    () async {
      final api = AuthApi(
        client: MockClient((_) async => http.Response('{"posts":{}}', 200)),
      );

      await expectLater(
        api.venues.newsFeed('session-token'),
        throwsA(
          isA<VenueApiException>()
              .having(
                (error) => error.kind,
                'kind',
                VenueApiErrorKind.invalidResponse,
              )
              .having((error) => error.statusCode, 'statusCode', 502),
        ),
      );
    },
  );

  test('venue heart IDs reject malformed response rows', () async {
    final api = AuthApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'businesses': [
              {'businessId': 'not-an-id'},
            ],
          }),
          200,
        ),
      ),
    );

    await expectLater(
      api.venues.customerHeartedBusinessIds('session-token'),
      throwsA(
        isA<VenueApiException>().having(
          (error) => error.kind,
          'kind',
          VenueApiErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('venue heart state is returned with normalized types', () async {
    final api = AuthApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'heartCount': '4', 'heartedByMe': 1}),
          200,
        ),
      ),
    );

    expect(
      await api.venues.setBusinessHearted(
        token: 'session-token',
        businessId: 12,
        hearted: true,
      ),
      isA<VenueHeartState>()
          .having((state) => state.heartCount, 'heartCount', 4)
          .having((state) => state.heartedByMe, 'heartedByMe', true),
    );
  });

  test(
    'feed responses expose typed posts and validate their contract',
    () async {
      final api = AuthApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'posts': [
                {
                  'id': 8,
                  'businessId': 12,
                  'title': 'Court update',
                  'body': 'New court hours.',
                },
              ],
            }),
            200,
          ),
        ),
      );

      final posts = await api.venues.newsFeed('session-token');

      expect(posts.single, isA<VenueFeedPost>());
      expect(posts.single.businessId, 12);
      expect(posts.single.title, 'Court update');
    },
  );

  test('catalog repository owns disabled-business selection', () async {
    final api = AuthApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'businesses': [
              {'id': 1, 'businessType': 'Sports', 'enabled': true},
              {'id': 2, 'businessType': 'Event', 'enabled': 'FALSE'},
              {'id': 3, 'businessType': 'Event', 'enabled': false},
            ],
          }),
          200,
        ),
      ),
    );
    final catalog = VenueCatalogRepository(api);

    expect(
      (await catalog.customerBusinesses()).map((business) => business.id),
      [1],
    );
    expect(
      (await catalog.customerBusinesses(includeDisabledEvents: true))
          .map((business) => business.id),
      [1, 2, 3],
    );
  });

  test('merchant news draft serializes a typed request contract', () async {
    late http.Request capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('{}', 201);
      }),
    );

    await api.venues.createMerchantNewsPost(
      token: 'session-token',
      post: const MerchantNewsPostDraft(
        businessId: 12,
        title: 'Court update',
        body: 'New court hours.',
        status: NewsPostStatus.published,
        imageUrl: 'https://example.com/court.jpg',
      ),
    );

    expect(jsonDecode(capturedRequest.body), {
      'businessId': 12,
      'title': 'Court update',
      'body': 'New court hours.',
      'status': 'published',
      'imageUrl': 'https://example.com/court.jpg',
    });
  });

  test(
    'HTTP conflicts have a typed venue error and preserve backend detail',
    () async {
      final api = AuthApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'You have already reviewed this booking.'}),
            409,
          ),
        ),
      );

      await expectLater(
        api.venues.createNewsReview(
          token: 'session-token',
          businessId: 12,
          rating: 5,
          comment: '',
        ),
        throwsA(
          isA<VenueApiException>()
              .having((error) => error.kind, 'kind', VenueApiErrorKind.conflict)
              .having(
                (error) => error.message,
                'message',
                'You have already reviewed this booking.',
              ),
        ),
      );
    },
  );

  test(
    'server errors expose a safe venue message and retain request ID',
    () async {
      final api = AuthApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'Private database failure'}),
            500,
            headers: {'x-request-id': 'abc12345-0000-4000-8000-000000000001'},
          ),
        ),
      );

      await expectLater(
        api.venues.newsFeed('session-token'),
        throwsA(
          isA<VenueApiException>()
              .having((error) => error.kind, 'kind', VenueApiErrorKind.server)
              .having(
                (error) => error.message,
                'message',
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
}
