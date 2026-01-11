// lib/providers/session_provider_paginated.dart (COMPLETE - ~300 lines)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';
import '../models/session_request_model.dart';
import '../models/pagination_state.dart';
import '../repositories/session_repository.dart';
import 'auth_provider.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(FirebaseFirestore.instance);
});

// ============================================================================
// PENDING REQUESTS PAGINATION (MOHAFFEZ)
// ============================================================================

/// First page provider for real-time updates
final pendingRequestsFirstPageProvider = StreamProvider.family<
    List<SessionRequestModel>, 
    String
>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchPendingRequestsFirstPage(mohaffezId);
});

/// Paginated state notifier for pending requests
class PaginatedPendingRequestsNotifier extends StateNotifier<PaginationState<SessionRequestModel>> {
  final SessionRepository _repository;
  final String _mohaffezId;
  bool _isLoadingMore = false;

  PaginatedPendingRequestsNotifier(this._repository, this._mohaffezId)
      : super(const PaginationState());

  /// Initialize with first page from stream
  void initializeWithFirstPage(List<SessionRequestModel> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null, // Will be set on first loadMore
        hasMore: firstPage.length >= 20, // Assume more if full page
        isLoadingMore: false,
      );
    }
  }

  /// Load next page
  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    // Get last document if we don't have it yet
    if (state.lastDocument == null && state.items.isNotEmpty) {
      // Need to fetch to get DocumentSnapshot
      final result = await _repository.getPendingRequestsNextPage(
        mohaffezId: _mohaffezId,
        lastDocument: null, // Will internally handle this
      );
      
      state = state.copyWith(
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
      );
      
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await _repository.getPendingRequestsNextPage(
        mohaffezId: _mohaffezId,
        lastDocument: state.lastDocument!,
      );

      // Merge with existing items, avoiding duplicates
      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = result.notifications
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'فشل تحميل المزيد: ${e.toString()}',
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Check scroll position and auto-load
  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage >= 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  /// Refresh from beginning
  Future<void> refresh() async {
    state = const PaginationState();
    _isLoadingMore = false;
  }
}

final paginatedPendingRequestsProvider = StateNotifierProvider.family<
    PaginatedPendingRequestsNotifier,
    PaginationState<SessionRequestModel>,
    String
>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  final notifier = PaginatedPendingRequestsNotifier(repository, mohaffezId);
  
  // Listen to first page stream and initialize
  ref.listen(
    pendingRequestsFirstPageProvider(mohaffezId),
    (previous, next) {
      next.whenData((firstPage) {
        notifier.initializeWithFirstPage(firstPage);
      });
    },
  );
  
  return notifier;
});

// ============================================================================
// ACCEPTED SESSIONS PAGINATION (MOHAFFEZ)
// ============================================================================

/// First page provider for accepted sessions
final acceptedSessionsFirstPageProvider = StreamProvider.family<
    List<SessionModel>,
    String
>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchAcceptedSessions(mohaffezId);
});

/// Paginated state notifier for accepted sessions
class PaginatedAcceptedSessionsNotifier extends StateNotifier<PaginationState<SessionModel>> {
  final SessionRepository _repository;
  final String _mohaffezId;
  bool _isLoadingMore = false;

  PaginatedAcceptedSessionsNotifier(this._repository, this._mohaffezId)
      : super(const PaginationState());

  void initializeWithFirstPage(List<SessionModel> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null,
        hasMore: firstPage.length >= 20,
        isLoadingMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await _repository.getAcceptedSessionsNextPage(
        mohaffezId: _mohaffezId,
        lastDocument: null,
      );
      
      state = state.copyWith(
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
      );
      
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await _repository.getAcceptedSessionsNextPage(
        mohaffezId: _mohaffezId,
        lastDocument: state.lastDocument!,
      );

      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = result.sessions
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'فشل تحميل المزيد: ${e.toString()}',
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage >= 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  Future<void> refresh() async {
    state = const PaginationState();
    _isLoadingMore = false;
  }
}

final paginatedAcceptedSessionsProvider = StateNotifierProvider.family<
    PaginatedAcceptedSessionsNotifier,
    PaginationState<SessionModel>,
    String
>((ref, mohaffezId) {
  final repository = ref.watch(sessionRepositoryProvider);
  final notifier = PaginatedAcceptedSessionsNotifier(repository, mohaffezId);
  
  ref.listen(
    acceptedSessionsFirstPageProvider(mohaffezId),
    (previous, next) {
      next.whenData((firstPage) {
        notifier.initializeWithFirstPage(firstPage);
      });
    },
  );
  
  return notifier;
});

// ============================================================================
// STUDENT SESSIONS PAGINATION
// ============================================================================

/// First page provider for student sessions
final studentSessionsFirstPageProvider = StreamProvider.family<
    List<SessionModel>,
    String
>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchStudentSessions(studentId);
});

/// Paginated state notifier for student sessions
class PaginatedStudentSessionsNotifier extends StateNotifier<PaginationState<SessionModel>> {
  final SessionRepository _repository;
  final String _studentId;
  bool _isLoadingMore = false;

  PaginatedStudentSessionsNotifier(this._repository, this._studentId)
      : super(const PaginationState());

  void initializeWithFirstPage(List<SessionModel> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null,
        hasMore: firstPage.length >= 20,
        isLoadingMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await _repository.getStudentSessionsNextPage(
        studentId: _studentId,
        lastDocument: null,
      );
      
      state = state.copyWith(
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
      );
      
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await _repository.getStudentSessionsNextPage(
        studentId: _studentId,
        lastDocument: state.lastDocument!,
      );

      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = result.sessions
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'فشل تحميل المزيد: ${e.toString()}',
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage >= 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  Future<void> refresh() async {
    state = const PaginationState();
    _isLoadingMore = false;
  }
}

final paginatedStudentSessionsProvider = StateNotifierProvider.family<
    PaginatedStudentSessionsNotifier,
    PaginationState<SessionModel>,
    String
>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  final notifier = PaginatedStudentSessionsNotifier(repository, studentId);
  
  ref.listen(
    studentSessionsFirstPageProvider(studentId),
    (previous, next) {
      next.whenData((firstPage) {
        notifier.initializeWithFirstPage(firstPage);
      });
    },
  );
  
  return notifier;
});

// ============================================================================
// STUDENT REQUESTS PAGINATION
// ============================================================================

/// First page provider for student requests
final studentRequestsFirstPageProvider = StreamProvider.family<
    List<SessionRequestModel>,
    String
>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.watchStudentRequests(studentId);
});

/// Paginated state notifier for student requests
class PaginatedStudentRequestsNotifier extends StateNotifier<PaginationState<SessionRequestModel>> {
  final SessionRepository _repository;
  final String _studentId;
  bool _isLoadingMore = false;

  PaginatedStudentRequestsNotifier(this._repository, this._studentId)
      : super(const PaginationState());

  void initializeWithFirstPage(List<SessionRequestModel> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null,
        hasMore: firstPage.length >= 20,
        isLoadingMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await _repository.getStudentRequestsNextPage(
        studentId: _studentId,
        lastDocument: null,
      );
      
      state = state.copyWith(
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
      );
      
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await _repository.getStudentRequestsNextPage(
        studentId: _studentId,
        lastDocument: state.lastDocument!,
      );

      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = result.requests
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDoc,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'فشل تحميل المزيد: ${e.toString()}',
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage >= 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  Future<void> refresh() async {
    state = const PaginationState();
    _isLoadingMore = false;
  }
}

final paginatedStudentRequestsProvider = StateNotifierProvider.family<
    PaginatedStudentRequestsNotifier,
    PaginationState<SessionRequestModel>,
    String
>((ref, studentId) {
  final repository = ref.watch(sessionRepositoryProvider);
  final notifier = PaginatedStudentRequestsNotifier(repository, studentId);
  
  ref.listen(
    studentRequestsFirstPageProvider(studentId),
    (previous, next) {
      next.whenData((firstPage) {
        notifier.initializeWithFirstPage(firstPage);
      });
    },
  );
  
  return notifier;
});
