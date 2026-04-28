import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/direct_payment_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/direct_payment_service.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/admin_app_bar.dart';
import '../../shared/widgets/admin_empty_state.dart';

class AdminTeacherCommissionsScreen extends ConsumerStatefulWidget {
  const AdminTeacherCommissionsScreen({super.key});

  @override
  ConsumerState<AdminTeacherCommissionsScreen> createState() =>
      _AdminTeacherCommissionsScreenState();
}

class _AdminTeacherCommissionsScreenState
    extends ConsumerState<AdminTeacherCommissionsScreen> {
  final Map<String, bool> _markingPaid = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
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
            backgroundColor: AppThemeConstants.error,
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
        appBar: const AdminAppBar(title: 'عمولات المحفظين'),
        body: StreamBuilder<List<WeeklyCommissionSummary>>(
          stream: DirectPaymentService.watchAllCommissions(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data!;
            if (list.isEmpty) {
              return const AdminEmptyState(
                icon: Icons.payments_outlined,
                message: 'لا توجد عمولات بعد',
              );
            }

            // Filter by search query
            final filteredList = _searchQuery.isEmpty
                ? list
                : list.where((item) {
                    final query = _searchQuery.toLowerCase();
                    return item.mohaffezName.toLowerCase().contains(query) ||
                        item.mohaffezId.toLowerCase().contains(query);
                  }).toList();

            // Group by mohaffezId
            final grouped = <String, List<WeeklyCommissionSummary>>{};
            for (final item in filteredList) {
              grouped.putIfAbsent(item.mohaffezId, () => []).add(item);
            }

            // Calculate total pending
            final totalPending = list
                .where((w) => w.isPending || w.isOverdue)
                .fold(0.0, (s, w) => s + w.commissionAmount);

            return Column(
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppThemeConstants.spaceMd,
                    AppThemeConstants.spaceMd,
                    AppThemeConstants.spaceMd,
                    0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    textDirection: ui.TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم المحفظ أو المعرف...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(
                        borderRadius: AppThemeConstants.borderRadiusMd,
                      ),
                      filled: true,
                      fillColor: AppThemeConstants.background,
                    ),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(height: AppThemeConstants.spaceMd),
                // Header card with total pending
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(AppThemeConstants.spaceMd),
                  padding: const EdgeInsets.all(AppThemeConstants.spaceMd),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warning.withValues(alpha: 0.1),
                    borderRadius: AppThemeConstants.borderRadiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'إجمالي المستحقات غير المدفوعة:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${totalPending.toStringAsFixed(2)} ج.م',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: totalPending > 0
                              ? AppThemeConstants.error
                              : AppThemeConstants.success,
                        ),
                      ),
                    ],
                  ),
                ),
                // List of teachers
                Expanded(
                  child: grouped.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.search_off,
                                size: 64,
                                color: AppThemeConstants.textSecondary,
                              ),
                              const SizedBox(height: AppThemeConstants.spaceMd),
                              Text(
                                'لا توجد نتائج لـ "$_searchQuery"',
                                style: const TextStyle(
                                  color: AppThemeConstants.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
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
                          ? AppThemeConstants.error
                          : hasAwaiting
                              ? AppThemeConstants.accentBlueDark
                              : pendingAmount > 0
                                  ? AppThemeConstants.warning
                                  : AppThemeConstants.success;

                      return Card(
                        margin: const EdgeInsets.only(
                            bottom: AppThemeConstants.spaceSm),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppThemeConstants.borderRadiusMd,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppThemeConstants.primary,
                            child: Text(
                              mohaffezName.isNotEmpty
                                  ? mohaffezName[0]
                                  : '?',
                              style: const TextStyle(
                                color: AppThemeConstants.white,
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
                                  color: AppThemeConstants.grey500,
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
                      ? [AppThemeConstants.accentAmberDark, AppThemeConstants.accentAmber]
                      : [AppThemeConstants.success, AppThemeConstants.accentGreenAlt],
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
                          color: AppThemeConstants.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${totalPaid.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          color: AppThemeConstants.white,
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
                          color: AppThemeConstants.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${totalPending.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          color: AppThemeConstants.white,
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
                        const Text(
                          'بانتظار التاكد:',
                          style: TextStyle(
                            color: AppThemeConstants.accentBlue,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${totalAwaiting.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            color: AppThemeConstants.accentBlue,
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
        'paid' => AppThemeConstants.success,
        'overdue' => AppThemeConstants.error,
        'awaiting_confirmation' => AppThemeConstants.accentBlue,
        _ => AppThemeConstants.warning,
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
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(weekLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${summary.totalSessions} جلسة • '
              'إجمالي: ${summary.totalRevenue.toStringAsFixed(0)} ج.م',
              style: const TextStyle(fontSize: 11, color: AppThemeConstants.grey500),
            ),
            if (due.isNotEmpty && !summary.isPaid)
              Text('الاستحقاق: $due',
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          summary.isOverdue ? AppThemeConstants.error : AppThemeConstants.grey500)),
          ],
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${summary.commissionAmount.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _statusColor)),
              Text(_statusLabel,
                  style: TextStyle(fontSize: 10, color: _statusColor)),
              if (showAdminActions && !summary.isPaid)
                SizedBox(
                  height: 20,
                  child: ElevatedButton(
                    onPressed: isMarkingPaid ? null : onMarkAsPaid,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: AppThemeConstants.success,
                      foregroundColor: AppThemeConstants.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: isMarkingPaid
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppThemeConstants.white,
                            ),
                          )
                        : const Text('تم الدفع',
                            style: TextStyle(fontSize: 9)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


