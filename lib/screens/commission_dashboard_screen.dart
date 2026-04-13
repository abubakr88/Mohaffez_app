import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/direct_payment_model.dart';
import '../providers/admin_provider.dart';
import '../providers/system_config_provider.dart';
import '../services/direct_payment_service.dart';
import '../shared/theme/app_theme_constants.dart';
import '../shared/widgets/admin_app_bar.dart';
import '../shared/widgets/admin_empty_state.dart';

class CommissionDashboardScreen extends ConsumerStatefulWidget {
  const CommissionDashboardScreen({super.key});

  @override
  ConsumerState<CommissionDashboardScreen> createState() =>
      _CommissionDashboardScreenState();
}

class _CommissionDashboardScreenState
    extends ConsumerState<CommissionDashboardScreen> {
  bool _isRunningJob = false;
  final Map<String, bool> _markingPaid = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get dynamic commission rate from system config, defaulting to 5%
  double get _commissionRate {
    final configAsync = ref.watch(systemConfigProvider);
    return configAsync.when(
      data: (config) => config.commissionRate,
      loading: () => 0.05,
      error: (_, __) => 0.05,
    );
  }

  Future<void> _triggerCommissionJob() async {
    setState(() => _isRunningJob = true);
    try {
      await ref.read(adminActionsProvider.notifier).triggerCommissionJob();
      final st = ref.read(adminActionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: st.hasError
              ? AppThemeConstants.error
              : AppThemeConstants.success,
          content: Text(st.hasError
              ? st.error.toString()
              : 'تمت معالجة العمولات بنجاح ✓'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isRunningJob = false);
    }
  }

  Future<void> _markAsPaid(String commissionId) async {
    setState(() => _markingPaid[commissionId] = true);
    try {
      await ref.read(adminActionsProvider.notifier).markCommissionPaid(commissionId);
      final st = ref.read(adminActionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: st.hasError
              ? AppThemeConstants.error
              : Colors.green,
          content: Text(st.hasError
              ? st.error.toString()
              : 'تم تسجيل الدفع بنجاح ✓'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text('خطأ: ${e.toString()}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _markingPaid.remove(commissionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AdminAppBar(
            title: 'عمولات التطبيق (${(_commissionRate * 100).toInt()}%)'),
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

            // Stats at top
            final totalPending = list
                .where((w) => w.isPending || w.isOverdue)
                .fold(0.0, (s, w) => s + w.commissionAmount);

            return Column(children: [
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: AppThemeConstants.background,
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 16),
              // Summary card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: totalPending > 0
                        ? [Colors.orange.shade700, Colors.orange.shade400]
                        : [Colors.green.shade700, Colors.green.shade400],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text(
                    totalPending > 0 ? 'مستحق عليك دفعه' : 'لا يوجد مستحقات 🎉',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${totalPending.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${(_commissionRate * 100).toInt()}% من إجمالي المدفوعات المباشرة',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),

              // List
              Expanded(
                child: filteredList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppThemeConstants.textSecondary,
                            ),
                            const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredList.length,
                  itemBuilder: (_, i) => _WeekSummaryCard(
                    summary: filteredList[i],
                    isMarkingPaid: _markingPaid[filteredList[i].id] == true,
                    onMarkAsPaid: () => _markAsPaid(filteredList[i].id),
                  ),
                ),
              ),
            ]);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isRunningJob ? null : _triggerCommissionJob,
          backgroundColor: _isRunningJob ? Colors.grey : AppThemeConstants.primaryAmber,
          icon: _isRunningJob
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow),
          label: Text(_isRunningJob ? 'جاري التشغيل...' : 'تشغيل عملية العمولة'),
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
    // ignore: unused_element_parameter
    this.showAdminActions = true,
  });

  Color get _statusColor => switch (summary.status) {
        'paid' => Colors.green,
        'overdue' => Colors.red,
        _ => Colors.orange,
      };

  String get _statusLabel => switch (summary.status) {
        'paid' => '✅ مدفوع',
        'overdue' => '⚠️ متأخر',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color: summary.isOverdue ? Colors.red : Colors.grey)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: isMarkingPaid
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('تم الدفع', style: TextStyle(fontSize: 9, height: 1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}




