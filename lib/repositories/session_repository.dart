// lib/repositories/session_repository.dart (COMPLETE FIXED VERSION)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';

class SessionRepository {
  final FirebaseFirestore _firestore;
  static const int pageSize = 20;

  SessionRepository(this._firestore);

  // ============================================================================
  // STREAM METHODS (Real-time first page)
  // ============================================================================

  /// Watch first page of pending requests (real-time)
  Stream<List<SessionRequestModel>> watchPendingRequestsFirstPage(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

// lib/repositories/session_repository.dart (ADD THESE METHODS)

  // ============================================================================
  // WATCH METHODS (Real-time, all items - for backward compatibility)
  // ============================================================================

  /// Watch all accepted sessions for mohaffez (real-time)
  Stream<List<SessionModel>> watchAcceptedSessions(String mohaffezId) {
    return _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id
                }))
            .toList());
  }

  /// Watch all sessions for student (real-time)
  Stream<List<SessionModel>> watchStudentSessions(String studentId) {
    return _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id
                }))
            .toList());
  }

  /// Watch all requests for student (real-time)
  Stream<List<SessionRequestModel>> watchStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id
                }))
            .toList());
  }

  /// Create a new session request
  Future<String> createSessionRequest({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required DateTime slotStart,
    required DateTime slotEnd,
    required String sessionType,
    required String timeSlot,
    required Map<String, dynamic> additionalData,
  }) async {
    final docRef = _firestore.collection('sessionRequests').doc();
    
    await docRef.set({
      'mohaffezId': mohaffezId,
      'studentId': studentId,
      'studentName': studentName,
      'mohaffezName': mohaffezName,
      'slotStart': Timestamp.fromDate(slotStart),
      'slotEnd': Timestamp.fromDate(slotEnd),
      'sessionType': sessionType,
      'preferredTimeSlot': timeSlot,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      ...additionalData,
    });
    
    return docRef.id;
  }

  // ============================================================================
  // PAGINATED METHODS (Load more)
  // ============================================================================

  /// Get next page of pending requests
  Future<({
    List<SessionRequestModel> notifications,
    DocumentSnapshot? lastDoc,
    bool hasMore
  })> getPendingRequestsNextPage({
    required String mohaffezId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();

    return (
      notifications: snapshot.docs
          .map((doc) => SessionRequestModel.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Get next page of accepted sessions
  Future<({
    List<SessionModel> sessions,
    DocumentSnapshot? lastDoc,
    bool hasMore
  })> getAcceptedSessionsNextPage({
    required String mohaffezId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();

    return (
      sessions: snapshot.docs
          .map((doc) => SessionModel.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Get next page of student sessions
  Future<({
    List<SessionModel> sessions,
    DocumentSnapshot? lastDoc,
    bool hasMore
  })> getStudentSessionsNextPage({
    required String studentId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();

    return (
      sessions: snapshot.docs
          .map((doc) => SessionModel.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Get next page of student requests
  Future<({
    List<SessionRequestModel> requests,
    DocumentSnapshot? lastDoc,
    bool hasMore
  })> getStudentRequestsNextPage({
    required String studentId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();

    return (
      requests: snapshot.docs
          .map((doc) => SessionRequestModel.fromJson({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  // ============================================================================
  // NON-PAGINATED METHODS (For compatibility with existing code)
  // ============================================================================

  /// Get all pending requests for a mohaffez (non-paginated)
  Future<List<SessionRequestModel>> getPendingRequests(String mohaffezId) async {
    final snapshot = await _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SessionRequestModel.fromJson({
              ...doc.data(),
              'id': doc.id
            }))
        .toList();
  }

  /// Watch pending requests (real-time, all)
  Stream<List<SessionRequestModel>> watchPendingRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({
                  ...doc.data(),
                  'id': doc.id
                }))
            .toList());
  }

  /// Get all sessions for a mohaffez (non-paginated)
  Future<List<SessionModel>> getMohaffezSessions(String mohaffezId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SessionModel.fromJson({
              ...doc.data(),
              'id': doc.id
            }))
        .toList();
  }

  /// Get all sessions for a student (non-paginated)
  Future<List<SessionModel>> getStudentSessions(String studentId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SessionModel.fromJson({
              ...doc.data(),
              'id': doc.id
            }))
        .toList();
  }

  /// Get all requests for a student (non-paginated)
  Future<List<SessionRequestModel>> getStudentRequests(String studentId) async {
    final snapshot = await _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SessionRequestModel.fromJson({
              ...doc.data(),
              'id': doc.id
            }))
        .toList();
  }

  // ============================================================================
  // WRITE METHODS
  // ============================================================================

  /// Accept a session request
  Future<void> acceptRequest(String requestId) async {
    await _firestore
        .collection('sessionRequests')
        .doc(requestId)
        .update({'status': 'accepted'});
  }

  /// Reject a session request
  Future<void> rejectRequest(String requestId) async {
    await _firestore
        .collection('sessionRequests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  /// Update session assignment (hifz, muraja, rating, notes)
  Future<void> updateSessionAssignment({
    required String sessionId,
    required String hifzAssignment,
    required String murajaAssignment,
    required int rating,
    required String notes,
  }) async {
    await _firestore.collection('hafizSessions').doc(sessionId).update({
      'hifzAssignment': hifzAssignment,
      'murajaAssignment': murajaAssignment,
      'sessionRating': rating,
      'sessionNotes': notes,
    });
  }

  // ============================================================================
  // QUERY METHODS
  // ============================================================================

  /// Get upcoming sessions for a mohaffez (next 3 sessions)
  Future<List<SessionModel>> getUpcomingSessions(String mohaffezId) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('sessionDate')
        .limit(3)
        .get();

    return snapshot.docs
        .map((doc) => SessionModel.fromJson({
              ...doc.data(),
              'id': doc.id
            }))
        .toList();
  }

  /// Get a single session by ID
  Future<SessionModel?> getSessionById(String sessionId) async {
    final doc = await _firestore.collection('hafizSessions').doc(sessionId).get();
    
    if (!doc.exists) return null;
    
    return SessionModel.fromJson({
      ...doc.data()!,
      'id': doc.id
    });
  }

  /// Get a single request by ID
  Future<SessionRequestModel?> getRequestById(String requestId) async {
    final doc = await _firestore.collection('sessionRequests').doc(requestId).get();
    
    if (!doc.exists) return null;
    
    return SessionRequestModel.fromJson({
      ...doc.data()!,
      'id': doc.id
    });
  }

  /// Get total session count for a mohaffez
  Future<int> getMohaffezSessionCount(String mohaffezId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  /// Get total session count for a student
  Future<int> getStudentSessionCount(String studentId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  // ============================================================================
  // DELETE METHODS (Admin/cleanup purposes)
  // ============================================================================

  /// Delete a session
  Future<void> deleteSession(String sessionId) async {
    await _firestore.collection('hafizSessions').doc(sessionId).delete();
  }

  /// Delete a session request
  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('sessionRequests').doc(requestId).delete();
  }

    /// ✅ ADDED: Batch update multiple sessions
  Future<void> batchUpdateSessions(
    List<String> sessionIds,
    Map<String, dynamic> updates,
  ) async {
    final batch = _firestore.batch();
    
    for (final sessionId in sessionIds) {
      batch.update(
        _firestore.collection('hafizSessions').doc(sessionId),
        updates,
      );
    }
    
    await batch.commit();
  }

}
