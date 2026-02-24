import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminFailedOperationsScreen extends ConsumerWidget {
  const AdminFailedOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(failedOperationsProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    Future<void> run(Future<void> Function() op) async {
      await op();
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
        appBar: AppBar(title: const Text(ArabicLabels.failedOperations)),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppThemeConstants.primaryAmber,
          onPressed: () => run(actions.triggerCleanupJob),
          label: const Text(ArabicLabels.runCleanupJob),
          icon: const Icon(Icons.cleaning_services),
        ),
        body: failed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) => ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final item = list[i];
              return Card(
                margin: const EdgeInsets.all(AppThemeConstants.spaceSm),
                child: ListTile(
                  title: Text(item['operationType']?.toString() ?? 'unknown'),
                  subtitle: Text(
                      '${item['error'] ?? ''}\n${item['timestamp'] ?? ''}\n${ArabicLabels.retryCount}: ${item['retryCount'] ?? 0}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(label: Text(item['status']?.toString() ?? '-')),
                      TextButton(
                        onPressed: () => run(() => actions
                            .dismissFailedOperation(item['id'].toString())),
                        child: const Text(ArabicLabels.dismiss),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
