// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider_paginated.dart'; // ✅ Only this one
import '../providers/user_provider.dart';
import '../shared/widgets/paginated_list_view.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/empty_state_illustrations.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final paginatedState = ref.watch(paginatedNotificationsProvider(user.uid));
    final unreadCount = ref.watch(unreadNotificationsCountProvider(user.uid)).value ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الإشعارات ${unreadCount > 0 ? '($unreadCount)' : ''}'),
          actions: [
            // Mark all as read
            if (paginatedState.items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'تعليم الكل كمقروء',
                onPressed: () {
                  ref.read(notificationActionsProvider)
                      .markAllAsRead(user.uid);
                },
              ),
            // Filter menu
            PopupMenuButton<NotificationFilter>(
              icon: const Icon(Icons.filter_list),
              onSelected: (filter) {
                ref.read(notificationFilterProvider.notifier).state = filter;
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: NotificationFilter.all,
                  child: Text('جميع الإشعارات'),
                ),
                const PopupMenuItem(
                  value: NotificationFilter.sessionRequest,
                  child: Text('طلبات الجلسات'),
                ),
                const PopupMenuItem(
                  value: NotificationFilter.sessionAccepted,
                  child: Text('جلسات مقبولة'),
                ),
                const PopupMenuItem(
                  value: NotificationFilter.assignmentUpdated,
                  child: Text('تحديث الواجبات'),
                ),
                const PopupMenuItem(
                  value: NotificationFilter.follow,
                  child: Text('متابعات جديدة'),
                ),
              ],
            ),
          ],
        ),
        body: paginatedState.items.isEmpty && !paginatedState.isLoadingMore
            ? IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noNotifications(),
                title: 'لا توجد إشعارات',
                message: 'سيتم عرض الإشعارات الخاصة بك هنا',
              )
            : PaginatedListView(
                items: paginatedState.items,
                hasMore: paginatedState.hasMore,
                isLoadingMore: paginatedState.isLoadingMore,
                error: paginatedState.error,
                itemBuilder: (context, notification, index) {
                  return _NotificationTile(
                    notification: notification,
                    onTap: () {
                      if (!notification.isRead) {
                        ref.read(notificationActionsProvider)
                            .markAsRead(user.uid, notification.id!);
                      }
                      // Navigate based on type
                      _handleNotificationTap(context, notification);
                    },
                    onDismiss: () {
                      ref.read(notificationActionsProvider)
                          .deleteNotification(user.uid, notification.id!);
                    },
                  );
                },
                onLoadMore: () {
                  return ref
                      .read(paginatedNotificationsProvider(user.uid).notifier)
                      .loadMore();
                },
                onRefresh: () async {
                  return ref
                      .read(paginatedNotificationsProvider(user.uid).notifier)
                      .refresh();
                },
              ),
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case 'session_request':
        // Navigate to pending requests screen
        break;
      case 'session_accepted':
        // Navigate to session details
        break;
      case 'assignment_updated':
        // Navigate to assignments
        break;
      case 'follow':
        // Navigate to profile
        break;
    }
  }
}

// ============================================================================
// NOTIFICATION TILE WIDGET
// ============================================================================

class _NotificationTile extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getNotificationColor(notification.type),
            child: Icon(
              _getNotificationIcon(notification.type),
              color: Colors.white,
            ),
          ),
          title: Text(
            notification.title ?? '',
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(notification.body ?? ''),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(notification.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          trailing: !notification.isRead
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'session_request':
        return Colors.orange;
      case 'session_accepted':
        return Colors.green;
      case 'assignment_updated':
        return Colors.blue;
      case 'follow':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'session_request':
        return Icons.pending_actions;
      case 'session_accepted':
        return Icons.check_circle;
      case 'assignment_updated':
        return Icons.assignment;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
