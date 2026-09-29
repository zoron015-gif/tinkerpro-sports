import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/sports.dart';

void main() {
  test('keeps each configured sport rate and slot setup independent', () {
    final slots = normalizeSportsSlotConfigurations(
      raw: jsonEncode([
        {
          'sportType': 'Tennis',
          'pricePerHour': 200,
          'fullStudio': true,
          'slotCount': 5,
        },
        {
          'sportType': 'Badminton',
          'pricePerHour': 75,
          'fullStudio': false,
          'slotCount': 4,
        },
      ]),
      legacySportTypes: 'Tennis, Badminton',
      legacyPrice: 200,
      totalSlots: 5,
      includedPlayers: 0,
      additionalPlayerFee: 0,
    );

    expect(slots, hasLength(2));
    expect(slots[0]['sportType'], 'Tennis');
    expect(slots[0]['pricePerHour'], 200);
    expect(slots[0]['fullStudio'], isTrue);
    expect(slots[0]['slotCount'], 5);
    expect(slots[1]['sportType'], 'Badminton');
    expect(slots[1]['pricePerHour'], 75);
    expect(slots[1]['fullStudio'], isFalse);
    expect(slots[1]['slotCount'], 4);
  });

  test('splits legacy combined sport categories into selectable options', () {
    final slots = normalizeSportsSlotConfigurations(
      raw: null,
      legacySportTypes: 'Tennis, Pickleball, Basketball',
      legacyPrice: 200,
      totalSlots: 1,
      includedPlayers: 5,
      additionalPlayerFee: 50,
    );

    expect(slots.map((slot) => slot['sportType']), [
      'Tennis',
      'Pickleball',
      'Basketball',
    ]);
    expect(slots.map((slot) => slot['pricePerHour']), [200, 200, 200]);
  });
}
