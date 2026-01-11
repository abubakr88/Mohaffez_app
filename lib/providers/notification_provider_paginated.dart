// lib/providers/notification_provider_paginated.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../models/pagination_state.dart';
import '../repositories/notification_repository.dart';
import 'notification_provider.dart';

class PaginatedNotificationsNotifier extends StateNotifier<PaginationState<NotificationModel>> {
  final NotificationRepository _repository;
  final String _userId;

  PaginatedNotificationsNotifier(this._repository, this._userId)
      : super(const PaginationState(hasMore: true));

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      if (state.lastDocument == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final result = await _repository.getNotificationsNextPage(
        _userId,
        state.lastDocument!,
      );

      state = state.copyWith(
        items: [...state.items, ...result.notifications],
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

  void updateFirstPage(List<NotificationModel> notifications, DocumentSnapshot? lastDoc) {
    state = state.copyWith(
      items: notifications,
      lastDocument: lastDoc,
      hasMore: notifications.length >= NotificationRepository.pageSize,
    );
  }
}

final paginatedNotificationsProvider = StateNotifierProvider.family<
    PaginatedNotificationsNotifier,
    PaginationState<NotificationModel>,
    String>((ref, userId) {
  final repository = ref.watch(notificationRepositoryProvider);
  return PaginatedNotificationsNotifier(repository, userId);
});

final notificationsFirstPageProvider = StreamProvider.family<
    ({List<NotificationModel> notifications, DocumentSnapshot? lastDoc}),
    String>((ref, userId) async* {
  final repository = ref.watch(notificationRepositoryProvider);
  
  await for (final notifications in repository.watchNotificationsFirstPage(userId)) {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(NotificationRepository.pageSize)
        .get();

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    ref.read(paginatedNotificationsProvider(userId).notifier)
        .updateFirstPage(notifications, lastDoc);

    yield (notifications: notifications, lastDoc: lastDoc);
  }
});
