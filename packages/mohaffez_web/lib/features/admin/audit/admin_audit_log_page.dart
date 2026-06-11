import 'dart:convert';

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
                  final target =
                      (r['targetUserId'] ?? r['targetId'] ?? r['userId'] ?? '')
                          .toString()
                          .toLowerCase();
                  final actor = (r['actorId'] ??
                          r['performedBy'] ??
                          r['adminId'] ??
                          r['adminName'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  final reason = (r['reason'] ?? '').toString().toLowerCase();
                  final data = _json(r['data']).toLowerCase();
                  final targetType =
                      (r['targetType'] ?? '').toString().toLowerCase();
                  return (r['action'] as String? ?? '')
                          .toLowerCase()
                          .contains(q) ||
                      target.contains(q) ||
                      actor.contains(q) ||
                      reason.contains(q) ||
                      targetType.contains(q) ||
                      data.contains(q);
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
                    onRowTap: (row) => _showDetails(context, row),
                    columns: [
                      DSColumnDef(
                        key: 'action',
                        label: 'الإجراء',
                        width: 180,
                        cellBuilder: (ctx, r) => Text(
                          r['action'] as String? ?? '—',
                          style: DSText.bodyMedium(ctx),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'targetId',
                        label: 'الهدف',
                        cellBuilder: (ctx, r) => Text(
                          (r['targetUserId'] ??
                                  r['targetId'] ??
                                  r['userId'] ??
                                  '—')
                              .toString(),
                          style: DSText.body(ctx, color: DSColors.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'adminId',
                        label: 'بواسطة',
                        cellBuilder: (ctx, r) => Text(
                          (r['actorId'] ??
                                  r['performedBy'] ??
                                  r['adminId'] ??
                                  r['adminName'] ??
                                  '—')
                              .toString(),
                          style: DSText.body(ctx, color: DSColors.text2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'reason',
                        label: 'السبب',
                        cellBuilder: (ctx, r) => Text(
                          (r['reason'] ?? _dataReason(r) ?? '—').toString(),
                          style: DSText.body(ctx, color: DSColors.text2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DSColumnDef(
                        key: 'request',
                        label: 'الطلب',
                        width: 150,
                        cellBuilder: (ctx, r) {
                          final request = _asMap(r['request']);
                          final ip = request['ip']?.toString() ?? '';
                          return Text(
                            ip.isEmpty ? '—' : ip,
                            style: DSText.caption(ctx, color: DSColors.text3),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
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

  Future<void> _showDetails(
    BuildContext context,
    Map<String, dynamic> row,
  ) {
    return DSDialog.show<void>(
      context,
      title: 'تفاصيل العملية',
      width: 720,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine(context, 'الإجراء', row['action']),
              _detailLine(
                context,
                'بواسطة',
                row['actorId'] ?? row['performedBy'] ?? row['adminId'],
              ),
              _detailLine(
                context,
                'الهدف',
                row['targetUserId'] ?? row['targetId'] ?? row['userId'],
              ),
              _detailLine(context, 'نوع الهدف', row['targetType']),
              _detailLine(context, 'السبب', row['reason'] ?? _dataReason(row)),
              _detailLine(context, 'التاريخ', _dateLabel(row)),
              const SizedBox(height: DSSpacing.lg),
              _jsonBlock(context, 'قبل', row['before']),
              const SizedBox(height: DSSpacing.md),
              _jsonBlock(context, 'بعد', row['after']),
              const SizedBox(height: DSSpacing.md),
              _jsonBlock(context, 'بيانات إضافية', row['data']),
              const SizedBox(height: DSSpacing.md),
              _jsonBlock(context, 'الطلب', row['request']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, dynamic value) {
    final text = value?.toString() ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: DSText.caption(context, color: DSColors.text3),
            ),
          ),
          Expanded(child: Text(text, style: DSText.body(context))),
        ],
      ),
    );
  }

  Widget _jsonBlock(BuildContext context, String label, dynamic value) {
    final content = _json(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DSText.caption(context, color: DSColors.text3)),
        const SizedBox(height: DSSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DSSpacing.md),
          decoration: BoxDecoration(
            color: DSColors.surfaceMuted,
            borderRadius: DSRadius.mdAll,
            border: Border.all(color: DSColors.border),
          ),
          child: SelectableText(
            content.isEmpty ? '—' : content,
            style: DSText.caption(context, color: DSColors.text2),
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static String? _dataReason(Map<String, dynamic> row) {
    final data = _asMap(row['data']);
    return data['reason']?.toString();
  }

  static String _json(dynamic value) {
    if (value == null) return '';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  static String _dateLabel(Map<String, dynamic> row) {
    final ts = row['timestamp'] ?? row['createdAt'];
    if (ts == null) return '—';
    try {
      final dt = ts is DateTime ? ts : (ts as dynamic).toDate() as DateTime;
      return DateFormat('dd/MM/yyyy HH:mm', 'ar').format(dt);
    } catch (_) {
      return '—';
    }
  }
}
