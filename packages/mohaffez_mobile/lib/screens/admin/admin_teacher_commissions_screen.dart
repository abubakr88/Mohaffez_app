import 'dart:ui' as ui;
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/utils/time_formatter.dart';
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
  bool _isRunningJob = false;
  final Map<String, bool> _markingPaid = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openReviewDialog(WeeklyCommissionSummary summary) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CommissionReviewDialog(
        summary: summary,
        onConfirm: (paidAmount, adminNote) =>
            _confirmPayment(summary.id, paidAmount, adminNote),
        onReject: (reason) => _rejectPayment(summary.id, reason),
      ),
    );
  }

  Future<void> _confirmPayment(
    String commissionId,
    double? paidAmount,
    String? adminNote,
  ) async {
    setState(() => _markingPaid[commissionId] = true);
    try {
      await ref.read(adminActionsProvider.notifier).markCommissionPaid(
            commissionId,
            paidAmount: paidAmount,
            adminNote: adminNote,
          );
      final st = ref.read(adminActionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
          content: Text(
              st.hasError ? st.error.toString() : 'تم تأكيد الدفع بنجاح ✓'),
        ),
      );
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

  Future<void> _rejectPayment(String commissionId, String reason) async {
    setState(() => _markingPaid[commissionId] = true);
    try {
      await ref
          .read(adminActionsProvider.notifier)
          .rejectCommissionPayment(commissionId, reason: reason);
      final st = ref.read(adminActionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              st.hasError ? AppThemeConstants.error : AppThemeConstants.warning,
          content: Text(st.hasError
              ? st.error.toString()
              : 'تم رفض الدفعة وإبلاغ المحفظ'),
        ),
      );
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

  Future<void> _triggerCommissionJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد'),
          content: const Text('هل أنت متأكد من تشغيل عملية حساب العمولات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeConstants.warning),
              child: const Text('تشغيل'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    setState(() => _isRunningJob = true);
    try {
      await ref.read(adminActionsProvider.notifier).triggerCommissionJob();
      final st = ref.read(adminActionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor:
              st.hasError ? AppThemeConstants.error : AppThemeConstants.success,
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
                    onChanged: (value) => setState(() => _searchQuery = value),
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
                                        color:
                                            chipColor.withValues(alpha: 0.15),
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
                                      builder: (_) =>
                                          _TeacherCommissionDetailScreen(
                                        mohaffezId: mohaffezId,
                                        mohaffezName: mohaffezName,
                                        summaries: summaries,
                                        markingPaid: _markingPaid,
                                        onReview: _openReviewDialog,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isRunningJob ? null : _triggerCommissionJob,
          backgroundColor: _isRunningJob
              ? AppThemeConstants.textSecondary
              : AppThemeConstants.primary,
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

class _TeacherCommissionDetailScreen extends StatelessWidget {
  final String mohaffezId;
  final String mohaffezName;
  final List<WeeklyCommissionSummary> summaries;
  final Map<String, bool> markingPaid;
  final Future<void> Function(WeeklyCommissionSummary) onReview;

  const _TeacherCommissionDetailScreen({
    required this.mohaffezId,
    required this.mohaffezName,
    required this.summaries,
    required this.markingPaid,
    required this.onReview,
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
                      ? [
                          AppThemeConstants.accentAmberDark,
                          AppThemeConstants.accentAmber
                        ]
                      : [
                          AppThemeConstants.success,
                          AppThemeConstants.accentGreenAlt
                        ],
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
                    onReview: () => onReview(summary),
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
  final VoidCallback onReview;
  final bool showAdminActions;

  const _WeekSummaryCard({
    required this.summary,
    required this.isMarkingPaid,
    required this.onReview,
    this.showAdminActions = true,
  });

  Color get _statusColor => switch (summary.status) {
        'paid' => AppThemeConstants.success,
        'overdue' => AppThemeConstants.error,
        'pendingVerification' ||
        'awaiting_confirmation' =>
          AppThemeConstants.accentBlue,
        _ => AppThemeConstants.warning,
      };

  String get _statusLabel => switch (summary.status) {
        'paid' => '✅ مدفوع',
        'overdue' => '⚠️ متأخر',
        'pendingVerification' || 'awaiting_confirmation' => '⏳ بانتظار التأكيد',
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
    final showActionButton =
        showAdminActions && !summary.isPaid && summary.isAwaitingConfirmation;
    final buttonLabel =
        summary.isAwaitingConfirmation ? 'مراجعة الدفعة' : 'تأكيد يدوي';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: showAdminActions && !summary.isPaid ? onReview : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(weekLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          '${summary.totalSessions} جلسة • '
                          'إجمالي: ${summary.totalRevenue.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                              fontSize: 11, color: AppThemeConstants.grey500),
                        ),
                        if (due.isNotEmpty && !summary.isPaid)
                          Text('الاستحقاق: $due',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: summary.isOverdue
                                      ? AppThemeConstants.error
                                      : AppThemeConstants.grey500)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${summary.commissionAmount.toStringAsFixed(2)} ج.م',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _statusColor)),
                      Text(_statusLabel,
                          style: TextStyle(fontSize: 11, color: _statusColor)),
                    ],
                  ),
                ],
              ),
              if (summary.isAwaitingConfirmation) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.accentBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary.paymentMethod != null)
                        Text('الطريقة: ${_methodLabel(summary.paymentMethod!)}',
                            style: const TextStyle(fontSize: 12)),
                      if (summary.paymentReference != null &&
                          summary.paymentReference!.isNotEmpty)
                        Text('المرجع: ${summary.paymentReference}',
                            style: const TextStyle(fontSize: 12)),
                      if (summary.reportedAmount != null)
                        Text(
                            'المبلغ المُعلَن: ${summary.reportedAmount!.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
              if (showActionButton) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isMarkingPaid ? null : onReview,
                    icon: isMarkingPaid
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppThemeConstants.white,
                            ),
                          )
                        : const Icon(Icons.fact_check_outlined, size: 16),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeConstants.primary,
                      foregroundColor: AppThemeConstants.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _methodLabel(String value) => switch (value) {
        'instapay' => 'إنستاباي',
        'vodafonecash' => 'فودافون كاش',
        'orangemoney' => 'أورنج موني',
        'etisalatcash' => 'اتصالات كاش',
        'wepay' => 'WE Pay',
        'bank' => 'تحويل بنكي',
        _ => value,
      };
}

class _CommissionReviewDialog extends StatefulWidget {
  final WeeklyCommissionSummary summary;
  final Future<void> Function(double? paidAmount, String? adminNote) onConfirm;
  final Future<void> Function(String reason) onReject;

  const _CommissionReviewDialog({
    required this.summary,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  State<_CommissionReviewDialog> createState() =>
      _CommissionReviewDialogState();
}

class _CommissionReviewDialogState extends State<_CommissionReviewDialog> {
  late final TextEditingController _amountController;
  final _adminNoteController = TextEditingController();
  final _rejectReasonController = TextEditingController();
  bool _showRejectForm = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.summary.reportedAmount ?? widget.summary.commissionAmount;
    _amountController = TextEditingController(text: initial.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _adminNoteController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final raw = _amountController.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('أدخل مبلغ صحيح'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    await widget.onConfirm(
      parsed,
      _adminNoteController.text.trim().isEmpty
          ? null
          : _adminNoteController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _handleReject() async {
    final reason = _rejectReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.error,
          content: Text('اكتب سبب الرفض'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    await widget.onReject(reason);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        title: Text('مراجعة عمولة الأسبوع ${s.weekNumber}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _kv('المحفظ', s.mohaffezName),
                _kv('المبلغ المتوقع',
                    '${s.commissionAmount.toStringAsFixed(2)} ج.م'),
                if (s.paymentMethod != null)
                  _kv('طريقة التحويل',
                      _WeekSummaryCard._methodLabel(s.paymentMethod!)),
                if (s.paymentReference != null &&
                    s.paymentReference!.isNotEmpty)
                  _kv('رقم المرجع', s.paymentReference!),
                if (s.reportedAmount != null)
                  _kv('المبلغ الذي أعلنه المحفظ',
                      '${s.reportedAmount!.toStringAsFixed(2)} ج.م'),
                if (s.mohaffezNote != null && s.mohaffezNote!.isNotEmpty)
                  _kv('ملاحظة المحفظ', s.mohaffezNote!),
                if (s.mohaffezReportedAt != null)
                  _kv('تم الإرسال في',
                      formatDateTimeToArabicAmPm(s.mohaffezReportedAt!)),
                const Divider(height: 24),
                if (!_showRejectForm) ...[
                  const Text('المبلغ المُستلَم فعلياً:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      suffixText: 'ج.م',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _adminNoteController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة الإدارة (اختياري)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ] else ...[
                  const Text('سبب رفض الدفعة:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppThemeConstants.error)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rejectReasonController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'مثال: لم نستلم المبلغ، رقم المرجع غير صحيح…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          if (!_showRejectForm) ...[
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _showRejectForm = true),
              style: TextButton.styleFrom(
                foregroundColor: AppThemeConstants.error,
              ),
              child: const Text('رفض الدفعة'),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _handleConfirm,
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppThemeConstants.white),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('تأكيد الاستلام'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.success,
                foregroundColor: AppThemeConstants.white,
              ),
            ),
          ] else ...[
            TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _showRejectForm = false),
              child: const Text('رجوع'),
            ),
            ElevatedButton(
              onPressed: _busy ? null : _handleReject,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeConstants.error,
                foregroundColor: AppThemeConstants.white,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppThemeConstants.white),
                    )
                  : const Text('تأكيد الرفض'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(
                      color: AppThemeConstants.grey600, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
            ),
          ],
        ),
      );
}
