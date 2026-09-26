bool isMerchantBusinessDisabled(Map<String, dynamic> business) {
  final nestedValue = business['business'];
  final nestedBusiness = nestedValue is Map
      ? Map<String, dynamic>.from(nestedValue)
      : const <String, dynamic>{};
  final values = [
    business['enabled'],
    business['businessEnabled'],
    business['isEnabled'],
    business['is_enabled'],
    nestedBusiness['enabled'],
    nestedBusiness['businessEnabled'],
    nestedBusiness['isEnabled'],
    nestedBusiness['is_enabled'],
    business['status'],
    business['businessStatus'],
    nestedBusiness['status'],
    nestedBusiness['businessStatus'],
  ];

  return values.any(_isDisabledValue);
}

bool _isDisabledValue(Object? value) {
  if (value == null) return false;
  if (value is bool) return !value;
  if (value is num) return value == 0;
  final normalized = value.toString().trim().toLowerCase();
  return normalized == '0' ||
      normalized == 'false' ||
      normalized == 'disabled' ||
      normalized == 'inactive' ||
      normalized == 'off';
}
