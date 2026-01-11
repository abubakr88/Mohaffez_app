// lib/screens/notifications_screen.dart (UPDATED)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';
import '../shared/widgets/empty_state_illustrations.dart';
import '../shared/widgets/empty_state.dart';
import '../providers/notification_provider_paginated.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../shared/utils/error_handler.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('غير مصرح')));
        return _buildContent(context, ref, user.uid);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorDisplay.dataLoad(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, String userId) {
    final firstPageAsync = ref.watch(notificationsFirstPageProvider(userId));
    final paginatedState = ref.watch(paginatedNotificationsProvider(userId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإشعارات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllAsRead(context, ref, userId),
              tooltip: 'تعليم الكل كمقروء',
            ),
          ],
        ),
        body: firstPageAsync.when(
          data: (_) {
            final notifications = paginatedState.items;

            if (notifications.isEmpty && !paginatedState.isLoadingMore) {
              return IllustratedEmptyState(
                illustration: EmptyStateIllustrations.noNotifications(), // Add parentheses ()
                title: 'لا توجد إشعارات',
                message: 'لم تتلق أي إشعارات حتى الآن.',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length + (paginatedState.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return _buildLoadMoreButton(ref, userId, paginatedState);
                }

                final notification = notifications[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => _markAsRead(ref, notification.id!),
                );
              },
            );
          },
          loading: () => ShimmerWidgets.list(
            itemCount: 6,
            itemBuilder: () => ShimmerWidgets.listItem(
              showAvatar: true,
              lines: 2),
          ),
          error: (e, _) => ErrorDisplay.dataLoad(
            onRetry: () => ref.invalidate(notificationsFirstPageProvider(userId)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(WidgetRef ref, String userId, paginatedState) {
    if (paginatedState.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (paginatedState.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'حدث خطأ: ${paginatedState.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(paginatedNotificationsProvider(userId).notifier).loadMore();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            ref.read(paginatedNotificationsProvider(userId).notifier).loadMore();
          },
          icon: const Icon(Icons.expand_more),
          label: const Text('تحميل المزيد'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _markAsRead(WidgetRef ref, String notificationId) async {
    final notifier = ref.read(notificationActionsProvider.notifier);
    await notifier.markAsRead(notificationId);
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref, String userId) async {
    final notifier = ref.read(notificationActionsProvider.notifier);
    await notifier.markAllAsRead(userId);
    if (context.mounted) {
      ErrorHandler.showSuccess(context, 'تم تعليم جميع الإشعارات كمقروءة');
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final type = notification.type;
    final title = notification.title;
    final body = notification.body;
    final mohaffezName = notification.mohaffezName ?? '';
    final createdAt = notification.createdAt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isRead ? Colors.white : Colors.amber.shade50,
      elevation: isRead ? 0.5 : 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type),
          child: Icon(
            _getTypeIcon(type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (mohaffezName.isNotEmpty) ...[
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(mohaffezName, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'session':
        return AppTheme.primaryAmber;
      case 'follow':
        return Colors.blue;
      case 'system':
        return Colors.purple;
      default:
        return AppTheme.accentGreen;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'session':
        return Icons.school;
      case 'follow':
        return Icons.person_add;
      case 'system':
        return Icons.info;
      default:
        return Icons.menu_book;
    }
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'أمس' : 'منذ ${difference.inDays} أيام';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1 ? 'منذ ساعة' : 'منذ ${difference.inHours} ساعات';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1 ? 'منذ دقيقة' : 'منذ ${difference.inMinutes} دقائق';
    } else {
      return 'الآن';
    }
  }
}
