import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('PromoCodeModel', () {
    test('reads the schema written by the admin dashboard', () {
      final promo = PromoCodeModel.fromMap({
        'code': 'ALFATEHA',
        'discountType': 'percent',
        'discountValue': 100,
        'isActive': true,
        'usedCount': 0,
      });

      expect(promo.code, 'ALFATEHA');
      expect(promo.type, 'percentage');
      expect(promo.discount, 100);
      expect(promo.perUserLimit, 1);
      expect(promo.isValid, isTrue);
    });

    test('keeps the canonical promo schema compatible', () {
      final promo = PromoCodeModel.fromMap({
        'code': 'WELCOME50',
        'type': 'percentage',
        'discountPercent': 50,
        'isActive': true,
        'usageLimit': 20,
        'usedCount': 3,
      });

      expect(promo.type, 'percentage');
      expect(promo.discount, 50);
      expect(promo.usageLimit, 20);
      expect(promo.usedCount, 3);
      expect(promo.isValid, isTrue);
    });
  });
}
