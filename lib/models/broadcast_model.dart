import 'package:cloud_firestore/cloud_firestore.dart';

class BroadcastModel {
  final String id;
  final String title;
  final String body;
  final String targetRole;
  final DateTime? sentAt;
  final String sentBy;
  final int recipientCount;

  const BroadcastModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetRole,
    required this.sentAt,
    required this.sentBy,
    required this.recipientCount,
  });

  factory BroadcastModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final sentAt = data['sentAt'];
    return BroadcastModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      targetRole: data['targetRole'] as String? ?? 'all',
      sentAt: sentAt is Timestamp ? sentAt.toDate() : null,
      sentBy: data['sentBy'] as String? ?? '',
      recipientCount: (data['recipientCount'] as num?)?.toInt() ?? 0,
    );
  }
}
