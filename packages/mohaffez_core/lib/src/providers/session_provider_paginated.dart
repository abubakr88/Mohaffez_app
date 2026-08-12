// lib/providers/session_provider_paginated.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/session_repository.dart';
import '../models/request_status.dart';
import '../models/quran_mistake_model.dart';
import '../models/mohaffez_student_summary.dart';
import '../models/subscription_model.dart';
import 'auth_provider.dart';

/// Parses time from timeSlot (e.g., "15:30 - 16:15" → 15:30) and combines with date
DateTime? _parseSessionDateTime(DateTime? date, String? timeSlot) {
  if (date == null) return null;
  if (timeSlot == null || timeSlot.isEmpty) return date;

  try {
    // Extract start time from "15:30 - 16:15" format
    final startTimeStr = timeSlot.split('-').first.trim();
    final parts = startTimeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  } catch (_) {
    // Fallback to original date if parsing fails
  }
  return date;
}

DateTime? _timestampDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _displayTimeSlot(Map<String, dynamic> data) {
  if ((data['bookingTimeZoneVersion'] as num?)?.toInt() == 1) {
    final start = _timestampDate(data['slotStart'])?.toLocal();
    final end = _timestampDate(data['slotEnd'])?.toLocal();
    if (start != null && end != null) {
      String clock(DateTime value) =>
          '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}';
      return '${clock(start)} - ${clock(end)}';
    }
  }
  return data['preferredTimeSlot'] as String? ??
      data['timeSlot'] as String? ??
      '08:00';
}

DateTime? _displaySessionDate(Map<String, dynamic> data) {
  if ((data['bookingTimeZoneVersion'] as num?)?.toInt() == 1) {
    return _timestampDate(data['slotStart'])?.toLocal();
  }
  return _timestampDate(data['sessionDate']);
}

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

bool _isVisibleUpcomingSession(Map<String, dynamic> data) {
  return data['isPaid'] == true ||
      data['isTrial'] == true ||
      data['bookingKind'] == 'trial';
}

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
    try {
      final query = FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'accepted')
          .where('isPaid', isEqualTo: true);
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      // Fallback: query without count() if index is missing
      final snapshot = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'accepted')
          .get();
      return snapshot.docs.where((d) => d.data()['isPaid'] == true).length;
    }
  },
);

final acceptedStudentSessionsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final seen = <String>{};
      return snapshot.docs.where((doc) => seen.add(doc.id)).map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': _displayTimeSlot(data),
          'sessionDate': _displaySessionDate(data),
          'slotStart': _timestampDate(data['slotStart'])?.toLocal(),
          'slotEnd': _timestampDate(data['slotEnd'])?.toLocal(),
          'bookingTimeZoneVersion': data['bookingTimeZoneVersion'] ?? 0,
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
        .where('sessionDate', isGreaterThanOrEqualTo: startOfDay)
        .orderBy('sessionDate', descending: false)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.where((doc) {
        return _isVisibleUpcomingSession(doc.data());
      }).map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'studentName': data['studentName'] as String? ?? '',
          'mohaffezName': data['mohaffezName'] as String? ?? '',
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': _displayTimeSlot(data),
          'sessionDate': (data['bookingTimeZoneVersion'] as num?)?.toInt() == 1
              ? _displaySessionDate(data)
              : _parseSessionDateTime(
                  (data['sessionDate'] as Timestamp?)?.toDate(),
                  data['preferredTimeSlot'] as String? ??
                      data['timeSlot'] as String?,
                ),
          'slotStart': _timestampDate(data['slotStart'])?.toLocal(),
          'slotEnd': _timestampDate(data['slotEnd'])?.toLocal(),
          'bookingTimeZoneVersion': data['bookingTimeZoneVersion'] ?? 0,
          'location': data['location'] as String? ??
              data['imamAddressText'] as String? ??
              '',
          'hifzAssignment': data['hifzAssignment'] as String?,
          'murajaAssignment': data['murajaAssignment'] as String?,
          'sessionRating': data['sessionRating'] as int?,
          'sessionNotes': data['sessionNotes'] as String?,
          'status': data['status'] as String? ?? 'accepted',
          'studentId': data['studentId'] as String?,
          'studentProfileId': data['studentProfileId'] as String?,
          'studentProfileName': data['studentProfileName'] as String?,
          'studentProfilePhotoUrl': data['studentProfilePhotoUrl'] as String?,
          'guardianId': data['guardianId'] as String?,
          'guardianName': data['guardianName'] as String?,
          'isPaid': data['isPaid'] as bool? ?? false,
          'isTrial': data['isTrial'] as bool? ?? false,
          'bookingKind': data['bookingKind'] as String?,
          'subscriptionId': data['subscriptionId'] as String?,
        };
      }).toList();
      // Secondary sort by time-of-day since Firestore only orders by date (day-level).
      list.sort((a, b) {
        final aDate = a['sessionDate'] as DateTime?;
        final bDate = b['sessionDate'] as DateTime?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      return list;
    });
  },
);

// ============================================================================
// STUDENT UPCOMING SESSIONS (for countdown)
// ============================================================================
final studentUpcomingSessionsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    final lifecycleListener = AppLifecycleListener(
      onResume: () => ref.invalidateSelf(),
    );
    ref.onDispose(lifecycleListener.dispose);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'accepted')
        .where('sessionDate', isGreaterThanOrEqualTo: startOfDay)
        .orderBy('sessionDate', descending: false)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.where((doc) {
              return _isVisibleUpcomingSession(doc.data());
            }).map((doc) {
              final data = doc.data();
              return <String, dynamic>{
                ...data,
                'id': doc.id,
                'sessionDate':
                    (data['bookingTimeZoneVersion'] as num?)?.toInt() == 1
                        ? _displaySessionDate(data)
                        : _parseSessionDateTime(
                            (data['sessionDate'] as Timestamp?)?.toDate(),
                            data['preferredTimeSlot'] as String? ??
                                data['timeSlot'] as String?,
                          ),
                'preferredTimeSlot': _displayTimeSlot(data),
                'slotStart': _timestampDate(data['slotStart'])?.toLocal(),
                'slotEnd': _timestampDate(data['slotEnd'])?.toLocal(),
                'mohaffezId': data['mohaffezId'] as String? ?? '',
                'mohaffezName': data['mohaffezName'] as String? ?? '',
                'studentId': data['studentId'] as String? ?? studentId,
                'studentProfileId': data['studentProfileId'] as String?,
                'studentProfileName': data['studentProfileName'] as String?,
                'isPaid': data['isPaid'] as bool? ?? false,
                'isTrial': data['isTrial'] as bool? ?? false,
                'bookingKind': data['bookingKind'] as String?,
              };
            }).toList());
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
            final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
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
            final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
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
  dependencies: [upcomingSessionsProvider],
);

// ============================================================================
// COMPLETED SESSIONS - Stream (Real-time)
// ============================================================================
final completedSessionsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
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
          'sessionDate': _displaySessionDate(data),
          'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': _displayTimeSlot(data),
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
          'sessionDate': _displaySessionDate(data),
          'completedAt': (data['completedAt'] as Timestamp?)?.toDate(),
          'sessionType': data['sessionType'] as String? ?? '',
          'preferredTimeSlot': _displayTimeSlot(data),
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
          'preferredTimeSlot': _displayTimeSlot(data),
          'sessionDate': _displaySessionDate(data),
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

final paginatedStudentSessionsProvider = StateNotifierProvider.autoDispose
    .family<StudentSessionsNotifier, StudentSessionsState, String>(
  (ref, studentId) {
    return StudentSessionsNotifier(studentId);
  },
);

final studentSessionsFirstPageProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (authUid == null || authUid != studentId) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }
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
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, studentId) {
    final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (authUid == null || authUid != studentId) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }
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
                'preferredTimeSlot': _displayTimeSlot(data),
                'bookingTimeZoneVersion': data['bookingTimeZoneVersion'] ?? 0,
                'slotStart': _timestampDate(data['slotStart'])?.toLocal(),
                'slotEnd': _timestampDate(data['slotEnd'])?.toLocal(),
                'status': data['status'] as String? ?? 'pending',
                'createdAt': data['createdAt'] as Timestamp?,
                'slotDate': data['slotDate'] as Timestamp?,
                'paymentDeadline': data['paymentDeadline'] as Timestamp?,
                'reminderSent': data['reminderSent'] as bool? ?? false,
                'sessionId': data['sessionId'] as String?,
                'planType': data['planType'] as String?,
                'planTitle': data['planTitle'] as String?,
                'sessionsCount': data['sessionsCount'],
                'directPaymentRequestId':
                    data['directPaymentRequestId'] as String?,
              };
            }).toList());
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

      debugPrint('✅ Request rejected successfully');
    } catch (e) {
      debugPrint('❌ Error rejecting request: $e');
      throw Exception('Failed to reject request: $e');
    }
  }

  Future<void> cancelSession(String sessionId,
      {required String cancelledBy}) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError('Session ID cannot be empty');
    }
    state = const AsyncValue.loading();
    try {
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

        final requestId = data['requestId'] as String?;
        final slotLockId = data['slotLockId'] as String?;
        final timeSlot =
            data['timeSlot'] as String? ?? data['preferredTimeSlot'] as String?;
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
          'cancelledBy': cancelledBy,
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

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<DocumentReference<Map<String, dynamic>>?>
      _findAvailabilityRefTransaction({
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
    bool? startedLate,
    String? technicalIssueSource,
    String? teacherRatingReason,
  }) async {
    final updates = <String, dynamic>{};
    if (hifz != null) updates['hifzAssignment'] = hifz;
    if (muraja != null) updates['murajaAssignment'] = muraja;
    if (notes != null) updates['reviewNotes'] = notes;
    if (rating != null) {
      updates['teacherRating'] = rating;
      updates['teacherRatingScale'] = 5;
      updates['teacherRatedAt'] = FieldValue.serverTimestamp();
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }
    if (startedLate != null) updates['startedLate'] = startedLate;
    if (technicalIssueSource != null) {
      updates['technicalIssueSource'] = technicalIssueSource;
    }
    if (teacherRatingReason != null) {
      updates['teacherRatingReason'] = teacherRatingReason;
    }
    if (updates.isNotEmpty) {
      await updateSession(sessionId, updates);

      // Note: Teacher rating update is now handled by Cloud Function
      // Client-side query not allowed due to Firestore security rules
    }
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
    String? newHifzFromAyah,
    String? newHifzToAyah,
    String? newMurajaFromAyah,
    String? newMurajaToAyah,
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
        // Stamp `meetingEndedAt` so the online-meeting button on the student
        // side flips to MeetingButtonState.ended (renders "انتهت الجلسة")
        // immediately, instead of staying on the active "انضم" button.
        'meetingEndedAt': FieldValue.serverTimestamp(),
        'sessionRating': sessionRating,
        'isLateCompletion': isLateCompletion,
        'quizUnlocked': false,
        'challengeAccess.status': 'closed',
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
      // Ayah range for new hifz
      if (newHifzFromAyah != null && newHifzFromAyah.isNotEmpty) {
        updates['hifzFromAyah'] = newHifzFromAyah;
      }
      if (newHifzToAyah != null && newHifzToAyah.isNotEmpty) {
        updates['hifzToAyah'] = newHifzToAyah;
      }
      // Ayah range for new muraja
      if (newMurajaFromAyah != null && newMurajaFromAyah.isNotEmpty) {
        updates['murajaFromAyah'] = newMurajaFromAyah;
      }
      if (newMurajaToAyah != null && newMurajaToAyah.isNotEmpty) {
        updates['murajaToAyah'] = newMurajaToAyah;
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

      // Send notification to student that session is completed and ready for rating
      // NOTE: Session completion notification moved to UI layer
      // The mobile package calls NotificationService.sendSessionCompletedNotification
      // after successful session completion. Keep this try-catch placeholder for future use.

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
    final rawProfileId = (data['studentProfileId'] as String?)?.trim();
    final studentProfileId = rawProfileId != null &&
            rawProfileId.isNotEmpty &&
            rawProfileId != 'self'
        ? rawProfileId
        : null;
    final groupKey =
        studentProfileId == null ? studentId : '$studentId::$studentProfileId';
    final profileName = (data['studentProfileName'] as String?)?.trim();
    final rawProfilePhotoUrl =
        (data['studentProfilePhotoUrl'] as String?)?.trim();
    final profilePhotoUrl =
        rawProfilePhotoUrl != null && rawProfilePhotoUrl.isNotEmpty
            ? rawProfilePhotoUrl
            : null;

    counts[groupKey] = (counts[groupKey] ?? 0) + 1;

    if (!students.containsKey(groupKey)) {
      students[groupKey] = MohaffezStudentSummary(
        studentId: studentId,
        studentName: profileName != null && profileName.isNotEmpty
            ? profileName
            : data['studentName'] as String? ?? '',
        studentProfileId: studentProfileId,
        photoUrl: profilePhotoUrl,
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
        previousHifzFromAyah: data['hifzFromAyah'] as String?,
        previousHifzToAyah: data['hifzToAyah'] as String?,
        previousMurajaFromAyah: data['murajaFromAyah'] as String?,
        previousMurajaToAyah: data['murajaToAyah'] as String?,
        performanceNotes: data['performanceNotes'] as String?,
      );
    }
  }

  // Batch-fetch photoUrl from users collection (chunked to respect Firestore whereIn limit of 30)
  final studentIds = students.values.map((s) => s.studentId).toSet().toList();
  final Map<String, String?> photoUrls = {};
  for (int i = 0; i < studentIds.length; i += 30) {
    final chunk = studentIds.sublist(
        i, i + 30 > studentIds.length ? studentIds.length : i + 30);
    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final doc in userDocs.docs) {
      final url = doc.data()['photoUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        photoUrls[doc.id] = url;
      }
    }
  }

  return students.values
      .map((s) => s.copyWith(
            sessionCount: counts[s.studentProfileId == null
                    ? s.studentId
                    : '${s.studentId}::${s.studentProfileId}'] ??
                1,
            photoUrl: s.photoUrl ?? photoUrls[s.studentId],
          ))
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
final activeBundleProvider = StreamProvider.autoDispose.family<
    ActiveBundleInfo?,
    ({String studentId, String mohaffezId, String sessionType})>(
  (ref, args) {
    return ref.watch(sessionRepositoryProvider).watchActiveBundle(
          studentId: args.studentId,
          mohaffezId: args.mohaffezId,
          sessionType: args.sessionType,
        );
  },
);
