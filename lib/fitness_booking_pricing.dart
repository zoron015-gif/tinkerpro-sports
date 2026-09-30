class FitnessBookingPricing {
  const FitnessBookingPricing._();

  static List<String> availablePlans(Map<String, dynamic>? category) {
    if (category == null) return [];
    return ['session', 'monthly', 'yearly'].where((plan) {
      return _amount(category['${plan}Price']) > 0;
    }).toList();
  }

  static double planPrice(Map<String, dynamic>? category, String? plan) {
    if (category == null || plan == null) return 0;
    var price = _amount(category['${plan}Price']);
    if (plan == 'yearly') {
      final offerType = category['yearlyDiscountType'];
      final offerValue = _amount(category['yearlyDiscountValue']);
      if (offerType == 'freeMonths') {
        price = (price - _amount(category['monthlyPrice']) * offerValue)
            .clamp(0, double.infinity);
      } else if (offerType == 'percentage') {
        price *= (1 - offerValue / 100).clamp(0, 1);
      }
    }
    return price;
  }

  static double coachPrice(
    Map<String, dynamic>? coach,
    String? plan,
  ) {
    if (coach == null || plan == null) return 0;
    return _amount(coach['monthlyPrice']) * (plan == 'yearly' ? 12 : 1);
  }

  static String? yearlyOfferLabel(
    Map<String, dynamic>? category,
    String? plan,
  ) {
    if (plan != 'yearly' || category == null) return null;
    final type = category['yearlyDiscountType'];
    final value = _amount(category['yearlyDiscountValue']);
    if (type == 'freeMonths' && value > 0) {
      return 'Yearly offer: ${value.toStringAsFixed(0)} free months';
    }
    if (type == 'percentage' && value > 0) {
      return 'Yearly offer: ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% off';
    }
    return null;
  }

  static String planTitle(String value) => switch (value) {
    'session' => 'Session',
    'monthly' => 'Monthly',
    'yearly' => 'Yearly',
    _ => value,
  };

  static double _amount(dynamic value) => double.tryParse('$value') ?? 0;
}
