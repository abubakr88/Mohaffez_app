// FILE: lib/providers/session_provider_paginated.dart
// CHANGES:
// - Converted ALL List<dynamic> to properly typed Map data
// - Fixed Timestamp conversion for dates
// - Added defensive null handling for all fields
// - Kept existing pagination and state management logic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// COUNTERS (Real-time StreamProviders for MohaffezHome)
// ============================================================================

final completedSessionsCountProvider = StreamProvider.family<int, String>((ref, mohaffezId) {
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

// ✅ FIXED: Properly format all fields with safe type conversion
final pendingRequestsFirstPageProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, mohaffezId) {
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
            'id': doc.id,
            'studentName': data['studentName'] as String? ?? 'غير معروف',
            'mohaffezName': data['mohaffezName'] as String? ?? '',
            'sessionType': data['sessionType'] as String? ?? 'منزل',
            'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
            'imamAddressText': data['imamAddressText'] as String?,
            'imamAddressLat': data['imamAddressLat'] as double?,
            'imamAddressLng': data['imamAddressLng'] as double?,
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate(), // ✅ Convert Timestamp
            'status': data['status'] as String? ?? 'pending',
            'mohaffezId': data['mohaffezId'] as String?,
            'studentId': data['studentId'] as String?,
          };
        }).toList();
      });
});

// ✅ FIXED: Properly format upcoming sessions with date conversion
final upcomingSessionsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, mohaffezId) {
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
            'id': doc.id,
            'studentName': data['studentName'] as String? ?? 'غير معروف',
            'mohaffezName': data['mohaffezName'] as String? ?? '',
            'sessionType': data['sessionType'] as String? ?? 'منزل',
            'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
            'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(), // ✅ Convert!
            'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
            'hifzAssignment': data['hifzAssignment'] as String?,
            'murajaAssignment': data['murajaAssignment'] as String?,
            'sessionRating': data['sessionRating'] as int?,
            'sessionNotes': data['sessionNotes'] as String?,
            'status': data['status'] as String? ?? 'accepted',
          };
        }).toList();
      });
});

// ============================================================================
// COMPLETED SESSIONS (Paginated)
// ============================================================================

class CompletedSessionsState {
  final List<Map<String, dynamic>> sessions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Set<String> loadedIds;

  CompletedSessionsState({
    this.sessions = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    Set<String>? loadedIds,
  }) : loadedIds = loadedIds ?? {};

  CompletedSessionsState copyWith({
    List<Map<String, dynamic>>? sessions,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
    Set<String>? loadedIds,
  }) {
    return CompletedSessionsState(
      sessions: sessions ?? this.sessions,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadedIds: loadedIds ?? this.loadedIds,
    );
  }
}

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
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }

      final newSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? 'غير معروف',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(), // ✅ Convert
          'sessionType': data['sessionType'] as String? ?? 'منزل',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'sessionRating': data['sessionRating'] as int?,
          'sessionNotes': data['sessionNotes'] as String?,
        };
      }).toList();

      // Filter duplicates
      final uniqueNewSessions = newSessions.where((s) {
        final id = s['id'] as String?;
        return id != null && !state.loadedIds.contains(id);
      }).toList();

      final newIds = uniqueNewSessions.map((s) => s['id'] as String).toSet();

      state = state.copyWith(
        sessions: [...state.sessions, ...uniqueNewSessions],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
        isLoadingMore: false,
        loadedIds: {...state.loadedIds, ...newIds},
      );
    } catch (e) {
      state = state.copyWith(
        error: 'فشل تحميل الجلسات. تحقق من الاتصال.',
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = CompletedSessionsState();
    loadMore();
  }
}

final completedSessionsPaginatedProvider =
    StateNotifierProvider.family<CompletedSessionsNotifier, CompletedSessionsState, String>(
  (ref, mohaffezId) => CompletedSessionsNotifier(mohaffezId),
);

// ============================================================================
// STUDENT SESSIONS (Paginated)
// ============================================================================

class StudentSessionsState {
  final List<Map<String, dynamic>> sessions;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Set<String> loadedIds;

  StudentSessionsState({
    this.sessions = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    Set<String>? loadedIds,
  }) : loadedIds = loadedIds ?? {};

  StudentSessionsState copyWith({
    List<Map<String, dynamic>>? sessions,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
    Set<String>? loadedIds,
  }) {
    return StudentSessionsState(
      sessions: sessions ?? this.sessions,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadedIds: loadedIds ?? this.loadedIds,
    );
  }
}

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
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }

      final newSessions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'mohaffezName': data['mohaffezName'] as String? ?? 'غير معروف',
          'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? 'منزل',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(), // ✅ Convert
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'sessionRating': data['sessionRating'] as int?,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'pending',
        };
      }).toList();

      // Filter duplicates
      final uniqueNewSessions = newSessions.where((s) {
        final id = s['id'] as String?;
        return id != null && !state.loadedIds.contains(id);
      }).toList();

      final newIds = uniqueNewSessions.map((s) => s['id'] as String).toSet();

      state = state.copyWith(
        sessions: [...state.sessions, ...uniqueNewSessions],
        lastDocument: snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
        isLoadingMore: false,
        loadedIds: {...state.loadedIds, ...newIds},
      );
    } catch (e) {
      state = state.copyWith(
        error: 'فشل تحميل الجلسات. تحقق من الاتصال.',
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = StudentSessionsState();
    loadMore();
  }
}

final paginatedStudentSessionsProvider =
    StateNotifierProvider.family<StudentSessionsNotifier, StudentSessionsState, String>(
  (ref, studentId) => StudentSessionsNotifier(studentId),
);

final studentSessionsFirstPageProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('studentId', isEqualTo: studentId)
      .orderBy('sessionDate', descending: true)
      .limit(20)
      .get();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(paginatedStudentSessionsProvider(studentId).notifier).refresh();
  });

  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'id': doc.id,
      'mohaffezName': data['mohaffezName'] as String? ?? 'غير معروف',
      'location': data['location'] as String? ?? data['imamAddressText'] as String? ?? '',
      'sessionType': data['sessionType'] as String? ?? 'منزل',
      'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
      'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(), // ✅ Convert
      'hifzAssignment': data['hifzAssignment'] as String?,
      'murajaAssignment': data['murajaAssignment'] as String?,
      'sessionRating': data['sessionRating'] as int?,
      'sessionNotes': data['sessionNotes'] as String?,
      'status': data['status'] as String? ?? 'pending',
    };
  }).toList();
});

final studentRequestsFirstPageProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) {
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
            'id': doc.id,
            'mohaffezName': data['mohaffezName'] as String? ?? 'غير معروف',
            'sessionType': data['sessionType'] as String? ?? 'منزل',
            'preferredTimeSlot': data['preferredTimeSlot'] as String? ?? '08:00',
            'status': data['status'] as String? ?? 'pending',
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate(), // ✅ Convert
            'imamAddressText': data['imamAddressText'] as String?,
          };
        }).toList();
      });
});

// ============================================================================
// SESSION ACTIONS
// ============================================================================

final sessionActionsProvider = StateNotifierProvider<SessionActionsNotifier, AsyncValue<void>>(
  (ref) => SessionActionsNotifier(),
);

class SessionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  SessionActionsNotifier() : super(const AsyncValue.data(null));

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ FIXED: Use transaction to ensure atomic accept + create
  Future<void> acceptRequestAndCreateSession(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('معرّف الطلب فارغ');
    }

    state = const AsyncValue.loading();
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Get the request data
        final requestRef = _firestore.collection('sessionRequests').doc(requestId);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('الطلب غير موجود');
        }

        final requestData = requestDoc.data()!;

        // 2. Create session in hafizSessions collection
        final sessionRef = _firestore.collection('hafizSessions').doc();
        transaction.set(sessionRef, {
          'mohaffezId': requestData['mohaffezId'],
          'studentId': requestData['studentId'],
          'studentName': requestData['studentName'],
          'mohaffezName': requestData['mohaffezName'],
          'sessionType': requestData['sessionType'],
          'preferredTimeSlot': requestData['preferredTimeSlot'],
          'location': requestData['imamAddressText'],
          'imamAddressLat': requestData['imamAddressLat'],
          'imamAddressLng': requestData['imamAddressLng'],
          'sessionDate': requestData['slotStart'],
          'slotStart': requestData['slotStart'],
          'slotEnd': requestData['slotEnd'],
          'status': 'accepted',
          'hifzAssignment': null,
          'murajaAssignment': null,
          'sessionRating': null,
          'sessionNotes': null,
          'mohaffezPhone': requestData['mohaffezPhone'],
          'createdAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // 3. Update request status
        transaction.update(requestRef, {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('معرّف الطلب فارغ');
    }

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

  Future<void> updateAssignment({
    required String sessionId,
    String? hifzAssignment,
    String? murajaAssignment,
    int? rating,
    String? notes,
  }) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('معرّف الجلسة فارغ');
    }

    if (rating != null && (rating < 0 || rating > 10)) {
      throw ArgumentError('التقييم يجب أن يكون بين 0 و 10');
    }

    state = const AsyncValue.loading();
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (hifzAssignment != null) updates['hifzAssignment'] = hifzAssignment.trim();
      if (murajaAssignment != null) updates['murajaAssignment'] = murajaAssignment.trim();
      if (rating != null) updates['sessionRating'] = rating;
      if (notes != null) updates['sessionNotes'] = notes.trim();

      await _firestore.collection('hafizSessions').doc(sessionId).update(updates);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}
