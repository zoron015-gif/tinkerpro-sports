import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/fitness_booking_pricing.dart';

void main() {
  const category = {
    'sessionPrice': 500,
    'monthlyPrice': 1200,
    'yearlyPrice': 12000,
    'yearlyDiscountType': 'freeMonths',
    'yearlyDiscountValue': 2,
  };

  test('lists only configured plans and discounts annual free months', () {
    expect(
      FitnessBookingPricing.availablePlans(category),
      ['session', 'monthly', 'yearly'],
    );
    expect(FitnessBookingPricing.planPrice(category, 'yearly'), 9600);
    expect(FitnessBookingPricing.planDurationDays(category, 'monthly'), 30);
    expect(FitnessBookingPricing.planDurationDays(category, 'yearly'), 425);
    expect(
      FitnessBookingPricing.planDurationLabel(category, 'yearly'),
      '425 days',
    );
    expect(
      FitnessBookingPricing.yearlyOfferLabel(category, 'yearly'),
      'Yearly offer: 2 free months',
    );
  });

  test('yearly duration adds only valid free-month offers', () {
    expect(
      FitnessBookingPricing.planDurationDays({
        'yearlyDiscountType': 'percentage',
        'yearlyDiscountValue': 2,
      }, 'yearly'),
      365,
    );
    expect(
      FitnessBookingPricing.planDurationDays({
        'yearlyDiscountType': 'freeMonths',
        'yearlyDiscountValue': 3,
      }, 'yearly'),
      455,
    );
  });

  test('calculates percentage discounts and coach fees by selected months', () {
    const percentageCategory = {
      'sessionPrice': 500,
      'monthlyPrice': 1200,
      'yearlyPrice': 12000,
      'yearlyDiscountType': 'percentage',
      'yearlyDiscountValue': 10,
    };
    expect(FitnessBookingPricing.planPrice(percentageCategory, 'yearly'), 10800);
    expect(
      FitnessBookingPricing.yearlyOfferLabel(
        percentageCategory,
        'yearly',
      ),
      'Yearly offer: 10% off',
    );
    const coach = {'monthlyPrice': 300};
    expect(FitnessBookingPricing.coachPrice(coach), 300);
    expect(FitnessBookingPricing.coachPrice(coach, durationMonths: 1), 300);
    expect(FitnessBookingPricing.coachPrice(coach, durationMonths: 5), 1500);
    expect(FitnessBookingPricing.coachPrice(coach, durationMonths: 0), 0);
  });

  test('handles absent merchant pricing without inventing a plan', () {
    expect(FitnessBookingPricing.availablePlans(null), isEmpty);
    expect(FitnessBookingPricing.planPrice(null, 'monthly'), 0);
    expect(FitnessBookingPricing.yearlyOfferLabel(null, 'yearly'), isNull);
    expect(FitnessBookingPricing.planTitle('custom'), 'custom');
  });
}
