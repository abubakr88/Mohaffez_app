import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminAuditLogPage extends ConsumerStatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  ConsumerState<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends ConsumerState<AdminAuditLogPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'سجل العمليات الإدارية',
            subtitle: 'آخر ١٠٠ إجراء قام به المديرون',
          ),
          const SizedBox(height: DSSpacing.lg),
          SizedBox(
            width: 360,
            child: DSSearchField(
              hint: 'بحث في النوع أو معرّف الهدف',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: DSSpacing.lg),
          Expanded(
            child: logsAsync.when(
              loading: () => const DSSkeletonCard(),
              error: (e, _) =>
                  DSBanner(message: '$e', variant: DSBannerVariant.error),
              data: (rows) {
                final filtered = rows.where((r) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  final target = (r['targetUserId'] ?? r['targetId'] ?? r['userId'] ?? '')
                      .toString()
                      .toLowerCase();
                  final actor = (r['performedBy'] ?? r['adminId'] ?? r['adminName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return (r['action'] as String? ?? '').toLowerCase().contains(q) ||
                      target.contains(q) ||
                      actor.contains(q);
                }).toList();
                if (filtered.isEmpty) {
                  return const DSCard(
                    child: DSEmptyState(
                      title: 'لا توجد سجلات',
                      icon: Icons.history_rounded,
                    ),
                  );
                }
                return DSCard(
                  child: DSDataTable<Map<String, dynamic>>(
                    columns: [
                      DSColumnDef(
                        key: 'action',
                        label: 'الإجراء',
                        width: 200,
                        cellBuilder: (ctx, r) => Text(
                          r['action'] as String? ?? '—',
                          style: DSText.bodyMedium(ctx),
                        ),
                      ),
                      DSColumnDef(
                        key: 'targetId',
                        label: 'الهدف',
                        cellBuilder: (ctx, r) => Text(
                          (r['targetUserId'] ?? r['targetId'] ?? r['userId'] ?? '—')
                              .toString(),
                          style: DSText.body(ctx, color: DSColors.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'adminId',
                        label: 'بواسطة',
                        cellBuilder: (ctx, r) => Text(
                          (r['performedBy'] ?? r['adminId'] ?? r['adminName'] ?? '—')
                              .toString(),
                          style: DSText.body(ctx, color: DSColors.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'timestamp',
                        label: 'التاريخ',
                        width: 160,
                        cellBuilder: (ctx, r) {
                          final ts = r['timestamp'] ?? r['createdAt'];
                          if (ts == null) return const Text('—');
                          try {
                            final dt = ts is DateTime
                                ? ts
                                : (ts as dynamic).toDate() as DateTime;
                            return Text(
                              DateFormat('dd/MM HH:mm', 'ar').format(dt),
                              style: DSText.body(ctx, color: DSColors.text2),
                            );
                          } catch (_) {
                            return const Text('—');
                          }
                        },
                      ),
                    ],
                    rows: filtered,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
