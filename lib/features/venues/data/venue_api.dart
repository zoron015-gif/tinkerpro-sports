part of '../../../auth_api.dart';

extension AuthApiVenueOperations on AuthApi {
  Future<List<Map<String, dynamic>>> newsFeed(String token) async {
    final response = await _request(
      'GET',
      '/api/news-feed',
      headers: _authHeaders(token),
    );
    return asMapList(response['posts']);
  }

  Future<Map<String, dynamic>> setBusinessHearted({
    required String token,
    required int businessId,
    required bool hearted,
  }) => _request(
    hearted ? 'PUT' : 'DELETE',
    '/api/businesses/$businessId/heart',
    headers: _authHeaders(token),
  );

  Future<Set<int>> customerHeartedBusinessIds(String token) async {
    final response = await _request(
      'GET',
      '/api/customer/venue-hearts',
      headers: _authHeaders(token),
    );
    return asMapList(response['businesses'])
        .map((business) => int.tryParse('${business['businessId'] ?? ''}'))
        .whereType<int>()
        .toSet();
  }

  Future<List<Map<String, dynamic>>> newsReviews({
    required String token,
    required int businessId,
  }) async {
    final response = await _request(
      'GET',
      '/api/news-feed/$businessId/reviews',
      headers: _authHeaders(token),
    );
    return asMapList(response['reviews']);
  }

  Future<void> createNewsReview({
    required String token,
    required int businessId,
    required int rating,
    required String comment,
  }) async {
    await _request(
      'POST',
      '/api/news-feed/$businessId/reviews',
      body: {'rating': rating, 'comment': comment},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> submitCustomerReview({
    required String token,
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    await _request(
      'POST',
      '/api/customer/reviews',
      body: {'bookingId': bookingId, 'rating': rating, 'comment': comment},
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<List<Map<String, dynamic>>> merchantNewsPosts(String token) async {
    final response = await _request(
      'GET',
      '/api/merchant/news-posts',
      headers: _authHeaders(token),
    );
    return asMapList(response['posts']);
  }

  Future<void> createMerchantNewsPost({
    required String token,
    required Map<String, dynamic> post,
  }) async {
    await _request(
      'POST',
      '/api/merchant/news-posts',
      body: post,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> updateMerchantNewsPost({
    required String token,
    required int id,
    required Map<String, dynamic> post,
  }) async {
    await _request(
      'PUT',
      '/api/merchant/news-posts/$id',
      body: post,
      headers: _authHeaders(token, extra: {'Content-Type': 'application/json'}),
    );
  }

  Future<void> deleteMerchantNewsPost({
    required String token,
    required int id,
  }) => _request(
    'DELETE',
    '/api/merchant/news-posts/$id',
    headers: _authHeaders(token),
  );
}
