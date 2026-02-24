import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminCredentialsScreen extends ConsumerWidget {
  const AdminCredentialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCredentialsProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    Future<void> action(Future<void> Function() call) async {
      await call();
      final st = ref.read(adminActionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
          content: Text(st.hasError
              ? st.error.toString()
              : ArabicLabels.operationSuccess),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.teacherCredentials)),
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
                final created = c['createdAt'];
                final ts = created is Timestamp
                    ? created.toDate().toString().split(' ').first
                    : '-';
                return Card(
                  margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                  child: ListTile(
                    title: Text(c['title']?.toString() ?? ArabicLabels.noData),
                    subtitle: Text(
                        '${ArabicLabels.userId}: ${c['userId'] ?? '-'}\n${ArabicLabels.submittedAt}: $ts'),
                    leading: c['imageUrl'] != null
                        ? ClipRRect(
                            borderRadius: AppThemeConstants.borderRadiusSm,
                            child: Image.network(c['imageUrl'].toString(),
                                width: 48, height: 48, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.image_not_supported),
                    trailing: Wrap(
                      spacing: AppThemeConstants.spaceXs,
                      children: [
                        IconButton(
                          color: AppThemeConstants.success,
                          icon: const Icon(Icons.check_circle),
                          onPressed: () => action(() =>
                              actions.approveCredential(
                                  c['userId'].toString(), c['id'].toString())),
                        ),
                        IconButton(
                          color: AppThemeConstants.error,
                          icon: const Icon(Icons.cancel),
                          onPressed: () async {
                            final ctrl = TextEditingController();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title:
                                    const Text(ArabicLabels.rejectCredential),
                                content: TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                        labelText:
                                            ArabicLabels.rejectionReason)),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text(ArabicLabels.cancel)),
                                  ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(ArabicLabels.reject)),
                                ],
                              ),
                            );
                            if (ok == true && ctrl.text.trim().isNotEmpty) {
                              await action(() => actions.rejectCredential(
                                  c['userId'].toString(),
                                  c['id'].toString(),
                                  ctrl.text.trim()));
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
