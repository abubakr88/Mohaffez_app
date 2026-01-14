// lib/providers/notification_provider_paginated.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/pagination_state.dart';
import '../repositories/notification_repository.dart';
import 'user_provider.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final _notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

// ============================================================================
// FIRST PAGE PROVIDER (Real-time)
// ============================================================================

/// Watch first page of notifications (real-time, auto-updates)
final notificationsFirstPageProvider = StreamProvider.family<
    List<NotificationModel>,
    String
>((ref, userId) {
  final repository = ref.watch(_notificationRepositoryProvider);
  return repository.watchNotificationsFirstPage(userId);
});

// ============================================================================
// UNREAD COUNT PROVIDER (Real-time)
// ============================================================================

/// Watch unread notification count (real-time)
final unreadNotificationsCountProvider = StreamProvider.family<int, String>(
  (ref, userId) {
    final repository = ref.watch(_notificationRepositoryProvider);
    return repository.watchUnreadCount(userId);
  },
);

// ============================================================================
// PAGINATED STATE NOTIFIER
// ============================================================================

/// Paginated state notifier for notifications
class PaginatedNotificationsNotifier extends StateNotifier<PaginationState<NotificationModel>> {
  final NotificationRepository _repository;
  final String _userId;
  bool _isLoadingMore = false;

  PaginatedNotificationsNotifier(this._repository, this._userId)
      : super(const PaginationState());

  /// Initialize with first page from stream
  void initializeWithFirstPage(List<NotificationModel> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null,
        hasMore: firstPage.length >= 20, // NotificationRepository.pageSize
        isLoadingMore: false,
      );
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    // Get lastDocument if not already set
    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await _repository.getNotificationsNextPage(
        _userId,
        null,
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
      final result = await _repository.getNotificationsNextPage(
        _userId,
        state.lastDocument!,
      );

      // Prevent duplicates
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

  /// Check scroll position and trigger load more
  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage >= 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  /// Refresh notifications (pull to refresh)
  Future<void> refresh() async {
    state = const PaginationState();
    _isLoadingMore = false;
  }

  /// Mark notification as read (update local state + Firestore)
  Future<void> markAsRead(String notificationId) async {
    try {
      // Update Firestore
      await _repository.markAsRead(notificationId);

      // Update local state
      final updatedItems = state.items.map((item) {
        if (item.id == notificationId) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      // Handle error silently or show snackbar
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead(_userId);

      // Update local state
      final updatedItems = state.items.map((item) {
        return item.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);

      // Remove from local state
      final updatedItems = state.items
          .where((item) => item.id != notificationId)
          .toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      await _repository.deleteAllNotifications(_userId);

      // Clear local state
      state = const PaginationState();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }
}

// ============================================================================
// PAGINATED PROVIDER
// ============================================================================

/// Main paginated notifications provider
final paginatedNotificationsProvider = StateNotifierProvider.family<
    PaginatedNotificationsNotifier,
    PaginationState<NotificationModel>,
    String
>((ref, userId) {
  final repository = ref.watch(_notificationRepositoryProvider);
  final notifier = PaginatedNotificationsNotifier(repository, userId);
  
  // Listen to first page stream and initialize
  ref.listen(
    notificationsFirstPageProvider(userId),
    (previous, next) {
      next.whenData((firstPage) {
        notifier.initializeWithFirstPage(firstPage);
      });
    },
  );
  
  return notifier;
});

// ============================================================================
// CONVENIENCE PROVIDERS
// ============================================================================

/// Get current user's notifications (auto-detects userId)
final currentUserNotificationsProvider = Provider<PaginationState<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const PaginationState();
  
  return ref.watch(paginatedNotificationsProvider(user.uid));
});

/// Get current user's unread count
final currentUserUnreadCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return 0;
  
  return ref.watch(unreadNotificationsCountProvider(user.uid)).value ?? 0;
});

// ============================================================================
// NOTIFICATION ACTIONS PROVIDER
// ============================================================================

/// Notification actions (mark as read, delete, etc.)
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref _ref;
  NotificationActions(this._ref);

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .markAsRead(notificationId);
  }

  /// Mark all as read
  Future<void> markAllAsRead(String userId) async {
    await _ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .markAllAsRead();
  }

  /// Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .deleteNotification(notificationId);
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    await _ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .deleteAllNotifications();
  }

  /// Refresh notifications
  Future<void> refresh(String userId) async {
    await _ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .refresh();
  }
}

// ============================================================================
// NOTIFICATION FILTER PROVIDER (Optional)
// ============================================================================

/// Filter notifications by type
enum NotificationFilter {
  all,
  sessionRequest,
  sessionAccepted,
  assignmentUpdated,
  follow,
  system,
}

final notificationFilterProvider = StateProvider<NotificationFilter>((ref) {
  return NotificationFilter.all;
});

/// Filtered notifications based on selected filter
final filteredNotificationsProvider = Provider.family<
    List<NotificationModel>,
    String
>((ref, userId) {
  final paginatedState = ref.watch(paginatedNotificationsProvider(userId));
  final filter = ref.watch(notificationFilterProvider);

  if (filter == NotificationFilter.all) {
    return paginatedState.items;
  }

  String filterType = '';
  switch (filter) {
    case NotificationFilter.sessionRequest:
      filterType = 'session_request';
      break;
    case NotificationFilter.sessionAccepted:
      filterType = 'session_accepted';
      break;
    case NotificationFilter.assignmentUpdated:
      filterType = 'assignment_updated';
      break;
    case NotificationFilter.follow:
      filterType = 'follow';
      break;
    case NotificationFilter.system:
      filterType = 'system';
      break;
    default:
      return paginatedState.items;
  }

  return paginatedState.items
      .where((notification) => notification.type == filterType)
      .toList();
});
