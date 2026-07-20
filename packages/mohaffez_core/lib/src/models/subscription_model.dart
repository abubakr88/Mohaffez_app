import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// For other exports, but use pricing_plan's TimestampConverter
import 'pricing_plan_model.dart'; // For PlanType, PlanTypeConverter, and TimestampConverter

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
    // BUG-6 FIX: Changed from String to PlanType enum with converter
    @PlanTypeConverter() required PlanType planType,
    required int totalSessions,
    required int remainingSessions,
    required double totalPaid,
    required String paymentTransactionId,
    int? sessionDurationMinutes,
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

  bool get isBundle => planType == PlanType.bundle;

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

// Simple ActiveBundle model for getActiveBundle query (compatible with existing freezed model)
class ActiveBundleInfo {
  final String id;
  final String studentId;
  final String mohaffezId;
  final String sessionType;
  final String planTitle;
  final int totalSessions;
  final int remainingSessions;
  final int? sessionDurationMinutes;
  final String status;
  final DateTime? expiryDate;

  const ActiveBundleInfo({
    required this.id,
    required this.studentId,
    required this.mohaffezId,
    required this.sessionType,
    required this.planTitle,
    required this.totalSessions,
    required this.remainingSessions,
    this.sessionDurationMinutes,
    required this.status,
    this.expiryDate,
  });

  factory ActiveBundleInfo.fromMap(Map<String, dynamic> map, String docId) {
    return ActiveBundleInfo(
      id: docId,
      studentId: map['studentId'] as String? ?? '',
      mohaffezId: map['mohaffezId'] as String? ?? '',
      sessionType: map['sessionType'] as String? ?? '',
      planTitle: map['planTitle'] as String? ?? '',
      totalSessions: map['totalSessions'] as int? ?? 0,
      remainingSessions: map['remainingSessions'] as int? ?? 0,
      sessionDurationMinutes: (map['sessionDurationMinutes'] as num?)?.toInt(),
      status: map['status'] as String? ?? 'active',
      expiryDate: map['expiryDate'] is Timestamp
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Lightweight teacher-facing projection of an active subscription.
///
/// Subscription documents deliberately carry the learner and guardian names
/// so teacher lists can render without an extra user/profile read per bundle.
class TeacherActiveBundleInfo {
  final String id;
  final String studentId;
  final String studentName;
  final String? guardianName;
  final String? studentProfileId;
  final String? studentProfileName;
  final String? studentProfilePhotoUrl;
  final String planTitle;
  final String sessionType;
  final int totalSessions;
  final int remainingSessions;
  final int? sessionDurationMinutes;
  final double totalPaid;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final DateTime? createdAt;

  const TeacherActiveBundleInfo({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.guardianName,
    this.studentProfileId,
    this.studentProfileName,
    this.studentProfilePhotoUrl,
    required this.planTitle,
    required this.sessionType,
    required this.totalSessions,
    required this.remainingSessions,
    this.sessionDurationMinutes,
    required this.totalPaid,
    this.startDate,
    this.expiryDate,
    this.createdAt,
  });

  String get learnerName {
    final profileName = studentProfileName?.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;
    final fallback = studentName.trim();
    return fallback.isEmpty ? 'طالب' : fallback;
  }

  String? get guardianDisplayName {
    final name = guardianName?.trim() ?? '';
    if (name.isEmpty || name == learnerName) return null;
    return name;
  }

  int get usedSessions =>
      (totalSessions - remainingSessions).clamp(0, totalSessions).toInt();

  double get progress {
    if (totalSessions <= 0) return 0;
    return (usedSessions / totalSessions).clamp(0.0, 1.0).toDouble();
  }

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  factory TeacherActiveBundleInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};
    return TeacherActiveBundleInfo(
      id: doc.id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      guardianName: data['guardianName'] as String?,
      studentProfileId: data['studentProfileId'] as String?,
      studentProfileName: data['studentProfileName'] as String?,
      studentProfilePhotoUrl: data['studentProfilePhotoUrl'] as String?,
      planTitle: data['planTitle'] as String? ?? 'باقة جلسات',
      sessionType: data['sessionType'] as String? ?? '',
      totalSessions: (data['totalSessions'] as num?)?.toInt() ?? 0,
      remainingSessions: (data['remainingSessions'] as num?)?.toInt() ?? 0,
      sessionDurationMinutes: (data['sessionDurationMinutes'] as num?)?.toInt(),
      totalPaid: (data['totalPaid'] as num?)?.toDouble() ?? 0,
      startDate: _subscriptionDate(data['startDate']),
      expiryDate: _subscriptionDate(data['expiryDate']),
      createdAt: _subscriptionDate(data['createdAt']),
    );
  }
}

DateTime? _subscriptionDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
