import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../utils/arabic_labels.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailScreen({super.key, required this.user});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState
    extends ConsumerState<AdminUserDetailScreen> {
  bool _isLoadingSuspend = false;
  bool _isLoadingUnsuspend = false;
  bool _isLoadingRoleChange = false;
  bool _isLoadingResetPassword = false;
  bool _isLoadingDelete = false;
  bool _isLoadingApproveCred = false;
  bool _isLoadingRejectCred = false;

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Runs [action], then shows a success/error snackbar.
  /// Must be called after setState has already been set to loading.
  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      // Read state AFTER the action completes
      final state = ref.read(adminActionsProvider);
      if (state.hasError) {
        _showSnackbar(state.error.toString(), isError: true);
      } else {
        _showSnackbar(ArabicLabels.operationSuccess, isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar(e.toString(), isError: true);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? AppThemeConstants.error : AppThemeConstants.success,
        content: Text(message),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(adminActionsProvider.notifier);
    final status = widget.user['status']?.toString() ?? 'active';
    final createdAt = widget.user['createdAt'];
    final date = createdAt is Timestamp
        ? DateFormat('yyyy/MM/dd').format(createdAt.toDate())
        : '-';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.userDetails),
        body: ListView(
          padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
          children: [
            // ── Profile card ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                        (widget.user['name']?.toString().isNotEmpty ?? false)
                            ? widget.user['name'].toString()[0]
                            : '?',
                      ),
                    ),
                    const SizedBox(height: AppThemeConstants.spaceSm),
                    Text(widget.user['name']?.toString() ?? '-'),
                    Text(widget.user['email']?.toString() ?? '-'),
                    Text('الدور: ${widget.user['role'] ?? '-'}'),
                    Text(
                      '${ArabicLabels.status}: '
                      '${status == 'suspended' ? ArabicLabels.userBanned : ArabicLabels.userActive}',
                    ),
                    Text('${ArabicLabels.joined}: $date'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppThemeConstants.spaceMd),

            // ── Action buttons ───────────────────────────────────────────────
            Wrap(
              spacing: AppThemeConstants.spaceSm,
              runSpacing: AppThemeConstants.spaceSm,
              children: [
                // Suspend
                if (status != 'suspended')
                  _ActionButton(
                    label: ArabicLabels.banUser,
                    isLoading: _isLoadingSuspend,
                    backgroundColor: AppThemeConstants.warning,
                    onPressed: () => _onSuspendPressed(actions),
                  ),

                // Unsuspend (only shown when suspended)
                if (status == 'suspended')
                  _ActionButton(
                    label: ArabicLabels.unbanUser,
                    isLoading: _isLoadingUnsuspend,
                    backgroundColor: AppThemeConstants.success,
                    onPressed: () => _onUnsuspendPressed(actions),
                  ),

                // Change role
                _ActionButton(
                  label: 'تغيير الدور',
                  isLoading: _isLoadingRoleChange,
                  backgroundColor: AppThemeConstants.primary,
                  onPressed: () => _onRoleChangePressed(actions),
                ),

                // Reset password
                _ActionButton(
                  label: 'إعادة تعيين كلمة المرور',
                  isLoading: _isLoadingResetPassword,
                  backgroundColor: AppThemeConstants.secondary,
                  onPressed: _onResetPasswordPressed,
                ),

                // Delete account
                _ActionButton(
                  label: 'حذف الحساب',
                  isLoading: _isLoadingDelete,
                  backgroundColor: AppThemeConstants.error,
                  onPressed: () => _onDeletePressed(actions),
                ),
              ],
            ),

            const SizedBox(height: AppThemeConstants.spaceMd),

            // ── Stats row ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _statBox(
                    'الجلسات',
                    widget.user['sessionCount']?.toString() ?? '0',
                  ),
                ),
                const SizedBox(width: AppThemeConstants.spaceSm),
                Expanded(
                  child: _statBox(
                    'الاشتراكات',
                    widget.user['subscriptionCount']?.toString() ?? '0',
                  ),
                ),
              ],
            ),

            // ── Credentials (mohaffez only) ──────────────────────────────────
            if ((widget.user['role']?.toString() ?? '') == 'mohaffez')
              _CredentialsSection(
                userId: widget.user['id'].toString(),
                isLoadingApprove: _isLoadingApproveCred,
                isLoadingReject: _isLoadingRejectCred,
                onApprove: (credId) async {
                  setState(() => _isLoadingApproveCred = true);
                  try {
                    await _runAction(() => actions.approveCredential(
                        widget.user['id'].toString(), credId));
                  } finally {
                    if (mounted) setState(() => _isLoadingApproveCred = false);
                  }
                },
                onReject: (credId) async {
                  setState(() => _isLoadingRejectCred = true);
                  try {
                    await _runAction(() => actions.rejectCredential(
                        widget.user['id'].toString(),
                        credId,
                        'تم الرفض من الإدارة'));
                  } finally {
                    if (mounted) setState(() => _isLoadingRejectCred = false);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  Future<void> _onSuspendPressed(AdminActionsNotifier actions) async {
    final reasonCtrl = TextEditingController();
    DateTime? expiry;

    // Capture context before async gap
    final screenContext = context;

    final confirmed = await showDialog<bool>(
      context: screenContext,
      builder: (dialogContext) => StatefulBuilder(
        // StatefulBuilder lets us call setState inside the dialog
        // so the date button label can update after picking a date
        builder: (_, setDialogState) => AlertDialog(
          title: const Text(ArabicLabels.banUser),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: ArabicLabels.rejectionReason,
                ),
              ),
              const SizedBox(height: AppThemeConstants.spaceSm),
              TextButton(
                onPressed: () async {
                  // Use screenContext (has Scaffold/MediaQuery) for date picker
                  final picked = await showDatePicker(
                    context: screenContext,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => expiry = picked);
                  }
                },
                child: Text(
                  expiry != null
                      ? DateFormat('yyyy/MM/dd').format(expiry!)
                      : 'تحديد تاريخ انتهاء الحظر (اختياري)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(ArabicLabels.confirm),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      setState(() => _isLoadingSuspend = true);
      try {
        await _runAction(() => actions.suspendUser(
              widget.user['id'].toString(),
              reasonCtrl.text.trim(),
              expiry,
            ));
      } finally {
        if (mounted) setState(() => _isLoadingSuspend = false);
      }
    } else if (confirmed == true && reasonCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إدخال سبب الإيقاف'),
            backgroundColor: AppThemeConstants.error,
          ),
        );
      }
    }
  }

  Future<void> _onUnsuspendPressed(AdminActionsNotifier actions) async {
    setState(() => _isLoadingUnsuspend = true);
    try {
      await _runAction(
          () => actions.unsuspendUser(widget.user['id'].toString()));
    } finally {
      if (mounted) setState(() => _isLoadingUnsuspend = false);
    }
  }

  Future<void> _onRoleChangePressed(AdminActionsNotifier actions) async {
    String role = widget.user['role']?.toString() == 'student'
        ? 'mohaffez'
        : 'student';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('تغيير الدور'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            items: const [
              DropdownMenuItem(
                  value: 'student', child: Text(ArabicLabels.student)),
              DropdownMenuItem(
                  value: 'mohaffez', child: Text(ArabicLabels.mohaffez)),
              DropdownMenuItem(value: 'admin', child: Text('مشرف')),
            ],
            onChanged: (v) {
              if (v != null) setDialogState(() => role = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(ArabicLabels.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(ArabicLabels.confirm),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() => _isLoadingRoleChange = true);
      try {
        await _runAction(
            () => actions.updateUserRole(widget.user['id'].toString(), role));
      } finally {
        if (mounted) setState(() => _isLoadingRoleChange = false);
      }
    }
  }

  Future<void> _onResetPasswordPressed() async {
    final email = widget.user['email']?.toString();
    if (email == null || email.isEmpty) return;

    setState(() => _isLoadingResetPassword = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackbar('تم إرسال رابط إعادة تعيين كلمة المرور', isError: false);
    } catch (e) {
      _showSnackbar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingResetPassword = false);
    }
  }

  Future<void> _onDeletePressed(AdminActionsNotifier actions) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(ArabicLabels.confirm),
          ),
        ],
      ),
    );
    if (first != true) return;

    if (!mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد نهائي'),
        content: const Text('هذا الإجراء لا يمكن التراجع عنه'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(ArabicLabels.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(ArabicLabels.delete),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (second == true) {
      setState(() => _isLoadingDelete = true);
      try {
        await _runAction(
            () => actions.deleteUserData(widget.user['id'].toString()));
      } finally {
        if (mounted) setState(() => _isLoadingDelete = false);
      }
    }
  }

  // ── Stat box ──────────────────────────────────────────────────────────────

  Widget _statBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
      decoration: const BoxDecoration(
        color: AppThemeConstants.surface,
        borderRadius: AppThemeConstants.borderRadiusMd,
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: AppThemeConstants.spaceXs),
          Text(
            value,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

// ── Reusable action button ──────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? backgroundColor;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: backgroundColor != null
          ? ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: AppThemeConstants.onPrimary,
            )
          : null,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

// ── Credentials section ─────────────────────────────────────────────────────

class _CredentialsSection extends StatelessWidget {
  final String userId;
  final bool isLoadingApprove;
  final bool isLoadingReject;
  final void Function(String credId) onApprove;
  final void Function(String credId) onReject;

  const _CredentialsSection({
    required this.userId,
    required this.isLoadingApprove,
    required this.isLoadingReject,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('credentials')
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppThemeConstants.spaceMd),
            const Text(
              'الشهادات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...docs.map((d) {
              final c = d.data();
              final credStatus = c['status']?.toString() ?? 'pending';
              final isPending = credStatus == 'pending';

              return ListTile(
                title: Text(c['title']?.toString() ?? d.id),
                subtitle: Text(credStatus),
                // Only show approve/reject for pending credentials
                trailing: isPending
                    ? Wrap(
                        spacing: AppThemeConstants.spaceXs,
                        children: [
                          TextButton(
                            onPressed: isLoadingApprove
                                ? null
                                : () => onApprove(d.id),
                            child: isLoadingApprove
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text(ArabicLabels.approve),
                          ),
                          TextButton(
                            onPressed: isLoadingReject
                                ? null
                                : () => onReject(d.id),
                            child: isLoadingReject
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text(ArabicLabels.reject),
                          ),
                        ],
                      )
                    : null,
              );
            }),
          ],
        );
      },
    );
  }
}


