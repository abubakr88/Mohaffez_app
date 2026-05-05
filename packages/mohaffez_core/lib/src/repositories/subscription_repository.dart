// lib/repositories/subscription_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_model.dart';

class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  const SubscriptionRepository(this._firestore);

  /// Streams ALL subscriptions for a student across all statuses.
  /// Used by ActiveSubscriptionsScreen filter tabs.
  Stream<List<SubscriptionModel>> watchStudentSubscriptions(
    String studentId, {
    String? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => SubscriptionModel.fromFirestore(d))
              .toList(),
        );
  }

  /// Lightweight count stream — used only by nav badge.
  /// Does NOT parse full SubscriptionModel to keep it fast.
  Stream<int> watchActiveSubscriptionCount(String studentId) {
    return _firestore
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Returns one active bundle for a specific teacher.
  /// Used by MohaffezProfileScreen banner.
  ///
  /// FIX: added optional [sessionType] filter. A student can hold both an
  /// 'online' and a 'home' bundle for the same teacher; without this filter
  /// the wrong bundle may be shown in the profile banner.
  /// Passing null keeps all existing callers working without changes.
  Future<SubscriptionModel?> getActiveBundleForTeacher({
    required String studentId,
    required String mohaffezId,
    String? sessionType, // FIX: optional filter
  }) async {
    var query = _firestore
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'active');

    // FIX: only filter by sessionType when provided
    if (sessionType != null && sessionType.isNotEmpty) {
      query = query.where('sessionType', isEqualTo: sessionType);
    }

    final snap = await query
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return SubscriptionModel.fromFirestore(snap.docs.first);
  }
}

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(FirebaseFirestore.instance);
});
