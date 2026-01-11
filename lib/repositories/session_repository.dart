// lib/repositories/session_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';

class BookingResult {
  final bool success;
  final String? requestId;
  final String? errorMessage;

  BookingResult.success(this.requestId)
      : success = true,
        errorMessage = null;

  BookingResult.failure(this.errorMessage)
      : success = false,
        requestId = null;
}

class SessionRepository {
  final FirebaseFirestore _firestore;
  static const int pageSize = 20;

  SessionRepository(this._firestore);

  // ==================== PAGINATED METHODS ====================

  /// PAGINATED: Watch accepted sessions for mohaffez (first page only - real-time)
  Stream<List<SessionModel>> watchAcceptedSessionsFirstPage(String mohaffezId) {
    return _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// PAGINATED: Get next page of accepted sessions
  Future<({List<SessionModel> sessions, DocumentSnapshot? lastDoc, bool hasMore})> 
      getAcceptedSessionsNextPage(
    String mohaffezId,
    DocumentSnapshot lastDocument,
  ) async {
    final query = _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .startAfterDocument(lastDocument)
        .limit(pageSize);

    final snapshot = await query.get();
    
    return (
      sessions: snapshot.docs
          .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// PAGINATED: Watch student sessions (first page only - real-time)
  Stream<List<SessionModel>> watchStudentSessionsFirstPage(String studentId) {
    return _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// PAGINATED: Get next page of student sessions
  Future<({List<SessionModel> sessions, DocumentSnapshot? lastDoc, bool hasMore})> 
      getStudentSessionsNextPage(
    String studentId,
    DocumentSnapshot lastDocument,
  ) async {
    final query = _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .startAfterDocument(lastDocument)
        .limit(pageSize);

    final snapshot = await query.get();
    
    return (
      sessions: snapshot.docs
          .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// PAGINATED: Watch pending requests (first page only - real-time)
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

  /// PAGINATED: Get next page of pending requests
  Future<({List<SessionRequestModel> requests, DocumentSnapshot? lastDoc, bool hasMore})> 
      getPendingRequestsNextPage(
    String mohaffezId,
    DocumentSnapshot lastDocument,
  ) async {
    final query = _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(pageSize);

    final snapshot = await query.get();
    
    return (
      requests: snapshot.docs
          .map((doc) => SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// PAGINATED: Watch student requests (first page only - real-time)
  Stream<List<SessionRequestModel>> watchStudentRequestsFirstPage(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// PAGINATED: Get next page of student requests
  Future<({List<SessionRequestModel> requests, DocumentSnapshot? lastDoc, bool hasMore})> 
      getStudentRequestsNextPage(
    String studentId,
    DocumentSnapshot lastDocument,
  ) async {
    final query = _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(pageSize);

    final snapshot = await query.get();
    
    return (
      requests: snapshot.docs
          .map((doc) => SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  // ==================== ORIGINAL NON-PAGINATED METHODS ====================
  // Keep these for backward compatibility and simple use cases

  /// Watch pending session requests for a mohaffez (all items - non-paginated)
  Stream<List<SessionRequestModel>> watchPendingRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Watch accepted sessions for a mohaffez (all items - non-paginated)
  Stream<List<SessionModel>> watchAcceptedSessions(String mohaffezId) {
    return _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Watch accepted sessions for a student (all items - non-paginated)
  Stream<List<SessionModel>> watchStudentSessions(String studentId) {
    return _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Watch session requests for a student (all items - non-paginated)
  Stream<List<SessionRequestModel>> watchStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ==================== TRANSACTION & WRITE METHODS ====================

  /// Create a new session request with conflict checking
  Future<BookingResult> createSessionRequest({
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
    try {
      return await _firestore.runTransaction<BookingResult>((transaction) async {
        // Check for conflicts
        final conflicts = await _firestore
            .collection('sessionRequests')
            .where('mohaffezId', isEqualTo: mohaffezId)
            .where('slotStart', isEqualTo: Timestamp.fromDate(slotStart))
            .where('status', whereIn: ['pending', 'accepted'])
            .get();

        if (conflicts.docs.isNotEmpty) {
          return BookingResult.failure('هذا الموعد محجوز بالفعل. يرجى اختيار موعد آخر.');
        }

        // Create request atomically
        final requestRef = _firestore.collection('sessionRequests').doc();
        transaction.set(requestRef, {
          'studentId': studentId,
          'studentName': studentName,
          'mohaffezId': mohaffezId,
          'mohaffezName': mohaffezName,
          'sessionType': sessionType,
          'preferredTimeSlot': timeSlot,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'slotStart': Timestamp.fromDate(slotStart),
          'slotEnd': Timestamp.fromDate(slotEnd),
          ...additionalData,
        });

        return BookingResult.success(requestRef.id);
      });
    } catch (e) {
      return BookingResult.failure(e.toString());
    }
  }

  /// Accept a session request and create a session
  Future<void> acceptRequest(String requestId, Map<String, dynamic> requestData) async {
    // Create session document
    final sessionRef = _firestore.collection('hafizSessions').doc();
    await sessionRef.set({
      'mohaffezId': requestData['mohaffezId'],
      'studentId': requestData['studentId'],
      'mohaffezName': requestData['mohaffezName'],
      'studentName': requestData['studentName'],
      'sessionType': requestData['sessionType'],
      'location': requestData['imamAddressText'] ?? '',
      'mohaffezPhone': requestData['mohaffezPhone'],
      'imamAddressLat': requestData['imamAddressLat'],
      'imamAddressLng': requestData['imamAddressLng'],
      'preferredTimeSlot': requestData['preferredTimeSlot'],
      'sessionDate': requestData['slotStart'],
      'slotStart': requestData['slotStart'],
      'slotEnd': requestData['slotEnd'],
      'createdAt': FieldValue.serverTimestamp(),
      'juzCount': 1,
      'hifzAssignment': '',
      'murajaAssignment': '',
      'sessionRating': 0,
      'sessionNotes': '',
    });

    // Update request status
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

  // ==================== QUERY METHODS ====================

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
        .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Get a single session by ID
  Future<SessionModel?> getSessionById(String sessionId) async {
    final doc = await _firestore.collection('hafizSessions').doc(sessionId).get();
    
    if (!doc.exists) return null;
    
    return SessionModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Get a single request by ID
  Future<SessionRequestModel?> getRequestById(String requestId) async {
    final doc = await _firestore.collection('sessionRequests').doc(requestId).get();
    
    if (!doc.exists) return null;
    
    return SessionRequestModel.fromJson({...doc.data()!, 'id': doc.id});
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

  /// Delete a session (admin/cleanup purposes)
  Future<void> deleteSession(String sessionId) async {
    await _firestore.collection('hafizSessions').doc(sessionId).delete();
  }

  /// Delete a session request (admin/cleanup purposes)
  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('sessionRequests').doc(requestId).delete();
  }
}
