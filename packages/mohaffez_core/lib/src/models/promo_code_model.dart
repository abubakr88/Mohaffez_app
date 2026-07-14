// lib/models/promo_code_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeModel {
  final String code;
  final String type; // 'percentage' or 'fixed'
  final double discount; // 100 for 100% off, or fixed amount
  final bool isActive;
  final DateTime? expiryDate;
  final int? usageLimit;
  final int perUserLimit;
  final int usedCount;
  final String? description;

  PromoCodeModel({
    required this.code,
    required this.type,
    required this.discount,
    required this.isActive,
    this.expiryDate,
    this.usageLimit,
    this.perUserLimit = 1,
    this.usedCount = 0,
    this.description,
  });

  factory PromoCodeModel.fromFirestore(DocumentSnapshot doc) {
    return PromoCodeModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  factory PromoCodeModel.fromMap(Map<String, dynamic> data) {
    // Admin promo documents use discountType/discountValue. Keep the older
    // fields readable so already-created codes remain valid.
    final discountValue = (data['discountPercent'] ??
        data['discountValue'] ??
        data['discount']) as num?;
    final rawType =
        (data['type'] ?? data['discountType'] ?? 'fixed').toString();
    final normalizedType = rawType == 'percent' ? 'percentage' : rawType;

    if (discountValue == null) {
      throw Exception('Promo code missing discount field');
    }

    return PromoCodeModel(
      code: data['code'] as String,
      type: normalizedType,
      discount: discountValue.toDouble(),
      isActive: data['isActive'] as bool? ?? true,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      usageLimit: (data['usageLimit'] as num?)?.toInt(),
      perUserLimit: 1,
      usedCount: (data['usedCount'] as num?)?.toInt() ?? 0,
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
