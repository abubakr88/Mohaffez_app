import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin_provider.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/admin_app_bar.dart';
import '../../shared/widgets/admin_empty_state.dart';
import '../../shared/utils/arabic_labels.dart';

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
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(pendingCredentialsProvider),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: const AdminEmptyState(
                        icon: Icons.verified_user_outlined,
                        message: ArabicLabels.noCredentialsPending,
                      ),
                    ),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(pendingCredentialsProvider),
              child: ListView.builder(
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
                  child: Padding(
                    padding: const EdgeInsets.all(AppThemeConstants.spaceSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                final urls = c['imageUrls'];
                                if (urls is List && urls.isNotEmpty) {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(urls.first.toString()),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: (c['imageUrls'] is List &&
                                      (c['imageUrls'] as List).isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius:
                                          AppThemeConstants.borderRadiusSm,
                                      child: Image.network(
                                        (c['imageUrls'] as List).first.toString(),
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image_not_supported),
                                      ),
                                    )
                                  : const Icon(Icons.image_not_supported, size: 48),
                            ),
                            const SizedBox(width: AppThemeConstants.spaceSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['title']?.toString() ?? ArabicLabels.noData,
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ArabicLabels.userId}: $userId\n${ArabicLabels.submittedAt}: $ts',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppThemeConstants.spaceSm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeConstants.success,
                                foregroundColor: AppThemeConstants.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: isApproving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppThemeConstants.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle, size: 16),
                              label: const Text('اعتماد', style: TextStyle(fontSize: 12)),
                              onPressed: isLoading
                                  ? null
                                  : () => _approveCredential(userId, credentialId),
                            ),
                            const SizedBox(width: AppThemeConstants.spaceSm),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeConstants.error,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: isRejecting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cancel, size: 16),
                              label: const Text('رفض', style: TextStyle(fontSize: 12)),
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
                      ],
                    ),
                  ),
                );
              },
            ),
          );
          },
        ),
      ),
    );
  }
}


