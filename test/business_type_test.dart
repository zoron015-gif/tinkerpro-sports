import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/business_type.dart';

void main() {
  test('business type aliases resolve to one canonical booking category', () {
    expect(BusinessTypeParser.parse('Sport'), BusinessType.sports);
    expect(BusinessTypeParser.parse('Sports'), BusinessType.sports);
    expect(BusinessTypeParser.parse('Events'), BusinessType.event);
    expect(BusinessTypeParser.parse('Event'), BusinessType.event);
    expect(BusinessTypeParser.parse('Fitness'), BusinessType.fitness);
    expect(BusinessTypeParser.parse('Wellness'), BusinessType.fitness);
    expect(
      BusinessTypeParser.parse('Fitness & Wellness'),
      BusinessType.fitness,
    );
    expect(BusinessTypeParser.parse('other'), BusinessType.unknown);
  });
}
