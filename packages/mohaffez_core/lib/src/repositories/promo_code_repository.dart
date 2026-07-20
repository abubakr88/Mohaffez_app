import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/promo_code_model.dart';

class PromoCodeValidationException implements Exception {
  const PromoCodeValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PromoCodeRepository {
  PromoCodeRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<PromoCodeModel?> validatePromoCode(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();
      final snapshot = await _firestore
          .collection('promoCodes')
          .where('code', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final promoCode = PromoCodeModel.fromFirestore(doc);
      if (!promoCode.isValid) return null;

      final user = _auth.currentUser;
      if (user != null) {
        final redemption =
            await doc.reference.collection('redemptions').doc(user.uid).get();
        final useCount = (redemption.data()?['useCount'] as num?)?.toInt() ?? 0;

        if (useCount >= promoCode.perUserLimit) {
          throw const PromoCodeValidationException(
            'لقد استخدمت كود الخصم من قبل، ولا يمكن استخدامه أكثر من مرة.',
          );
        }
      }

      return promoCode;
    } on PromoCodeValidationException {
      rethrow;
    } catch (error) {
      debugPrint('Error validating promo code: $error');
      return null;
    }
  }
}
