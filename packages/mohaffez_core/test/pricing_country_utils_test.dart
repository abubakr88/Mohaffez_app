import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('equivalentHourlyRateEgp', () {
    test('calculates a single-session hourly rate', () {
      final rate = PricingCountryUtils.equivalentHourlyRateEgp(
        totalPriceEgp: 75,
        sessionsCount: 1,
        sessionDurationMinutes: 45,
      );

      expect(rate, 100);
    });

    test('calculates a bundle hourly rate from its total price', () {
      final rate = PricingCountryUtils.equivalentHourlyRateEgp(
        totalPriceEgp: 400,
        sessionsCount: 5,
        sessionDurationMinutes: 60,
      );

      expect(rate, 80);
    });

    test('returns zero for invalid terms', () {
      expect(
        PricingCountryUtils.equivalentHourlyRateEgp(
          totalPriceEgp: 100,
          sessionsCount: 0,
          sessionDurationMinutes: 60,
        ),
        0,
      );
    });
  });

  group('preferCountryPlans', () {
    PricingPlanModel plan({
      required String id,
      required String countryCode,
      double? displayPrice,
    }) {
      return PricingPlanModel(
        id: id,
        mohaffezId: 'teacher-1',
        title: 'Plan $id',
        type: PlanType.single,
        mode: SessionMode.online,
        priceEGP: 100,
        countryCode: countryCode,
        displayPrice: displayPrice,
        sessionsCount: 1,
      );
    }

    test('returns only the viewer country variant', () {
      final plans = [
        plan(id: 'eg', countryCode: 'EG', displayPrice: 100),
        plan(id: 'sa', countryCode: 'SA', displayPrice: 10),
        plan(id: 'ae', countryCode: 'AE', displayPrice: 8),
      ];

      final result = PricingCountryUtils.preferCountryPlans(plans, 'SA');

      expect(result.map((item) => item.id), ['sa']);
    });

    test('uses a legacy global plan only when no country variant exists', () {
      final plans = [
        plan(id: 'legacy', countryCode: 'EG'),
        plan(id: 'eg-only', countryCode: 'EG', displayPrice: 100),
      ];

      final result = PricingCountryUtils.preferCountryPlans(plans, 'KW');

      expect(result.map((item) => item.id), ['legacy']);
    });
  });
}
