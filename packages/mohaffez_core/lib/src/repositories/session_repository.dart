// lib/repositories/session_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';
import '../models/subscription_model.dart';
import '../models/request_status.dart'; // ← single source of truth for status strings

class SessionRepository {
  final FirebaseFirestore _firestore;
  static const int pageSize = 20;

  SessionRepository(this._firestore);

  // ============================================================================
  // MOHAFFEZ STUDENTS
  // ============================================================================

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
      debugPrint('SessionRepository: Error getting student session count: $e');
      return 0;
    }
  }

  // ============================================================================
  // TEACHER PENDING REQUESTS — CANONICAL QUERY (single source of truth)
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
  ///   Fields: mohaffezId ASC · status ASC · slotDate ASC
  Stream<List<SessionRequestModel>> watchPendingRequests(String mohaffezId) {
    return _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereNotIn: RequestStatus.teacherInboxExcluded)
        .orderBy('slotDate', descending: false) // nearest first
        .limit(100)
        .snapshots()
        .asyncMap((snap) async {
      final docs = snap.docs;
      final studentIds = docs
          .map((doc) => doc.data()['studentId'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final studentAges = <String, int?>{};
      await Future.wait(
        studentIds.map((studentId) async {
          final userDoc =
              await _firestore.collection('users').doc(studentId).get();
          final data = userDoc.data();
          final dob = data?['dateOfBirth'];
          studentAges[studentId] = _calculateAgeFromField(dob);
        }),
      );

      return docs.map((doc) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        return SessionRequestModel.fromJson({
          ...data,
          'id': doc.id,
          'studentAge': studentId != null ? studentAges[studentId] : null,
        });
      }).toList();
    });
  }

  /// Non-paginated one-shot fetch of all pending requests (for export/admin).
  Future<List<SessionRequestModel>> getPendingRequests(String mohaffezId,
      {int? limit}) async {
    var query = _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereNotIn: RequestStatus.teacherInboxExcluded)
        .orderBy('slotDate', descending: false);
    if (limit != null) query = query.limit(limit);
    final snapshot = await query.get();

    final studentIds = snapshot.docs
        .map((doc) => doc.data()['studentId'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final studentAges = <String, int?>{};
    await Future.wait(
      studentIds.map((studentId) async {
        final userDoc =
            await _firestore.collection('users').doc(studentId).get();
        final data = userDoc.data();
        studentAges[studentId] = _calculateAgeFromField(data?['dateOfBirth']);
      }),
    );

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final studentId = data['studentId'] as String?;
      return SessionRequestModel.fromJson({
        ...data,
        'id': doc.id,
        'studentAge': studentId != null ? studentAges[studentId] : null,
      });
    }).toList();
  }

  int? _calculateAgeFromField(Object? rawDob) {
    DateTime? dob;
    if (rawDob is Timestamp) {
      dob = rawDob.toDate();
    } else if (rawDob is DateTime) {
      dob = rawDob;
    }
    if (dob == null) return null;

    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }

  /// Paginated load-more for the pending requests list.
  ///
  /// FIX: was `.where('status', isEqualTo: 'pending')` — this dropped all
  /// [awaitingPayment] and [awaitingDirectPayment] requests on page 2+.
  Future<
      ({
        List<SessionRequestModel> requests,
        DocumentSnapshot? lastDoc,
        bool hasMore,
      })> getPendingRequestsNextPage({
    required String mohaffezId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', whereNotIn: RequestStatus.teacherInboxExcluded)
        .orderBy('slotDate', descending: false);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(pageSize).get();
    return (
      requests: snapshot.docs
          .map((doc) => SessionRequestModel.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
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
            .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
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
            .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Watch a student's own requests (real-time).
  /// Excludes [accepted] requests that already have a [sessionId] — once
  /// accepted and a hafizSession is created they should not appear here too.
  Stream<List<SessionRequestModel>> watchStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: RequestStatus.studentVisible)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            // FIX: hide accepted requests that already became a hafizSession
            // to prevent the same booking rendering twice on the home screen.
            .where((doc) =>
                doc.data()['status'] != RequestStatus.accepted ||
                doc.data()['sessionId'] == null)
            .map((doc) =>
                SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
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
  ///   - [slotDate]  = midnight DateTime of the calendar day ← was broken
  ///   - [slotStart] = exact session start time
  ///   - [slotEnd]   = exact session end time
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
      // Always UTC — server parseFlutterDate assumes naive strings are UTC,
      // so sending local time without `.toUtc()` shifts the stored value by
      // the device's UTC offset (e.g. +3h in Cairo).
      'slotDate': slotDate.toUtc().toIso8601String(),
      'slotStart': slotStart.toUtc().toIso8601String(),
      'slotEnd': slotEnd.toUtc().toIso8601String(),
      'sessionType': sessionType,
      'preferredTimeSlot': timeSlot,
      ...additionalData,
    });
    return (result.data as Map<String, dynamic>)['requestId'] as String;
  }

  // ============================================================================
  // PAGINATED METHODS — Sessions
  // ============================================================================

  /// Next page of accepted sessions for a mohaffez.
  Future<
      ({
        List<SessionModel> sessions,
        DocumentSnapshot? lastDoc,
        bool hasMore,
      })> getAcceptedSessionsNextPage({
    required String mohaffezId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
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
                ...doc.data(),
                'id': doc.id,
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Next page of sessions for a student.
  Future<
      ({
        List<SessionModel> sessions,
        DocumentSnapshot? lastDoc,
        bool hasMore,
      })> getStudentSessionsNextPage({
    required String studentId,
    DocumentSnapshot? lastDocument,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
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
                ...doc.data(),
                'id': doc.id,
              }))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  /// Next page of requests for a student.
  // ✅ FIXED: added Firestore-level status filter for consistency with
  // watchStudentRequests, and preserved the client-side accepted+sessionId guard.
  Future<
      ({
        List<SessionRequestModel> requests,
        DocumentSnapshot? lastDoc,
        bool hasMore,
      })> getStudentRequestsNextPage({
    required String studentId,
    DocumentSnapshot? lastDocument,
  }) async {
    // BUG FIX #5: Added `.where('status', whereIn: RequestStatus.studentVisible)`
    // The original query had no status filter at all, unlike watchStudentRequests.
    // This meant paginated pages could surface internal-status requests that are
    // never visible on page 1, creating an inconsistent experience.
    Query<Map<String, dynamic>> query = _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .where('status', whereIn: RequestStatus.studentVisible)
        .orderBy('createdAt', descending: true);

    if (lastDocument != null) query = query.startAfterDocument(lastDocument);

    final snapshot = await query.limit(pageSize).get();
    return (
      requests: snapshot.docs
          // FIX: same guard as watchStudentRequests —
          // hide accepted requests once a hafizSession is created.
          .where((doc) =>
              doc.data()['status'] != RequestStatus.accepted ||
              doc.data()['sessionId'] == null)
          .map((doc) =>
              SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList(),
      lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == pageSize,
    );
  }

  // ============================================================================
  // NON-PAGINATED METHODS
  // ============================================================================

  /// All sessions for a mohaffez (one-shot, for export/admin use).
  Future<List<SessionModel>> getMohaffezSessions(String mohaffezId,
      {int? limit}) async {
    var query = _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true);
    if (limit != null) query = query.limit(limit);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// All sessions for a student (one-shot).
  Future<List<SessionModel>> getStudentSessions(String studentId,
      {int? limit}) async {
    var query = _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true);
    if (limit != null) query = query.limit(limit);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// All requests for a student (one-shot).
  /// NOTE: intentionally returns all statuses — used for export/admin.
  /// UI-facing code should use [watchStudentRequests] or
  /// [getStudentRequestsNextPage] which apply the studentVisible filter.
  Future<List<SessionRequestModel>> getStudentRequests(String studentId) async {
    final snapshot = await _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) =>
            SessionRequestModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  // ============================================================================
  // WRITE METHODS
  // ============================================================================

  /// Accept a session request and create the session atomically.
  ///
  /// BUG FIX #1 + #2 + #3:
  /// The original code ALWAYS created a [hafizSession] document regardless of
  /// [requiresPaymentOnAcceptance]. When that flag is true the Cloud Function
  /// creates the real session after payment is confirmed, resulting in two
  /// [hafizSession] docs for the same booking (= duplicated cards on the home
  /// screen).
  ///
  /// Fixed behaviour:
  ///   • requiresPaymentOnAcceptance == false  →  set request to [accepted],
  ///     create session immediately with isPaid:true, set
  ///     notificationsAlreadySent:true on both docs so the Firestore triggers
  ///     (onSessionCreated / onSessionRequestAccepted) do not send a second
  ///     push notification, send one inline notification.
  ///   • requiresPaymentOnAcceptance == true   →  set request to
  ///     [awaitingPayment] ONLY — do NOT create the session (the CF does that
  ///     after payment). Do NOT send an inline notification (the CF trigger
  ///     onSessionRequestAccepted handles it to avoid a double notification).
  Future<void> acceptRequest(
    String requestId, {
    required double sessionPrice,
  }) async {
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
    final studentPhone = requestData['studentPhone'] as String?;
    final preferredProvider = requestData['preferredProvider'] as String?;
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

    // ── Availability slot disable (shared by both paths) ─────────────────────
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

    if (!requiresPaymentOnAcceptance) {
      // ── PATH A: no payment required — accept immediately ─────────────────
      // BUG FIX #2: use RequestStatus.accepted (was incorrectly awaitingPayment)
      // BUG FIX #3: set notificationsAlreadySent:true to suppress the
      //             onSessionRequestAccepted CF trigger sending a duplicate
      //             push notification.
      final sessionRef = _firestore.collection('hafizSessions').doc();

      batch.update(requestRef, {
        'status': RequestStatus.accepted, // FIX #2
        'acceptedAt': FieldValue.serverTimestamp(),
        'sessionId': sessionRef.id,
        'notificationsAlreadySent': true, // FIX #3
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // BUG FIX #1: session is only created here, on the no-payment path.
      // BUG FIX #3: notificationsAlreadySent:true suppresses onSessionCreated
      //             trigger so it does not fire a second push notification.
      batch.set(sessionRef, {
        'requestId': requestId,
        'mohaffezId': mohaffezId,
        'studentId': studentId,
        'mohaffezName': mohaffezName,
        'studentName': studentName,
        'sessionType': sessionType,
        if (preferredProvider != null) 'preferredProvider': preferredProvider,
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
        'studentPhone': studentPhone,
        'status': RequestStatus.accepted,
        'isPaid': true, // no payment needed = paid
        'sessionPrice': sessionPrice,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'reminder24hSent': false,
        'reminder1hSent': false,
        'juzCount': 1,
        'sessionRating': 10,
        'notificationsAlreadySent': true, // FIX #3
      });

      // Inline notification — safe because notificationsAlreadySent:true
      // prevents the CF trigger from firing a duplicate.
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
    } else {
      // ── PATH B: payment required — only update the request ───────────────
      // BUG FIX #1: do NOT create a hafizSession here. The CF creates it
      //             atomically after the student pays, preventing duplication.
      // BUG FIX #3: do NOT send an inline notification. The CF trigger
      //             onSessionRequestAccepted fires on the awaitingPayment
      //             status change and sends the "payment required" notification
      //             to the student. A second notification here would duplicate it.
      final deadline = DateTime.now().add(const Duration(hours: 24));

      batch.update(requestRef, {
        'status': RequestStatus.awaitingPayment,
        'acceptedAt': FieldValue.serverTimestamp(),
        'paymentDeadline': Timestamp.fromDate(deadline),
        'reminderSent': false,
        'paymentAmount': sessionPrice,
        // NOTE: sessionId intentionally omitted — no session doc exists yet.
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Disable availability slot (both paths)
    if (availabilityRef != null && updatedSlots != null) {
      batch.update(availabilityRef, {
        'timeSlots': updatedSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Reject a session request.
  Future<void> rejectRequest(
    String requestId, [
    String? reason,
  ]) async {
    await _firestore.collection('sessionRequests').doc(requestId).update({
      'status': RequestStatus.rejected,
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update session assignment fields (hifz, muraja, rating, notes).
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
      'status': 'completed', // FIX: BUG #1
      'completedAt': FieldValue.serverTimestamp(), // FIX: BUG #1
    });
  }

  // ============================================================================
  // QUERY METHODS
  // ============================================================================

  /// Get the next 3 upcoming sessions for a mohaffez.
  Future<List<SessionModel>> getUpcomingSessions(String mohaffezId) async {
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    // BUG FIX #4: added status filter — the original query returned completed
    // sessions too because it only filtered by date, not by status.
    final snapshot = await _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: RequestStatus.accepted) // FIX #4
        .where('sessionDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('sessionDate')
        .limit(3)
        .get();
    return snapshot.docs
        .map((doc) => SessionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  /// Fetch a single session by its Firestore document ID.
  Future<SessionModel?> getSessionById(String sessionId) async {
    final doc =
        await _firestore.collection('hafizSessions').doc(sessionId).get();
    if (!doc.exists) return null;
    return SessionModel.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Fetch a single session request by its Firestore document ID.
  Future<SessionRequestModel?> getRequestById(String requestId) async {
    final doc =
        await _firestore.collection('sessionRequests').doc(requestId).get();
    if (!doc.exists) return null;
    return SessionRequestModel.fromJson({...doc.data()!, 'id': doc.id});
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
    await _firestore.collection('hafizSessions').doc(sessionId).delete();
  }

  /// Delete a session request document (admin/cleanup only).
  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('sessionRequests').doc(requestId).delete();
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

  // ============================================================================
  // BUNDLE / SUBSCRIPTION
  // ============================================================================

  /// Get active bundle for a student + mohaffez combination.
  ///
  /// FIX: added optional [sessionType] filter so a student with both an
  /// 'online' and a 'home' bundle for the same teacher gets the correct one.
  /// Passing null keeps all existing callers working without changes.
  Future<ActiveBundleInfo?> getActiveBundle({
    required String studentId,
    required String mohaffezId,
    String? sessionType, // FIX: optional — null = no filter (backward compat)
  }) async {
    try {
      debugPrint(
          '🔍 getActiveBundle: studentId=$studentId mohaffezId=$mohaffezId sessionType=$sessionType');

      var query = _firestore
          .collection('subscriptions')
          .where('studentId', isEqualTo: studentId)
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'active')
          .where('remainingSessions', isGreaterThan: 0);

      // FIX: only filter by sessionType when provided
      if (sessionType != null && sessionType.isNotEmpty) {
        query = query.where('sessionType', isEqualTo: sessionType);
      }

      final snapshot = await query.limit(1).get();
      debugPrint('🔍 getActiveBundle: found ${snapshot.docs.length} docs');

      if (snapshot.docs.isEmpty) return null;
      return ActiveBundleInfo.fromMap(
        snapshot.docs.first.data(),
        snapshot.docs.first.id,
      );
    } catch (e, stack) {
      debugPrint('❌ getActiveBundle FAILED: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  /// Real-time stream of the active bundle for a specific
  /// (student, mohaffez, sessionType).
  /// Returns null if no active bundle exists.
  Stream<ActiveBundleInfo?> watchActiveBundle({
    required String studentId,
    required String mohaffezId,
    required String sessionType,
  }) {
    return _firestore
        .collection('subscriptions')
        .where('studentId', isEqualTo: studentId)
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('sessionType', isEqualTo: sessionType)
        .where('status', isEqualTo: 'active')
        .where('remainingSessions', isGreaterThan: 0)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final sub = SubscriptionModel.fromFirestore(doc);
      // Guard expired subscriptions Firestore hasn't cleaned up yet
      if (sub.expiryDate != null && sub.expiryDate!.isBefore(DateTime.now())) {
        return null;
      }
      return ActiveBundleInfo.fromMap(doc.data(), doc.id);
    }).handleError((e, stack) {
      debugPrint('watchActiveBundle error: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    });
  }

  /// Get a subscription bundle by its ID.
  Future<SubscriptionModel?> getBundleById(String subscriptionId) async {
    final doc =
        await _firestore.collection('subscriptions').doc(subscriptionId).get();
    if (!doc.exists) return null;
    return SubscriptionModel.fromFirestore(doc);
  }
}
