import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart'; // For TimestampConverter

part 'subscription_model.freezed.dart';
part 'subscription_model.g.dart';

enum SubscriptionStatus {
  @JsonValue('active')
  active,
  @JsonValue('expired')
  expired,
  @JsonValue('depleted')
  depleted,
  @JsonValue('cancelled')
  cancelled,
}

@freezed
class SubscriptionModel with _$SubscriptionModel {
  const factory SubscriptionModel({
    String? id,
    required String studentId,
    required String studentName,
    required String mohaffezId,
    required String mohaffezName,
    required String planId,
    required String planTitle,
    required String planType, // 'single', 'bundle', 'subscription'
    required int totalSessions,
    required int remainingSessions,
    required double totalPaid,
    required String paymentTransactionId,
    @Default(SubscriptionStatus.active) SubscriptionStatus status,
    @TimestampConverter() DateTime? startDate,
    @TimestampConverter() DateTime? expiryDate,
    @TimestampConverter() DateTime? lastUsedAt,
    @TimestampConverter() DateTime? createdAt,
  }) = _SubscriptionModel;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }
}

// Extension helpers
extension SubscriptionExtension on SubscriptionModel {
  bool get isActive => status == SubscriptionStatus.active;
  bool get isExpired => status == SubscriptionStatus.expired;
  bool get isDepleted => status == SubscriptionStatus.depleted;
  bool get hasSessionsLeft => remainingSessions > 0;
  
  bool get canBookSession {
    if (!isActive) return false;
    if (!hasSessionsLeft) return false;
    if (expiryDate != null && expiryDate!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }
  
  int get usedSessions => totalSessions - remainingSessions;
  double get progressPercentage =>
      totalSessions > 0 ? (usedSessions / totalSessions) * 100 : 0;
}
