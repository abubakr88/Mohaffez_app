// lib/repositories/notification_repository.dart (COMPLETE VERSION)
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  static const int pageSize = 20;

  NotificationRepository(this._firestore);

  // ==================== ORIGINAL METHOD (Keep for backward compatibility) ====================
  
  /// Watch ALL notifications for a user (non-paginated)
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50) // Reasonable limit for non-paginated
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ==================== PAGINATED METHODS (New) ====================

  /// PAGINATED: Watch notifications (first page only - real-time)
  Stream<List<NotificationModel>> watchNotificationsFirstPage(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// PAGINATED: Get next page of notifications
  Future<({List<NotificationModel> notifications, DocumentSnapshot? lastDoc, bool hasMore})> 
      getNotificationsNextPage(
    String userId,
    DocumentSnapshot lastDocument,
  ) async {
    final query = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(pageSize);

    final snapshot = await query.get();
    
    return (
      notifications: snapshot.docs
          .map((doc) => NotificationModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  // ==================== COMMON METHODS ====================

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
