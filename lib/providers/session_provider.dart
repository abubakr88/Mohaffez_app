// lib/providers/session_provider.dart (FIX LINES 57 & 98)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';
import '../models/booking_result.dart';
import '../repositories/session_repository.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});

// ============================================================================
// STREAM PROVIDERS (Real-time data)
// ============================================================================

/// Watch accepted sessions for mohaffez
final mohaffezAcceptedSessionsProvider = StreamProvider.family<
    List<SessionModel>,
    String
>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchAcceptedSessions(mohaffezId);
});

/// Watch sessions for student
final studentSessionsProvider = StreamProvider.family<
    List<SessionModel>,
    String
>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchStudentSessions(studentId);
});

/// Watch requests for student
final studentRequestsProvider = StreamProvider.family<
    List<SessionRequestModel>,
    String
>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchStudentRequests(studentId);
});

// ============================================================================
// SESSION BOOKING NOTIFIER
// ============================================================================

class SessionBookingNotifier extends StateNotifier<AsyncValue<BookingResult>> {
  final SessionRepository _repository;

  // FIXED LINE 57: Removed const
  SessionBookingNotifier(this._repository) : super(AsyncValue.data(
    BookingResult(success: false, sessionId: null, errorMessage: null)
  ));

  Future<BookingResult> requestSession({
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
    state = const AsyncValue.loading();

    try {
      final sessionId = await _repository.createSessionRequest(
        mohaffezId: mohaffezId,
        studentId: studentId,
        studentName: studentName,
        mohaffezName: mohaffezName,
        slotStart: slotStart,
        slotEnd: slotEnd,
        sessionType: sessionType,
        timeSlot: timeSlot,
        additionalData: additionalData,
      );

      final result = BookingResult.success(sessionId);
      state = AsyncValue.data(result);
      return result;
    } catch (e, stack) {
      final result = BookingResult.failure('فشل إنشاء الطلب: ${e.toString()}');
      state = AsyncValue.error(e, stack);
      return result;
    }
  }

  // FIXED LINE 98: Removed const
  void reset() {
    state = AsyncValue.data(
      BookingResult(success: false, sessionId: null, errorMessage: null)
    );
  }
}

final sessionBookingProvider = StateNotifierProvider<
    SessionBookingNotifier,
    AsyncValue<BookingResult>
>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  return SessionBookingNotifier(repository);
});

// ============================================================================
// SESSION ACTIONS NOTIFIER
// ============================================================================

class SessionActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final SessionRepository _repository;

  SessionActionsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> acceptRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.acceptRequest(requestId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectRequest(requestId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateAssignment({
    required String sessionId,
    required String hifzAssignment,
    required String murajaAssignment,
    required int rating,
    required String notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateSessionAssignment(
        sessionId: sessionId,
        hifzAssignment: hifzAssignment,
        murajaAssignment: murajaAssignment,
        rating: rating,
        notes: notes,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final sessionActionsProvider = StateNotifierProvider<
    SessionActionsNotifier,
    AsyncValue<void>
>((ref) {
  final repository = ref.watch(sessionRepositoryProvider);
  return SessionActionsNotifier(repository);
});

// ============================================================================
// FUTURE PROVIDERS (One-time queries)
// ============================================================================

/// Get upcoming sessions for mohaffez
final upcomingSessionsProvider = FutureProvider.family<
    List<SessionModel>,
    String
>((ref, mohaffezId) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getUpcomingSessions(mohaffezId);
});

/// Get session by ID
final sessionByIdProvider = FutureProvider.family<
    SessionModel?,
    String
>((ref, sessionId) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getSessionById(sessionId);
});

/// Get request by ID
final requestByIdProvider = FutureProvider.family<
    SessionRequestModel?,
    String
>((ref, requestId) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getRequestById(requestId);
});

/// Get mohaffez session count
final mohaffezSessionCountProvider = FutureProvider.family<int, String>(
  (ref, mohaffezId) async {
    final repository = ref.watch(sessionRepositoryProvider);
    return repository.getMohaffezSessionCount(mohaffezId);
  },
);

/// Get student session count
final studentSessionCountProvider = FutureProvider.family<int, String>(
  (ref, studentId) async {
    final repository = ref.watch(sessionRepositoryProvider);
    return repository.getStudentSessionCount(studentId);
  },
);
