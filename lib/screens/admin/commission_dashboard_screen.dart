import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/direct_payment_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/system_config_provider.dart';
import '../../services/direct_payment_service.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../shared/widgets/admin_app_bar.dart';
import '../../shared/widgets/admin_empty_state.dart';

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
  Stream<List<WeeklyCommissionSummary>>? _commissionsStream;

  @override
  void initState() {
    super.initState();
    _commissionsStream = DirectPaymentService.watchAllCommissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              ? 'حدث خطأ أثناء معالجة العمولات'
              : 'تمت معالجة العمولات بنجاح ✓'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('حدث خطأ أثناء تشغيل عملية العمولة'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isRunningJob = false);
    }
  }

  Future<void> _markAsPaid(String commissionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الدفع'),
          content: const Text('هل أنت متأكد من تسجيل هذا الدفع؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    setState(() => _markingPaid[commissionId] = true);
    try {
      await ref.read(adminActionsProvider.notifier).markCommissionPaid(commissionId);
      final st = ref.read(adminActionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: st.hasError
              ? AppThemeConstants.error
              : AppThemeConstants.success,
          content: Text(st.hasError
              ? 'حدث خطأ أثناء تسجيل الدفع'
              : 'تم تسجيل الدفع بنجاح ✓'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('حدث خطأ أثناء تسجيل الدفع'),
        ));
      }
    } finally {
      if (mounted) setState(() => _markingPaid.remove(commissionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(systemConfigProvider);
    final commissionRate = configAsync.when(
      data: (config) => config.commissionRate,
      loading: () => 0.05,
      error: (_, __) => 0.05,
    );

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AdminAppBar(
            title: 'عمولات التطبيق (${(commissionRate * 100).toInt()}%)'),
        body: StreamBuilder<List<WeeklyCommissionSummary>>(
          stream: _commissionsStream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppThemeConstants.error),
                    const SizedBox(height: 16),
                    const Text('حدث خطأ أثناء تحميل البيانات'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data ?? [];
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
            final totalPending = filteredList
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
                        ? [AppThemeConstants.warning, AppThemeConstants.warning.withValues(alpha: 0.7)]
                        : [AppThemeConstants.success, AppThemeConstants.success.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text(
                    totalPending > 0 ? 'مستحق عليك دفعه' : 'لا يوجد مستحقات 🎉',
                    style: TextStyle(color: AppThemeConstants.onPrimary.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${totalPending.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                        color: AppThemeConstants.onPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${(commissionRate * 100).toInt()}% من إجمالي المدفوعات المباشرة',
                      style: TextStyle(color: AppThemeConstants.onPrimary.withValues(alpha: 0.7), fontSize: 12)),
                ]),
              ),

              // List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                      _commissionsStream = DirectPaymentService.watchAllCommissions();
                    });
                  },
                  child: filteredList.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
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
              ),
            ]);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isRunningJob ? null : () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => Directionality(
                textDirection: ui.TextDirection.rtl,
                child: AlertDialog(
                  title: const Text('تأكيد'),
                  content: const Text('هل أنت متأكد من تشغيل عملية العمولة؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppThemeConstants.warning),
                      child: const Text('تشغيل'),
                    ),
                  ],
                ),
              ),
            );
            if (confirm == true) {
              _triggerCommissionJob();
            }
          },
          backgroundColor: _isRunningJob ? AppThemeConstants.textSecondary : AppThemeConstants.primary,
          icon: _isRunningJob
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppThemeConstants.onPrimary,
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

  const _WeekSummaryCard({
    required this.summary,
    required this.isMarkingPaid,
    required this.onMarkAsPaid,
  });

  Color get _statusColor => switch (summary.status) {
        'paid' => AppThemeConstants.success,
        'overdue' => AppThemeConstants.error,
        _ => AppThemeConstants.warning,
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
            '${DateFormat('d MMM', 'ar').format(summary.weekStart!)}'
        : 'الأسبوع ${summary.weekNumber}';
    final due = summary.dueDate != null
        ? DateFormat('d MMMM y', 'ar').format(summary.dueDate!)
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
              style: const TextStyle(fontSize: 12, color: AppThemeConstants.textSecondary),
            ),
            if (due.isNotEmpty && !summary.isPaid)
              Text('الاستحقاق: $due',
                  style: TextStyle(
                      fontSize: 12,
                      color: summary.isOverdue ? AppThemeConstants.error : AppThemeConstants.textSecondary)),
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
              if (!summary.isPaid)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: isMarkingPaid ? null : onMarkAsPaid,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: AppThemeConstants.success,
                      foregroundColor: AppThemeConstants.onPrimary,
                      minimumSize: const Size(44, 36),
                    ),
                    child: isMarkingPaid
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppThemeConstants.onPrimary,
                            ),
                          )
                        : const Text('تم الدفع', style: TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
