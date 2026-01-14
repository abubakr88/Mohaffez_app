// lib/providers/session_provider_paginated.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// COUNTERS (Real-time StreamProviders for MohaffezHome)
// ============================================================================

/// Real-time count of completed sessions for a mohaffez
final completedSessionsCountProvider = StreamProvider.family<int, String>((ref, mohaffezId) {
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.length;
      });
});

/// Real-time pending session requests for a mohaffez (returns full list)
final pendingRequestsFirstPageProvider = StreamProvider.family<List<dynamic>, String>((ref, mohaffezId) {
  return FirebaseFirestore.instance
      .collection('sessionRequests')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
            'studentName': data['studentName'] ?? 'غير معروف',
            'sessionType': data['sessionType'] ?? 'بيت',
            'preferredTimeSlot': data['preferredTimeSlot'] ?? '08:00',
            'imamAddressText': data['imamAddressText'],
            'createdAt': data['createdAt'],
          };
        }).toList();
      });
});

/// Real-time upcoming sessions for mohaffez (next 7 days)
final upcomingSessionsProvider = StreamProvider.family<List<dynamic>, String>((ref, mohaffezId) {
  final now = DateTime.now();
  final weekFromNow = now.add(const Duration(days: 7));
  
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('status', isEqualTo: 'accepted')
      .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
      .where('sessionDate', isLessThanOrEqualTo: Timestamp.fromDate(weekFromNow))
      .orderBy('sessionDate', descending: false)
      .limit(10)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
            'studentName': data['studentName'] ?? 'غير معروف',
            'mohaffezName': data['mohaffezName'] ?? '',
            'sessionType': data['sessionType'] ?? 'بيت',
            'preferredTimeSlot': data['preferredTimeSlot'] ?? '08:00',
            'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
            'hifzAssignment': data['hifzAssignment'],
            'murajaAssignment': data['murajaAssignment'],
            'sessionRating': data['sessionRating'],
            'sessionNotes': data['sessionNotes'],
          };
        }).toList();
      });
});

// ============================================================================
// COMPLETED SESSIONS (Paginated)
// ============================================================================

/// State for paginated completed sessions
class CompletedSessionsState {
  final List<dynamic> sessions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  CompletedSessionsState({
    this.sessions = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
  });

  CompletedSessionsState copyWith({
    List<dynamic>? sessions,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
  }) {
    return CompletedSessionsState(
      sessions: sessions ?? this.sessions,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

/// Notifier for completed sessions pagination
class CompletedSessionsNotifier extends StateNotifier<CompletedSessionsState> {
  final String mohaffezId;
  static const int pageSize = 20;

  CompletedSessionsNotifier(this.mohaffezId) : super(CompletedSessionsState());

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      Query query = FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'completed')
          .orderBy('sessionDate', descending: true)
          .limit(pageSize);

      if (state.lastDocument != null) {
        query = query.startAfterDocument(state.lastDocument!);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        state = state.copyWith(
          hasMore: false,
          isLoadingMore: false,
        );
        return;
      }

      final newSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
          'studentName': data['studentName'] ?? 'غير معروف',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] ?? 'بيت',
          'preferredTimeSlot': data['preferredTimeSlot'],
          'location': data['location'] ?? data['imamAddressText'] ?? '',
          'hifzAssignment': data['hifzAssignment'],
          'murajaAssignment': data['murajaAssignment'],
          'sessionRating': data['sessionRating'],
          'sessionNotes': data['sessionNotes'],
        };
      }).toList();

      state = state.copyWith(
        sessions: [...state.sessions, ...newSessions],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = CompletedSessionsState();
    loadMore();
  }
}

/// Provider for completed sessions pagination
final completedSessionsPaginatedProvider = StateNotifierProvider.family<
    CompletedSessionsNotifier, CompletedSessionsState, String>(
  (ref, mohaffezId) => CompletedSessionsNotifier(mohaffezId),
);

/// First page loader for completed sessions
final completedSessionsFirstPageProvider = FutureProvider.family<List<dynamic>, String>((ref, mohaffezId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('status', isEqualTo: 'completed')
      .orderBy('sessionDate', descending: true)
      .limit(20)
      .get();

  // Trigger pagination state
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(completedSessionsPaginatedProvider(mohaffezId).notifier).refresh();
  });

  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      ...data,
      'id': doc.id,
      'studentName': data['studentName'] ?? 'غير معروف',
      'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
      'sessionType': data['sessionType'] ?? 'بيت',
      'preferredTimeSlot': data['preferredTimeSlot'],
      'location': data['location'] ?? data['imamAddressText'] ?? '',
      'hifzAssignment': data['hifzAssignment'],
      'murajaAssignment': data['murajaAssignment'],
      'sessionRating': data['sessionRating'],
      'sessionNotes': data['sessionNotes'],
    };
  }).toList();
});

// ============================================================================
// STUDENT SESSIONS (For StudentAssignmentsScreen & AcceptedSessionsScreen)
// ============================================================================

/// State for paginated student sessions
class StudentSessionsState {
  final List<dynamic> sessions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  StudentSessionsState({
    this.sessions = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
  });

  StudentSessionsState copyWith({
    List<dynamic>? sessions,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
  }) {
    return StudentSessionsState(
      sessions: sessions ?? this.sessions,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

/// Notifier for student sessions
class StudentSessionsNotifier extends StateNotifier<StudentSessionsState> {
  final String studentId;
  static const int pageSize = 20;

  StudentSessionsNotifier(this.studentId) : super(StudentSessionsState());

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      Query query = FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('studentId', isEqualTo: studentId)
          .orderBy('sessionDate', descending: true)
          .limit(pageSize);

      if (state.lastDocument != null) {
        query = query.startAfterDocument(state.lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        state = state.copyWith(
          hasMore: false,
          isLoadingMore: false,
        );
        return;
      }

      final newSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
          'mohaffezName': data['mohaffezName'] ?? 'غير معروف',
          'location': data['location'] ?? data['imamAddressText'] ?? '',
          'sessionType': data['sessionType'] ?? 'بيت',
          'preferredTimeSlot': data['preferredTimeSlot'] ?? '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'hifzAssignment': data['hifzAssignment'],
          'murajaAssignment': data['murajaAssignment'],
          'sessionRating': data['sessionRating'],
          'sessionNotes': data['sessionNotes'],
          'status': data['status'] ?? 'pending',
        };
      }).toList();

      state = state.copyWith(
        sessions: [...state.sessions, ...newSessions],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = StudentSessionsState();
    loadMore();
  }
}

/// Provider for student sessions pagination
final paginatedStudentSessionsProvider = StateNotifierProvider.family<
    StudentSessionsNotifier, StudentSessionsState, String>(
  (ref, studentId) => StudentSessionsNotifier(studentId),
);

/// First page loader for student sessions
final studentSessionsFirstPageProvider = FutureProvider.family<List<dynamic>, String>((ref, studentId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('studentId', isEqualTo: studentId)
      .orderBy('sessionDate', descending: true)
      .limit(20)
      .get();

  // Trigger pagination
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(paginatedStudentSessionsProvider(studentId).notifier).refresh();
  });

  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      ...data,
      'id': doc.id,
      'mohaffezName': data['mohaffezName'] ?? 'غير معروف',
      'location': data['location'] ?? data['imamAddressText'] ?? '',
      'sessionType': data['sessionType'] ?? 'بيت',
      'preferredTimeSlot': data['preferredTimeSlot'] ?? '08:00',
      'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
      'hifzAssignment': data['hifzAssignment'],
      'murajaAssignment': data['murajaAssignment'],
      'sessionRating': data['sessionRating'],
      'sessionNotes': data['sessionNotes'],
      'status': data['status'] ?? 'pending',
    };
  }).toList();
});

// ============================================================================
// STUDENT SESSION REQUESTS (For StudentRequestsScreen & StudentHome)
// ============================================================================

/// Real-time student session requests
final studentRequestsFirstPageProvider = StreamProvider.family<List<dynamic>, String>((ref, studentId) {
  return FirebaseFirestore.instance
      .collection('sessionRequests')
      .where('studentId', isEqualTo: studentId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
            'mohaffezName': data['mohaffezName'] ?? 'غير معروف',
            'sessionType': data['sessionType'] ?? 'بيت',
            'preferredTimeSlot': data['preferredTimeSlot'] ?? '08:00',
            'status': data['status'] ?? 'pending',
            'createdAt': data['createdAt'],
            'imamAddressText': data['imamAddressText'],
          };
        }).toList();
      });
});

// ============================================================================
// SESSION ACTIONS (Accept, Reject, Update, etc.)
// ============================================================================

/// Provider for session actions
final sessionActionsProvider = StateNotifierProvider<SessionActionsNotifier, AsyncValue<void>>(
  (ref) => SessionActionsNotifier(),
);

class SessionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  SessionActionsNotifier() : super(const AsyncValue.data(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Accept request and create actual session in hafizSessions
  Future<void> acceptRequestAndCreateSession(String requestId) async {
    state = const AsyncValue.loading();
    
    try {
      // 1. Get the request data
      final requestDoc = await _firestore
          .collection('sessionRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('الطلب غير موجود');
      }

      final requestData = requestDoc.data()!;

      // 2. Create session in hafizSessions collection
      await _firestore.collection('hafizSessions').add({
        // Core fields
        'mohaffezId': requestData['mohaffezId'],
        'studentId': requestData['studentId'],
        'studentName': requestData['studentName'],
        'mohaffezName': requestData['mohaffezName'],
        'sessionType': requestData['sessionType'],
        'preferredTimeSlot': requestData['preferredTimeSlot'],
        
        // Location
        'location': requestData['imamAddressText'],
        'imamAddressLat': requestData['imamAddressLat'],
        'imamAddressLng': requestData['imamAddressLng'],
        
        // Session date from request
        'sessionDate': requestData['slotStart'],
        'slotStart': requestData['slotStart'],
        'slotEnd': requestData['slotEnd'],
        
        // Session details (initially empty)
        'status': 'accepted',
        'hifzAssignment': null,
        'murajaAssignment': null,
        'sessionRating': null,
        'sessionNotes': null,
        
        // Phone
        'mohaffezPhone': requestData['mohaffezPhone'],
        
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 3. Update request status
      await _firestore.collection('sessionRequests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Reject a session request
  Future<void> rejectRequest(String requestId) async {
    state = const AsyncValue.loading();
    
    try {
      await _firestore.collection('sessionRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
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
    
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (hifzAssignment != null) updates['hifzAssignment'] = hifzAssignment;
      if (murajaAssignment != null) updates['murajaAssignment'] = murajaAssignment;
      if (rating != null) updates['sessionRating'] = rating;
      if (notes != null) updates['sessionNotes'] = notes;

      await _firestore.collection('hafizSessions').doc(sessionId).update(updates);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Complete a session
  Future<void> completeSession(String sessionId) async {
    state = const AsyncValue.loading();
    
    try {
      await _firestore.collection('hafizSessions').doc(sessionId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Cancel a session
  Future<void> cancelSession(String sessionId, String reason) async {
    state = const AsyncValue.loading();
    
    try {
      await _firestore.collection('hafizSessions').doc(sessionId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Update session date
  Future<void> updateSessionDate({
    required String sessionId,
    required DateTime sessionDate,
    required DateTime slotStart,
    required DateTime slotEnd,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _firestore.collection('hafizSessions').doc(sessionId).update({
        'sessionDate': Timestamp.fromDate(sessionDate),
        'slotStart': Timestamp.fromDate(slotStart),
        'slotEnd': Timestamp.fromDate(slotEnd),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
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
    
    try {
      await _firestore.collection('hafizSessions').doc(sessionId).update({
        'studentRating': rating,
        'studentFeedback': feedback,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}
