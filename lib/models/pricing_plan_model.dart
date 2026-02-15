import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'pricing_plan_model.freezed.dart';
part 'pricing_plan_model.g.dart';

enum PlanType {
  @JsonValue('single')
  single,
  @JsonValue('bundle')
  bundle,
  @JsonValue('subscription')
  subscription,
}

enum SessionMode {
  @JsonValue('online')
  online,
  @JsonValue('home')
  home,
  @JsonValue('mosque')
  mosque,
}

@freezed
class PricingPlanModel with _$PricingPlanModel {
  const factory PricingPlanModel({
    String? id,
    required String mohaffezId,
    required String title,
    required PlanType type,
    required SessionMode mode,
    required double priceEGP,
    required int sessionsCount,
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

  factory PricingPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PricingPlanModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}

// TimestampConverter for Firestore Timestamp <-> DateTime
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
