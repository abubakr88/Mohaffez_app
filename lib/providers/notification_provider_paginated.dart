import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/pagination_state.dart';
import '../repositories/notification_repository.dart';
import 'user_provider.dart';

// REPOSITORY PROVIDER
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

// FIRST PAGE PROVIDER (Real-time)
final notificationsFirstPageProvider = StreamProvider.family<List<NotificationModel>, String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    return repository.watchNotificationsFirstPage(userId);
  },
);

// UNREAD COUNT PROVIDER (Real-time)
final unreadNotificationsCountProvider = StreamProvider.family<int, String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    return repository.watchUnreadCount(userId);
  },
);

// PAGINATED STATE NOTIFIER
class PaginatedNotificationsNotifier extends StateNotifier<PaginationState<NotificationModel>> {
  final NotificationRepository repository;
  final String userId;
  bool _isLoadingMore = false;

  PaginatedNotificationsNotifier(this.repository, this.userId)
      : super(const PaginationState());

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

  Future<void> loadMore() async {
    if (!state.hasMore || _isLoadingMore) return;

    // ✅ FIXED: Initialize lastDocument if needed
    if (state.lastDocument == null && state.items.isNotEmpty) {
      final result = await repository.getNotificationsNextPage(
        userId: userId,
        lastDocument: null,
      );
      state = state.copyWith(
        lastDocument: result.lastDocument, // ✅ FIXED: Use lastDocument not lastDoc
        hasMore: result.hasMore,
      );
      if (!result.hasMore) return;
    }

    if (state.lastDocument == null) return;

    _isLoadingMore = true;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      // ✅ FIXED: Pass userId as named parameter
      final result = await repository.getNotificationsNextPage(
        userId: userId,
        lastDocument: state.lastDocument,
      );

      final existingIds = state.items.map((e) => e.id).toSet();
      // ✅ FIXED: Use result.items not result.notifications
      final newItems = result.items
          .where((item) => !existingIds.contains(item.id))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        lastDocument: result.lastDocument, // ✅ FIXED: Use lastDocument not lastDoc
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

  Future<void> checkScrollPosition(double scrollPercentage) async {
    if (scrollPercentage > 0.8 && state.hasMore && !_isLoadingMore) {
      await loadMore();
    }
  }

  Future<void> refresh() async {
    state = const PaginationState(isLoadingMore: false);
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await repository.markAsRead(notificationId);
      
      final updatedItems = state.items.map((item) {
        if (item.id == notificationId) {
          return item.copyWith(isRead: true);
        }
        return item;
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await repository.markAllAsRead(userId);
      
      final updatedItems = state.items.map((item) {
        return item.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await repository.deleteNotification(notificationId);
      
      final updatedItems = state.items
          .where((item) => item.id != notificationId)
          .toList();

      state = state.copyWith(items: updatedItems);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      await repository.deleteAllNotifications(userId);
      state = const PaginationState();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }
}

// PAGINATED PROVIDER
final paginatedNotificationsProvider = StateNotifierProvider.family<
    PaginatedNotificationsNotifier,
    PaginationState<NotificationModel>,
    String>(
  (ref, userId) {
    final repository = ref.watch(notificationRepositoryProvider);
    final notifier = PaginatedNotificationsNotifier(repository, userId);

    ref.listen(
      notificationsFirstPageProvider(userId),
      (previous, next) {
        next.whenData((firstPage) => notifier.initializeWithFirstPage(firstPage));
      },
    );

    return notifier;
  },
);

// CONVENIENCE PROVIDERS
final currentUserNotificationsProvider = Provider<PaginationState<NotificationModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const PaginationState();
  return ref.watch(paginatedNotificationsProvider(user.uid));
});

final currentUserUnreadCountProvider = Provider<int>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return 0;
  return ref.watch(unreadNotificationsCountProvider(user.uid)).value ?? 0;
});

// NOTIFICATION ACTIONS PROVIDER
final notificationActionsProvider = Provider<NotificationActions>((ref) {
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

// NOTIFICATION FILTER
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
