// lib/providers/notification_provider.dart (UPDATED)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import 'auth_provider.dart';

// Repository provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

// Notifications stream (using first page for backward compatibility)
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) async* {
  final authUser = await ref.watch(authStateProvider.future);
  if (authUser == null) {
    yield [];
    return;
  }
  
  // Use first page method instead of watchNotifications
  yield* ref.watch(notificationRepositoryProvider).watchNotificationsFirstPage(authUser.uid);
});

// Unread count provider derived from notifications
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});

// Notification actions notifier
class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;

  NotificationActionsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.markAllAsRead(userId);
    });
  }
}

final notificationActionsProvider = StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>((ref) {
  return NotificationActionsNotifier(ref.watch(notificationRepositoryProvider));
});
