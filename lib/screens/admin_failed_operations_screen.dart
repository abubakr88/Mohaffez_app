import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../utils/arabic_labels.dart';

class AdminFailedOperationsScreen extends ConsumerStatefulWidget {
  const AdminFailedOperationsScreen({super.key});

  @override
  ConsumerState<AdminFailedOperationsScreen> createState() =>
      _AdminFailedOperationsScreenState();
}

class _AdminFailedOperationsScreenState
    extends ConsumerState<AdminFailedOperationsScreen> {
  final Map<String, bool> _dismissingIds = {};

  Future<void> _run(Future<void> Function() op) async {
    await op();
    final st = ref.read(adminActionsProvider);
    if (!mounted) return;
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

  Future<void> _dismissOperation(String id) async {
    setState(() => _dismissingIds[id] = true);
    try {
      await ref
          .read(adminActionsProvider.notifier)
          .dismissFailedOperation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('تم تجاهل العملية بنجاح ✓'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('خطأ: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _dismissingIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = ref.watch(failedOperationsProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(ArabicLabels.failedOperations)),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppThemeConstants.primaryAmber,
          onPressed: () => _run(actions.triggerCleanupJob),
          label: const Text(ArabicLabels.runCleanupJob),
          icon: const Icon(Icons.cleaning_services),
        ),
        body: failed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) => ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final op = list[i];
              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: AppThemeConstants.spaceMd,
                    vertical: AppThemeConstants.spaceSm),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppThemeConstants.spaceMd,
                      vertical: AppThemeConstants.spaceSm),
                  title: Text(
                    op['operationType']?.toString() ?? 'عملية غير معروفة',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppThemeConstants.primaryAmber,
                    ),
                  ),
                  subtitle: Text(
                    op['error']?.toString() ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppThemeConstants.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 18,
                        color: AppThemeConstants.textSecondary),
                    tooltip: 'نسخ المعرف',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: op['id'] ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('تم نسخ المعرف'),
                        duration: Duration(seconds: 1),
                      ));
                    },
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppThemeConstants.spaceMd,
                          vertical: AppThemeConstants.spaceSm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...op.entries
                              .where((e) =>
                                  !['id', 'operationType', 'error'].contains(e.key) &&
                                  e.value != null)
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppThemeConstants.spaceXs),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${e.key}: ',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppThemeConstants.primaryAmber)),
                                        Expanded(
                                          child: Text(e.value.toString(),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppThemeConstants.textSecondary)),
                                        ),
                                      ],
                                    ),
                                  )),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _dismissingIds[op['id']] == true
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : TextButton.icon(
                                    icon: const Icon(Icons.check_circle_outline,
                                        color: Colors.orange),
                                    label: const Text('تجاهل هذه العملية',
                                        style: TextStyle(color: Colors.orange)),
                                    onPressed: () {
                                      final id = op['id'] as String?;
                                      if (id == null) return;
                                      _dismissOperation(id);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
