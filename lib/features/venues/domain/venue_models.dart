part of '../../../auth_api.dart';

class VenueBusiness {
  VenueBusiness._(this.id, this.businessType, this.enabled, this._data);

  factory VenueBusiness.fromJson(Map<String, dynamic> json) {
    final id = _venuePositiveId(json['id'] ?? json['businessId']);
    final businessType = json['businessType'] ?? json['business_type'];
    if (id == null || (businessType != null && businessType is! String)) {
      throw _invalidVenueResponse('The server returned an invalid business.');
    }
    return VenueBusiness._(
      id,
      businessType as String? ?? '',
      _venueBoolean(json['enabled'] ?? true, 'enabled'),
      Map<String, dynamic>.unmodifiable(json),
    );
  }

  final int id;
  final String businessType;
  final bool enabled;
  final Map<String, dynamic> _data;

  Map<String, dynamic> toViewData() => Map<String, dynamic>.of(_data);
}

class VenueFeedPost {
  VenueFeedPost._(this.id, this.businessId, this.title, this.body, this._data);

  factory VenueFeedPost.fromJson(Map<String, dynamic> json) {
    final id = _venuePositiveId(json['id'] ?? json['businessId']);
    final businessId = _venuePositiveId(json['businessId']);
    final title = json['title'];
    final body = json['body'];
    if (id == null ||
        businessId == null ||
        title is! String ||
        body is! String) {
      throw _invalidVenueResponse('The server returned an invalid news post.');
    }
    return VenueFeedPost._(
      id,
      businessId,
      title,
      body,
      Map<String, dynamic>.unmodifiable(json),
    );
  }

  final int id;
  final int businessId;
  final String title;
  final String body;
  final Map<String, dynamic> _data;

  Map<String, dynamic> toViewData() => Map<String, dynamic>.of(_data);
}

class VenueReview {
  const VenueReview({
    required this.id,
    required this.customerId,
    required this.rating,
    required this.comment,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.imageData,
    required this.createdAt,
  });

  factory VenueReview.fromJson(Map<String, dynamic> json) {
    final id = _venuePositiveId(json['id']);
    final customerId = _venuePositiveId(
      json['customerId'] ?? json['customer_id'],
    );
    final rating = _venueInteger(json['rating'], 'rating');
    if (rating < 1 || rating > 5) {
      throw _invalidVenueResponse('The server returned an invalid review.');
    }
    return VenueReview(
      id: id,
      customerId: customerId,
      rating: rating,
      comment: _venueOptionalString(json['comment'], 'comment'),
      firstName: _venueOptionalString(json['firstName'], 'firstName'),
      lastName: _venueOptionalString(json['lastName'], 'lastName'),
      avatarUrl: _venueOptionalString(
        json['avatarUrl'] ?? json['avatar_url'],
        'avatarUrl',
      ),
      imageData: _venueOptionalString(
        json['imageData'] ?? json['image_data'],
        'imageData',
      ),
      createdAt: _venueOptionalString(json['createdAt'], 'createdAt'),
    );
  }

  final int? id;
  final int? customerId;
  final int rating;
  final String? comment;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? imageData;
  final String? createdAt;
}

class VenueHeartState {
  const VenueHeartState({required this.heartCount, required this.heartedByMe});

  final int heartCount;
  final bool heartedByMe;
}

enum NewsPostStatus { draft, published, archived }

class MerchantNewsPostDraft {
  const MerchantNewsPostDraft({
    required this.title,
    required this.body,
    required this.status,
    this.businessId,
    this.imageUrl,
  });

  final int? businessId;
  final String title;
  final String body;
  final NewsPostStatus status;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
    if (businessId != null) 'businessId': businessId,
    'title': title,
    'body': body,
    'status': status.name,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

class MerchantNewsPost {
  MerchantNewsPost._(
    this.id,
    this.businessId,
    this.title,
    this.body,
    this.status,
    this._data,
  );

  factory MerchantNewsPost.fromJson(Map<String, dynamic> json) {
    final id = _venuePositiveId(json['id']);
    final businessId = _venuePositiveId(json['businessId']);
    final title = json['title'];
    final body = json['body'];
    final statusName = json['status'];
    final status = statusName is String
        ? NewsPostStatus.values.where((value) => value.name == statusName)
        : const <NewsPostStatus>[];
    if (id == null ||
        businessId == null ||
        title is! String ||
        body is! String ||
        status.isEmpty) {
      throw _invalidVenueResponse(
        'The server returned an invalid merchant news post.',
      );
    }
    return MerchantNewsPost._(
      id,
      businessId,
      title,
      body,
      status.first,
      Map<String, dynamic>.unmodifiable(json),
    );
  }

  final int id;
  final int businessId;
  final String title;
  final String body;
  final NewsPostStatus status;
  final Map<String, dynamic> _data;

  Map<String, dynamic> toViewData() => Map<String, dynamic>.of(_data);
}

int? _venuePositiveId(dynamic value) {
  final id = value is int
      ? value
      : value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt()
      : value is String
      ? int.tryParse(value.trim())
      : null;
  return id != null && id > 0 ? id : null;
}

String? _venueOptionalString(dynamic value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw _invalidVenueResponse('The server returned an invalid $field value.');
}
