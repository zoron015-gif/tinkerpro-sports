class VenueDomainException implements Exception {
  const VenueDomainException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VenueBusiness {
  VenueBusiness._(this.id, this.businessType, this.enabled, this._data);

  factory VenueBusiness.fromJson(Map<String, dynamic> json) {
    final id = parseVenuePositiveId(json['id'] ?? json['businessId']);
    final businessType = json['businessType'] ?? json['business_type'];
    if (id == null || (businessType != null && businessType is! String)) {
      throw const VenueDomainException('The server returned an invalid business.');
    }
    return VenueBusiness._(
      id,
      businessType as String? ?? '',
      parseVenueBoolean(json['enabled'] ?? true, 'enabled'),
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
    final id = parseVenuePositiveId(json['id'] ?? json['businessId']);
    final businessId = parseVenuePositiveId(json['businessId']);
    final title = json['title'];
    final body = json['body'];
    if (id == null ||
        businessId == null ||
        title is! String ||
        body is! String) {
      throw const VenueDomainException('The server returned an invalid news post.');
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
    final id = parseVenuePositiveId(json['id']);
    final customerId = parseVenuePositiveId(
      json['customerId'] ?? json['customer_id'],
    );
    final rating = parseVenueInteger(json['rating'], 'rating');
    if (rating < 1 || rating > 5) {
      throw const VenueDomainException('The server returned an invalid review.');
    }
    return VenueReview(
      id: id,
      customerId: customerId,
      rating: rating,
      comment: parseVenueOptionalString(json['comment'], 'comment'),
      firstName: parseVenueOptionalString(json['firstName'], 'firstName'),
      lastName: parseVenueOptionalString(json['lastName'], 'lastName'),
      avatarUrl: parseVenueOptionalString(
        json['avatarUrl'] ?? json['avatar_url'],
        'avatarUrl',
      ),
      imageData: parseVenueOptionalString(
        json['imageData'] ?? json['image_data'],
        'imageData',
      ),
      createdAt: parseVenueOptionalString(json['createdAt'], 'createdAt'),
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
    final id = parseVenuePositiveId(json['id']);
    final businessId = parseVenuePositiveId(json['businessId']);
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
      throw const VenueDomainException(
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

int? parseVenuePositiveId(dynamic value) {
  final id = value is int
      ? value
      : value is num && value.isFinite && value == value.roundToDouble()
      ? value.toInt()
      : value is String
      ? int.tryParse(value.trim())
      : null;
  return id != null && id > 0 ? id : null;
}

String? parseVenueOptionalString(dynamic value, String field) {
  if (value == null) return null;
  if (value is String) return value;
  throw VenueDomainException('The server returned an invalid $field value.');
}

int parseVenueInteger(dynamic value, String field) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw VenueDomainException('The server returned an invalid $field value.');
}

bool parseVenueBoolean(dynamic value, String field) {
  if (value == true || value == 1 || value == '1') {
    return true;
  }
  if (value == false || value == 0 || value == '0') {
    return false;
  }
  if (value is String && value.trim().toLowerCase() == 'true') return true;
  if (value is String && value.trim().toLowerCase() == 'false') return false;
  throw VenueDomainException('The server returned an invalid $field value.');
}
