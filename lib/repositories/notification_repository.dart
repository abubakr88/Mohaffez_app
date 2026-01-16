import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../shared/pagination/firestore_pagination_mixin.dart';
import '../shared/pagination/pagination_result.dart';

class NotificationRepository with FirestorePaginationMixin {
  final FirebaseFirestore firestore;
  static const int pageSize = 20;

  NotificationRepository(this.firestore);

  // ========== STREAM METHODS (Real-time first page) ==========

  /// Watch first page of notifications (real-time, paginated)
  Stream<List<NotificationModel>> watchNotificationsFirstPage(String userId) {
    return watchFirstPage(
      query: firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
      fromFirestore: (doc) => NotificationModel.fromJson({
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      }),
      pageSize: pageSize,
    );
  }

  /// Watch unread count (real-time)
  Stream<int> watchUnreadCount(String userId) {
    return firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Watch ALL notifications for user (real-time, non-paginated)
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  // ========== PAGINATED METHODS (REFACTORED using mixin) ==========

  /// Get next page of notifications
  Future<PaginationResult<NotificationModel>> getNotificationsNextPage({
    required String userId,
    DocumentSnapshot? lastDocument,
  }) async {
    return executePaginatedQuery(
      query: firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
      fromFirestore: (doc) => NotificationModel.fromJson({
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      }),
      lastDocument: lastDocument,
      pageSize: pageSize,
    );
  }

  // ========== QUERY METHODS (Non-paginated) ==========

  /// Get all notifications for user (non-paginated)
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final snapshot = await firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => NotificationModel.fromJson({
              ...doc.data(),
              'id': doc.id,
            }))
        .toList();
  }

  /// Get single notification by ID
  Future<NotificationModel?> getNotificationById(String notificationId) async {
    final doc = await firestore
        .collection('notifications')
        .doc(notificationId)
        .get();

    if (!doc.exists) return null;
    return NotificationModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ========== WRITE METHODS ==========

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    await firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    final batch = firestore.batch();
    for (final id in notificationIds) {
      batch.update(
        firestore.collection('notifications').doc(id),
        {'isRead': true},
      );
    }
    await batch.commit();
  }

  /// Mark all notifications as read for a user
  /// ✅ OPTIMIZED: Mark all as read with batch
  Future<void> markAllAsRead(String userId) async {
    final batch = firestore.batch();
    final snapshot = await firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(500) // Firestore batch limit
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Create a notification (generic)
  Future<String> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    bool isRead = false,
    String? scheduleId,
    String? mohaffezId,
    String? mohaffezName,
  }) async {
    final docRef = firestore.collection('notifications').doc();
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
    await firestore.collection('notifications').doc(notificationId).delete();
  }

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    final batch = firestore.batch();
    final snapshot = await firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ========== SPECIALIZED NOTIFICATION CREATORS ==========

  /// Create notification when session request is created
  Future<String> createSessionRequestNotification({
    required String mohaffezId,
    required String studentName,
    required String sessionType,
    required String preferredTimeSlot,
    required String requestId,
  }) async {
    final docRef = firestore.collection('notifications').doc();
    await docRef.set({
      'userId': mohaffezId,
      'title': 'طلب حجز جديد',
      'body': '$studentName - $sessionType - $preferredTimeSlot',
      'type': 'session_request',
      'isRead': false,
      'scheduleId': requestId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Create notification when session is accepted
  Future<String> createSessionAcceptedNotification({
    required String studentId,
    required String mohaffezName,
    required String sessionType,
    required DateTime sessionDate,
    required String sessionId,
  }) async {
    final docRef = firestore.collection('notifications').doc();
    await docRef.set({
      'userId': studentId,
      'mohaffezId': mohaffezName,
      'mohaffezName': mohaffezName,
      'title': 'تم قبول طلبك',
      'body':
          '$mohaffezName - ${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
      'type': 'session_accepted',
      'isRead': false,
      'scheduleId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Create notification when assignment is updated
  Future<String> createAssignmentUpdatedNotification({
    required String studentId,
    required String mohaffezName,
    required String sessionId,
    required bool hasHifz,
    required bool hasMuraja,
    required int rating,
  }) async {
    final docRef = firestore.collection('notifications').doc();
    String body = '$mohaffezName - ';
    final List<String> parts = [];
    if (hasHifz) parts.add('حفظ');
    if (hasMuraja) parts.add('مراجعة');
    if (rating > 0) parts.add('$rating/10');
    body += parts.join(' - ');

    await docRef.set({
      'userId': studentId,
      'mohaffezId': mohaffezName,
      'mohaffezName': mohaffezName,
      'title': 'تم تحديث الواجب',
      'body': body,
      'type': 'assignment_updated',
      'isRead': false,
      'scheduleId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }


}
