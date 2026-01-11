// lib/providers/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

// Repository provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

// Stream provider for notifications
final notificationsProvider = StreamProvider.family<
    List<NotificationModel>,
    String
>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.watchNotificationsFirstPage(userId);
});

// FIXED: Unread count provider (family)
final unreadCountProvider = StreamProvider.family<int, String>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.watchUnreadCount(userId);
});

// Alternative: Derive from notifications provider
final unreadCountFromNotificationsProvider = Provider.family<int, String>(
  (ref, userId) {
    final notificationsAsync = ref.watch(notificationsProvider(userId));
    return notificationsAsync.when(
      data: (notifications) => notifications.where((n) => !n.isRead).length,
      loading: () => 0,
      error: (_, __) => 0,
    );
  },
);

// Notification actions notifier
class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;

  NotificationActionsNotifier(this._repository)
      : super(const AsyncValue.data(null));

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> markAllAsRead(String userId) async {
    state = const AsyncValue.loading();
    try {
      await _repository.markAllAsRead(userId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final notificationActionsProvider = StateNotifierProvider<
    NotificationActionsNotifier,
    AsyncValue<void>
>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationActionsNotifier(repository);
});
