class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.activityType,
    required this.title,
    required this.description,
    required this.actorRole,
    required this.requestId,
    required this.venueId,
    required this.venueName,
    required this.sportType,
    required this.createdAt,
    required this.details,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return ActivityLogEntry(
      id: json['id'],
      activityType: _string(json['activityType']),
      title: _string(json['title']),
      description: _string(json['description']),
      actorRole: _string(json['actorRole']),
      requestId: _string(json['requestId']),
      venueId: json['venueId']?.toString(),
      venueName: _string(json['venueName']),
      sportType: _string(json['sportType']),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      details: rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : const {},
    );
  }

  final Object? id;
  final String? activityType;
  final String? title;
  final String? description;
  final String? actorRole;
  final String? requestId;
  final String? venueId;
  final String? venueName;
  final String? sportType;
  final DateTime? createdAt;
  final Map<String, dynamic> details;

  static String? _string(dynamic value) => value?.toString();
}
