import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminUserDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(adminActionsProvider.notifier);
    final status = user['status']?.toString() ?? 'active';
    final createdAt = user['createdAt'];
    final date = createdAt is Timestamp
        ? DateFormat('yyyy/MM/dd').format(createdAt.toDate())
        : '-';

    Future<void> runAction(Future<void> Function() action) async {
      await action();
      final state = ref.read(adminActionsProvider);
      if (!context.mounted) return;
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppThemeConstants.error,
              content: Text(state.error.toString())),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: AppThemeConstants.success,
              content: Text(ArabicLabels.operationSuccess)),
        );
      }
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.userDetails)),
        body: ListView(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text((user['name']?.toString().isNotEmpty ?? false)
                          ? user['name'].toString()[0]
                          : '?'),
                    ),
                    const SizedBox(height: AppThemeConstants.spaceSm),
                    Text(user['name']?.toString() ?? '-'),
                    Text(user['email']?.toString() ?? '-'),
                    Text('الدور: ${user['role'] ?? '-'}'),
                    Text(
                        '${ArabicLabels.status}: ${status == 'suspended' ? ArabicLabels.userBanned : ArabicLabels.userActive}'),
                    Text('${ArabicLabels.joined}: $date'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppThemeConstants.spaceMd),
            Wrap(
              spacing: AppThemeConstants.spaceSm,
              runSpacing: AppThemeConstants.spaceSm,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final reasonCtrl = TextEditingController();
                    DateTime? expiry;
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text(ArabicLabels.banUser),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                                controller: reasonCtrl,
                                decoration: const InputDecoration(
                                    labelText: ArabicLabels.rejectionReason)),
                            const SizedBox(height: AppThemeConstants.spaceSm),
                            TextButton(
                              onPressed: () async {
                                expiry = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                              },
                              child: const Text(
                                  'تحديد تاريخ انتهاء الحظر (اختياري)'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(ArabicLabels.cancel)),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(ArabicLabels.confirm)),
                        ],
                      ),
                    );

                    if (confirmed == true &&
                        reasonCtrl.text.trim().isNotEmpty) {
                      await runAction(() => actions.suspendUser(
                          user['id'].toString(),
                          reasonCtrl.text.trim(),
                          expiry));
                    }
                  },
                  child: const Text(ArabicLabels.banUser),
                ),
                if (status == 'suspended')
                  ElevatedButton(
                    onPressed: () => runAction(
                        () => actions.unsuspendUser(user['id'].toString())),
                    child: const Text(ArabicLabels.unbanUser),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    String role = user['role']?.toString() == 'student'
                        ? 'mohaffez'
                        : 'student';
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('تغيير الدور'),
                        content: DropdownButtonFormField<String>(
                          value: role,
                          items: const [
                            DropdownMenuItem(
                                value: 'student',
                                child: Text(ArabicLabels.student)),
                            DropdownMenuItem(
                                value: 'mohaffez',
                                child: Text(ArabicLabels.mohaffez)),
                          ],
                          onChanged: (v) => role = v ?? role,
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(ArabicLabels.cancel)),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(ArabicLabels.confirm)),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await runAction(() =>
                          actions.updateUserRole(user['id'].toString(), role));
                    }
                  },
                  child: const Text('تغيير الدور'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final email = user['email']?.toString();
                    if (email != null && email.isNotEmpty) {
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(email: email);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'تم إرسال رابط إعادة تعيين كلمة المرور')));
                      }
                    }
                  },
                  child: const Text('إعادة تعيين كلمة المرور'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.error),
                  onPressed: () async {
                    final first = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('حذف الحساب'),
                        content: const Text('هل أنت متأكد؟'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(ArabicLabels.cancel)),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(ArabicLabels.confirm)),
                        ],
                      ),
                    );
                    if (first != true) return;
                    final second = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('تأكيد نهائي'),
                        content: const Text('هذا الإجراء لا يمكن التراجع عنه'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(ArabicLabels.cancel)),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(ArabicLabels.delete)),
                        ],
                      ),
                    );
                    if (second == true) {
                      await runAction(
                          () => actions.deleteUserData(user['id'].toString()));
                    }
                  },
                  child: const Text('حذف الحساب'),
                ),
              ],
            ),
            const SizedBox(height: AppThemeConstants.spaceMd),
            Row(
              children: [
                Expanded(
                    child: _statBox(
                        'الجلسات', user['sessionCount']?.toString() ?? '0')),
                const SizedBox(width: AppThemeConstants.spaceSm),
                Expanded(
                    child: _statBox('الاشتراكات',
                        user['subscriptionCount']?.toString() ?? '0')),
              ],
            ),
            if ((user['role']?.toString() ?? '') == 'mohaffez')
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user['id'])
                    .collection('credentials')
                    .snapshots(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppThemeConstants.spaceMd),
                      const Text('الشهادات',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      ...docs.map((d) {
                        final c = d.data();
                        return ListTile(
                          title: Text(c['title']?.toString() ?? d.id),
                          subtitle: Text(c['status']?.toString() ?? 'pending'),
                          trailing: Wrap(
                            spacing: AppThemeConstants.spaceXs,
                            children: [
                              TextButton(
                                onPressed: () => runAction(() =>
                                    actions.approveCredential(
                                        user['id'].toString(), d.id)),
                                child: const Text(ArabicLabels.approve),
                              ),
                              TextButton(
                                onPressed: () => runAction(() =>
                                    actions.rejectCredential(
                                        user['id'].toString(),
                                        d.id,
                                        'تم الرفض من الإدارة')),
                                child: const Text(ArabicLabels.reject),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppThemeConstants.surfaceWhite,
        borderRadius: AppThemeConstants.borderRadiusMd,
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: AppThemeConstants.spaceXs),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
