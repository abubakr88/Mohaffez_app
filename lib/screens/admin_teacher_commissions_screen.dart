import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/direct_payment_model.dart';
import '../providers/admin_provider.dart';
import '../services/direct_payment_service.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';

class AdminTeacherCommissionsScreen extends ConsumerStatefulWidget {
  const AdminTeacherCommissionsScreen({super.key});

  @override
  ConsumerState<AdminTeacherCommissionsScreen> createState() =>
      _AdminTeacherCommissionsScreenState();
}

class _AdminTeacherCommissionsScreenState
    extends ConsumerState<AdminTeacherCommissionsScreen> {
  final Map<String, bool> _markingPaid = {};

  Future<void> _markAsPaid(String commissionId) async {
    setState(() => _markingPaid[commissionId] = true);
    try {
      await ref
          .read(adminActionsProvider.notifier)
          .markCommissionPaid(commissionId);
      final st = ref.read(adminActionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                st.hasError ? AppThemeConstants.error : Colors.green,
            content: Text(st.hasError
                ? st.error.toString()
                : 'تم تسجيل الدفع بنجاح ✓'),
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
      if (mounted) setState(() => _markingPaid.remove(commissionId));
    }
  }

  // ignore: unused_element
  void _refresh() {
    ref.invalidate(adminActionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: const AdminAppBar(title: 'عمولات المحافظين'),
        body: StreamBuilder<List<WeeklyCommissionSummary>>(
          stream: DirectPaymentService.watchAllCommissions(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const Center(
                child: Text('لا توجد عمولات بعد'),
              );
            }

            // Group by mohaffezId
            final grouped = <String, List<WeeklyCommissionSummary>>{};
            for (final item in list) {
              grouped.putIfAbsent(item.mohaffezId, () => []).add(item);
            }

            // Calculate total pending
            final totalPending = list
                .where((w) => w.isPending || w.isOverdue)
                .fold(0.0, (s, w) => s + w.commissionAmount);

            return Column(
              children: [
                // Header card with total pending
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(AppThemeConstants.spaceMd),
                  padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: AppThemeConstants.borderRadiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إجمالي المستحقات غير المدفوعة:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${totalPending.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: totalPending > 0
                              ? Colors.red.shade700
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                // List of teachers
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppThemeConstants.spaceMd,
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final mohaffezId = grouped.keys.elementAt(index);
                      final summaries = grouped[mohaffezId]!;
                      final mohaffezName = summaries.first.mohaffezName;
                      final totalSessions = summaries.fold<int>(
                          0, (s, w) => s + w.totalSessions);
                      final totalRevenue = summaries.fold<double>(
                          0.0, (s, w) => s + w.totalRevenue);
                      final pendingAmount = summaries
                          .where((w) => !w.isPaid)
                          .fold(0.0, (s, w) => s + w.commissionAmount);
                      final hasOverdue =
                          summaries.any((w) => w.isOverdue);
                      final hasAwaiting =
                          summaries.any((w) => w.isAwaitingConfirmation);

                      // Color priority: overdue > awaiting > pending > paid
                      final chipColor = hasOverdue
                          ? Colors.red.shade700
                          : hasAwaiting
                              ? Colors.blue.shade700
                              : pendingAmount > 0
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700;

                      return Card(
                        margin: const EdgeInsets.only(
                            bottom: AppThemeConstants.spaceSm),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppThemeConstants.borderRadiusMd,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppThemeConstants.primaryAmber,
                            child: Text(
                              mohaffezName.isNotEmpty
                                  ? mohaffezName[0]
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            mohaffezName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'جلسات: $totalSessions | إجمالي: ${totalRevenue.toStringAsFixed(0)} ج.م',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${pendingAmount.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: chipColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasAwaiting ? 'بانتظار التأكيد' : 'مستحق',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _TeacherCommissionDetailScreen(
                                  mohaffezId: mohaffezId,
                                  mohaffezName: mohaffezName,
                                  summaries: summaries,
                                  markingPaid: _markingPaid,
                                  onMarkAsPaid: _markAsPaid,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TeacherCommissionDetailScreen extends StatelessWidget {
  final String mohaffezId;
  final String mohaffezName;
  final List<WeeklyCommissionSummary> summaries;
  final Map<String, bool> markingPaid;
  final Future<void> Function(String) onMarkAsPaid;

  const _TeacherCommissionDetailScreen({
    required this.mohaffezId,
    required this.mohaffezName,
    required this.summaries,
    required this.markingPaid,
    required this.onMarkAsPaid,
  });

  @override
  Widget build(BuildContext context) {
    final totalPaid = summaries
        .where((w) => w.isPaid)
        .fold(0.0, (s, w) => s + w.commissionAmount);
    final totalPending = summaries
        .where((w) => w.isPending || w.isOverdue)
        .fold(0.0, (s, w) => s + w.commissionAmount);
    final totalAwaiting = summaries
        .where((w) => w.isAwaitingConfirmation)
        .fold(0.0, (s, w) => s + w.commissionAmount);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AdminAppBar(title: '$mohaffezName — مستحقاته'),
        body: Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppThemeConstants.spaceMd),
              padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: totalPending > 0
                      ? [Colors.amber.shade700, Colors.amber.shade400]
                      : [Colors.green.shade700, Colors.green.shade400],
                ),
                borderRadius: AppThemeConstants.borderRadiusMd,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'المدفوع:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${totalPaid.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'المستحق:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${totalPending.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (totalAwaiting > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'بانتظار التاكد:',
                          style: TextStyle(
                            color: Colors.lightBlue.shade200,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${totalAwaiting.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                            color: Colors.lightBlue.shade200,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppThemeConstants.spaceMd,
                ),
                itemCount: summaries.length,
                itemBuilder: (context, index) {
                  final summary = summaries[index];
                  return _WeekSummaryCard(
                    summary: summary,
                    isMarkingPaid: markingPaid[summary.id] ?? false,
                    onMarkAsPaid: () => onMarkAsPaid(summary.id),
                    showAdminActions: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final WeeklyCommissionSummary summary;
  final bool isMarkingPaid;
  final VoidCallback onMarkAsPaid;
  final bool showAdminActions;

  const _WeekSummaryCard({
    required this.summary,
    required this.isMarkingPaid,
    required this.onMarkAsPaid,
    this.showAdminActions = true,
  });

  Color get _statusColor => switch (summary.status) {
        'paid' => Colors.green,
        'overdue' => Colors.red,
        'awaiting_confirmation' => Colors.blue,
        _ => Colors.orange,
      };

  String get _statusLabel => switch (summary.status) {
        'paid' => '✅ مدفوع',
        'overdue' => '⚠️ متأخر',
        'awaiting_confirmation' => '⏳ بانتظار التأكيد',
        _ => '⏳ مستحق',
      };

  @override
  Widget build(BuildContext context) {
    final weekLabel = summary.weekStart != null
        ? 'الأسبوع ${summary.weekNumber} – '
            '${DateFormat('dd MMM', 'ar').format(summary.weekStart!)}'
        : 'الأسبوع ${summary.weekNumber}';
    final due = summary.dueDate != null
        ? DateFormat('dd/MM/yyyy').format(summary.dueDate!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(weekLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${summary.totalSessions} جلسة • '
              'إجمالي: ${summary.totalRevenue.toStringAsFixed(0)} ج.م',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (due.isNotEmpty && !summary.isPaid)
              Text('الاستحقاق: $due',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          summary.isOverdue ? Colors.red : Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${summary.commissionAmount.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _statusColor)),
            const SizedBox(height: 4),
            Text(_statusLabel,
                style: TextStyle(fontSize: 11, color: _statusColor)),
            if (showAdminActions && !summary.isPaid) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 24,
                child: ElevatedButton(
                  onPressed: isMarkingPaid ? null : onMarkAsPaid,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: isMarkingPaid
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('تم الدفع',
                          style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


