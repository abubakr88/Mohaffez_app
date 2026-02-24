// lib/repositories/session_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';
import '../models/request_status.dart'; // â† single source of truth for status strings

/// Provides a Riverpod-compatible repository instance.
/// Usage: ref.watch(sessionRepositoryProvider)
// final sessionRepositoryProvider = Provider<SessionRepository>(
//   (ref) => SessionRepository(FirebaseFirestore.instance),
// );

class SessionRepository {
  final FirebaseFirestore _firestore;
  static const int pageSize = 20;

  SessionRepository(this._firestore);

  // ============================================================================
  // MOHAFFEZ STUDENTS
  // ============================================================================

  /// Get all unique students for a specific mohaffez with their last session.
  Future<List<Map<String, dynamic>>> getMohaffezStudents(
      String mohaffezId) async {
    try {
      debugPrint(
          'SessionRepository: Fetching students for mohaffez $mohaffezId');

      final snapshot = await _firestore
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', whereIn: [
            RequestStatus.accepted,
            'completed',
          ])
          .orderBy('sessionDate', descending: true)
          .get();

      debugPrint(
          'SessionRepository: Found ${snapshot.docs.length} sessions');

      final Map<String, Map<String, dynamic>> studentsMap = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        if (studentId != null && !studentsMap.containsKey(studentId)) {
          studentsMap[studentId] = {
            ...data,
            'id': doc.id,
            'studentId': studentId,
            'studentName': data['studentName'] ?? '',
            'lastSessionDate':
                (data['sessionDate'] as Timestamp?)?.toDate(),
            'hifzAssignment': data['hifzAssignment'],
            'murajaAssignment': data['murajaAssignment'],
            'sessionRating': data['sessionRating'] ?? 0,
            'sessionNotes': data['sessionNotes'],
            'previousHifzCompleted': data['previousHifzCompleted'],
            'previousHifzRating': data['previousHifzRating'] ?? 0,
            'previousMurajaCompleted': data['previousMurajaCompleted'],
            'previousMurajaRating': data['previousMurajaRating'] ?? 0,
            'performanceNotes': data['performanceNotes'],
            'status': data['status'],
          };
        }
      }

      final students = studentsMap.values.toList()
        ..sort((a, b) {
          final dateA = a['lastSessionDate'] as DateTime?;
          final dateB = b['lastSessionDate'] as DateTime?;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

      debugPrint(
          'SessionRepository: Returning ${students.length} unique students');
      return students;
    } catch (e) {
      debugPrint(
          'SessionRepository: Error getting mohaffez students: $e');
      rethrow;
    }
  }

  /// Get total session count for a specific student with a mohaffez.
  Future<int> getStudentSessionCountWithMohaffez(
      String mohaffezId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('studentId', isEqualTo: studentId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint(
          'SessionRepository: Error getting student session count: $e');
      return 0;
    }
  }

  // ============================================================================
  // TEACHER PENDING REQUESTS â€” CANONICAL QUERY (single source of truth)
  // ============================================================================

  /// [PRIMARY] Real-time stream of ALL pending requests for a teacher.
  ///
  /// Rules:
  /// - NO date filter: teachers must see every pending request regardless of
  ///   whether the slot date has passed (they need to reject stale ones too).
  /// - Ordered by [slotDate] ascending = nearest upcoming session shown first.
  /// - Covers all three teacher-inbox statuses via [RequestStatus.teacherInbox].
  ///
  /// Required Firestore composite index:
  ///   Collection: sessionRequests
  ///   Fields: mohaffezId ASC Â· status ASC Â· slotDate ASC
  Stream<List<SessionRequestModel>> watchPendingRequests(
      String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereIn: RequestStatus.teacherInbox)
        .orderBy('slotDate', descending: false) // nearest first
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionRequestModel.fromJson(
                {...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Alias kept for backward compatibility with any code still calling
  /// [watchPendingRequestsFirstPage]. Both delegate to [watchPendingRequests].
  Stream<List<SessionRequestModel>> watchPendingRequestsFirstPage(
          String mohaffezId) =>
      watchPendingRequests(mohaffezId);

  /// Non-paginated one-shot fetch of all pending requests (for export/admin).
  Future<List<SessionRequestModel>> getPendingRequests(
      String mohaffezId) async {
    final snapshot = await _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereIn: RequestStatus.teacherInbox)
        .orderBy('slotDate', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => SessionRequestModel.fromJson(
            {...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Paginated load-more for the pending requests list.
  ///
  /// FIX: was `.where('status', isEqualTo: 'pending')` â€” this dropped all
  /// [awaitingPayment] and [awaitingDirectPayment] requests on page 2+.
  Future<({
    List<SessionRequestModel> requests,
    DocumentSnapshot? lastDoc,
    bool hasMore,
  })> getPendingRequestsNextPage({
    required String mohaffezId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query query = _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereIn: RequestStatus.teacherInbox) // â† FIXED
        .orderBy('slotDate', descending: false);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();
    return (
      requests: snapshot.docs
          .map((doc) => SessionRequestModel.fromJson({
                ...doc.data()! as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList(),
      lastDoc:
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  // ============================================================================
  // SESSION STREAMS (Real-time)
  // ============================================================================

  /// Watch all sessions for a mohaffez (real-time), newest first.
  Stream<List<SessionModel>> watchAcceptedSessions(String mohaffezId) {
    return _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionModel.fromJson(
                {...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Watch all sessions for a student (real-time), newest first.
  Stream<List<SessionModel>> watchStudentSessions(String studentId) {
    return _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionModel.fromJson(
                {...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Watch a student's own requests (real-time).
  /// Excludes [accepted] â€” once accepted it becomes a session, not a request.
  Stream<List<SessionRequestModel>> watchStudentRequests(
      String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: RequestStatus.studentVisible)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) =>
                doc.data()['status'] != RequestStatus.accepted ||
                doc.data()['sessionId'] == null)
            .map((doc) => SessionRequestModel.fromJson(
                {...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ============================================================================
  // CREATE SESSION REQUEST
  // ============================================================================

  /// Creates a sessionRequest document on the client path.
  ///
  /// FIX: previously stored [slotStart] in the [slotDate] field, causing the
  /// Firestore date-filter query to exclude requests where slotDate appeared to
  /// be in the past (off-by-timezone). Now stores each field correctly:
  /// - [slotDate] = midnight DateTime of the calendar day  â† was broken
  /// - [slotStart] = exact session start time
  /// - [slotEnd]   = exact session end time
  @Deprecated('Use BookingService.createSessionRequest() in '
      'booking_provider.dart which calls the Cloud Function. '
      'This method now delegates to the CF internally.')
  Future<String> createSessionRequest({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required DateTime slotDate,
    required DateTime slotStart,
    required DateTime slotEnd,
    required String sessionType,
    required String timeSlot,
    required Map<String, dynamic> additionalData,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createSessionRequest',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call({
      'mohaffezId': mohaffezId,
      'studentId': studentId,
      'studentName': studentName,
      'mohaffezName': mohaffezName,
      'slotDate': slotDate.toIso8601String(),
      'slotStart': slotStart.toIso8601String(),
      'slotEnd': slotEnd.toIso8601String(),
      'sessionType': sessionType,
      'preferredTimeSlot': timeSlot,
      ...additionalData,
    });
    return (result.data as Map)['requestId'] as String;
  }

  // ============================================================================
  // PAGINATED METHODS â€” Sessions
  // ============================================================================

  /// Next page of accepted sessions for a mohaffez.
  Future<({
    List<SessionModel> sessions,
    DocumentSnapshot? lastDoc,
    bool hasMore,
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
                ...doc.data()! as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList(),
      lastDoc:
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Next page of sessions for a student.
  Future<({
    List<SessionModel> sessions,
    DocumentSnapshot? lastDoc,
    bool hasMore,
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
                ...doc.data()! as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList(),
      lastDoc:
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Next page of requests for a student.
  Future<({
    List<SessionRequestModel> requests,
    DocumentSnapshot? lastDoc,
    bool hasMore,
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
                ...doc.data()! as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList(),
      lastDoc:
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  // ============================================================================
  // NON-PAGINATED METHODS
  // ============================================================================

  /// All sessions for a mohaffez (one-shot, for export/admin use).
  Future<List<SessionModel>> getMohaffezSessions(
      String mohaffezId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .get();
    return snapshot.docs
        .map((doc) =>
            SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// All sessions for a student (one-shot).
  Future<List<SessionModel>> getStudentSessions(
      String studentId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .get();
    return snapshot.docs
        .map((doc) =>
            SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// All requests for a student (one-shot).
  Future<List<SessionRequestModel>> getStudentRequests(
      String studentId) async {
    final snapshot = await _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => SessionRequestModel.fromJson(
            {...doc.data(), 'id': doc.id}))
        .toList();
  }

  // ============================================================================
  // WRITE METHODS
  // ============================================================================

  /// Accept a session request and create the session atomically.

  Future<void> acceptRequest(String requestId) async {
    final requestRef = _firestore.collection('sessionRequests').doc(requestId);
    final requestSnap = await requestRef.get();
    if (!requestSnap.exists) {
      throw StateError('Session request not found: $requestId');
    }

    final requestData = requestSnap.data()!;
    final studentId = requestData['studentId'] as String?;
    final mohaffezId = requestData['mohaffezId'] as String?;
    final studentName = requestData['studentName'] as String?;
    final mohaffezName = requestData['mohaffezName'] as String?;
    final sessionType = requestData['sessionType'] as String?;
    final preferredTimeSlot = requestData['preferredTimeSlot'] as String?;
    final slotDate = requestData['slotDate'] as Timestamp?;
    final slotStart = requestData['slotStart'] as Timestamp?;
    final slotEnd = requestData['slotEnd'] as Timestamp?;
    final imamAddressText = requestData['imamAddressText'] as String?;
    final imamAddressLat = requestData['imamAddressLat'];
    final imamAddressLng = requestData['imamAddressLng'];
    final mohaffezPhone = requestData['mohaffezPhone'] as String?;
    final requiresPaymentOnAcceptance =
        requestData['requiresPaymentOnAcceptance'] as bool? ?? false;

    if (studentId == null ||
        mohaffezId == null ||
        studentName == null ||
        mohaffezName == null ||
        sessionType == null ||
        preferredTimeSlot == null ||
        slotDate == null ||
        slotStart == null ||
        slotEnd == null) {
      throw StateError(
          'Session request missing required fields for acceptance: $requestId');
    }

    final sessionRef = _firestore.collection('hafizSessions').doc();
    final dayOfWeek = slotDate.toDate().weekday;
    final availabilityQuery = await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .get();

    DocumentReference<Map<String, dynamic>>? availabilityRef;
    List<Map<String, dynamic>>? updatedSlots;
    if (availabilityQuery.docs.isNotEmpty) {
      final availabilityDoc = availabilityQuery.docs.first;
      final availabilityData = availabilityDoc.data();
      final timeSlots =
          List<Map<String, dynamic>>.from(availabilityData['timeSlots'] ?? []);
      final normalizedPreferred = preferredTimeSlot.replaceAll(' ', '');

      var changed = false;
      for (var i = 0; i < timeSlots.length; i++) {
        final slot = Map<String, dynamic>.from(timeSlots[i]);
        final slotTime =
            '${slot['startTime']}-${slot['endTime']}'.replaceAll(' ', '');
        if (slotTime == normalizedPreferred &&
            slot['sessionType'] == sessionType &&
            slot['enabled'] == true) {
          slot['enabled'] = false;
          timeSlots[i] = slot;
          changed = true;
          break;
        }
      }

      if (changed) {
        availabilityRef = availabilityDoc.reference;
        updatedSlots = timeSlots;
      }
    }

    final batch = _firestore.batch();
    batch.update(requestRef, {
      'status': RequestStatus.accepted,
      'acceptedAt': FieldValue.serverTimestamp(),
      'sessionId': sessionRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(sessionRef, {
      'requestId': requestId,
      'mohaffezId': mohaffezId,
      'studentId': studentId,
      'mohaffezName': mohaffezName,
      'studentName': studentName,
      'sessionType': sessionType,
      'preferredTimeSlot': preferredTimeSlot,
      'timeSlot': preferredTimeSlot,
      'sessionDate': slotDate,
      'slotStart': slotStart,
      'slotEnd': slotEnd,
      'location': imamAddressText ?? '',
      'imamAddressText': imamAddressText,
      'imamAddressLat': imamAddressLat,
      'imamAddressLng': imamAddressLng,
      'mohaffezPhone': mohaffezPhone,
      'status': RequestStatus.accepted,
      'isPaid': requiresPaymentOnAcceptance == false,
      'sessionPrice': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': FieldValue.serverTimestamp(),
      'reminder24hSent': false,
      'reminder1hSent': false,
      'juzCount': 1,
      'sessionRating': 10,
    });

    if (availabilityRef != null && updatedSlots != null) {
      batch.update(availabilityRef, {
        'timeSlots': updatedSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'userId': studentId,
      'recipientId': studentId,
      'senderId': mohaffezId,
      'title': 'تم قبول طلبك',
      'body': mohaffezName,
      'type': 'sessionconfirmed',
      'isRead': false,
      'data': {
        'sessionId': sessionRef.id,
        'requestId': requestId,
        'mohaffezId': mohaffezId,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Reject a session request.
  Future<void> rejectRequest(String requestId) async {
    await _firestore
        .collection('sessionRequests')
        .doc(requestId)
        .update({'status': RequestStatus.rejected});
  }

  /// Update session assignment fields (hifz, muraja, rating, notes).
  Future<void> updateSessionAssignment({
    required String sessionId,
    required String hifzAssignment,
    required String murajaAssignment,
    required int rating,
    required String notes,
  }) async {
    await _firestore
        .collection('hafizSessions')
        .doc(sessionId)
        .update({
      'hifzAssignment': hifzAssignment,
      'murajaAssignment': murajaAssignment,
      'sessionRating': rating,
      'sessionNotes': notes,
    });
  }

  // ============================================================================
  // QUERY METHODS
  // ============================================================================

  /// Get the next 3 upcoming sessions for a mohaffez.
  Future<List<SessionModel>> getUpcomingSessions(
      String mohaffezId) async {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('sessionDate',
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(todayStart))
        .orderBy('sessionDate')
        .limit(3)
        .get();
    return snapshot.docs
        .map((doc) =>
            SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Fetch a single session by its Firestore document ID.
  Future<SessionModel?> getSessionById(String sessionId) async {
    final doc = await _firestore
        .collection('hafizSessions')
        .doc(sessionId)
        .get();
    if (!doc.exists) return null;
    return SessionModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Fetch a single session request by its Firestore document ID.
  Future<SessionRequestModel?> getRequestById(
      String requestId) async {
    final doc = await _firestore
        .collection('sessionRequests')
        .doc(requestId)
        .get();
    if (!doc.exists) return null;
    return SessionRequestModel.fromJson(
        {...doc.data()!, 'id': doc.id});
  }

  /// Aggregate count of all sessions for a mohaffez.
  Future<int> getMohaffezSessionCount(String mohaffezId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Aggregate count of all sessions for a student.
  Future<int> getStudentSessionCount(String studentId) async {
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ============================================================================
  // DELETE / BATCH METHODS
  // ============================================================================

  /// Delete a session document (admin/cleanup only).
  Future<void> deleteSession(String sessionId) async {
    await _firestore
        .collection('hafizSessions')
        .doc(sessionId)
        .delete();
  }

  /// Delete a session request document (admin/cleanup only).
  Future<void> deleteRequest(String requestId) async {
    await _firestore
        .collection('sessionRequests')
        .doc(requestId)
        .delete();
  }

  /// Apply the same [updates] map to multiple sessions in a single batch write.
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
