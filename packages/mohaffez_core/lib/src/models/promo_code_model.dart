// lib/models/promo_code_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeModel {
  final String code;
  final String type; // 'percentage' or 'fixed'
  final double discount; // 100 for 100% off, or fixed amount
  final bool isActive;
  final DateTime? expiryDate;
  final int? usageLimit;
  final int usedCount;
  final String? description;

  PromoCodeModel({
    required this.code,
    required this.type,
    required this.discount,
    required this.isActive,
    this.expiryDate,
    this.usageLimit,
    this.usedCount = 0,
    this.description,
  });

  factory PromoCodeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Try discountPercent first, then fallback to discount (for legacy docs)
    final discountValue = (data['discountPercent'] ?? data['discount']) as num?;

    if (discountValue == null) {
      throw Exception('Promo code missing discount field');
    }

    return PromoCodeModel(
      code: data['code'] as String,
      type: data['type'] as String,
      discount: discountValue.toDouble(),      // store as double internally
      isActive: data['isActive'] as bool? ?? true,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      usageLimit: data['usageLimit'] as int?,
      usedCount: data['usedCount'] as int? ?? 0,
      description: data['description'] as String?,
    );
  }


  bool get isValid {
    if (!isActive) return false;
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) return false;
    if (usageLimit != null && usedCount >= usageLimit!) return false;
    return true;
  }
}
