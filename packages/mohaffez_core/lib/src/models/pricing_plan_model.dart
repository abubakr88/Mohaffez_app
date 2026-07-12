// lib/models/pricing_plan_model.dart

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

part 'pricing_plan_model.freezed.dart';
part 'pricing_plan_model.g.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum PlanType {
  @JsonValue('single')
  single,
  @JsonValue('bundle')
  bundle,
}

enum SessionMode {
  @JsonValue('online')
  online,
  @JsonValue('home')
  home,
  @JsonValue('mosque')
  mosque,
}

// ─── Model ────────────────────────────────────────────────────────────────────

@freezed
class PricingPlanModel with _$PricingPlanModel {
  const factory PricingPlanModel({
    String? id,
    required String mohaffezId,
    required String title,
    required PlanType type,

    // FIX 1: mode is nullable — old Firestore docs may not have this field.
    // A missing mode no longer throws during parsing and crashes the entire
    // getPlansForTeacher() list, which previously silently disabled Option 2.
    SessionMode? mode,
    required double priceEGP,
    @Default('EG') String countryCode,
    @Default('مصر') String countryName,
    @Default('EGP') String currencyCode,
    @Default('ج.م') String currencyLabel,
    double? displayPrice,
    @Default(1.0) double fxRateToEGP,
    required int sessionsCount,
    int? sessionDurationMinutes,
    int? validityDays,
    int? sessionsPerWeek,
    @Default(true) bool isActive,
    @Default(false) bool isFreeTrialAvailable,
    String? description,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _PricingPlanModel;

  factory PricingPlanModel.fromJson(Map<String, dynamic> json) =>
      _$PricingPlanModelFromJson(json);

  // FIX 2: fromFirestore always uses doc.id (never data['id'] which is null
  // in all existing documents — visible in the Firebase Console screenshot).
  // FIX 3: safe field coercion handles int/double mismatch from Firestore
  // (Firestore stores numbers as int, Dart freezed expects double for priceEGP).
  factory PricingPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Coerce Firestore numeric types safely
    final rawPrice = data['priceEGP'];
    final rawDisplayPrice = data['displayPrice'];
    final rawFxRate = data['fxRateToEGP'];
    final rawSessions = data['sessionsCount'];
    final rawDuration = data['sessionDurationMinutes'];

    final safeData = {
      ...data,
      'id': doc.id, // FIX 2
      'priceEGP': rawPrice is int // FIX 3
          ? rawPrice.toDouble()
          : rawPrice ?? 0.0,
      'displayPrice':
          rawDisplayPrice is int ? rawDisplayPrice.toDouble() : rawDisplayPrice,
      'fxRateToEGP': rawFxRate is int ? rawFxRate.toDouble() : rawFxRate ?? 1.0,
      'sessionsCount': rawSessions is double // FIX 3
          ? rawSessions.toInt()
          : rawSessions ?? 0,
      'sessionDurationMinutes':
          rawDuration is double ? rawDuration.toInt() : rawDuration,
    };

    try {
      return PricingPlanModel.fromJson(safeData);
    } catch (e) {
      // FIX 4: surface parse errors in debug builds instead of crashing
      // the entire plans list — returns a safe placeholder so the screen
      // still renders and the broken plan is visible in logs.
      debugPrint('❌ [PricingPlanModel] parse failed for doc ${doc.id}: $e');
      debugPrint('   Raw data: $safeData');
      return PricingPlanModel(
        id: doc.id,
        mohaffezId: data['mohaffezId'] as String? ?? '',
        title: data['title'] as String? ?? '(خطأ في التحميل)',
        type: PlanType.single,
        mode: null,
        priceEGP: 0.0,
        countryCode: data['countryCode'] as String? ?? 'EG',
        countryName: data['countryName'] as String? ?? 'مصر',
        currencyCode: data['currencyCode'] as String? ?? 'EGP',
        currencyLabel: data['currencyLabel'] as String? ?? 'ج.م',
        displayPrice: null,
        fxRateToEGP: 1.0,
        sessionsCount: 0,
        isActive: false, // disabled so it won't be selectable
      );
    }
  }
}

// ─── Converters ───────────────────────────────────────────────────────────────

class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is Timestamp) return json.toDate();
    if (json is DateTime) return json;
    return null;
  }

  @override
  Object? toJson(DateTime? date) {
    if (date == null) return null;
    return Timestamp.fromDate(date);
  }
}

// Used by SubscriptionModel for its planType field
class PlanTypeConverter implements JsonConverter<PlanType, String> {
  const PlanTypeConverter();

  @override
  PlanType fromJson(String json) => PlanType.values.firstWhere(
        (e) => e.name == json,
        orElse: () => PlanType.single,
      );

  @override
  String toJson(PlanType type) => type.name;
}
