import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../shared/widgets/shimmer_widgets.dart';
import '../shared/widgets/error_widgets.dart';
import '../shared/constants/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _rebuildKey = 0;

  void _retry() {
    setState(() {
      _rebuildKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(
          child: Text(
            'يرجى تسجيل الدخول',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإشعارات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllAsRead(user.uid),
              tooltip: 'تعليم الكل كمقروء',
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_rebuildKey),
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            // Show error state
            if (snapshot.hasError) {
              return ErrorDisplay.dataLoad(
                onRetry: _retry,
              );
            }

            // Show shimmer loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ShimmerWidgets.list(
                itemCount: 6,
                itemBuilder: () => ShimmerWidgets.listItem(
                  showAvatar: true,
                  lines: 2,
                ),
              );
            }

            // Check if data exists
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد إشعارات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ستظهر الإشعارات هنا عند وصولها',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final data = notif.data();
                final isRead = data['isRead'] as bool? ?? false;
                final type = data['type'] as String? ?? '';
                final title = data['title'] as String? ?? '';
                final body = data['body'] as String? ?? '';
                final mohaffezName = data['mohaffezName'] as String? ?? '';
                final timestamp = data['createdAt'] as Timestamp?;
                final timeStr = timestamp != null
                    ? _formatTimestamp(timestamp.toDate())
                    : '';

                return _buildNotificationCard(
                  notificationId: notif.id,
                  isRead: isRead,
                  type: type,
                  title: title,
                  body: body,
                  mohaffezName: mohaffezName,
                  timeStr: timeStr,
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Build notification card
  Widget _buildNotificationCard({
    required String notificationId,
    required bool isRead,
    required String type,
    required String title,
    required String body,
    required String mohaffezName,
    required String timeStr,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      color: isRead ? Colors.white : Colors.amber.shade50,
      elevation: isRead ? 0.5 : 2,
      child: ListTile(
        // Leading icon
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type),
          child: Icon(
            _getTypeIcon(type),
            color: Colors.white,
            size: 20,
          ),
        ),

        // Title
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 15,
          ),
        ),

        // Subtitle with body, mohaffez name, and time
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Mohaffez name
                if (mohaffezName.isNotEmpty) ...[
                  Icon(
                    Icons.person,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mohaffezName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Time
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Unread indicator
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

        // On tap - mark as read
        onTap: () => _markAsRead(notificationId),
      ),
    );
  }

  /// Get icon color based on notification type
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

  /// Get icon based on notification type
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

  /// Mark single notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead(String userId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (notifications.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('جميع الإشعارات مقروءة بالفعل')),
          );
        }
        return;
      }

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم تعليم جميع الإشعارات كمقروءة'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  /// Format timestamp to relative time
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1
          ? 'منذ يوم'
          : 'منذ ${difference.inDays} أيام';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1
          ? 'منذ ساعة'
          : 'منذ ${difference.inHours} ساعات';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1
          ? 'منذ دقيقة'
          : 'منذ ${difference.inMinutes} دقائق';
    } else {
      return 'الآن';
    }
  }
}
