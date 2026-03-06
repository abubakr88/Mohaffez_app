import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
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
      await ref.read(adminActionsProvider.notifier).dismissFailedOperation(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            // WHY: Keep success color sourced from app theme constants.
            backgroundColor: AppThemeConstants.accentGreen,
            content: Text(ArabicLabels.operationSuccess),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // WHY: Keep error color sourced from app theme constants.
            backgroundColor: AppThemeConstants.error,
            content: Text('${ArabicLabels.operationFailed}: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _dismissingIds.remove(id));
      }
    }
  }

  // WHY: Provide operation-specific visual cue for faster admin scanning.
  IconData _iconForOperationType(String operationType) {
    switch (operationType) {
      case 'cancellation-notification':
        return Icons.notifications_off;
      case 'rejection-notification':
        return Icons.cancel;
      case 'slot-release':
        return Icons.lock_open;
      case 'commission-calculation':
        return Icons.monetization_on;
      default:
        return Icons.error_outline;
    }
  }

  // WHY: Highlight operation status with consistent semantic theme colors.
  Color _statusColor(String status) {
    switch (status) {
      case 'pending-retry':
      case 'pending_retry':
      case 'pending':
        return AppThemeConstants.primaryAmber;
      case 'failed':
        return AppThemeConstants.error;
      case 'dismissed':
        return AppThemeConstants.accentGreen;
      default:
        return AppThemeConstants.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final failed = ref.watch(failedOperationsProvider);
    final actions = ref.read(adminActionsProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: ArabicLabels.failedOperations),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppThemeConstants.primaryAmber,
          onPressed: () => _run(actions.triggerCleanupJob),
          label: const Text(ArabicLabels.runCleanupJob),
          icon: const Icon(Icons.cleaning_services),
        ),
        body: failed.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (list) {
            // WHY: Explicit success state helps admins confirm queue is healthy.
            if (list.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppThemeConstants.accentGreen,
                    ),
                    SizedBox(height: AppThemeConstants.spaceMd),
                    Text(
                      ArabicLabels.noFailedOperations,
                      style: TextStyle(color: AppThemeConstants.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final op = list[i];
                final operationType = op['operationType']?.toString() ?? 'unknown';
                final status = op['status']?.toString() ?? 'unknown';
                final statusColor = _statusColor(status);
                final id = op['id'] as String?;
                final isDismissing = id != null && _dismissingIds[id] == true;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppThemeConstants.spaceMd,
                    vertical: AppThemeConstants.spaceSm,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppThemeConstants.spaceMd,
                      vertical: AppThemeConstants.spaceSm,
                    ),
                    leading: Icon(
                      _iconForOperationType(operationType),
                      color: AppThemeConstants.primaryAmber,
                    ),
                    title: Text(
                      operationType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppThemeConstants.primaryAmber,
                      ),
                    ),
                    subtitle: Text(
                      op['error']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppThemeConstants.textSecondary,
                      ),
                    ),
                    // WHY: Keep status plus retry/dismiss controls visible at glance.
                    trailing: SizedBox(
                      width: 152,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Chip(
                            backgroundColor: statusColor.withValues(alpha: 0.14),
                            side: BorderSide(color: statusColor.withValues(alpha: 0.35)),
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.replay,
                                  color: AppThemeConstants.primaryAmber,
                                ),
                                tooltip: ArabicLabels.retryOperation,
                                onPressed: () => _run(actions.triggerCleanupJob),
                              ),
                              isDismissing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        color: AppThemeConstants.accentGreen,
                                      ),
                                      tooltip: ArabicLabels.dismissOperation,
                                      onPressed: id == null
                                          ? null
                                          : () => _dismissOperation(id),
                                    ),
                            ],
                          ),
                        ],
                      ),
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
