class Venue {
  const Venue({
    this.id,
    this.name = 'Venue',
    this.businessType = '',
    this.category = '',
    this.address = '',
    this.ownerName = '',
    this.facilityType = '',
    this.hours = '',
    this.availability = '',
    this.details = '',
    this.pricePerHour = 0,
    this.eventFee = 0,
    this.amenities = const [],
    this.ratePeriods = const [],
    this.imageUrl = '',
    this.imageUrls = const [],
    this.visitUrl = '',
    this.eventTypes = const [],
    this.attendanceMin,
    this.attendanceMax,
    this.accessibilityNeeds = const [],
    this.parkingNeeds = const [],
    this.securityNeeds = const [],
  });

  final int? id;
  final String name;
  final String businessType;
  final String category;
  final String address;
  final String ownerName;
  final String facilityType;
  final String hours;
  final String availability;
  final String details;
  final double pricePerHour;
  final double eventFee;
  final List<String> amenities;
  final List<Map<String, dynamic>> ratePeriods;
  final String imageUrl;
  final List<String> imageUrls;
  final String visitUrl;
  final List<String> eventTypes;
  final int? attendanceMin;
  final int? attendanceMax;
  final List<String> accessibilityNeeds;
  final List<String> parkingNeeds;
  final List<String> securityNeeds;

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: _intValue(json['venueId'] ?? json['id']),
      name: _text(json['venueName'] ?? json['name'], fallback: 'Venue'),
      businessType: _text(json['businessType']),
      category: _text(json['category']),
      address: _text(json['address']),
      ownerName: _text(json['ownerName']),
      facilityType: _text(json['facilityType']),
      hours: _text(json['hours']),
      availability: _text(json['availability']),
      details: _text(json['details']),
      pricePerHour: _doubleValue(
        json['venuePricePerHour'] ?? json['pricePerHour'],
      ),
      eventFee: _doubleValue(json['eventFee']),
      amenities: _stringList(json['amenities'] ?? json['tags']),
      ratePeriods: _mapList(json['ratePeriods']),
      imageUrl: _text(json['imageUrl']),
      imageUrls: _stringList(json['imageUrls']),
      visitUrl: _text(json['visitUrl']),
      eventTypes: _stringList(json['eventTypes']),
      attendanceMin: _intValue(json['attendanceMin']),
      attendanceMax: _intValue(json['attendanceMax']),
      accessibilityNeeds: _stringList(json['accessibilityNeeds']),
      parkingNeeds: _stringList(json['parkingNeeds']),
      securityNeeds: _stringList(json['securityNeeds']),
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.venue,
    this.date = '',
    this.startTime = '',
    this.durationHours = 0,
    this.players = 0,
    this.paymentMethod = '',
    this.pricePerHour = 0,
    this.total = 0,
    this.downpayment = 0,
    this.extraPlayerCharge = 0,
    this.status = 'pending',
    this.createdAt = '',
    this.reviewId,
    this.reviewRating,
  });

  final int? id;
  final Venue venue;
  final String date;
  final String startTime;
  final double durationHours;
  final int players;
  final String paymentMethod;
  final double pricePerHour;
  final double total;
  final double downpayment;
  final double extraPlayerCharge;
  final String status;
  final String createdAt;
  final int? reviewId;
  final int? reviewRating;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: _intValue(json['id']),
    venue: Venue.fromJson(json),
    date: _text(json['date']),
    startTime: _text(json['startTime']),
    durationHours: _doubleValue(json['durationHours']),
    players: _intValue(json['players']) ?? 0,
    paymentMethod: _text(json['paymentMethod']),
    pricePerHour: _doubleValue(json['pricePerHour']),
    total: _doubleValue(json['total']),
    downpayment: _doubleValue(json['downpayment']),
    extraPlayerCharge: _doubleValue(json['extraPlayerCharge']),
    status: _text(json['status'], fallback: 'pending').toLowerCase(),
    createdAt: _text(json['createdAt']),
    reviewId: _intValue(json['reviewId']),
    reviewRating: _intValue(json['reviewRating']),
  );

  dynamic operator [](String key) => switch (key) {
    'id' => id,
    'venueId' => venue.id,
    'venueName' => venue.name,
    'businessType' => venue.businessType,
    'category' => venue.category,
    'address' => venue.address,
    'ownerName' => venue.ownerName,
    'facilityType' => venue.facilityType,
    'hours' => venue.hours,
    'availability' => venue.availability,
    'details' => venue.details,
    'venuePricePerHour' => venue.pricePerHour,
    'eventFee' => venue.eventFee,
    'amenities' => venue.amenities,
    'ratePeriods' => venue.ratePeriods,
    'imageUrl' => venue.imageUrl,
    'imageUrls' => venue.imageUrls,
    'visitUrl' => venue.visitUrl,
    'eventTypes' => venue.eventTypes,
    'attendanceMin' => venue.attendanceMin,
    'attendanceMax' => venue.attendanceMax,
    'accessibilityNeeds' => venue.accessibilityNeeds,
    'parkingNeeds' => venue.parkingNeeds,
    'securityNeeds' => venue.securityNeeds,
    'date' => date,
    'startTime' => startTime,
    'durationHours' => durationHours,
    'players' => players,
    'paymentMethod' => paymentMethod,
    'pricePerHour' => pricePerHour,
    'total' => total,
    'downpayment' => downpayment,
    'extraPlayerCharge' => extraPlayerCharge,
    'status' => status,
    'createdAt' => createdAt,
    'reviewId' => reviewId,
    'reviewRating' => reviewRating,
    _ => null,
  };
}

String _text(dynamic value, {String fallback = ''}) {
  final text = '$value'.trim();
  return value == null || text == 'null' ? fallback : text;
}

int? _intValue(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value');

double _doubleValue(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => _text(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}
