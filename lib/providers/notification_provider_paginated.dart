// lib/providers/notification_provider_paginated.dart (FIXED)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/pagination_state.dart';
import '../repositories/notification_repository.dart';
import 'notification_provider.dart';

// ============================================================================
// NOTIFICATIONS PAGINATION
// ============================================================================

/// First page provider for real-time updates
final notificationsFirstPageProvider = StreamProvider.family<
    List<NotificationModel>,
    String
>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.watchNotificationsFirstPage(userId);
});

/// Paginated state notifier
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
        hasMore: firstPage.length >= 20,
        isLoadingMore: false,
      );
    }
  }

  /// Load next page
  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    // FIXED: Get last document from Firestore if we don't have it
    if (state.lastDocument == null) {
      if (state.items.isEmpty) {
        // No items yet, can't paginate
        return;
      }
      
      // Fetch the current page to get the last DocumentSnapshot
      try {
        final result = await _repository.getNotificationsPage(
          _userId,
          limit: state.items.length,
        );
        
        if (result.lastDoc == null) {
          // No more items
          state = state.copyWith(hasMore: false);
          return;
        }
        
        state = state.copyWith(
          lastDocument: result.lastDoc,
        );
      } catch (e) {
        state = state.copyWith(
          error: 'فشل الحصول على بيانات الصفحة: ${e.toString()}',
        );
        return;
      }
    }

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await _repository.getNotificationsNextPage(
        _userId,
        state.lastDocument!, // Now safe to use !
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
        error: 'فشل تحميل المزيد من الإشعارات: ${e.toString()}',
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

  /// Update single notification (e.g., mark as read)
  void updateNotification(String notificationId, NotificationModel updatedNotification) {
    final updatedItems = state.items.map((item) {
      if (item.id == notificationId) {
        return updatedNotification;
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  /// Remove notification (e.g., after deletion)
  void removeNotification(String notificationId) {
    final updatedItems = state.items
        .where((item) => item.id != notificationId)
        .toList();

    state = state.copyWith(items: updatedItems);
  }
}

final paginatedNotificationsProvider = StateNotifierProvider.family<
    PaginatedNotificationsNotifier,
    PaginationState<NotificationModel>,
    String
>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
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
// UNREAD COUNT (derived from paginated state)
// ============================================================================

final unreadNotificationCountProvider = Provider.family<int, String>((ref, userId) {
  final notifications = ref.watch(paginatedNotificationsProvider(userId));
  return notifications.items.where((n) => !n.isRead).length;
});
