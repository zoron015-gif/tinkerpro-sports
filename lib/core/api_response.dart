List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList(growable: false);
}

List<String> asStringList(dynamic value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Object>()
      .map((entry) => '$entry'.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}
