// lib/providers/notification_provider_paginated.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/pagination_state.dart';
import '../repositories/notification_repository.dart';
import 'user_provider.dart';

// ===== REPOSITORY PROVIDER =====

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

// ===== FIRST PAGE PROVIDER (Real-time) =====

final notificationsFirstPageProvider = StreamProvider.family<List<NotificationModel>, String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    return repository.watchNotificationsFirstPage(userId);
  },
);

// ===== UNREAD COUNT PROVIDER (Real-time) =====

final unreadNotificationsCountProvider = StreamProvider.family<int, String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    return repository.watchUnreadCount(userId);
  },
);

// ===== PAGINATED STATE NOTIFIER =====

class PaginatedNotificationsNotifier extends StateNotifier<PaginationState<NotificationModel>> {
  final NotificationRepository repository;
  final String userId;
  bool _isLoadingMore = false;

  PaginatedNotificationsNotifier(this.repository, this.userId)
      : super(const PaginationState());

  /// Initialize with first page from real-time stream
  void initializeWithFirstPage(List<NotificationModel> firstPage) {
    if (state.items.isEmpty && firstPage.isNotEmpty) {
      state = PaginationState(
        items: firstPage,
        lastDocument: null,
        hasMore: firstPage.length >= 20, // Assume more if we got full page
        isLoadingMore: false,
      );
    }
  }

  /// Load more notifications (paginated)
  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    // ✅ FIXED: Initialize lastDocument if needed
    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await repository.getNotificationsNextPage(
        userId: userId,
        lastDocument: null,
      );
      state = state.copyWith(
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
      );
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await repository.getNotificationsNextPage(
        userId: userId,
        lastDocument: state.lastDocument,
      );

      // Avoid duplicates
      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems = result.items
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Check scroll position and auto-load more
  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage > 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  /// Refresh (reset state)
  Future<void> refresh() async {
    state = const PaginationState(isLoadingMore: false);
  }

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await repository.markAsRead(notificationId);
      
      // Update local state
      final updatedItems = state.items.map((item) {
        if (item.id == notificationId) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await repository.markAllAsRead(userId);
      
      // Update local state
      final updatedItems = state.items.map((item) {
        return item.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Delete single notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await repository.deleteNotification(notificationId);
      
      // Remove from local state
      final updatedItems = state.items
          .where((item) => item.id != notificationId)
          .toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      await repository.deleteAllNotifications(userId);
      state = const PaginationState();
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }
}

// ===== PAGINATED PROVIDER =====

final paginatedNotificationsProvider = StateNotifierProvider.family<
    PaginatedNotificationsNotifier,
    PaginationState<NotificationModel>,
    String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    final notifier = PaginatedNotificationsNotifier(repository, userId);

    // Listen to first page changes (real-time)
    ref.listen(
      notificationsFirstPageProvider(userId),
      (previous, next) {
        next.whenData((firstPage) => notifier.initializeWithFirstPage(firstPage));
      },
    );

    return notifier;
  },
);

// ===== CONVENIENCE PROVIDERS =====

/// Current user's notifications (based on auth state)
final currentUserNotificationsProvider = Provider<PaginationState<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const PaginationState();
  return ref.watch(paginatedNotificationsProvider(user.uid));
});

/// Current user's unread count
final currentUserUnreadCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return 0;
  return ref.watch(unreadNotificationsCountProvider(user.uid)).value ?? 0;
});

// ===== NOTIFICATION ACTIONS PROVIDER =====

final notificationActionsProvider = Provider((ref) {
  return NotificationActions(ref);
});

class NotificationActions {
  final Ref ref;

  NotificationActions(this.ref);

  Future<void> markAsRead(String userId, String notificationId) async {
    await ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .markAsRead(notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .markAllAsRead();
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .deleteNotification(notificationId);
  }

  Future<void> deleteAllNotifications(String userId) async {
    await ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .deleteAllNotifications();
  }

  Future<void> refresh(String userId) async {
    await ref
        .read(paginatedNotificationsProvider(userId).notifier)
        .refresh();
  }
}

// ===== NOTIFICATION FILTER =====

enum NotificationFilter {
  all,
  sessionRequest,
  sessionAccepted,
  assignmentUpdated,
  paymentRequired, // ✅ NEW
  sessionRejected, // ✅ NEW
  follow,
  system,
}

final notificationFilterProvider = StateProvider<NotificationFilter>((ref) {
  return NotificationFilter.all;
});

/// Filtered notifications based on selected filter
final filteredNotificationsProvider = Provider.family<List<NotificationModel>, String>(
  (ref, userId) {
    final paginatedState = ref.watch(paginatedNotificationsProvider(userId));
    final filter = ref.watch(notificationFilterProvider);

    if (filter == NotificationFilter.all) {
      return paginatedState.items;
    }

    String filterType;
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
      case NotificationFilter.paymentRequired: // ✅ NEW
        filterType = 'payment_required';
        break;
      case NotificationFilter.sessionRejected: // ✅ NEW
        filterType = 'session_rejected';
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
  },
);
