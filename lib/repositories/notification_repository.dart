// lib/repositories/notification_repository.dart (COMPLETE - ~250 lines)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;
  static const int pageSize = 20;

  NotificationRepository(this._firestore);

  // ============================================================================
  // STREAM METHODS (Real-time)
  // ============================================================================

  /// Watch first page of notifications (real-time, paginated)
  Stream<List<NotificationModel>> watchNotificationsFirstPage(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id
                }))
            .toList());
  }

  /// Watch ALL notifications for user (real-time, non-paginated)
  /// Use this for backward compatibility or simple cases
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100) // Reasonable limit to prevent excessive data
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id
                }))
            .toList());
  }

  // ============================================================================
  // PAGINATED METHODS
  // ============================================================================

  /// Get next page of notifications
  Future<({
    List<NotificationModel> notifications,
    DocumentSnapshot? lastDoc,
    bool hasMore
  })> getNotificationsNextPage(
    String userId,
    DocumentSnapshot? lastDocument,
  ) async {
    Query query = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    // Start after last document if provided
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();

    return (
      notifications: snapshot.docs
          .map((doc) => NotificationModel.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Get specific page (helper method for recovering pagination state)
  Future<({
    List<NotificationModel> notifications,
    DocumentSnapshot? lastDoc,
    bool hasMore
  })> getNotificationsPage(
    String userId, {
    int limit = 20,
  }) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return (
      notifications: snapshot.docs
          .map((doc) => NotificationModel.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }

  // ============================================================================
  // QUERY METHODS (Non-paginated)
  // ============================================================================

  /// Get all notifications for user (non-paginated, one-time fetch)
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromJson({
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id
            }))
        .toList();
  }

  /// Get single notification by ID
  Future<NotificationModel?> getNotificationById(String notificationId) async {
    final doc = await _firestore
        .collection('notifications')
        .doc(notificationId)
        .get();

    if (!doc.exists) return null;

    return NotificationModel.fromJson({
      ...doc.data()! as Map<String, dynamic>,
      'id': doc.id
    });
  }

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

  /// Watch unread count (real-time)
  Stream<int> watchUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ============================================================================
  // WRITE METHODS
  // ============================================================================

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    final batch = _firestore.batch();

    for (final id in notificationIds) {
      batch.update(
        _firestore.collection('notifications').doc(id),
        {'isRead': true},
      );
    }

    await batch.commit();
  }

  /// Mark all notifications as read for a user
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

  /// Create a notification (for admin/system use)
  Future<String> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type, // 'session', 'follow', 'system'
    bool isRead = false,
    String? scheduleId,
    String? mohaffezId,
    String? mohaffezName,
  }) async {
    final docRef = _firestore.collection('notifications').doc();

    await docRef.set({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'scheduleId': scheduleId,
      'mohaffezId': mohaffezId,
      'mohaffezName': mohaffezName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  /// Delete multiple notifications
  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    final batch = _firestore.batch();

    for (final id in notificationIds) {
      batch.delete(_firestore.collection('notifications').doc(id));
    }

    await batch.commit();
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

  /// Delete old notifications (cleanup utility)
  Future<int> deleteOldNotifications({
    required String userId,
    required Duration olderThan,
  }) async {
    final cutoffDate = DateTime.now().subtract(olderThan);
    final batch = _firestore.batch();

    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    return snapshot.docs.length;
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Get notifications for multiple users (admin use)
  Future<Map<String, List<NotificationModel>>> getNotificationsForUsers(
    List<String> userIds,
  ) async {
    final Map<String, List<NotificationModel>> results = {};

    // Firestore 'in' query limit is 10
    final chunks = _chunkList(userIds, 10);

    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      for (final doc in snapshot.docs) {
        final notification = NotificationModel.fromJson({
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id
        });

        results.putIfAbsent(notification.userId, () => []);
        results[notification.userId]!.add(notification);
      }
    }

    return results;
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Chunk list into smaller lists (for batch operations)
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize),
      );
    }
    return chunks;
  }
}
