import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pricing_plan_model.dart';
import '../models/promo_code_model.dart';

class PricingResult {
  final double originalPrice;
  final double discount;
  final double finalPrice;
  final String? promoCode;
  final bool isFree;

  const PricingResult({
    required this.originalPrice,
    required this.discount,
    required this.finalPrice,
    this.promoCode,
    required this.isFree,
  });
}

class PricingService {
  double calculateBasePrice(PricingPlanModel plan) {
    return plan.priceEGP;
  }

  double calculatePricePerSession(PricingPlanModel plan) {
    if (plan.sessionsCount <= 0) {
      return plan.priceEGP;
    }
    return plan.priceEGP / plan.sessionsCount;
  }

  double calculateSavings(PricingPlanModel plan, double regularPrice) {
    final savings = regularPrice - plan.priceEGP;
    return savings > 0 ? savings : 0;
  }

  PricingResult applyPromoCode(PricingPlanModel plan, PromoCodeModel? promo) {
    final basePrice = calculateBasePrice(plan);

    if (promo == null || !isPlanEligibleForPromo(plan, promo)) {
      return PricingResult(
        originalPrice: basePrice,
        discount: 0,
        finalPrice: basePrice,
        promoCode: null,
        isFree: isFreeTrial(plan, null),
      );
    }

    final discount = calculateDiscount(basePrice, promo);
    final finalPrice = (basePrice - discount).clamp(0, double.infinity).toDouble();

    return PricingResult(
      originalPrice: basePrice,
      discount: discount,
      finalPrice: finalPrice,
      promoCode: promo.code,
      isFree: isFreeTrial(plan, promo) || finalPrice == 0,
    );
  }

  double calculateDiscount(double basePrice, PromoCodeModel promo) {
    if (promo.type == 'percentage') {
      return basePrice * (promo.discount / 100);
    }

    return promo.discount;
  }

  bool isPlanEligibleForPromo(PricingPlanModel plan, PromoCodeModel promo) {
    if (!promo.isValid) {
      return false;
    }

    if (plan.priceEGP <= 0) {
      return false;
    }

    return true;
  }

  bool isFreeTrial(PricingPlanModel plan, PromoCodeModel? promo) {
    if (plan.isFreeTrialAvailable) {
      return true;
    }

    if (promo == null) {
      return false;
    }

    if (promo.type == 'percentage' && promo.discount >= 100) {
      return true;
    }

    return false;
  }
}

final pricingServiceProvider = Provider<PricingService>((ref) {
  return PricingService();
});
