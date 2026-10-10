part of '../../../auth_api.dart';

enum VenueApiErrorKind {
  invalidInput,
  invalidResponse,
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  unknown,
}

class VenueApiException extends AuthApiException {
  const VenueApiException(
    this.kind,
    String message,
    int statusCode, [
    Map<String, dynamic> data = const {},
    String? requestId,
  ]) : super(message, statusCode, data, requestId);

  final VenueApiErrorKind kind;

  static VenueApiException from(AuthApiException error) {
    final kind = switch (error.statusCode) {
      0 => VenueApiErrorKind.network,
      408 => VenueApiErrorKind.timeout,
      400 => VenueApiErrorKind.invalidInput,
      401 => VenueApiErrorKind.unauthorized,
      403 => VenueApiErrorKind.forbidden,
      404 => VenueApiErrorKind.notFound,
      409 => VenueApiErrorKind.conflict,
      >= 500 => VenueApiErrorKind.server,
      _ => VenueApiErrorKind.unknown,
    };
    final message = switch (kind) {
      VenueApiErrorKind.unauthorized =>
        'Please sign in again before continuing.',
      VenueApiErrorKind.forbidden =>
        'You are not allowed to perform this venue action.',
      VenueApiErrorKind.notFound =>
        'The requested venue or news post could not be found.',
      VenueApiErrorKind.conflict =>
        error.message.trim().isEmpty
            ? 'This venue action conflicts with existing data.'
            : error.message,
      VenueApiErrorKind.network ||
      VenueApiErrorKind.timeout ||
      VenueApiErrorKind.server => error.userMessage,
      _ => error.message,
    };
    return VenueApiException(
      kind,
      message,
      error.statusCode,
      error.data,
      error.requestId,
    );
  }
}

typedef _VenueRequest = Future<Map<String, dynamic>> Function(
  String method,
  String path, {
  Map<String, dynamic>? body,
  Map<String, String>? headers,
});
typedef _VenueAuthHeaders = Map<String, String> Function(
  String? token, {
  Map<String, String>? extra,
});

class VenueApi {
  const VenueApi._({required this._request, required this._authHeaders});

  final _VenueRequest _request;
  final _VenueAuthHeaders _authHeaders;

  Future<List<VenueBusiness>> businesses() async {
    final response = await _venueRequest(
      () => _request('GET', '/api/businesses'),
    );
    return _venueObjects(
      response,
      'businesses',
    ).map(VenueBusiness.fromJson).toList(growable: false);
  }

  Future<List<VenueFeedPost>> newsFeed(
    String token, {
    String? businessType,
  }) async {
    _validateToken(token);
    final normalizedBusinessType = businessType?.trim();
    if (businessType != null && normalizedBusinessType!.isEmpty) {
      throw _invalidVenueInput('Business type cannot be empty.');
    }
    final response = await _venueRequest(
      () => _request(
        'GET',
        Uri(
          path: '/api/news-feed',
          queryParameters: normalizedBusinessType == null
              ? null
              : {'businessType': normalizedBusinessType},
        ).toString(),
        headers: _authHeaders(token),
      ),
    );
    return _venueObjects(
      response,
      'posts',
    ).map(VenueFeedPost.fromJson).toList(growable: false);
  }

  Future<VenueHeartState> setBusinessHearted({
    required String token,
    required int businessId,
    required bool hearted,
  }) async {
    _validateToken(token);
    _validatePositiveId(businessId, 'Business ID');
    final response = await _venueRequest(
      () => _request(
        hearted ? 'PUT' : 'DELETE',
        '/api/businesses/$businessId/heart',
        headers: _authHeaders(token),
      ),
    );
    final heartCount = _venueInteger(response['heartCount'], 'heartCount');
    final heartedByMe = _venueBoolean(response['heartedByMe'], 'heartedByMe');
    if (heartCount < 0 || heartedByMe != hearted) {
      throw _invalidVenueResponse('The venue heart state was invalid.');
    }
    return VenueHeartState(heartCount: heartCount, heartedByMe: heartedByMe);
  }

  Future<Set<int>> customerHeartedBusinessIds(String token) async {
    _validateToken(token);
    final response = await _venueRequest(
      () => _request(
        'GET',
        '/api/customer/venue-hearts',
        headers: _authHeaders(token),
      ),
    );
    return _venueObjects(response, 'businesses').map((business) {
      final value = business['businessId'] ?? business['business_id'];
      final id = _venuePositiveId(value);
      if (id == null) {
        throw _invalidVenueResponse(
          'A venue heart response contained an invalid business ID.',
        );
      }
      return id;
    }).toSet();
  }

  Future<List<VenueReview>> newsReviews({
    required String token,
    required int businessId,
  }) async {
    _validateToken(token);
    _validatePositiveId(businessId, 'Business ID');
    final response = await _venueRequest(
      () => _request(
        'GET',
        '/api/news-feed/$businessId/reviews',
        headers: _authHeaders(token),
      ),
    );
    return _venueObjects(
      response,
      'reviews',
    ).map(VenueReview.fromJson).toList(growable: false);
  }

  Future<void> createNewsReview({
    required String token,
    required int businessId,
    required int rating,
    required String comment,
  }) async {
    _validateToken(token);
    _validatePositiveId(businessId, 'Business ID');
    _validateReview(rating, comment);
    await _venueRequest(
      () => _request(
        'POST',
        '/api/news-feed/$businessId/reviews',
        body: {'rating': rating, 'comment': comment},
        headers: _authHeaders(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
      ),
    );
  }

  Future<void> submitCustomerReview({
    required String token,
    required int bookingId,
    required int rating,
    String comment = '',
    String? imageData,
  }) async {
    _validateToken(token);
    _validatePositiveId(bookingId, 'Booking ID');
    _validateReview(rating, comment);
    await _venueRequest(
      () => _request(
        'POST',
        '/api/customer/reviews',
        body: {
          'bookingId': bookingId,
          'rating': rating,
          'comment': comment,
          'imageData': ?imageData,
        },
        headers: _authHeaders(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
      ),
    );
  }

  Future<List<MerchantNewsPost>> merchantNewsPosts(String token) async {
    _validateToken(token);
    final response = await _venueRequest(
      () => _request(
        'GET',
        '/api/merchant/news-posts',
        headers: _authHeaders(token),
      ),
    );
    return _venueObjects(
      response,
      'posts',
    ).map(MerchantNewsPost.fromJson).toList(growable: false);
  }

  Future<void> createMerchantNewsPost({
    required String token,
    required MerchantNewsPostDraft post,
  }) async {
    _validateToken(token);
    _validateNewsPost(post, requireBusinessId: true);
    await _venueRequest(
      () => _request(
        'POST',
        '/api/merchant/news-posts',
        body: post.toJson(),
        headers: _authHeaders(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
      ),
    );
  }

  Future<void> updateMerchantNewsPost({
    required String token,
    required int id,
    required MerchantNewsPostDraft post,
  }) async {
    _validateToken(token);
    _validatePositiveId(id, 'News post ID');
    _validateNewsPost(post);
    await _venueRequest(
      () => _request(
        'PUT',
        '/api/merchant/news-posts/$id',
        body: post.toJson(),
        headers: _authHeaders(
          token,
          extra: {'Content-Type': 'application/json'},
        ),
      ),
    );
  }

  Future<void> deleteMerchantNewsPost({
    required String token,
    required int id,
  }) async {
    _validateToken(token);
    _validatePositiveId(id, 'News post ID');
    await _venueRequest(
      () => _request(
        'DELETE',
        '/api/merchant/news-posts/$id',
        headers: _authHeaders(token),
      ),
    );
  }
}

class VenueCatalogRepository {
  const VenueCatalogRepository(this._api);

  final AuthApi _api;

  Future<List<VenueBusiness>> customerBusinesses({
    bool includeDisabledEvents = false,
  }) async {
    final businesses = await _api.venues.businesses();
    return businesses
        .where((business) {
          final isEvent = business.businessType.trim().toLowerCase() == 'event';
          return (includeDisabledEvents && isEvent) || business.enabled;
        })
        .toList(growable: false);
  }
}

Future<Map<String, dynamic>> _venueRequest(
  Future<Map<String, dynamic>> Function() request,
) async {
  try {
    return await request();
  } on VenueApiException {
    rethrow;
  } on AuthApiException catch (error) {
    throw VenueApiException.from(error);
  }
}

List<Map<String, dynamic>> _venueObjects(
  Map<String, dynamic> response,
  String key,
) {
  final value = response[key];
  if (value is! List) {
    throw _invalidVenueResponse('The server returned an invalid $key list.');
  }
  return List<Map<String, dynamic>>.unmodifiable(
    value.map((entry) {
      if (entry is! Map || entry.keys.any((key) => key is! String)) {
        throw _invalidVenueResponse(
          'The server returned an invalid item in the $key list.',
        );
      }
      return Map<String, dynamic>.from(entry);
    }),
  );
}

void _validateToken(String token) {
  if (token.trim().isEmpty) {
    throw _invalidVenueInput('A signed-in session is required.');
  }
}

void _validatePositiveId(int id, String label) {
  if (id <= 0) {
    throw _invalidVenueInput('$label must be a positive number.');
  }
}

void _validateReview(int rating, String comment) {
  if (rating < 1 || rating > 5) {
    throw _invalidVenueInput('Rating must be between 1 and 5.');
  }
  if (comment.length > 2000) {
    throw _invalidVenueInput('Review comments cannot exceed 2000 characters.');
  }
}

void _validateNewsPost(
  MerchantNewsPostDraft post, {
  bool requireBusinessId = false,
}) {
  if (requireBusinessId && (post.businessId == null || post.businessId! <= 0)) {
    throw _invalidVenueInput('A valid business ID is required.');
  }
  if (post.title.trim().isEmpty || post.title.length > 255) {
    throw _invalidVenueInput(
      'News post titles must contain 1 to 255 characters.',
    );
  }
  if (post.body.trim().isEmpty || post.body.length > 5000) {
    throw _invalidVenueInput(
      'News post text must contain 1 to 5000 characters.',
    );
  }
  if (post.imageUrl != null && post.imageUrl!.length > 10 * 1024 * 1024) {
    throw _invalidVenueInput('The venue image is invalid or too large.');
  }
}

int _venueInteger(dynamic value, String field) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw _invalidVenueResponse('The server returned an invalid $field value.');
}

bool _venueBoolean(dynamic value, String field) {
  if (value == true || value == 1 || value == '1') {
    return true;
  }
  if (value == false || value == 0 || value == '0') {
    return false;
  }
  if (value is String && value.trim().toLowerCase() == 'true') return true;
  if (value is String && value.trim().toLowerCase() == 'false') return false;
  throw _invalidVenueResponse('The server returned an invalid $field value.');
}

VenueApiException _invalidVenueInput(String message) =>
    VenueApiException(VenueApiErrorKind.invalidInput, message, 400);

VenueApiException _invalidVenueResponse(String message) =>
    VenueApiException(VenueApiErrorKind.invalidResponse, message, 502);
