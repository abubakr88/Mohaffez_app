// lib/providers/session_provider_paginated.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/session_repository.dart';
import '../models/request_status.dart';
import '../models/quran_mistake_model.dart';
import '../models/mohaffez_student_summary.dart';
import '../models/subscription_model.dart';

// ============================================================================
// FILTER ENUM AND PROVIDER
// ============================================================================
enum UpcomingFilter {
  all,
  today,
  thisWeek,
  thisMonth,
}

final upcomingSessionsFilterProvider = StateProvider<UpcomingFilter>((ref) {
  return UpcomingFilter.all;
});

// ============================================================================
// COUNTERS
// ============================================================================
final completedSessionsCountProvider = FutureProvider.family<int, String>(
  (ref, mohaffezId) async {
    final query = FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'completed');
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  },
);

final acceptedSessionsCountProvider = FutureProvider.family<int, String>(
  (ref, mohaffezId) async {
    final query = FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'accepted')
        .where('isPaid', isEqualTo: true);
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
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
      final seen = <String>{};
      return snapshot.docs
          .where((doc) => seen.add(doc.id))
          .map((doc) {
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
          })
          .toList();
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
  return ref
          .watch(pendingRequestsFirstPageProvider(mohaffezId))
          .value
          ?.length ??
      0;
});

// ============================================================================
// UPCOMING SESSIONS
// ============================================================================
final upcomingSessionsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    // FIXED: Invalidate on app resume so DateTime.now() is always fresh
    final lifecycleListener = AppLifecycleListener(
      onResume: () => ref.invalidateSelf(),
    );
    ref.onDispose(lifecycleListener.dispose);

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
          // BUG FIX #4: Use start-of-next-period as exclusive upper bound.
          // The original used DateTime(..., 23, 59, 59) which silently drops
          // sessions scheduled in the last millisecond of the period.
          case UpcomingFilter.today:
            final startOfTomorrow =
                DateTime(now.year, now.month, now.day + 1);
            return sessions.where((session) {
              final date = session['sessionDate'] as DateTime?;
              return date != null && date.isBefore(startOfTomorrow);
            }).toList();
          case UpcomingFilter.thisWeek:
            final endOfWeek = now.add(const Duration(days: 7));
            return sessions.where((session) {
              final date = session['sessionDate'] as DateTime?;
              return date != null && date.isBefore(endOfWeek);
            }).toList();
          case UpcomingFilter.thisMonth:
            // BUG FIX #4: Use start of next month as exclusive bound.
            final startOfNextMonth =
                DateTime(now.year, now.month + 1, 1);
            return sessions.where((session) {
              final date = session['sessionDate'] as DateTime?;
              return date != null && date.isBefore(startOfNextMonth);
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
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
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
        final data = doc.data();
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
    } catch (e, stack) {
      debugPrint('loadMore failed: $e\n$stack');
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
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
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
          'mistakes': data['mistakes'],
          'mistakesCount': data['mistakesCount'] as int? ?? 0,
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
    } catch (e, stack) {
      debugPrint('loadMore failed: $e\n$stack');
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

final paginatedStudentSessionsProvider = StateNotifierProvider.autoDispose.family<
    StudentSessionsNotifier, StudentSessionsState, String>(
  (ref, studentId) {
    return StudentSessionsNotifier(studentId);
  },
);

final studentSessionsFirstPageProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                ...data,
              };
            }).toList());
  },
);

// FIX Bug 1: Was hardcoding 4 statuses and missing 'rejected' and 'cancelled'.
// Students could never see their rejected or cancelled requests.
// Now uses RequestStatus.studentVisible as the single source of truth.
// ─── studentRequestsFirstPageProvider ── FIXED ─────────────────
final studentRequestsFirstPageProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) {
  return FirebaseFirestore.instance
      .collection('sessionRequests')
      .where('studentId', isEqualTo: studentId)
      .where('status', whereIn: RequestStatus.studentVisible)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs
          // ✅ FIX: same guard as watchStudentRequests —
          //    hide accepted requests that already have a hafizSession
          .where((doc) =>
              doc.data()['status'] != RequestStatus.accepted ||
              doc.data()['sessionId'] == null)
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'mohaffezName': data['mohaffezName'] as String? ?? '',
              'mohaffezId': data['mohaffezId'] as String?,
              'sessionType': data['sessionType'] as String? ?? '',
              'preferredTimeSlot': data['preferredTimeSlot'] as String? ??
                  data['timeSlot'] as String? ?? '08:00',
              'status': data['status'] as String? ?? 'pending',
              'createdAt': data['createdAt'] as Timestamp?,
              'slotDate': data['slotDate'] as Timestamp?,
              'paymentDeadline': data['paymentDeadline'] as Timestamp?,
              'reminderSent': data['reminderSent'] as bool? ?? false,
              'sessionId': data['sessionId'] as String?,
              'planType': data['planType'] as String?,
              'planTitle': data['planTitle'] as String?,
              'sessionsCount': data['sessionsCount'],
              'directPaymentRequestId': data['directPaymentRequestId'] as String?,
            };
          }).toList());
});

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
      if (slotTime == normalizedSelected &&
          slot['sessionType'] == sessionType) {
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
    debugPrint('🎯 Accepting request: $requestId');
    state = const AsyncValue.loading();
    try {
      final requestSnap =
          await _firestore.collection('sessionRequests').doc(requestId).get();
      if (!requestSnap.exists) throw Exception('Request not found');
      final requestData = requestSnap.data() ?? {};
      final sessionPrice = (requestData['paymentAmount'] as num?)?.toDouble() ??
          (requestData['sessionPrice'] as num?)?.toDouble() ??
          0.0;
      await _ref
          .read(sessionRepositoryProvider)
          .acceptRequest(requestId, sessionPrice: sessionPrice);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      debugPrint('❌ Error accepting request: $e');
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId, String? reason) async {
    try {
      debugPrint('🚫 Rejecting request: $requestId');

      String? notifyStudentId;
      String? notifyMohaffezName;

      await _firestore.runTransaction((transaction) async {
        // ══════════════════════════════════════════════════════════
        // ── READS PHASE — all reads must come before any write ────
        // ══════════════════════════════════════════════════════════

        // READ 1: sessionRequest
        final requestRef =
            _firestore.collection('sessionRequests').doc(requestId);
        final requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists) throw Exception('Request not found');

        final requestData = requestSnap.data()!;
        final status = requestData['status'] as String? ?? '';

        if (status == 'rejected') return;
        if (status == 'accepted' ||
            status == 'cancelled' ||
            status == 'completed') {
          throw Exception('Cannot reject request with status: $status');
        }

        final subscriptionId = requestData['subscriptionId'] as String?;
        final mohaffezId = requestData['mohaffezId'] as String?;
        final slotDate = requestData['slotDate'] as Timestamp?;
        final timeSlot = requestData['preferredTimeSlot'] as String? ??
            requestData['timeSlot'] as String?;
        final sessionType = requestData['sessionType'] as String?;
        final slotLockId = requestData['slotLockId'] as String?;

        notifyStudentId = requestData['studentId'] as String?;
        notifyMohaffezName = requestData['mohaffezName'] as String?;

        // READ 2: find availability doc ref (regular query, not tracked by tx)
        DocumentReference<Map<String, dynamic>>? availRef;
        if (mohaffezId != null && slotDate != null) {
          availRef = await _findAvailabilityRefTransaction(
            transaction: transaction,
            mohaffezId: mohaffezId,
            slotDate: slotDate,
          );
        }

        // READ 3: availability document (transaction.get — MUST be before writes)
        DocumentSnapshot<Map<String, dynamic>>? availSnap;
        if (availRef != null) {
          availSnap = await transaction.get(availRef);
        }

        // ══════════════════════════════════════════════════════════
        // ── WRITES PHASE ──────────────────────────────────────────
        // ══════════════════════════════════════════════════════════

        // WRITE 1: update sessionRequest status
        transaction.update(requestRef, {
          'status': RequestStatus.rejected,
          'rejectionReason': reason,
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // WRITE 2: release slot lock
        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }

        // WRITE 3: restore availability slot
        if (availRef != null &&
            availSnap != null &&
            availSnap.exists &&
            timeSlot != null &&
            sessionType != null) {
          final availData = availSnap.data();
          if (availData != null) {
            final updatedSlots =
                _computeRestoredSlots(availData, timeSlot, sessionType);
            if (updatedSlots != null) {
              transaction.update(availRef, {
                'timeSlots': updatedSlots,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        if (subscriptionId != null) {
          debugPrint('💳 Subscription credit NOT consumed (request rejected)');
        }
      });

      if (notifyStudentId != null) {
        try {
          await _sendRejectionNotification(
            studentId: notifyStudentId!,
            mohaffezName: notifyMohaffezName ?? '',
            reason: reason,
          );
        } catch (e) {
          try {
            await _firestore.collection('failedOperations').add({
              'operationType': 'rejection-notification',
              'requestId': requestId,
              'studentId': notifyStudentId,
              'error': e.toString(),
              'timestamp': FieldValue.serverTimestamp(),
              'retryCount': 0,
              'status': 'pending-retry',
            });
          } catch (enqueueError) {
            debugPrint(
                'rejectRequest: failed to enqueue notification retry: $enqueueError');
          }
        }
      }

      debugPrint('✅ Request rejected successfully');
    } catch (e) {
      debugPrint('❌ Error rejecting request: $e');
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
      debugPrint('❌ Error sending rejection notification: $e');
    }
  }

  Future<void> cancelSession(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }
    state = const AsyncValue.loading();
    try {
      String? notifyStudentId;
      String? notifyMohaffezId;

      await _firestore.runTransaction((transaction) async {
        // ══════════════════════════════════════════════════════════
        // ── READS PHASE ───────────────────────────────────────────
        // ══════════════════════════════════════════════════════════

        // READ 1: hafizSession
        final sessionRef =
            _firestore.collection('hafizSessions').doc(sessionId);
        final sessionSnap = await transaction.get(sessionRef);
        if (!sessionSnap.exists) throw Exception('Session not found');

        final data = sessionSnap.data()!;
        final status = data['status'] as String? ?? '';

        if (status == 'cancelled') return;
        if (status == 'completed') {
          throw Exception('Cannot cancel a completed session');
        }

        notifyStudentId = data['studentId'] as String?;
        notifyMohaffezId = data['mohaffezId'] as String?;

        final requestId = data['requestId'] as String?;
        final slotLockId = data['slotLockId'] as String?;
        final timeSlot = data['timeSlot'] as String? ??
            data['preferredTimeSlot'] as String?;
        final sessionType = data['sessionType'] as String?;
        final mohaffezId = data['mohaffezId'] as String?;

        // READ 2: linked sessionRequest (MUST be before any write)
        DocumentReference<Map<String, dynamic>>? reqRef;
        DocumentSnapshot<Map<String, dynamic>>? reqSnap;
        if (requestId != null && requestId.trim().isNotEmpty) {
          reqRef = _firestore.collection('sessionRequests').doc(requestId);
          reqSnap = await transaction.get(reqRef);
        }

        // READ 3: availability document (MUST be before any write)
        // BUG FIX #1: The original code required `availDocId` from
        // data['availabilityDocId'], which is NEVER written to the session
        // doc by acceptRequest — so the slot was silently never restored.
        // Fix: use _findAvailabilityRefTransaction with sessionDate,
        // matching the same pattern used in rejectRequest.
        DocumentReference<Map<String, dynamic>>? availRef;
        DocumentSnapshot<Map<String, dynamic>>? availSnap;
        if (mohaffezId != null && timeSlot != null && sessionType != null) {
          final sessionDateTs = data['sessionDate'] as Timestamp?;
          if (sessionDateTs != null) {
            availRef = await _findAvailabilityRefTransaction(
              transaction: transaction,
              mohaffezId: mohaffezId,
              slotDate: sessionDateTs,
            );
            if (availRef != null) {
              availSnap = await transaction.get(availRef);
            }
          }
        }

        // ══════════════════════════════════════════════════════════
        // ── WRITES PHASE ──────────────────────────────────────────
        // ══════════════════════════════════════════════════════════

        // WRITE 1: cancel session
        transaction.update(sessionRef, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // WRITE 2: cancel linked sessionRequest
        if (reqRef != null && reqSnap != null && reqSnap.exists) {
          transaction.update(reqRef, {
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // WRITE 3: release slot lock (if one exists)
        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }

        // WRITE 4: restore availability slot
        if (availRef != null &&
            availSnap != null &&
            availSnap.exists &&
            timeSlot != null &&
            sessionType != null) {
          final availData = availSnap.data();
          if (availData != null) {
            final updatedSlots =
                _computeRestoredSlots(availData, timeSlot, sessionType);
            if (updatedSlots != null) {
              transaction.update(availRef, {
                'timeSlots': updatedSlots,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      });

      if (notifyStudentId != null && notifyMohaffezId != null) {
        await sendCancellationNotifications(
          studentId: notifyStudentId!,
          mohaffezId: notifyMohaffezId!,
          sessionId: sessionId,
        );
      }

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
      String? notifyMohaffezId;
      String? notifyStudentId;
      // BUG FIX #2: extract the real sessionId so sendCancellationNotifications
      // receives the hafizSession ID, not the request ID. Fall back to requestId
      // only when no session has been created yet (pre-payment cancellation).
      String? linkedSessionId;

      await _firestore.runTransaction((transaction) async {
        // ══════════════════════════════════════════════════════════
        // ── READS PHASE ───────────────────────────────────────────
        // ══════════════════════════════════════════════════════════

        // READ 1: sessionRequest
        final requestRef =
            _firestore.collection('sessionRequests').doc(requestId);
        final requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists) throw Exception('Request not found');

        final requestData = requestSnap.data()!;
        final status =
            requestData['status'] as String? ?? RequestStatus.pending;

        if (status == RequestStatus.cancelled) return;
        if (status == 'completed') {
          throw Exception('Cannot cancel completed session');
        }

        notifyStudentId = requestData['studentId'] as String?;
        notifyMohaffezId = requestData['mohaffezId'] as String?;
        // BUG FIX #2: read sessionId from the request document
        linkedSessionId = requestData['sessionId'] as String?;

        final mohaffezId = requestData['mohaffezId'] as String?;
        final slotDate = requestData['slotDate'] as Timestamp?;
        final timeSlot = requestData['preferredTimeSlot'] as String? ??
            requestData['timeSlot'] as String?;
        final sessionType = requestData['sessionType'] as String?;
        final slotLockId = requestData['slotLockId'] as String?;

        // READ 2: find availability ref (regular query — not tracked by tx)
        DocumentReference<Map<String, dynamic>>? availRef;
        if (slotLockId != null &&
            slotLockId.trim().isNotEmpty &&
            mohaffezId != null &&
            slotDate != null &&
            timeSlot != null &&
            sessionType != null) {
          availRef = await _findAvailabilityRefTransaction(
            transaction: transaction,
            mohaffezId: mohaffezId,
            slotDate: slotDate,
          );
        }

        // READ 3: availability document (transaction.get — MUST be before writes)
        DocumentSnapshot<Map<String, dynamic>>? availSnap;
        if (availRef != null) {
          availSnap = await transaction.get(availRef);
        }

        // ══════════════════════════════════════════════════════════
        // ── WRITES PHASE ──────────────────────────────────────────
        // ══════════════════════════════════════════════════════════

        // WRITE 1: cancel request
        transaction.update(requestRef, {
          'status': RequestStatus.cancelled,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': 'student',
        });

        // WRITE 2: release slot lock
        if (slotLockId != null && slotLockId.trim().isNotEmpty) {
          final lockRef = _firestore.collection('slotLocks').doc(slotLockId);
          transaction.delete(lockRef);
        }

        // WRITE 3: restore availability slot
        if (availRef != null &&
            availSnap != null &&
            availSnap.exists &&
            timeSlot != null &&
            sessionType != null) {
          final availData = availSnap.data();
          if (availData != null) {
            final rawSlots = availData['timeSlots'];
            if (rawSlots is List) {
              final updatedSlots =
                  _computeRestoredSlots(availData, timeSlot, sessionType);
              if (updatedSlots != null) {
                transaction.update(availRef, {
                  'timeSlots': updatedSlots,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }
        }
      });

      if (notifyMohaffezId != null && notifyStudentId != null) {
        await sendCancellationNotifications(
          studentId: notifyStudentId!,
          mohaffezId: notifyMohaffezId!,
          // BUG FIX #2: use the real session ID; fall back to requestId
          // only if no session was created yet (pending-state cancellation).
          sessionId: linkedSessionId ?? requestId,
        );
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findAvailabilityRefTransaction({
    required Transaction transaction,
    required String mohaffezId,
    required Timestamp slotDate,
  }) async {
    final slotDateObj = slotDate.toDate();
    final dayOfWeek = slotDateObj.weekday;
    final availQuery = _firestore
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', isEqualTo: dayOfWeek)
        .limit(1);
    final availSnap = await availQuery.get();
    if (availSnap.docs.isEmpty) return null;
    return availSnap.docs.first.reference;
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
    } catch (e, stack) {
      debugPrint(
          'sendCancellationNotifications failed for session $sessionId: $e\n$stack');
      try {
        await _firestore.collection('failedOperations').add({
          'operationType': 'cancellation-notification',
          'sessionId': sessionId,
          'error': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
          'retryCount': 0,
          'status': 'pending-retry',
        });
      } catch (_) {}
    }
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

      if (previousHifzCompleted != null) {
        updates['previousHifzCompleted'] = previousHifzCompleted;
      }
      if (previousHifzRating != null) {
        updates['previousHifzRating'] = previousHifzRating;
      }
      if (previousMurajaCompleted != null) {
        updates['previousMurajaCompleted'] = previousMurajaCompleted;
      }
      if (previousMurajaRating != null) {
        updates['previousMurajaRating'] = previousMurajaRating;
      }
      if (performanceNotes != null && performanceNotes.isNotEmpty) {
        updates['performanceNotes'] = performanceNotes;
      }
      if (newHifzAssignment != null && newHifzAssignment.isNotEmpty) {
        updates['hifzAssignment'] = newHifzAssignment;
      }
      if (newMurajaAssignment != null && newMurajaAssignment.isNotEmpty) {
        updates['murajaAssignment'] = newMurajaAssignment;
      }
      if (generalNotes != null && generalNotes.isNotEmpty) {
        updates['sessionNotes'] = generalNotes;
      }

      if (mistakes != null && mistakes.isNotEmpty) {
        updates['mistakes'] = mistakes.map((m) => m.toMap()).toList();
        updates['mistakesCount'] = mistakes.length;
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

      if (pagesRead != null && pagesRead.isNotEmpty) {
        updates['pagesRead'] = pagesRead;
      }
      if (currentPage != null) {
        updates['currentPage'] = currentPage;
      }

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

  // BUG FIX #3: Added status filter — the original query had no status filter,
  // so students from cancelled or rejected sessions appeared as active students
  // in the teacher's student list. Only sessions that actually happened or are
  // upcoming (accepted/completed) should contribute a student entry.
  final snapshot = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('status', whereIn: ['accepted', 'completed']) // FIX #3
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

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});

/// Fetches a single subscription document by its Firestore document ID.
/// Returns null if the document does not exist.
final bundleByIdProvider = FutureProvider.autoDispose
    .family<SubscriptionModel?, String>((ref, subscriptionId) async {
  return ref.watch(sessionRepositoryProvider).getBundleById(subscriptionId);
});

// FIX Bug 2: Added missing activeBundleProvider.
// watchActiveBundle() exists in SessionRepository but had no Riverpod
// provider — any widget calling activeBundleProvider would throw
// ProviderNotFoundException at runtime.
final activeBundleProvider = StreamProvider.autoDispose
    .family<ActiveBundleInfo?, ({String studentId, String mohaffezId, String sessionType})>(
  (ref, args) {
    return ref.watch(sessionRepositoryProvider).watchActiveBundle(
          studentId: args.studentId,
          mohaffezId: args.mohaffezId,
          sessionType: args.sessionType,
        );
  },
);
