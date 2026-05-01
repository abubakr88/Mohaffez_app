import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mohaffez_core/src/theme/app_theme_constants.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:mohaffez_core/src/providers/notification_provider_paginated.dart';
import 'package:mohaffez_core/src/providers/user_provider.dart';
import 'package:mohaffez_core/src/models/notification_model.dart';
import 'package:mohaffez_core/src/utils/arabic_labels.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Configure timeago for Arabic
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final paginatedState = ref.watch(paginatedNotificationsProvider(user.uid));
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider(user.uid)).value ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            // 1. Reset paginated state cleanly via the notifier's own method
            ref
                .read(paginatedNotificationsProvider(user.uid).notifier)
                .refresh();

            // 2. Force the real-time first-page stream to re-emit by invalidating it
            ref.invalidate(notificationsFirstPageProvider(user.uid));

            // 3. Wait for the first page to actually arrive before hiding the spinner
            await ref.read(notificationsFirstPageProvider(user.uid).future);
          },
          child: CustomScrollView(
            slivers: [
              // Modern App Bar
              SliverAppBar(
                expandedHeight: 100,
                floating: true,
                pinned: true,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppThemeConstants.primary, AppThemeConstants.primaryVariant],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      ArabicLabels.notifications,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppThemeConstants.onPrimary,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Text(
                                        '$unreadCount غير مقروءة',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppThemeConstants.onPrimary.withValues(alpha: 0.9),
                                        ),
                                      ),
                                  ],
                                ),
                                if (paginatedState.items.isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppThemeConstants.surface.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.done_all,
                                        color: AppThemeConstants.onPrimary,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(notificationActionsProvider)
                                            .markAllAsRead(user.uid);
                                      },
                                      tooltip: 'تحديد الكل كمقروء',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SliverToBoxAdapter(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: ArabicLabels.all,
                          count: paginatedState.items.length,
                          isSelected: selectedFilter == 'all',
                          onTap: () => setState(() => selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'الجلسات',
                          isSelected: selectedFilter == 'session',
                          onTap: () =>
                              setState(() => selectedFilter = 'session'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'المدفوعات',
                          isSelected: selectedFilter == 'payment',
                          onTap: () =>
                              setState(() => selectedFilter = 'payment'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'المتابعات',
                          isSelected: selectedFilter == 'follow',
                          onTap: () =>
                              setState(() => selectedFilter = 'follow'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Notifications List
              if (paginatedState.items.isEmpty && !paginatedState.isLoadingMore)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.notifications_none,
                    title: ArabicLabels.noNotifications,
                    message: 'ستظهر إشعاراتك هنا',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= paginatedState.items.length) {
                          return paginatedState.isLoadingMore
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                )
                              : const SizedBox.shrink();
                        }

                        final notification = paginatedState.items[index];

                        // Filter logic
                        if (selectedFilter != 'all') {
                          if (selectedFilter == 'session' &&
                              ![
                                'session_request',
                                'session_accepted',
                                'session_rejected',
                              ].contains(notification.type)) {
                            return const SizedBox.shrink();
                          }

                          if (selectedFilter == 'payment' &&
                              notification.type != 'payment_required') {
                            return const SizedBox.shrink();
                          }

                          if (selectedFilter == 'follow' &&
                              notification.type != 'follow') {
                            return const SizedBox.shrink();
                          }
                        }

                        return _NotificationCard(
                          notification: notification,
                          onTap: () async {
                            if (!notification.isRead) {
                              ref
                                  .read(notificationActionsProvider)
                                  .markAsRead(user.uid, notification.id!);
                            }

                            await _handleNotificationTap(
                              context,
                              notification,
                            );
                          },
                          onDismiss: () {
                            ref
                                .read(notificationActionsProvider)
                                .deleteNotification(user.uid, notification.id!);
                          },
                        );
                      },
                      childCount: paginatedState.items.length +
                          (paginatedState.hasMore ? 1 : 0),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle notification tap with proper navigation
  Future<void> _handleNotificationTap(
      BuildContext context, NotificationModel notification) async {
    final type = notification.type;

    switch (type) {
      case 'payment_required':
      case 'paymentrequired':
        {
          final Map<String, dynamic> data =
              notification.data ?? <String, dynamic>{};

          final requestId = data['requestId'] as String?;
          final mohaffezId = data['mohaffezId'] as String?;
          final mohaffezName = data['mohaffezName'] as String? ??
              notification.mohaffezName ??
              '';

          if (requestId != null &&
              mohaffezId != null &&
              mohaffezName.isNotEmpty) {
            // ✅ Fetch full request details to lock payment screen
            try {
              final requestSnapshot = await FirebaseFirestore.instance
                  .collection('sessionRequests')
                  .doc(requestId)
                  .get();

              if (requestSnapshot.exists && context.mounted) {
                context.push(
                  '/payment/$mohaffezId?name=${Uri.encodeComponent(mohaffezName)}&requestId=$requestId',
                  extra: {
                    'requestId': requestId,
                    'mohaffezId': mohaffezId,
                    'mohaffezName': mohaffezName,
                    'lockedRequest': requestSnapshot.data(),
                  },
                );
              } else if (context.mounted) {
                context.push(
                  '/payment/$mohaffezId?name=${Uri.encodeComponent(mohaffezName)}&requestId=$requestId',
                  extra: {
                    'requestId': requestId,
                    'mohaffezId': mohaffezId,
                    'mohaffezName': mohaffezName,
                    'sessionDetails': data,
                  },
                );
              }
            } catch (e) {
              if (context.mounted) {
                context.push(
                  '/payment/$mohaffezId?name=${Uri.encodeComponent(mohaffezName)}&requestId=$requestId',
                  extra: {
                    'requestId': requestId,
                    'mohaffezId': mohaffezId,
                    'mohaffezName': mohaffezName,
                    'sessionDetails': data,
                  },
                );
              }
            }
          } else if (mohaffezId != null && mohaffezName.isNotEmpty) {
            // Fallback: generic payment screen
            final sessionType = data['sessionType'] as String?;
            final preferredTimeSlot =
                data['timeSlot'] ?? data['preferredTimeSlot'];

            context.push(
              '/payment/$mohaffezId?name=${Uri.encodeComponent(mohaffezName)}'
              '${sessionType != null ? '&sessionType=$sessionType' : ''}'
              '${preferredTimeSlot != null ? '&timeSlot=$preferredTimeSlot' : ''}',
              extra: {
                'preselectedSessionType': sessionType,
                'preselectedTimeSlot': preferredTimeSlot != null
                    ? {
                        'startTime': preferredTimeSlot,
                        'endTime': null,
                      }
                    : null,
                'preselectedDate': data['sessionDate'],
                'autoBookAfterPayment': true,
              },
            );
          }
          break;
        }

      case 'session_accepted':
      case 'sessionaccepted':
      case 'accepted':
        context.go('/home');
        break;

      case 'session_rejected':
      case 'sessionrejected':
      case 'rejected':
        {
          // ignore: dead_null_aware_expression
          final reason = notification.body ?? 'لم يذكر سبب الرفض';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('تم رفض الطلب'),
              content: Text(reason),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(ArabicLabels.ok),
                ),
              ],
            ),
          );
          break;
        }

      case 'session_request':
        // Navigate to pending requests
        context.go('/mohaffez-home');
        break;

      case 'assignment_updated':
        // Navigate to student assignments
        context.go('/assignments');
        break;

      // BUG-10 FIX: Handle subscription_created notification
      case 'subscription_created':
      case 'subscriptioncreated':
      case 'subscriptionsessionconsumed':
        // Navigate to active subscriptions screen so student can see their bundle
        context.push('/active-subscriptions');
        break;

      // FIX: Handle direct payment pending confirmation notification
      case 'directpaymentpending':
        {
          final Map<String, dynamic> data =
              notification.data ?? <String, dynamic>{};
          final directPaymentRequestId = data['directPaymentRequestId'] as String?;
          
          if (directPaymentRequestId != null && directPaymentRequestId.isNotEmpty) {
            // Navigate directly to the specific direct payment request
            context.push('/mohaffez/requests/confirm?directPaymentRequestId=$directPaymentRequestId');
          } else {
            // Fallback: navigate to all pending confirmations
            context.push('/mohaffez/requests/confirm');
          }
          break;
        }

      default:
        // No specific action
        break;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeConstants.primary : AppThemeConstants.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppThemeConstants.primary : AppThemeConstants.grey300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppThemeConstants.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppThemeConstants.white : AppThemeConstants.grey700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppThemeConstants.white.withValues(alpha: 0.3)
                      : AppThemeConstants.grey200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppThemeConstants.white : AppThemeConstants.grey700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final dynamic notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);

    return Dismissible(
      key: Key(notification.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppThemeConstants.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: AppThemeConstants.white, size: 28),
      ),
      onDismissed: (_) => onDismiss(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: notification.isRead ? 1 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  notification.isRead ? AppThemeConstants.white : color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notification.isRead
                    ? AppThemeConstants.grey200
                    : color.withValues(alpha: 0.3),
                width: notification.isRead ? 1 : 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.body ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppThemeConstants.grey700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppThemeConstants.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _getNotificationColor(String? type) {
  switch (type) {
    case 'session_request':
      return AppThemeConstants.warning;
    case 'session_accepted':
      return AppThemeConstants.success;
    case 'payment_required':
    case 'paymentrequired':
      return AppThemeConstants.primary;
    case 'session_rejected':
      return AppThemeConstants.error;
    case 'assignment_updated':
      return AppThemeConstants.accentBlue;
    case 'follow':
      return AppThemeConstants.accentPurple;
    default:
      return AppThemeConstants.grey500;
  }
}

IconData _getNotificationIcon(String? type) {
  switch (type) {
    case 'session_request':
      return Icons.pending_actions;
    case 'session_accepted':
      return Icons.check_circle;
    case 'payment_required':
    case 'paymentrequired':
      return Icons.payment;
    case 'session_rejected':
      return Icons.cancel;
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
  return timeago.format(timestamp, locale: 'ar');
}
