import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(
          child: Text('يجب تسجيل الدخول لعرض الإشعارات'),
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
              tooltip: 'تحديد الكل كمقروء',
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

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
                        color: Colors.grey.shade600,
                      ),
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

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: isRead ? Colors.white : Colors.amber.shade50,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: type == 'session'
                          ? AppTheme.primaryAmber
                          : AppTheme.accentGreen,
                      child: Icon(
                        type == 'session' ? Icons.school : Icons.menu_book,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(body),
                        const SizedBox(height: 4),
                        Row(
                          children: [
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
                    onTap: () => _markAsRead(notif.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> _markAllAsRead(String userId) async {
    final batch = FirebaseFirestore.instance.batch();

    final notifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} ${difference.inDays == 1 ? 'يوم' : 'أيام'}';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ${difference.inHours == 1 ? 'ساعة' : 'ساعات'}';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} ${difference.inMinutes == 1 ? 'دقيقة' : 'دقائق'}';
    } else {
      return 'الآن';
    }
  }
}
