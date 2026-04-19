import 'dart:ui' as ui;
import 'package:cloud_functions/cloud_functions.dart'; // FIXED: FIX-COMMISSION — added for CF call
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_theme_constants.dart';
import '../../models/direct_payment_model.dart';
import '../../providers/system_config_provider.dart';
import '../../services/direct_payment_service.dart';


class MohaffezCommissionScreen extends ConsumerStatefulWidget {
  final String mohaffezId;

  const MohaffezCommissionScreen({
    super.key,
    required this.mohaffezId,
  });

  @override
  ConsumerState<MohaffezCommissionScreen> createState() =>
      _MohaffezCommissionScreenState();
}

class _MohaffezCommissionScreenState
    extends ConsumerState<MohaffezCommissionScreen> {
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
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => context.pop(),
                  tooltip: 'رجوع',
                )
              : null,
          title: const Text('مستحقات المنصة'),
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.onPrimary,
        ),
        body: StreamBuilder<List<WeeklyCommissionSummary>>(
          stream: DirectPaymentService.watchCommissions(widget.mohaffezId),
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

            final totalPending = list
                .where((w) => w.isPending || w.isOverdue)
                .fold(0.0, (s, w) => s + w.commissionAmount);

            return Column(children: [
              // Summary card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: totalPending > 0
                        ? [AppThemeConstants.warning, AppThemeConstants.warning.withValues(alpha: 0.6)]
                        : [AppThemeConstants.success, AppThemeConstants.success.withValues(alpha: 0.6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text(
                    totalPending > 0
                        ? 'إجمالي المستحق للمنصة'
                        : 'لا يوجد مستحقات 🎉',
                    style: TextStyle(
                      color: AppThemeConstants.onPrimary.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
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
                  Text('معدل العمولة: ${(commissionRate * 100).toInt()}%',
                      style: TextStyle(color: AppThemeConstants.onPrimary.withValues(alpha: 0.7), fontSize: 12)),
                ]),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _MohaffezWeekSummaryCard(
                    summary: list[i],
                    mohaffezId: widget.mohaffezId,
                    onPayNow: () => _showPayNowSheet(context, list[i]),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  void _showPayNowSheet(
      BuildContext context, WeeklyCommissionSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PayNowSheet(
        summary: summary,
        mohaffezId: widget.mohaffezId,
      ),
    );
  }
}


class _MohaffezWeekSummaryCard extends StatelessWidget {
  final WeeklyCommissionSummary summary;
  final String mohaffezId;
  final VoidCallback onPayNow;

  const _MohaffezWeekSummaryCard({
    required this.summary,
    required this.mohaffezId,
    required this.onPayNow,
  });

  Color get _statusColor => switch (summary.status) {
        'paid' => Colors.green,
        'overdue' => Colors.red,
        'awaiting_confirmation' => Colors.blue,
        _ => Colors.orange,
      };

  String get _statusLabel => switch (summary.status) {
        'paid' => 'مدفوع',
        'overdue' => 'متأخر',
        'awaiting_confirmation' => 'بانتظار التأكيد',
        _ => 'قيد الانتظار',
      };

  @override
  Widget build(BuildContext context) {
    final weekLabel = summary.weekStart != null
        ? 'الأسبوع ${summary.weekNumber} — ${DateFormat('yyyy', 'ar').format(summary.weekStart!)}'
        : 'الأسبوع ${summary.weekNumber}';
    final due = summary.dueDate != null
        ? DateFormat('dd/MM/yyyy', 'ar').format(summary.dueDate!)
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  weekLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _statusColor),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    label: 'الجلسات',
                    value: '${summary.totalSessions}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    label: 'الإجمالي',
                    value:
                        '${summary.totalRevenue.toStringAsFixed(0)} ج.م',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (due.isNotEmpty)
                  Text(
                    'الاستحقاق: $due',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          summary.isOverdue ? Colors.red : Colors.grey,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  '${summary.commissionAmount.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ],
            ),
            if (summary.isActionable) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: onPayNow,
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('ادفع الآن', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            if (summary.isAwaitingConfirmation)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top,
                        size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'في انتظار تأكيد الأدمن',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}


class _PayNowSheet extends StatefulWidget {
  final WeeklyCommissionSummary summary;
  final String mohaffezId;

  const _PayNowSheet({
    required this.summary,
    required this.mohaffezId,
  });

  @override
  State<_PayNowSheet> createState() => _PayNowSheetState();
}

class _PayNowSheetState extends State<_PayNowSheet> {
  final _noteController = TextEditingController();
  bool _isLoading = false;
  Map<String, String?> _adminWallets = {};

  @override
  void initState() {
    super.initState();
    _loadAdminWallets();
  }

  Future<void> _loadAdminWallets() async {
    try {
      final wallets =
          await DirectPaymentService.getAdminWalletNumbers();
      if (mounted) {
        setState(() => _adminWallets = wallets);
      }
    } catch (_) {
      // Silently ignore — wallets section just stays empty
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekLabel = widget.summary.weekStart != null
        ? 'الأسبوع ${widget.summary.weekNumber} — ${DateFormat('yyyy', 'ar').format(widget.summary.weekStart!)}'
        : 'الأسبوع ${widget.summary.weekNumber}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'تسديد مستحقات المنصة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$weekLabel — ${widget.summary.commissionAmount.toStringAsFixed(2)} ج.م',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Info container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'يرجى تحويل المبلغ المستحق إلى حساب المنصة عبر إحدى وسائل الدفع التالية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Admin wallets
              if (_adminWallets.isNotEmpty) ...[
                ..._adminWallets.entries
                    .where(
                        (e) => e.value != null && e.value!.isNotEmpty)
                    .map((entry) => _WalletTile(
                          method: entry.key,
                          value: entry.value!,
                        )),
                const SizedBox(height: 16),
              ],

              // Amount chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppThemeConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemeConstants.primary),
                ),
                child: Text(
                  'المبلغ المستحق: ${widget.summary.commissionAmount.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note field
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeConstants.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'تأكيد إرسال الدفعة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED: FIX-COMMISSION
  // ROOT CAUSE: DirectPaymentService.notifyAdminOfCommissionPayment was doing
  // a client-side batch write that included weeklyCommissionSummaries
  // (allow write: if false) alongside a notifications write. Firestore
  // rejected the entire batch and surfaced the error on the notifications path.
  //
  // FIX: Call the mohaffezReportCommissionPayment Cloud Function directly.
  // Admin SDK inside the CF bypasses security rules entirely.
  Future<void> _submitPayment() async {
    setState(() => _isLoading = true);
    try {
      // FIXED: FIX-COMMISSION — replaced broken client batch with CF call
      final callable = FirebaseFunctions.instance
          .httpsCallable('mohaffezReportCommissionPayment');

      await callable.call({
        'weeklyCommissionSummaryId': widget.summary.id,
        'note': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      });

      if (!mounted) return; // FIXED: FIX-1 — mounted guard after await
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppThemeConstants.success,
          content: Text('تم إرسال تأكيد الدفع، سيتم المراجعة قريباً'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      // FIXED: FIX-COMMISSION — surface CF-specific error codes clearly
      if (!mounted) return;
      final message = switch (e.code) {
        'not-found' => 'لم يتم العثور على سجل العمولة',
        'permission-denied' => 'غير مصرح لك بهذه العملية',
        'already-exists' => 'تم إرسال الدفع مسبقاً',
        _ => 'خطأ: ${e.message ?? e.code}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return; // FIXED: FIX-1 — mounted guard in catch
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('خطأ: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}


class _WalletTile extends StatelessWidget {
  final String method;
  final String value;

  const _WalletTile({
    required this.method,
    required this.value,
  });

  IconData get _icon => switch (method) {
        'instapay' => Icons.send,
        'vodafonecash' => Icons.phone_android,
        'orangemoney' => Icons.phone_android,
        _ => Icons.account_balance,
      };

  String get _label => switch (method) {
        'instapay' => 'إنستاباي',
        'vodafonecash' => 'فودافون كاش',
        'orangemoney' => 'أورنج موني',
        _ => method,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_icon, color: AppThemeConstants.primary),
        title: Text(_label),
        subtitle: Text(value),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 20),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم نسخ $value'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}


