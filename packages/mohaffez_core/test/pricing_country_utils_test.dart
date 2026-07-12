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
}
