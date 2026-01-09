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

  SessionRepository(this._firestore);

  /// Watch pending session requests for a mohaffez
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
                  'id': doc.id,
                }))
            .toList());
  }

  /// Watch accepted sessions for a mohaffez
  Stream<List<SessionModel>> watchAcceptedSessions(String mohaffezId) {
    return _firestore
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  /// Watch accepted sessions for a student
  Stream<List<SessionModel>> watchStudentSessions(String studentId) {
    return _firestore
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

  /// Watch session requests for a student
  Stream<List<SessionRequestModel>> watchStudentRequests(String studentId) {
    return _firestore
        .collection('sessionRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionRequestModel.fromJson({
                  ...doc.data(),
                  'id': doc.id,
                }))
            .toList());
  }

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
        // final conflicts = await _firestore
        //     .collection('sessionRequests')
        //     .where('mohaffezId', isEqualTo: mohaffezId)
        //     .where('slotStart', isEqualTo: Timestamp.fromDate(slotStart))
        //     .where('status', whereIn: ['pending', 'accepted'])
        //     .get();

        // if (conflicts.docs.isNotEmpty) {
        //   return BookingResult.failure('هذا الموعد محجوز بالفعل');
        // }

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

  /// Accept a session request
  Future<void> acceptRequest(String requestId, Map<String, dynamic> requestData) async {
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

  /// Update session assignment
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

  /// Get upcoming sessions for a mohaffez
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
              'id': doc.id,
            }))
        .toList();
  }
}
