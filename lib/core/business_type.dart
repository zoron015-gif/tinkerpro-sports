enum BusinessType { sports, event, fitness, unknown }

extension BusinessTypeX on BusinessType {
  String get value => switch (this) {
    BusinessType.sports => 'Sports',
    BusinessType.event => 'Event',
    BusinessType.fitness => 'Fitness & Wellness',
    BusinessType.unknown => '',
  };
}

class BusinessTypeParser {
  const BusinessTypeParser();

  static BusinessType parse(Object? value) {
    final normalized = '${value ?? ''}'.trim().toLowerCase();
    return switch (normalized) {
      'sports' || 'sport' => BusinessType.sports,
      'event' || 'events' => BusinessType.event,
      'fitness' ||
      'wellness' ||
      'fitness & wellness' ||
      'fitness wellness' ||
      'fitness_wellness' => BusinessType.fitness,
      _ => BusinessType.unknown,
    };
  }

  static String normalized(Object? value) => parse(value).value;
}
