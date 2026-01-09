import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';
import '../repositories/session_repository.dart';

// Repository provider
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});

// Pending requests for mohaffez
final pendingRequestsProvider = StreamProvider.family<List<SessionRequestModel>, String>(
  (ref, mohaffezId) {
    return ref.watch(sessionRepositoryProvider).watchPendingRequests(mohaffezId);
  },
);

// Accepted sessions for mohaffez
final acceptedSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, mohaffezId) {
    return ref.watch(sessionRepositoryProvider).watchAcceptedSessions(mohaffezId);
  },
);

// Student sessions
final studentSessionsProvider = StreamProvider.family<List<SessionModel>, String>(
  (ref, studentId) {
    return ref.watch(sessionRepositoryProvider).watchStudentSessions(studentId);
  },
);

// Student requests
final studentRequestsProvider = StreamProvider.family<List<SessionRequestModel>, String>(
  (ref, studentId) {
    return ref.watch(sessionRepositoryProvider).watchStudentRequests(studentId);
  },
);

// Upcoming sessions for mohaffez
final upcomingSessionsProvider = FutureProvider.family<List<SessionModel>, String>(
  (ref, mohaffezId) async {
    return ref.watch(sessionRepositoryProvider).getUpcomingSessions(mohaffezId);
  },
);

// Session booking notifier
class SessionBookingNotifier extends StateNotifier<AsyncValue<void>> {
  final SessionRepository _repository;

  SessionBookingNotifier(this._repository) : super(const AsyncValue.data(null));

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
      final result = await _repository.createSessionRequest(
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

      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return BookingResult.failure(e.toString());
    }
  }

  Future<void> acceptRequest(String requestId, Map<String, dynamic> requestData) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _repository.acceptRequest(requestId, requestData);
    });
  }

  Future<void> rejectRequest(String requestId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _repository.rejectRequest(requestId);
    });
  }

  Future<void> updateAssignment({
    required String sessionId,
    required String hifzAssignment,
    required String murajaAssignment,
    required int rating,
    required String notes,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _repository.updateSessionAssignment(
        sessionId: sessionId,
        hifzAssignment: hifzAssignment,
        murajaAssignment: murajaAssignment,
        rating: rating,
        notes: notes,
      );
    });
  }
}

final sessionBookingProvider =
    StateNotifierProvider<SessionBookingNotifier, AsyncValue<void>>((ref) {
  return SessionBookingNotifier(ref.watch(sessionRepositoryProvider));
});
