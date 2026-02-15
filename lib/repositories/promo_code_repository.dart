// lib/repositories/promo_code_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_code_model.dart';

class PromoCodeRepository {
  final FirebaseFirestore _firestore;

  PromoCodeRepository(this._firestore);

  /// التحقق من صحة الكود وإرجاع بياناته
  Future<PromoCodeModel?> validatePromoCode(String code) async {
    try {
      final doc = await _firestore
          .collection('promocodes')
          .doc(code.toUpperCase())
          .get();

      if (!doc.exists) return null;

      final promoCode = PromoCodeModel.fromFirestore(doc);
      
      if (!promoCode.isValid) return null;

      return promoCode;
    } catch (e) {
      print('❌ Error validating promo code: $e');
      return null;
    }
  }

  /// زيادة عداد الاستخدام
  Future<void> incrementUsageCount(String code) async {
    try {
      await _firestore.collection('promocodes').doc(code.toUpperCase()).update({
        'usedCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('❌ Error incrementing usage count: $e');
    }
  }
}
