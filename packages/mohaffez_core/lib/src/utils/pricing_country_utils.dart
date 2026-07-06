import '../models/pricing_plan_model.dart';
import '../models/user_model.dart';

class PricingCountryOption {
  final String code;
  final String nameAr;
  final String currencyCode;
  final String currencyLabel;
  final double egpRate;

  const PricingCountryOption({
    required this.code,
    required this.nameAr,
    required this.currencyCode,
    required this.currencyLabel,
    required this.egpRate,
  });

  double toEgp(double localAmount) => localAmount * egpRate;

  double fromEgp(double egpAmount) =>
      egpRate <= 0 ? egpAmount : egpAmount / egpRate;
}

class PricingCountryUtils {
  PricingCountryUtils._();

  static const egypt = PricingCountryOption(
    code: 'EG',
    nameAr: 'مصر',
    currencyCode: 'EGP',
    currencyLabel: 'ج.م',
    egpRate: 1,
  );

  // Rates are commercial configuration snapshots, not live FX rates.
  // Keep payment settlement in EGP while allowing teachers to price locally.
  static const countries = <PricingCountryOption>[
    egypt,
    PricingCountryOption(
      code: 'SA',
      nameAr: 'السعودية',
      currencyCode: 'SAR',
      currencyLabel: 'ر.س',
      egpRate: 13,
    ),
    PricingCountryOption(
      code: 'AE',
      nameAr: 'الإمارات',
      currencyCode: 'AED',
      currencyLabel: 'د.إ',
      egpRate: 14,
    ),
    PricingCountryOption(
      code: 'KW',
      nameAr: 'الكويت',
      currencyCode: 'KWD',
      currencyLabel: 'د.ك',
      egpRate: 160,
    ),
    PricingCountryOption(
      code: 'QA',
      nameAr: 'قطر',
      currencyCode: 'QAR',
      currencyLabel: 'ر.ق',
      egpRate: 13.7,
    ),
    PricingCountryOption(
      code: 'US',
      nameAr: 'الولايات المتحدة',
      currencyCode: 'USD',
      currencyLabel: '\$',
      egpRate: 50,
    ),
  ];

  static PricingCountryOption byCode(String? code) {
    final normalized = normalizeCountryCode(code);
    return countries.firstWhere(
      (country) => country.code == normalized,
      orElse: () => egypt,
    );
  }

  static String normalizeCountryCode(String? code) {
    final value = code?.trim().toUpperCase();
    if (value == null || value.isEmpty) return egypt.code;
    if (value == 'KSA') return 'SA';
    if (value == 'UAE') return 'AE';
    return value;
  }

  static PricingCountryOption inferUserCountry(UserModel? user) {
    return inferCountry(
      countryCode: user?.countryCode,
      countryName: user?.country,
      city: user?.city,
      addressText: user?.addressText,
    );
  }

  static PricingCountryOption inferCountry({
    String? countryCode,
    String? countryName,
    String? city,
    String? addressText,
  }) {
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      return byCode(countryCode);
    }

    final haystack = [
      countryName,
      city,
      addressText,
    ]
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .join(' ');

    if (haystack.contains('السعود') ||
        haystack.contains('saudi') ||
        haystack.contains('riyadh') ||
        haystack.contains('jeddah')) {
      return byCode('SA');
    }
    if (haystack.contains('الإمارات') ||
        haystack.contains('الامارات') ||
        haystack.contains('uae') ||
        haystack.contains('dubai') ||
        haystack.contains('abu dhabi')) {
      return byCode('AE');
    }
    if (haystack.contains('الكويت') || haystack.contains('kuwait')) {
      return byCode('KW');
    }
    if (haystack.contains('قطر') || haystack.contains('qatar')) {
      return byCode('QA');
    }
    if (haystack.contains('united states') ||
        haystack.contains('usa') ||
        haystack.contains('america')) {
      return byCode('US');
    }

    return egypt;
  }

  static SessionMode? modeFromSessionType(String? sessionType) {
    switch (sessionType?.trim().toLowerCase()) {
      case 'online':
        return SessionMode.online;
      case 'home':
        return SessionMode.home;
      case 'mosque':
        return SessionMode.mosque;
      default:
        return null;
    }
  }

  static double displayAmount(PricingPlanModel plan) {
    final rate = plan.fxRateToEGP <= 0 ? 1.0 : plan.fxRateToEGP;
    return plan.displayPrice ?? (plan.priceEGP / rate);
  }

  static String displayPriceText(PricingPlanModel plan) {
    final amount = displayAmount(plan);
    final digits = amount == amount.roundToDouble() ? 0 : 2;
    return '${amount.toStringAsFixed(digits)} ${plan.currencyLabel}';
  }

  static String egpPriceText(PricingPlanModel plan) {
    final digits = plan.priceEGP == plan.priceEGP.roundToDouble() ? 0 : 2;
    return '${plan.priceEGP.toStringAsFixed(digits)} ج.م';
  }

  static bool matchesMode(PricingPlanModel plan, String? sessionType) {
    final wanted = modeFromSessionType(sessionType);
    if (wanted == null) return true;
    return plan.mode == null || plan.mode == wanted;
  }

  static List<PricingPlanModel> preferCountryPlans(
    List<PricingPlanModel> plans,
    String? countryCode,
  ) {
    if (plans.isEmpty) return plans;

    final wanted = normalizeCountryCode(countryCode);
    final exact = plans
        .where((plan) => normalizeCountryCode(plan.countryCode) == wanted)
        .toList();
    if (exact.isNotEmpty) return exact;

    // Old plans created before country pricing had no displayPrice/currency
    // snapshot. Treat those as legacy global plans so existing teachers remain
    // bookable while new Egypt-only plans do not leak to other countries.
    final legacyGlobal = plans
        .where((plan) =>
            normalizeCountryCode(plan.countryCode) == egypt.code &&
            plan.displayPrice == null)
        .toList();
    return legacyGlobal;
  }

  static Map<String, dynamic> paymentSnapshot(PricingPlanModel plan) {
    return {
      'studentCountryCode': plan.countryCode,
      'studentCountryName': plan.countryName,
      'displayCurrencyCode': plan.currencyCode,
      'displayCurrencyLabel': plan.currencyLabel,
      'displayAmount': displayAmount(plan),
      'fxRateToEGP': plan.fxRateToEGP,
      'chargedAmountEGP': plan.priceEGP,
      'sessionDurationMinutes': plan.sessionDurationMinutes,
    };
  }
}
