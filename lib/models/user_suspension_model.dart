import 'package:cloud_firestore/cloud_firestore.dart';

class UserSuspensionModel {
  final String userId;
  final String suspendedBy;
  final String reason;
  final DateTime? suspendedAt;
  final DateTime? expiresAt;
  final bool isActive;

  const UserSuspensionModel({
    required this.userId,
    required this.suspendedBy,
    required this.reason,
    required this.suspendedAt,
    required this.expiresAt,
    required this.isActive,
  });

  factory UserSuspensionModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final suspendedAt = data['suspendedAt'];
    final expiresAt = data['expiresAt'];
    return UserSuspensionModel(
      userId: data['userId'] as String? ?? doc.id,
      suspendedBy: data['suspendedBy'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      suspendedAt: suspendedAt is Timestamp ? suspendedAt.toDate() : null,
      expiresAt: expiresAt is Timestamp ? expiresAt.toDate() : null,
      isActive: data['isActive'] as bool? ?? false,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}
