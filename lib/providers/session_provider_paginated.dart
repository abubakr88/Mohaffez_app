// lib/providers/session_provider_paginated.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../repositories/session_repository.dart';
import '../models/request_status.dart';
import '../models/quran_mistake_model.dart';
import '../models/mohaffez_student_summary.dart';

// ============================================================================
// FILTER ENUM AND PROVIDER
// ============================================================================
enum UpcomingFilter {
  all,
  today,
  thisWeek,
  thisMonth,
}

final upcomingSessionsFilterProvider = StateProvider((ref) {
  return UpcomingFilter.all;
});

// ============================================================================
// COUNTERS
// ============================================================================
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

final acceptedSessionsCountProvider = StreamProvider.family<int, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'accepted')
        .where('isPaid', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  },
);

final acceptedStudentSessionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
              data['timeSlot'] as String? ??
              '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'accepted',
          'createdAt': data['createdAt'] as Timestamp?,
          'mohaffezId': data['mohaffezId'] as String? ?? '',
          'studentId': data['studentId'] as String? ?? '',
          'studentName': data['studentName'] as String? ?? '',
          'isPaid': data['isPaid'] as bool? ?? false,
        };
      }).toList();
    });
  },
);

// ============================================================================
// PENDING REQUESTS - First Page Real-time
// ============================================================================
final pendingRequestsFirstPageProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    final repository = ref.watch(sessionRepositoryProvider);
    return repository.watchPendingRequests(mohaffezId).map(
          (list) => list.map((r) => r.toJson()).toList(),
        );
  },
);

final pendingRequestsCountProvider =
    Provider.autoDispose.family<int, String>((ref, mohaffezId) {
  return ref.watch(pendingRequestsFirstPageProvider(mohaffezId)).value?.length ??
      0;
});

// ============================================================================
// UPCOMING SESSIONS
// ============================================================================
final upcomingSessionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'accepted')
        .where('isPaid', isEqualTo: true)
        .where('sessionDate', isGreaterThanOrEqualTo: startOfDay)
        .orderBy('sessionDate', descending: false)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
              data['timeSlot'] as String? ??
              '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'sessionRating': data['sessionRating'] as int?,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'accepted',
          'studentId': data['studentId'] as String?,
          'isPaid': data['isPaid'] as bool? ?? false,
          'subscriptionId': data['subscriptionId'] as String?,
        };
      }).toList();
    });
  },
);

final filteredUpcomingSessionsProvider =
    Provider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    final allSessions = ref.watch(upcomingSessionsProvider(mohaffezId));
    final filter = ref.watch(upcomingSessionsFilterProvider);
    return allSessions.when(
      data: (sessions) {
        final now = DateTime.now();
        switch (filter) {
          case UpcomingFilter.all:
            return sessions;
          case UpcomingFilter.today:
            final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
            return sessions.where((session) {
              final date = session['sessionDate'] as DateTime?;
              return date != null && date.isBefore(endOfDay);
            }).toList();
          case UpcomingFilter.thisWeek:
            final endOfWeek = now.add(const Duration(days: 7));
            return sessions.where((session) {
              final date = session['sessionDate'] as DateTime?;
              return date != null && date.isBefore(endOfWeek);
            }).toList();
          case UpcomingFilter.thisMonth:
            final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            return sessions.where((session) {
              final date = session['sessionDate'] as DateTime?;
              return date != null && date.isBefore(endOfMonth);
            }).toList();
        }
      },
      loading: () => [],
      error: (_, __) => [],
    );
  },
);

// ============================================================================
// COMPLETED SESSIONS - Stream (Real-time)
// ============================================================================
final completedSessionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'studentId': data['studentId'] as String? ?? '',
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
              data['timeSlot'] as String? ??
              '08:00',
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
          'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes': data['performanceNotes'] as String?,
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,
          'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
        };
      }).toList();
    });
  },
);

// ============================================================================
// COMPLETED SESSIONS - Paginated
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
          .orderBy('completedAt', descending: true)
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
          'studentName': data['studentName'] as String? ?? '',
          'studentId': data['studentId'] as String? ?? '',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
              data['timeSlot'] as String? ??
              '08:00',
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
          'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes': data['performanceNotes'] as String?,
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,
          'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
        };
      }).toList();

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
        error: 'حدث خطأ في تحميل الجلسات. حاول مرة أخرى.',
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = CompletedSessionsState();
    loadMore();
  }
}

final completedSessionsPaginatedProvider = StateNotifierProvider.family<
    CompletedSessionsNotifier, CompletedSessionsState, String>(
  (ref, mohaffezId) {
    return CompletedSessionsNotifier(mohaffezId);
  },
);

// ============================================================================
// STUDENT SESSIONS - Paginated
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
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
              data['timeSlot'] as String? ??
              '08:00',
          'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
          'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
          'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
          'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
          'performanceNotes': data['performanceNotes'] as String?,
          'sessionRating': data['sessionRating'] as int? ?? 0,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'pending',
          'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
        };
      }).toList();

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
        error: 'حدث خطأ في تحميل الجلسات. حاول مرة أخرى.',
        isLoadingMore: false,
      );
    }
  }

  void refresh() {
    state = StudentSessionsState();
    loadMore();
  }
}

final paginatedStudentSessionsProvider = StateNotifierProvider.family<
    StudentSessionsNotifier, StudentSessionsState, String>(
  (ref, studentId) {
    return StudentSessionsNotifier(studentId);
  },
);

final studentSessionsFirstPageProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .limit(20)
        .get();

    WidgetsBinding.instance.addPostFrameCallback((_) =>
        ref.read(paginatedStudentSessionsProvider(studentId).notifier).refresh());

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'mohaffezName': data['mohaffezName'] as String? ?? '',
        'location': data['location'] as String? ??
            data['imamAddressText'] as String? ??
            '',
        'sessionType': data['sessionType'] as String? ?? '',
        'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
            data['timeSlot'] as String? ??
            '08:00',
        'sessionDate': (data['sessionDate'] as Timestamp?)?.toDate(),
        'hifzAssignment': data['hifzAssignment'] as String?,
        'murajaAssignment': data['murajaAssignment'] as String?,
        'previousHifzCompleted': data['previousHifzCompleted'] as bool?,
        'previousHifzRating': data['previousHifzRating'] as int? ?? 0,
        'previousMurajaCompleted': data['previousMurajaCompleted'] as bool?,
        'previousMurajaRating': data['previousMurajaRating'] as int? ?? 0,
        'performanceNotes': data['performanceNotes'] as String?,
        'sessionRating': data['sessionRating'] as int? ?? 0,
        'sessionNotes': data['sessionNotes'] as String?,
        'status': data['status'] as String? ?? 'pending',
        'isLateCompletion': data['isLateCompletion'] as bool? ?? false,
      };
    }).toList();
  },
);

final studentRequestsFirstPageProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
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
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'mohaffezId': data['mohaffezId'] as String?,
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
              data['timeSlot'] as String? ??
              '08:00',
          'status': data['status'] as String? ?? 'pending',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'slotDate': data['slotDate'] as Timestamp?,
          'paymentDeadline': data['paymentDeadline'] as Timestamp?,
          'reminderSent': data['reminderSent'] as bool? ?? false,
          'slotLockId': data['slotLockId'] as String?,
          'imamAddressText': data['imamAddressText'] as String?,
          'location': data['location'] as String?,
          'rejectionReason': data['rejectionReason'] as String?,
          'isPaid': data['isPaid'] as bool? ?? false,
          'requiresPaymentOnAcceptance':
              data['requiresPaymentOnAcceptance'] as bool? ?? false,
        };
      }).toList();
    });
  },
);

// ============================================================================
// SESSION ACTIONS
// ============================================================================
final sessionActionsProvider =
    StateNotifierProvider<SessionActionsNotifier, AsyncValue<void>>(
  (ref) => SessionActionsNotifier(ref),
);

class SessionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  SessionActionsNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentReference?> _findAvailabilityRef({
    required String mohaffezId,
    required Timestamp slotDate,
  }) async {
    final date = slotDate.toDate();
    final dayOfWeek = date.weekday;
    final snap = await _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.reference;
  }

  List<Map<String, dynamic>>? _computeRestoredSlots(
    Map<String, dynamic> availabilityData,
    String timeSlot,
    String sessionType,
  ) {
    final timeSlots =
        List<Map<String, dynamic>>.from(availabilityData['timeSlots'] ?? []);
    final normalizedSelected = _normalizeTimeSlot(timeSlot);
    var restored = false;
    for (final slot in timeSlots) {
      final slotTime =
          _normalizeTimeSlot('${slot['startTime']}-${slot['endTime']}');
      if (slotTime == normalizedSelected && slot['sessionType'] == sessionType) {
        slot.remove('lockedBy');
        slot.remove('lockId');
        slot.remove('lockedAt');
        slot['enabled'] = true;
        restored = true;
        break;
      }
    }
    return restored ? timeSlots : null;
  }

  Future<void> acceptRequestAndCreateSession(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('Request ID cannot be empty');
    }

    print('🎯 Accepting request: $requestId');
    state = const AsyncValue.loading();
    try {
      // FIX: Bug B - Use atomic repository method instead of non-atomic multi-step process
      final requestDoc =
          await _firestore.collection('sessionRequests').doc(requestId).get();

      if (!requestDoc.exists) throw Exception('Request not found');

      final requestData = requestDoc.data()!;
      final sessionPrice = (requestData['sessionPrice'] as num?)?.toDouble() ?? 0.0;

      await _ref.read(sessionRepositoryProvider)
          .acceptRequest(requestId, sessionPrice: sessionPrice);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('❌ Error accepting request: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // FIX: Bug C - removed dead code _removeBookedSlotFromAvailability (unused after Bug B fix)
  // FIX: Bug B - removed dead code _consumeSubscriptionCredit (unused after atomic refactor)
  // FIX: Bug B - removed dead code _sendPaymentRequestNotification (unused after atomic refactor)
  // FIX: Bug B - removed dead code _createSessionFromRequest (unused after atomic refactor)
  // FIX: Bug B - removed dead code _sendAcceptanceNotification (unused after atomic refactor)

  Future<void> rejectRequest(String requestId, String? reason) async {
    try {
      print('🚫 Rejecting request: $requestId');
      final requestDoc =
          await _firestore.collection('sessionRequests').doc(requestId).get();

      if (!requestDoc.exists) throw Exception('Request not found');

      final requestData = requestDoc.data()!;
      final subscriptionId = requestData['subscriptionId'] as String?;
      final mohaffezId = requestData['mohaffezId'] as String?;
      final slotDate = requestData['slotDate'] as Timestamp?;
      final timeSlot = requestData['preferredTimeSlot'] as String? ??
          requestData['timeSlot'] as String?;
      final sessionType = requestData['sessionType'] as String?;
      final slotLockId = requestData['slotLockId'] as String?;

      DocumentReference? availRef;
      if (mohaffezId != null && slotDate != null) {
        availRef = await _findAvailabilityRef(
          mohaffezId: mohaffezId,
          slotDate: slotDate,
        );
      }

      await _firestore.runTransaction((transaction) async {
        Map<String, dynamic>? availData;
        final resolvedAvailRef = availRef;
        if (resolvedAvailRef != null) {
          final availSnap = await transaction.get(resolvedAvailRef);
          availData = availSnap.exists
              ? availSnap.data() as Map<String, dynamic>?
              : null;
        }

        transaction.update(
            _firestore.collection('sessionRequests').doc(requestId), {
          'status': RequestStatus.rejected,
          'rejectionReason': reason,
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }

        if (resolvedAvailRef != null &&
            availData != null &&
            timeSlot != null &&
            sessionType != null) {
          final updatedSlots =
              _computeRestoredSlots(availData, timeSlot, sessionType);
          if (updatedSlots != null) {
            transaction.update(resolvedAvailRef, {
              'timeSlots': updatedSlots,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      if (subscriptionId != null) {
        print('💳 Subscription credit NOT consumed (request rejected)');
      }

      await _sendRejectionNotification(
        studentId: requestData['studentId'],
        mohaffezName: requestData['mohaffezName'],
        reason: reason,
      );

      print('✅ Request rejected successfully');
    } catch (e) {
      print('❌ Error rejecting request: $e');
      throw Exception('Failed to reject request: $e');
    }
  }

  Future<void> _sendRejectionNotification({
    required String studentId,
    required String mohaffezName,
    String? reason,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'title': 'تم رفض طلب الحجز',
        'body':
            '$mohaffezName اعتذر عن قبول الطلب${reason != null ? ": $reason" : ""}',
        'type': 'session_rejected',
        'isRead': false,
        'mohaffezName': mohaffezName,
        'rejectionReason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending rejection notification: $e');
    }
  }

  Future<void> cancelSession(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }

    state = const AsyncValue.loading();
    try {
      final sessionDoc =
          await _firestore.collection('hafizSessions').doc(sessionId).get();
      if (!sessionDoc.exists) throw Exception('Session not found');

      final sessionData = sessionDoc.data()!;
      final requestId = sessionData['requestId'] as String?;
      Map<String, dynamic>? requestData;
      if (requestId != null && requestId.trim().isNotEmpty) {
        final requestDoc =
            await _firestore.collection('sessionRequests').doc(requestId).get();
        requestData = requestDoc.data();
      }

      final mohaffezId =
          (requestData?['mohaffezId'] ?? sessionData['mohaffezId']) as String?;
      final slotDate = (requestData?['slotDate'] ?? sessionData['sessionDate'])
          as Timestamp?;
      final timeSlot = (requestData?['preferredTimeSlot'] ??
              requestData?['timeSlot'] ??
              sessionData['preferredTimeSlot'] ??
              sessionData['timeSlot']) as String?;
      final sessionType =
          (requestData?['sessionType'] ?? sessionData['sessionType']) as String?;
      final slotLockId =
          (requestData?['slotLockId'] ?? sessionData['slotLockId']) as String?;

      DocumentReference? availRef;
      if (mohaffezId != null && slotDate != null) {
        availRef = await _findAvailabilityRef(
          mohaffezId: mohaffezId,
          slotDate: slotDate,
        );
      }

      await _firestore.runTransaction((transaction) async {
        Map<String, dynamic>? availData;
        final resolvedAvailRef = availRef;
        if (resolvedAvailRef != null) {
          final availSnap = await transaction.get(resolvedAvailRef);
          availData = availSnap.exists
              ? availSnap.data() as Map<String, dynamic>?
              : null;
        }

        transaction
            .update(_firestore.collection('hafizSessions').doc(sessionId), {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (requestId != null && requestId.trim().isNotEmpty) {
          transaction.update(
              _firestore.collection('sessionRequests').doc(requestId), {
            'status': RequestStatus.cancelled,
            'cancelledAt': FieldValue.serverTimestamp(),
          });
        }

        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          transaction
              .delete(_firestore.collection('slotLocks').doc(slotLockId));
        }

        if (resolvedAvailRef != null &&
            availData != null &&
            timeSlot != null &&
            sessionType != null) {
          final updatedSlots =
              _computeRestoredSlots(availData, timeSlot, sessionType);
          if (updatedSlots != null) {
            transaction.update(resolvedAvailRef, {
              'timeSlots': updatedSlots,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      await sendCancellationNotifications(
        studentId: sessionData['studentId'] as String,
        mohaffezId: sessionData['mohaffezId'] as String,
        sessionId: sessionId,
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> cancelRequest(String requestId) async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('Request ID cannot be empty');
    }

    state = const AsyncValue.loading();
    try {
      final requestDoc =
          await _firestore.collection('sessionRequests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception('Request not found');

      final requestData = requestDoc.data()!;
      final status = requestData['status'] as String? ?? RequestStatus.pending;
      final mohaffezId = requestData['mohaffezId'] as String?;
      final slotDate = requestData['slotDate'] as Timestamp?;
      final timeSlot = requestData['preferredTimeSlot'] as String? ??
          requestData['timeSlot'] as String?;
      final sessionType = requestData['sessionType'] as String?;
      final slotLockId = requestData['slotLockId'] as String?;

      if (status == 'completed') {
        throw Exception('Cannot cancel completed session');
      }

      DocumentReference? availRef;
      if (mohaffezId != null && slotDate != null) {
        availRef = await _findAvailabilityRef(
          mohaffezId: mohaffezId,
          slotDate: slotDate,
        );
      }

      await _firestore.runTransaction((transaction) async {
        Map<String, dynamic>? availData;
        final resolvedAvailRef = availRef;
        if (resolvedAvailRef != null) {
          final availSnap = await transaction.get(resolvedAvailRef);
          availData = availSnap.exists
              ? availSnap.data() as Map<String, dynamic>?
              : null;
        }

        transaction.update(
            _firestore.collection('sessionRequests').doc(requestId), {
          'status': RequestStatus.cancelled,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          transaction
              .delete(_firestore.collection('slotLocks').doc(slotLockId));
        }

        if ((status == RequestStatus.awaitingPayment ||
                status == RequestStatus.accepted) &&
            resolvedAvailRef != null &&
            availData != null &&
            timeSlot != null &&
            sessionType != null) {
          final updatedSlots =
              _computeRestoredSlots(availData, timeSlot, sessionType);
          if (updatedSlots != null) {
            transaction.update(resolvedAvailRef, {
              'timeSlots': updatedSlots,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      if (mohaffezId != null) {
        await sendCancellationNotifications(
          studentId: requestData['studentId'] as String,
          mohaffezId: mohaffezId,
          sessionId: requestId,
        );
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> _releaseSlotLockById(String? slotLockId) async {
    if (slotLockId == null || slotLockId.trim().isEmpty) return;

    try {
      final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
      final lockDoc = await lockRef.get();
      if (!lockDoc.exists) return;

      final data = lockDoc.data()!;
      final mohaffezId = data['mohaffezId'] as String?;
      final availabilityDocId = data['availabilityDocId'] as String?;
      final timeSlot = data['timeSlot'] as String?;
      final sessionType = data['sessionType'] as String?;

      if (mohaffezId != null &&
          availabilityDocId != null &&
          timeSlot != null &&
          sessionType != null) {
        await _releaseSlotLockFieldsFromAvailability(
          mohaffezId: mohaffezId,
          availabilityDocId: availabilityDocId,
          timeSlot: timeSlot,
          sessionType: sessionType,
          lockId: slotLockId,
        );
      }

      await lockRef.delete();
    // FIX-6: Log slot lock release failures instead of silently swallowing them
    } catch (e, stack) {
      debugPrint('⚠️ Failed to release slot lock $slotLockId: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _releaseSlotLockFieldsFromAvailability({
    required String mohaffezId,
    required String availabilityDocId,
    required String timeSlot,
    required String sessionType,
    required String lockId,
  }) async {
    // FIX: Bug C - removed UID guard that caused silent exit on admin/system calls
    final availabilityRef = _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .doc(availabilityDocId);

    await _firestore.runTransaction((transaction) async {
      final availabilityDoc = await transaction.get(availabilityRef);
      if (!availabilityDoc.exists) return;

      final data = availabilityDoc.data() ?? <String, dynamic>{};
      final slots = List<Map<String, dynamic>>.from(data['timeSlots'] ?? []);
      var changed = false;

      final normalizedSelected = _normalizeTimeSlot(timeSlot);
      for (var i = 0; i < slots.length; i++) {
        final slot = slots[i];
        final slotTime =
            _normalizeTimeSlot('${slot['startTime']}-${slot['endTime']}');
        if (slotTime == normalizedSelected &&
            slot['sessionType'] == sessionType &&
            slot['lockId'] == lockId) {
          final updated = Map<String, dynamic>.from(slot)
            ..remove('lockedBy')
            ..remove('lockId')
            ..remove('lockedAt');
          slots[i] = updated;
          changed = true;
          break;
        }
      }

      if (changed) {
        transaction.update(availabilityRef, {
          'timeSlots': slots,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  String _normalizeTimeSlot(String raw) => raw.replaceAll(' ', '');

  Future<void> sendCancellationNotifications({
    required String studentId,
    required String mohaffezId,
    required String sessionId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': studentId,
        'recipientId': studentId,
        'senderId': mohaffezId,
        'title': 'تم إلغاء الجلسة',
        'body': 'تم إلغاء الجلسة المحجوزة',
        'type': 'session_cancelled',
        'isRead': false,
        'sessionId': sessionId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'userId': mohaffezId,
        'recipientId': mohaffezId,
        'senderId': studentId,
        'title': 'تم إلغاء الجلسة',
        'body': 'قام الطالب بإلغاء الجلسة المحجوزة',
        'type': 'session_cancelled',
        'isRead': false,
        'sessionId': sessionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> updateSession(
    String sessionId,
    Map<String, dynamic> updates,
  ) async {
    state = const AsyncValue.loading();
    try {
      await _firestore
          .collection('hafizSessions')
          .doc(sessionId)
          .update(updates);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateAssignment({
    required String sessionId,
    String? hifz,
    String? muraja,
    String? notes,
    int? rating,
  }) async {
    final updates = <String, dynamic>{};
    if (hifz != null) updates['hifzAssignment'] = hifz;
    if (muraja != null) updates['murajaAssignment'] = muraja;
    if (notes != null) updates['sessionNotes'] = notes;
    if (rating != null) updates['sessionRating'] = rating;
    if (updates.isNotEmpty) await updateSession(sessionId, updates);
  }

  Future<void> completeSessionWithDetails({
    required String sessionId,
    bool? previousHifzCompleted,
    int? previousHifzRating,
    bool? previousMurajaCompleted,
    int? previousMurajaRating,
    String? performanceNotes,
    String? newHifzAssignment,
    String? newMurajaAssignment,
    int sessionRating = 7,
    String? generalNotes,
    bool isLateCompletion = false,
    List<QuranMistake>? mistakes,
    List<int>? pagesRead,
    int? currentPage,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updates = <String, dynamic>{
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'sessionRating': sessionRating,
        'isLateCompletion': isLateCompletion,
      };

      if (previousHifzCompleted != null)
        updates['previousHifzCompleted'] = previousHifzCompleted;
      if (previousHifzRating != null)
        updates['previousHifzRating'] = previousHifzRating;
      if (previousMurajaCompleted != null)
        updates['previousMurajaCompleted'] = previousMurajaCompleted;
      if (previousMurajaRating != null)
        updates['previousMurajaRating'] = previousMurajaRating;
      if (performanceNotes != null && performanceNotes.isNotEmpty)
        updates['performanceNotes'] = performanceNotes;
      if (newHifzAssignment != null && newHifzAssignment.isNotEmpty)
        updates['hifzAssignment'] = newHifzAssignment;
      if (newMurajaAssignment != null && newMurajaAssignment.isNotEmpty)
        updates['murajaAssignment'] = newMurajaAssignment;
      if (generalNotes != null && generalNotes.isNotEmpty)
        updates['sessionNotes'] = generalNotes;

      if (mistakes != null && mistakes.isNotEmpty) {
        updates['mistakes'] = mistakes.map((m) => m.toJson()).toList();
        updates['tajweedMistakesCount'] =
            mistakes.where((m) => m.type == MistakeType.tajweed).length;
        updates['pronunciationMistakesCount'] =
            mistakes.where((m) => m.type == MistakeType.pronunciation).length;
        updates['readingMistakesCount'] =
            mistakes.where((m) => m.type == MistakeType.reading).length;
        updates['skipMistakesCount'] =
            mistakes.where((m) => m.type == MistakeType.skip).length;
        updates['additionMistakesCount'] =
            mistakes.where((m) => m.type == MistakeType.addition).length;
        updates['otherMistakesCount'] =
            mistakes.where((m) => m.type == MistakeType.other).length;
      }

      if (pagesRead != null && pagesRead.isNotEmpty)
        updates['pagesRead'] = pagesRead;
      if (currentPage != null) updates['currentPage'] = currentPage;

      await _firestore
          .collection('hafizSessions')
          .doc(sessionId)
          .update(updates);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// ============================================================================
// MOHAFFEZ STUDENTS PROVIDERS
// ============================================================================
final mohaffezStudentsProvider = FutureProvider.autoDispose
    .family<List<MohaffezStudentSummary>, String>((ref, mohaffezId) async {
  if (mohaffezId.isEmpty) return [];

  final snapshot = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .limit(300)
      .get()
      .timeout(const Duration(seconds: 15));

  final docs = snapshot.docs
    ..sort((a, b) {
      final aDate =
          (a.data()['sessionDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bDate =
          (b.data()['sessionDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

  final Map<String, MohaffezStudentSummary> students = {};
  final Map<String, int> counts = {};

  for (final doc in docs) {
    final data = doc.data();
    final studentId = data['studentId'] as String?;
    if (studentId == null) continue;

    counts[studentId] = (counts[studentId] ?? 0) + 1;

    if (!students.containsKey(studentId)) {
      students[studentId] = MohaffezStudentSummary(
        studentId: studentId,
        studentName: data['studentName'] as String? ?? '',
        lastSessionDate: (data['sessionDate'] as Timestamp?)?.toDate(),
        lastSessionStatus: data['status'] as String? ?? 'accepted',
        hifzAssignment: data['hifzAssignment'] as String? ?? '',
        murajaAssignment: data['murajaAssignment'] as String? ?? '',
        sessionRating: data['sessionRating'] as int? ?? 0,
        sessionCount: 0,
        previousHifzCompleted: data['previousHifzCompleted'] as bool?,
        previousHifzRating: data['previousHifzRating'] as int? ?? 0,
        previousMurajaCompleted: data['previousMurajaCompleted'] as bool?,
        previousMurajaRating: data['previousMurajaRating'] as int? ?? 0,
        performanceNotes: data['performanceNotes'] as String?,
      );
    }
  }

  return students.values
      .map((s) => s.copyWith(sessionCount: counts[s.studentId] ?? 1))
      .toList();
});

final sessionRepositoryProvider = Provider((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});

