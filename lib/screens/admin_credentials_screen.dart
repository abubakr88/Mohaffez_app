import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../utils/arabic_labels.dart';

class AdminCredentialsScreen extends ConsumerStatefulWidget {
  const AdminCredentialsScreen({super.key});

  @override
  ConsumerState<AdminCredentialsScreen> createState() =>
      _AdminCredentialsScreenState();
}

class _AdminCredentialsScreenState
    extends ConsumerState<AdminCredentialsScreen> {
  final Set<String> _loadingApprove = {};
  final Set<String> _loadingReject = {};

  String _credentialKey(String userId, String credentialId) =>
      '$userId:$credentialId';

  Future<void> _approveCredential(String userId, String credentialId) async {
    final key = _credentialKey(userId, credentialId);
    setState(() => _loadingApprove.add(key));

    try {
      await ref.read(adminActionsProvider.notifier).approveCredential(userId, credentialId);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text(ArabicLabels.operationSuccess),
        ),
      );
      ref.invalidate(pendingCredentialsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingApprove.remove(key));
      }
    }
  }

  Future<void> _rejectCredential(
      String userId, String credentialId, String reason) async {
    final key = _credentialKey(userId, credentialId);
    setState(() => _loadingReject.add(key));

    try {
      await ref
          .read(adminActionsProvider.notifier)
          .rejectCredential(userId, credentialId, reason);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text(ArabicLabels.operationSuccess),
        ),
      );
      ref.invalidate(pendingCredentialsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingReject.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingCredentialsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.teacherCredentials),
        body: pending.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                  child: Text(ArabicLabels.noCredentialsPending));
            }

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final userId = c['userId']?.toString() ?? '';
                final credentialId = c['id']?.toString() ?? '';
                final key = _credentialKey(userId, credentialId);
                final created = c['createdAt'];
                final ts = created is Timestamp
                    ? created.toDate().toString().split(' ').first
                    : '-';

                final isApproving = _loadingApprove.contains(key);
                final isRejecting = _loadingReject.contains(key);
                final isLoading = isApproving || isRejecting;

                return Card(
                  margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                  child: ListTile(
                    title: Text(c['title']?.toString() ?? ArabicLabels.noData),
                    subtitle: Text(
                        '${ArabicLabels.userId}: $userId\n${ArabicLabels.submittedAt}: $ts'),
                    leading: c['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: AppThemeConstants.borderRadiusSm,
                            child: Image.network(c['imageUrl'].toString(),
                                width: 48, height: 48, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.image_not_supported),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeConstants.success,
                            foregroundColor: Colors.white,
                          ),
                          icon: isApproving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: const Text('اعتماد ✅'),
                          onPressed: isLoading
                              ? null
                              : () => _approveCredential(userId, credentialId),
                        ),
                        const SizedBox(width: AppThemeConstants.spaceXs),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeConstants.error,
                            foregroundColor: Colors.white,
                          ),
                          icon: isRejecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cancel),
                          label: const Text('رفض ❌'),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final ctrl = TextEditingController();
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text(
                                          ArabicLabels.rejectCredential),
                                      content: TextField(
                                          controller: ctrl,
                                          decoration: const InputDecoration(
                                              labelText: ArabicLabels
                                                  .rejectionReason)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext, false),
                                            child:
                                                const Text(ArabicLabels.cancel)),
                                        ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(dialogContext, true),
                                            child:
                                                const Text(ArabicLabels.reject)),
                                      ],
                                    ),
                                  );
                                  if (ok == true &&
                                      ctrl.text.trim().isNotEmpty) {
                                    await _rejectCredential(userId,
                                        credentialId, ctrl.text.trim());
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


