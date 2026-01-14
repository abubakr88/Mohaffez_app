// lib/repositories/notification_repository.dart

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
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
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

  // ============================================================================
  // QUERY METHODS (Non-paginated)
  // ============================================================================

  /// Get all notifications for user
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

  // ============================================================================
  // SPECIALIZED NOTIFICATION CREATORS
  // ============================================================================

  /// Create notification when session request is created
  Future<String> createSessionRequestNotification({
    required String mohaffezId,
    required String studentName,
    required String sessionType,
    required String preferredTimeSlot,
    required String requestId,
  }) async {
    final docRef = _firestore.collection('notifications').doc();
    
    await docRef.set({
      'userId': mohaffezId,
      'title': 'طلب حجز جديد',
      'body': 'لديك طلب حجز جديد من $studentName لجلسة $sessionType في $preferredTimeSlot',
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
    final docRef = _firestore.collection('notifications').doc();
    
    await docRef.set({
      'userId': studentId,
      'mohaffezId': mohaffezName,
      'mohaffezName': mohaffezName,
      'title': 'تم قبول طلبك',
      'body': 'تم قبول طلب الجلسة مع $mohaffezName في ${sessionDate.day}/${sessionDate.month}/${sessionDate.year}',
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
    final docRef = _firestore.collection('notifications').doc();
    
    String body = 'قام $mohaffezName بإضافة ';
    final List<String> parts = [];
    
    if (hasHifz) parts.add('حفظ جديد');
    if (hasMuraja) parts.add('مراجعة');
    if (rating > 0) parts.add('تقييم ($rating/10)');
    
    body += parts.join(' و ');
    
    await docRef.set({
      'userId': studentId,
      'mohaffezId': mohaffezName,
      'mohaffezName': mohaffezName,
      'title': 'تحديث الواجبات',
      'body': body,
      'type': 'assignment_updated',
      'isRead': false,
      'scheduleId': sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return docRef.id;
  }
}
