import 'dart:convert';

List<Map<String, dynamic>> normalizeSportsSlotConfigurations({
  required dynamic raw,
  String? legacySportTypes,
  required double legacyPrice,
  required int totalSlots,
  required int includedPlayers,
  required double additionalPlayerFee,
}) {
  dynamic decoded = raw;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      decoded = null;
    }
  }
  if (decoded is List) {
    final configurations = decoded
        .whereType<Map>()
        .map((item) {
          final sportType = _text(item['sportType'] ?? item['sport_type']);
          return <String, dynamic>{
            'sportType': sportType,
            'pricePerHour': _number(item['pricePerHour'] ?? item['price_per_hour']),
            'fullStudio': _boolean(item['fullStudio'] ?? item['full_studio']),
            'slotCount': _integer(
              item['slotCount'] ?? item['slot_count'],
              totalSlots,
            ),
            'includedPlayers': _integer(
              item['includedPlayers'] ?? item['included_players'],
              includedPlayers,
            ),
            'additionalPlayerFee': _number(
              item['additionalPlayerFee'] ?? item['additional_player_fee'],
              additionalPlayerFee,
            ),
          };
        })
        .where((item) => (item['sportType'] as String).isNotEmpty)
        .toList();
    if (configurations.isNotEmpty) return configurations;
  }

  final legacyCategories = (legacySportTypes ?? '')
      .split(',')
      .map((category) => category.trim())
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList();
  if (legacyCategories.isEmpty) legacyCategories.add('Sports');

  return legacyCategories
      .map(
        (sportType) => <String, dynamic>{
          'sportType': sportType,
          'pricePerHour': legacyPrice,
          'fullStudio': true,
          'slotCount': 1,
          'includedPlayers': includedPlayers,
          'additionalPlayerFee': additionalPlayerFee,
        },
      )
      .toList();
}

String _text(dynamic value) =>
    value == null ? '' : value.toString().trim();

double _number(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

int _integer(dynamic value, int fallback) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

bool _boolean(dynamic value) =>
    value == true || value == 1 || value == '1' || value == 'true';
