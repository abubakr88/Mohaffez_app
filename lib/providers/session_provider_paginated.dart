// lib/providers/session_provider_paginated.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';
import '../models/pagination_state.dart';
import '../repositories/session_repository.dart';
import 'session_provider.dart';

// Paginated Accepted Sessions Notifier
class PaginatedAcceptedSessionsNotifier extends StateNotifier<PaginationState<SessionModel>> {
  final SessionRepository _repository;
  final String _mohaffezId;

  PaginatedAcceptedSessionsNotifier(this._repository, this._mohaffezId)
      : super(const PaginationState(hasMore: true));

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      if (state.lastDocument == null) {
        // This shouldn't happen as first page is loaded via Stream
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final result = await _repository.getAcceptedSessionsNextPage(
        _mohaffezId,
        state.lastDocument!,
      );

      state = state.copyWith(
        items: [...state.items, ...result.sessions],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void updateFirstPage(List<SessionModel> sessions, DocumentSnapshot? lastDoc) {
    state = state.copyWith(
      items: sessions,
      lastDocument: lastDoc,
      hasMore: sessions.length >= SessionRepository.pageSize,
    );
  }
}

// Provider for paginated accepted sessions
final paginatedAcceptedSessionsProvider = StateNotifierProvider.family<
    PaginatedAcceptedSessionsNotifier,
    PaginationState<SessionModel>,
    String>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return PaginatedAcceptedSessionsNotifier(repository, mohaffezId);
});

// Stream provider for first page (real-time updates)
final acceptedSessionsFirstPageProvider = StreamProvider.family<
    ({List<SessionModel> sessions, DocumentSnapshot? lastDoc}),
    String>((ref, mohaffezId) async* {
  final repository = ref.watch(sessionRepositoryProvider);
  
  await for (final sessions in repository.watchAcceptedSessionsFirstPage(mohaffezId)) {
    // Get the last document for pagination
    final snapshot = await FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .orderBy('sessionDate', descending: true)
        .limit(SessionRepository.pageSize)
        .get();

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    // Update the paginated state
    ref.read(paginatedAcceptedSessionsProvider(mohaffezId).notifier)
        .updateFirstPage(sessions, lastDoc);

    yield (sessions: sessions, lastDoc: lastDoc);
  }
});

// Paginated Student Sessions Notifier
class PaginatedStudentSessionsNotifier extends StateNotifier<PaginationState<SessionModel>> {
  final SessionRepository _repository;
  final String _studentId;

  PaginatedStudentSessionsNotifier(this._repository, this._studentId)
      : super(const PaginationState(hasMore: true));

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      if (state.lastDocument == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final result = await _repository.getStudentSessionsNextPage(
        _studentId,
        state.lastDocument!,
      );

      state = state.copyWith(
        items: [...state.items, ...result.sessions],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void updateFirstPage(List<SessionModel> sessions, DocumentSnapshot? lastDoc) {
    state = state.copyWith(
      items: sessions,
      lastDocument: lastDoc,
      hasMore: sessions.length >= SessionRepository.pageSize,
    );
  }
}

// Provider for paginated student sessions
final paginatedStudentSessionsProvider = StateNotifierProvider.family<
    PaginatedStudentSessionsNotifier,
    PaginationState<SessionModel>,
    String>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return PaginatedStudentSessionsNotifier(repository, studentId);
});

// Stream provider for first page
final studentSessionsFirstPageProvider = StreamProvider.family<
    ({List<SessionModel> sessions, DocumentSnapshot? lastDoc}),
    String>((ref, studentId) async* {
  final repository = ref.watch(sessionRepositoryProvider);
  
  await for (final sessions in repository.watchStudentSessionsFirstPage(studentId)) {
    final snapshot = await FirebaseFirestore.instance
        .collection('hafizSessions')
        .where('studentId', isEqualTo: studentId)
        .orderBy('sessionDate', descending: true)
        .limit(SessionRepository.pageSize)
        .get();

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    ref.read(paginatedStudentSessionsProvider(studentId).notifier)
        .updateFirstPage(sessions, lastDoc);

    yield (sessions: sessions, lastDoc: lastDoc);
  }
});

// Paginated Pending Requests Notifier
class PaginatedPendingRequestsNotifier extends StateNotifier<PaginationState<SessionRequestModel>> {
  final SessionRepository _repository;
  final String _mohaffezId;

  PaginatedPendingRequestsNotifier(this._repository, this._mohaffezId)
      : super(const PaginationState(hasMore: true));

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      if (state.lastDocument == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final result = await _repository.getPendingRequestsNextPage(
        _mohaffezId,
        state.lastDocument!,
      );

      state = state.copyWith(
        items: [...state.items, ...result.requests],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void updateFirstPage(List<SessionRequestModel> requests, DocumentSnapshot? lastDoc) {
    state = state.copyWith(
      items: requests,
      lastDocument: lastDoc,
      hasMore: requests.length >= SessionRepository.pageSize,
    );
  }
}

final paginatedPendingRequestsProvider = StateNotifierProvider.family<
    PaginatedPendingRequestsNotifier,
    PaginationState<SessionRequestModel>,
    String>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return PaginatedPendingRequestsNotifier(repository, mohaffezId);
});

final pendingRequestsFirstPageProvider = StreamProvider.family<
    ({List<SessionRequestModel> requests, DocumentSnapshot? lastDoc}),
    String>((ref, mohaffezId) async* {
  final repository = ref.watch(sessionRepositoryProvider);
  
  await for (final requests in repository.watchPendingRequestsFirstPage(mohaffezId)) {
    final snapshot = await FirebaseFirestore.instance
        .collection('sessionRequests')
        .where('mohaffezId', isEqualTo: mohaffezId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(SessionRepository.pageSize)
        .get();

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    ref.read(paginatedPendingRequestsProvider(mohaffezId).notifier)
        .updateFirstPage(requests, lastDoc);

    yield (requests: requests, lastDoc: lastDoc);
  }
});
