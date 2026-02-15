// lib/providers/promo_code_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_code_model.dart';
import '../repositories/promo_code_repository.dart';

final promoCodeRepositoryProvider = Provider((ref) {
  return PromoCodeRepository(FirebaseFirestore.instance);
});

final promoCodeProvider =
    StateNotifierProvider<PromoCodeNotifier, AsyncValue<PromoCodeModel?>>(
        (ref) {
  return PromoCodeNotifier(ref.watch(promoCodeRepositoryProvider));
});

class PromoCodeNotifier extends StateNotifier<AsyncValue<PromoCodeModel?>> {
  final PromoCodeRepository _repository;

  PromoCodeNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> validateCode(String code) async {
    if (code.trim().isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();

    try {
      final promoCode = await _repository.validatePromoCode(code);

      if (promoCode == null) {
        state = AsyncValue.error(
            'كود غير صحيح أو منتهي الصلاحية', StackTrace.current);
      } else {
        state = AsyncValue.data(promoCode);
      }
    } catch (e, stack) {
      state = AsyncValue.error('حدث خطأ في التحقق من الكود', stack);
    }
  }

  void clearPromoCode() {
    state = const AsyncValue.data(null);
  }

  Future<void> applyPromoCode(String code) async {
    await _repository.incrementUsageCount(code);
  }

  Future<void> incrementPromoCodeUsage(String code) async {
    await _repository.incrementUsageCount(code);
  }
}
