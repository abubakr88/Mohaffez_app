// providers/session_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/session_model.dart';
import '../repositories/session_repository.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Repository provider for session operations
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});

// ==================== SESSION PROVIDERS ====================

/// Get all sessions for a mohaffez
final mohaffezSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')  // ✅ FIXED: Changed from 'sessions' to 'hafizSessions'
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList());
  },
);

/// Get total session count for a mohaffez
final mohaffezSessionCountProvider = StreamProvider.family<int, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  },
);

/// Get completed sessions (past sessions with status = 'completed')
final completedSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed')
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList());
  },
);

/// Get count of completed sessions
final completedSessionsCountProvider = StreamProvider.family<int, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  },
);

/// Get upcoming sessions (accepted sessions within next 7 days)
final upcomingSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, mohaffezId) {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'accepted')
        .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('sessionDate', isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow))
        .orderBy('sessionDate', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList());
  },
);

/// Get pending session requests for a mohaffez
final pendingSessionRequestsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList());
  },
);

/// Get sessions for a student
final studentSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList());
  },
);

/// Get accepted sessions for a student
final acceptedStudentSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('sessionDate', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList());
  },
);

/// Get single session by ID
final sessionByIdProvider = StreamProvider.family<SessionModel?, String>(
  (ref, sessionId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .doc(sessionId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return SessionModel.fromFirestore(snapshot);
    });
  },
);

// ==================== SESSION ACTIONS PROVIDER ====================

/// Provider for session actions (accept, reject, complete, etc.)
final sessionActionsProvider = StateNotifierProvider<SessionActionsNotifier, AsyncValue<void>>(
  (ref) {
    final repository = ref.watch(sessionRepositoryProvider);
    return SessionActionsNotifier(repository);
  },
);

/// Session actions notifier - handles all session state changes
class SessionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final SessionRepository _repository;

  SessionActionsNotifier(this._repository) : super(const AsyncValue.data(null));

  /// Accept a session request
  Future<void> acceptRequest(String sessionId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.acceptRequest(sessionId);
    });
  }

  /// Reject a session request
  Future<void> rejectRequest(String sessionId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.rejectRequest(sessionId);
    });
  }

  /// Complete a session
  Future<void> completeSession(String sessionId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await FirebaseFirestore.instance.collection('hafizSessions').doc(sessionId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cancel a session
  Future<void> cancelSession(String sessionId, String reason) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await FirebaseFirestore.instance.collection('hafizSessions').doc(sessionId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Update session assignment (hifz, muraja, rating, notes)
  Future<void> updateAssignment({
    required String sessionId,
    String? hifzAssignment,
    String? murajaAssignment,
    int? rating,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateSessionAssignment(
        sessionId: sessionId,
        hifzAssignment: hifzAssignment ?? '',
        murajaAssignment: murajaAssignment ?? '',
        rating: rating ?? 0,
        notes: notes ?? '',
      );
    });
  }

  /// Update session date
  Future<void> updateSessionDate({
    required String sessionId,
    required DateTime sessionDate,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await FirebaseFirestore.instance.collection('hafizSessions').doc(sessionId).update({
        'sessionDate': Timestamp.fromDate(sessionDate),
        'slotStart': Timestamp.fromDate(slotStart),
        'slotEnd': Timestamp.fromDate(slotEnd),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Book a new session (for students)
  Future<String> bookSession({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    String? location,
    String? notes,
    double? imamAddressLat,
    double? imamAddressLng,
  }) async {
    state = const AsyncValue.loading();
    try {
      final docRef = await FirebaseFirestore.instance.collection('hafizSessions').add({
        'mohaffezId': mohaffezId,
        'studentId': studentId,
        'studentName': studentName,
        'mohaffezName': mohaffezName,
        'sessionType': sessionType,
        'preferredTimeSlot': preferredTimeSlot,
        'location': location ?? '',
        'sessionNotes': notes,
        'imamAddressLat': imamAddressLat,
        'imamAddressLng': imamAddressLng,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'hifzAssignment': null,
        'murajaAssignment': null,
        'sessionRating': 0,
        'juzCount': 1,
      });
      state = const AsyncValue.data(null);
      return docRef.id;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Rate a completed session (for students)
  Future<void> rateSession({
    required String sessionId,
    required int rating,
    String? feedback,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await FirebaseFirestore.instance.collection('hafizSessions').doc(sessionId).update({
        'studentRating': rating,
        'studentFeedback': feedback,
        'ratedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

// ==================== SESSION BOOKING PROVIDER (Alternative Service) ====================

/// Alternative booking service provider
final sessionBookingProvider = Provider((ref) {
  return SessionBookingService();
});

/// Session booking service for creating and managing sessions
class SessionBookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new session request
  Future<String> createSession({
    required String mohaffezId,
    required String studentId,
    required String studentName,
    required String mohaffezName,
    required String sessionType,
    required String preferredTimeSlot,
    String? location,
    String? notes,
    double? imamAddressLat,
    double? imamAddressLng,
  }) async {
    final docRef = await _firestore.collection('hafizSessions').add({
      'mohaffezId': mohaffezId,
      'studentId': studentId,
      'studentName': studentName,
      'mohaffezName': mohaffezName,
      'sessionType': sessionType,
      'preferredTimeSlot': preferredTimeSlot,
      'location': location ?? '',
      'sessionNotes': notes,
      'imamAddressLat': imamAddressLat,
      'imamAddressLng': imamAddressLng,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Accept a session request
  Future<void> acceptSession(String sessionId) async {
    await _firestore.collection('hafizSessions').doc(sessionId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a session request
  Future<void> rejectSession(String sessionId) async {
    await _firestore.collection('hafizSessions').doc(sessionId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Complete a session
  Future<void> completeSession(String sessionId) async {
    await _firestore.collection('hafizSessions').doc(sessionId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a session
  Future<void> cancelSession(String sessionId, String reason) async {
    await _firestore.collection('hafizSessions').doc(sessionId).update({
      'status': 'cancelled',
      'cancellationReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
}

// ==================== SESSION STATISTICS PROVIDER ====================

/// Get session statistics for a mohaffez
final sessionStatsProvider = StreamProvider.family<SessionStats, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .snapshots()
        .map((snapshot) {
      int total = snapshot.docs.length;
      int pending = 0;
      int accepted = 0;
      int completed = 0;
      int rejected = 0;
      int cancelled = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'accepted':
            accepted++;
            break;
          case 'completed':
            completed++;
            break;
          case 'rejected':
            rejected++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      return SessionStats(
        total: total,
        pending: pending,
        accepted: accepted,
        completed: completed,
        rejected: rejected,
        cancelled: cancelled,
      );
    });
  },
);

/// Session statistics model
class SessionStats {
  final int total;
  final int pending;
  final int accepted;
  final int completed;
  final int rejected;
  final int cancelled;

  SessionStats({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.completed,
    required this.rejected,
    required this.cancelled,
  });
}
