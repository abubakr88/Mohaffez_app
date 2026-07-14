import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

import '../../../design_system/design_system.dart';
import 'admin_payment_formatters.dart';

class AdminPaymentsPage extends ConsumerStatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  ConsumerState<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends ConsumerState<AdminPaymentsPage> {
  static const _pageSize = 50;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _paymentDocs = [];
  String _query = '';
  String? _statusFilter;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadPayments(reset: true));
  }

  Future<void> _loadPayments({required bool reset}) async {
    if (_loadingMore || (!reset && !_hasMore)) return;
    setState(() {
      if (reset) {
        _loading = true;
        _loadError = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (!reset && _paymentDocs.isNotEmpty) {
        query = query.startAfterDocument(_paymentDocs.last);
      }
      final snapshot = await query.get();
      if (!mounted) return;
      setState(() {
        if (reset) _paymentDocs.clear();
        _paymentDocs.addAll(snapshot.docs);
        _hasMore = snapshot.docs.length == _pageSize;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _payments {
    final normalizedQuery = _query.trim().toLowerCase();
    return _paymentDocs
        .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
        .where((payment) {
      final status = '${payment['status'] ?? ''}'.toLowerCase();
      if (_statusFilter != null && status != _statusFilter) return false;
      if (normalizedQuery.isEmpty) return true;
      final metadata = adminMap(payment['metadata']);
      final values = <dynamic>[
        payment['id'],
        payment['studentName'],
        payment['mohaffezName'],
        payment['planTitle'],
        payment['studentId'],
        payment['mohaffezId'],
        adminTransactionReference(payment),
        metadata['requestId'],
        metadata['studentProfileName'],
      ];
      return values.any(
        (value) => '$value'.toLowerCase().contains(normalizedQuery),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final failedAsync = ref.watch(failedOperationsProvider);
    final metricsAsync = ref.watch(adminMetricsStreamProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'مراقبة المدفوعات',
            subtitle: 'معاملات مقروءة، أوقات دقيقة، ومتابعة العمليات الفاشلة',
            actions: [
              DSButton(
                label: 'تحديث المعاملات',
                onPressed: _loading ? null : () => _loadPayments(reset: true),
                variant: DSButtonVariant.secondary,
                leading: const Icon(Icons.refresh_rounded, size: 17),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          metricsAsync.maybeWhen(
            data: (metrics) => DSBanner(
              title: 'مصدر البيانات وتكلفته',
              message: metrics.generatedAt == null
                  ? 'المؤشرات مجمعة مسبقاً، والمعاملات تحمل على دفعات من 50 سجلاً فقط.'
                  : 'المؤشرات مجمعة مسبقاً وآخر تحديث لها ${adminExactTimestamp(metrics.generatedAt)}. المعاملات تحمل على دفعات من 50 سجلاً فقط.',
              variant: DSBannerVariant.info,
            ),
            orElse: () => const DSBanner(
              message:
                  'المعاملات تحمل على دفعات من 50 سجلاً فقط لتقليل قراءات Firestore.',
            ),
          ),
          const SizedBox(height: DSSpacing.xxl),
          metricsAsync.when(
            loading: () => const _SkeletonRow(),
            error: (error, _) => DSBanner(
              message: '$error',
              variant: DSBannerVariant.error,
            ),
            data: (metrics) => _MetricsSection(metrics: metrics),
          ),
          const SizedBox(height: DSSpacing.xxl),
          const SectionHeader(title: 'أحدث المعاملات'),
          const SizedBox(height: DSSpacing.md),
          Wrap(
            spacing: DSSpacing.md,
            runSpacing: DSSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: DSSearchField(
                  hint: 'اسم الطالب أو المحفظ أو رقم العملية',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SizedBox(
                width: 210,
                child: DSSelect<String?>(
                  hint: 'كل الحالات',
                  value: _statusFilter,
                  items: const [
                    DSSelectItem<String?>(label: 'كل الحالات', value: null),
                    DSSelectItem<String?>(
                        label: 'قيد الانتظار', value: 'pending'),
                    DSSelectItem<String?>(
                        label: 'قيد المعالجة', value: 'processing'),
                    DSSelectItem<String?>(label: 'مكتملة', value: 'completed'),
                    DSSelectItem<String?>(label: 'فشلت', value: 'failed'),
                    DSSelectItem<String?>(label: 'مستردة', value: 'refunded'),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
              Text(
                'المحمّل: ${_paymentDocs.length} معاملة',
                style: DSText.caption(context, color: DSColors.text3),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          if (_loading)
            const DSSkeletonCard()
          else if (_loadError != null)
            DSBanner(
              title: 'تعذر تحميل المعاملات',
              message:
                  '$_loadError\nتأكد من نشر قواعد Firestore التي تسمح لصلاحية الإدارة المالية بقراءة payments.',
              variant: DSBannerVariant.error,
              action: DSButton(
                label: 'إعادة المحاولة',
                onPressed: () => _loadPayments(reset: true),
                size: DSButtonSize.sm,
              ),
            )
          else if (_payments.isEmpty)
            const DSCard(
              child: DSEmptyState(
                title: 'لا توجد معاملات مطابقة',
                subtitle: 'غيّر البحث أو الحالة لعرض نتائج أخرى',
                icon: Icons.receipt_long_outlined,
              ),
            )
          else
            _PaymentsTable(
              payments: _payments,
              onOpen: (payment) => _showPaymentDetails(context, payment),
            ),
          if (!_loading && _hasMore) ...[
            const SizedBox(height: DSSpacing.lg),
            Center(
              child: DSButton(
                label: 'تحميل 50 معاملة أخرى',
                onPressed:
                    _loadingMore ? null : () => _loadPayments(reset: false),
                loading: _loadingMore,
                variant: DSButtonVariant.secondary,
                leading: const Icon(Icons.expand_more_rounded, size: 18),
              ),
            ),
          ],
          const SizedBox(height: DSSpacing.xxl),
          failedAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (error, _) => DSBanner(
              message: '$error',
              variant: DSBannerVariant.error,
            ),
            data: (operations) => _FailedOperations(operations: operations),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentDetails(
    BuildContext context,
    Map<String, dynamic> payment,
  ) async {
    final metadata = adminMap(payment['metadata']);
    final reference = adminTransactionReference(payment);
    final paymentId = '${payment['id'] ?? '—'}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تفاصيل المعاملة'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailLine(
                    label: 'الحالة',
                    value:
                        adminPaymentStatusLabel('${payment['status'] ?? ''}')),
                _DetailLine(
                    label: 'المبلغ',
                    value: adminMoney(
                        payment['amount'], '${payment['currency'] ?? 'EGP'}')),
                _DetailLine(
                    label: 'وسيلة الدفع',
                    value: adminPaymentMethodLabel(payment)),
                _DetailLine(
                    label: 'الطالب', value: '${payment['studentName'] ?? '—'}'),
                _DetailLine(
                    label: 'المحفظ',
                    value: '${payment['mohaffezName'] ?? '—'}'),
                _DetailLine(
                    label: 'الخطة', value: '${payment['planTitle'] ?? '—'}'),
                _DetailLine(
                    label: 'نوع الخطة',
                    value: adminPlanTypeLabel(
                        payment['planType'] ?? metadata['planType'])),
                _DetailLine(
                    label: 'وقت الإنشاء',
                    value: adminExactTimestamp(payment['createdAt'])),
                _DetailLine(
                    label: 'وقت الدفع',
                    value: adminExactTimestamp(
                        payment['paidAt'] ?? payment['completedAt'])),
                _DetailLine(
                    label: 'آخر تحديث',
                    value: adminExactTimestamp(payment['updatedAt'])),
                _CopyDetailLine(label: 'Payment ID', value: paymentId),
                _CopyDetailLine(label: 'مرجع البوابة', value: reference),
                if ('${metadata['requestId'] ?? ''}'.isNotEmpty)
                  _CopyDetailLine(
                      label: 'Request ID', value: '${metadata['requestId']}'),
                if ('${payment['subscriptionId'] ?? ''}'.isNotEmpty)
                  _CopyDetailLine(
                      label: 'Subscription ID',
                      value: '${payment['subscriptionId']}'),
                if ('${payment['sessionId'] ?? ''}'.isNotEmpty)
                  _CopyDetailLine(
                      label: 'Session ID', value: '${payment['sessionId']}'),
                if ('${payment['failureReason'] ?? ''}'.isNotEmpty)
                  _DetailLine(
                      label: 'سبب الفشل',
                      value: '${payment['failureReason']}',
                      valueColor: DSColors.error),
                const SizedBox(height: DSSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(adminBrowserTimezoneLabel(),
                      style:
                          DSText.caption(dialogContext, color: DSColors.text3)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          DSButton(
            label: 'إغلاق',
            onPressed: () => Navigator.of(dialogContext).pop(),
            variant: DSButtonVariant.ghost,
          ),
        ],
      ),
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.payments, required this.onOpen});

  final List<Map<String, dynamic>> payments;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    return DSDataTable<Map<String, dynamic>>(
      initialSortKey: 'time',
      initialSortAsc: false,
      onRowTap: onOpen,
      columns: [
        DSColumnDef(
          key: 'status',
          label: 'الحالة',
          width: 125,
          cellBuilder: (ctx, payment) {
            final status = '${payment['status'] ?? ''}';
            return DSBadge(
              label: adminPaymentStatusLabel(status),
              variant: adminPaymentStatusVariant(status),
            );
          },
        ),
        DSColumnDef(
          key: 'parties',
          label: 'الطالب / المحفظ',
          cellBuilder: (ctx, payment) => _TwoLineCell(
            primary: '${payment['studentName'] ?? 'طالب غير محدد'}',
            secondary: '${payment['mohaffezName'] ?? 'محفظ غير محدد'}',
          ),
        ),
        DSColumnDef(
          key: 'plan',
          label: 'الخطة',
          cellBuilder: (ctx, payment) => _TwoLineCell(
            primary: '${payment['planTitle'] ?? '—'}',
            secondary: adminPlanTypeLabel(
              payment['planType'] ?? adminMap(payment['metadata'])['planType'],
            ),
          ),
        ),
        DSColumnDef(
          key: 'amount',
          label: 'المبلغ',
          width: 125,
          sortable: true,
          sortValue: (payment) => (payment['amount'] as num?) ?? 0,
          cellBuilder: (ctx, payment) => Text(
            adminMoney(payment['amount'], '${payment['currency'] ?? 'EGP'}'),
            style: DSText.bodyMedium(ctx),
          ),
        ),
        DSColumnDef(
          key: 'method',
          label: 'الوسيلة',
          width: 145,
          cellBuilder: (ctx, payment) => Text(
            adminPaymentMethodLabel(payment),
            style: DSText.body(ctx, color: DSColors.text2),
          ),
        ),
        DSColumnDef(
          key: 'time',
          label: 'وقت العملية',
          width: 205,
          sortable: true,
          sortValue: (payment) =>
              adminPaymentDate(_operationTime(payment)) ?? DateTime(1970),
          cellBuilder: (ctx, payment) => _TwoLineCell(
            primary: adminExactTimestamp(_operationTime(payment)),
            secondary: _operationTimeLabel(payment),
          ),
        ),
        DSColumnDef(
          key: 'reference',
          label: 'مرجع العملية',
          cellBuilder: (ctx, payment) {
            final reference = adminTransactionReference(payment);
            return Tooltip(
              message: reference,
              child: Text(
                adminShortId(reference),
                style: DSText.body(ctx, color: DSColors.text2),
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ],
      rows: payments,
    );
  }
}

dynamic _operationTime(Map<String, dynamic> payment) =>
    payment['paidAt'] ??
    payment['completedAt'] ??
    payment['updatedAt'] ??
    payment['createdAt'];

String _operationTimeLabel(Map<String, dynamic> payment) {
  if (payment['paidAt'] != null || payment['completedAt'] != null) {
    return 'وقت الدفع الفعلي';
  }
  if (payment['updatedAt'] != null) return 'آخر تحديث';
  return 'وقت الإنشاء';
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.metrics});

  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          children: [
            DSStatCard(
              label: 'إيرادات هذا الشهر',
              value: _money(metrics.revenue.thisMonth),
              trend:
                  _delta(metrics.revenue.thisMonth, metrics.revenue.lastMonth),
              trendPositive:
                  metrics.revenue.thisMonth >= metrics.revenue.lastMonth,
              icon: Icons.trending_up_rounded,
              iconColor: DSColors.success,
            ),
            DSStatCard(
              label: 'إيرادات الشهر السابق',
              value: _money(metrics.revenue.lastMonth),
              icon: Icons.history_rounded,
              iconColor: DSColors.primary,
            ),
            DSStatCard(
              label: 'مستحقات معلقة',
              value: _money(metrics.commissions.outstanding),
              trend: metrics.commissions.overdue > 0
                  ? 'متأخرات: ${_money(metrics.commissions.overdue)}'
                  : 'لا توجد متأخرات',
              trendPositive: metrics.commissions.overdue == 0,
              icon: Icons.payments_outlined,
              iconColor: metrics.commissions.overdue > 0
                  ? DSColors.error
                  : DSColors.warning,
            ),
            DSStatCard(
              label: 'بانتظار التأكيد',
              value: _money(metrics.commissions.pendingVerification),
              icon: Icons.fact_check_outlined,
              iconColor: DSColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.xxl),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          children: [
            _BreakdownCard(
                title: 'الإيرادات حسب الوسيلة (الشهر)',
                values: metrics.revenue.byMethod,
                labelOf: _methodLabel),
            _BreakdownCard(
                title: 'الإيرادات حسب نوع الباقة (الشهر)',
                values: metrics.revenue.byType,
                labelOf: adminPlanTypeLabel),
          ],
        ),
      ],
    );
  }
}

class _FailedOperations extends StatelessWidget {
  const _FailedOperations({required this.operations});

  final List<Map<String, dynamic>> operations;

  @override
  Widget build(BuildContext context) {
    if (operations.isEmpty) {
      return const DSCard(
        child: DSEmptyState(
          title: 'لا توجد عمليات فاشلة',
          subtitle: 'جميع عمليات الدفع تعمل بشكل طبيعي',
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'العمليات الفاشلة'),
        const SizedBox(height: DSSpacing.md),
        DSDataTable<Map<String, dynamic>>(
          columns: [
            DSColumnDef(
              key: 'type',
              label: 'النوع',
              cellBuilder: (ctx, operation) => Text(
                '${operation['type'] ?? operation['operationType'] ?? '—'}',
                style: DSText.body(ctx),
              ),
            ),
            DSColumnDef(
              key: 'error',
              label: 'الخطأ',
              cellBuilder: (ctx, operation) => Text(
                '${operation['error'] ?? operation['errorMessage'] ?? '—'}',
                style: DSText.body(ctx, color: DSColors.error),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DSColumnDef(
              key: 'date',
              label: 'الوقت الدقيق',
              width: 205,
              cellBuilder: (ctx, operation) => Text(
                adminExactTimestamp(
                    operation['timestamp'] ?? operation['createdAt']),
                style: DSText.body(ctx, color: DSColors.text2),
              ),
            ),
          ],
          rows: operations,
        ),
      ],
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.primary, required this.secondary});

  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(primary,
            style: DSText.bodyMedium(context), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(secondary,
            style: DSText.caption(context, color: DSColors.text3),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(
      {required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 145,
              child: Text(label,
                  style: DSText.caption(context, color: DSColors.text3))),
          Expanded(
              child: Text(value,
                  style: DSText.body(context,
                      color: valueColor ?? DSColors.text1))),
        ],
      ),
    );
  }
}

class _CopyDetailLine extends StatelessWidget {
  const _CopyDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DSSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 145,
              child: Text(label,
                  style: DSText.caption(context, color: DSColors.text3))),
          Expanded(child: SelectableText(value, style: DSText.body(context))),
          IconButton(
            tooltip: 'نسخ',
            onPressed: value == '—'
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم النسخ')));
                  },
            icon: const Icon(Icons.copy_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const DSGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      children: [
        DSSkeletonCard(),
        DSSkeletonCard(),
        DSSkeletonCard(),
        DSSkeletonCard()
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard(
      {required this.title, required this.values, required this.labelOf});

  final String title;
  final Map<String, double> values;
  final String Function(String) labelOf;

  @override
  Widget build(BuildContext context) {
    final total = values.values
        .fold<double>(0, (totalValue, value) => totalValue + value);
    final entries = values.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: DSSpacing.lg),
          if (entries.isEmpty)
            const DSEmptyState(
                title: 'لا توجد إيرادات هذا الشهر',
                icon: Icons.bar_chart_rounded)
          else
            ...entries.map((entry) {
              final percentage =
                  total == 0 ? 0.0 : (entry.value / total).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: DSSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(labelOf(entry.key),
                            style: DSText.bodyMedium(context)),
                        Text(_money(entry.value),
                            style: DSText.bodyMedium(context)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    DSProgressBar(value: percentage, color: DSColors.primary),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

String _money(double value) =>
    '${NumberFormat.decimalPattern('ar').format(value.round())} ج.م';

String _delta(double current, double previous) {
  if (previous == 0) return current > 0 ? 'بداية جديدة' : '';
  final percentage = ((current - previous) / previous * 100).round();
  return percentage >= 0
      ? '▲ $percentage% عن السابق'
      : '▼ ${percentage.abs()}% عن السابق';
}

String _methodLabel(String key) => switch (key) {
      'paymob' => 'بطاقة (Paymob)',
      'wallet' => 'محفظة التطبيق',
      'instapay' => 'InstaPay',
      'vodafonecash' || 'vodafone_cash' => 'Vodafone Cash',
      'orangemoney' || 'orange_money' => 'Orange Money',
      'etisalatcash' || 'etisalat_cash' => 'Etisalat Cash',
      'wepay' => 'WE Pay',
      'cash' || 'direct' => 'دفع مباشر',
      'free' => 'كوبون مجاني',
      'unknown' => 'غير محدد',
      _ => key,
    };
