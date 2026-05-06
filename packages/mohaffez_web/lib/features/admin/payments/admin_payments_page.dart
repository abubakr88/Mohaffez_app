import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedAsync = ref.watch(failedOperationsProvider);
    final metricsAsync = ref.watch(adminMetricsStreamProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'المدفوعات',
            subtitle: 'الإيرادات، عمولات المحفظين، والعمليات الفاشلة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          metricsAsync.when(
            loading: () => const _SkeletonRow(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (m) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DSGrid(
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 4,
                  children: [
                    DSStatCard(
                      label: 'إيرادات هذا الشهر',
                      value: _money(m.revenue.thisMonth),
                      trend: _delta(m.revenue.thisMonth, m.revenue.lastMonth),
                      trendPositive:
                          m.revenue.thisMonth >= m.revenue.lastMonth,
                      icon: Icons.trending_up_rounded,
                      iconColor: DSColors.success,
                    ),
                    DSStatCard(
                      label: 'إيرادات الشهر السابق',
                      value: _money(m.revenue.lastMonth),
                      icon: Icons.history_rounded,
                      iconColor: DSColors.primary,
                    ),
                    DSStatCard(
                      label: 'مستحقات معلقة',
                      value: _money(m.commissions.outstanding),
                      trend: m.commissions.overdue > 0
                          ? 'متأخرات: ${_money(m.commissions.overdue)}'
                          : 'لا توجد متأخرات',
                      trendPositive: m.commissions.overdue == 0,
                      icon: Icons.payments_outlined,
                      iconColor: m.commissions.overdue > 0
                          ? DSColors.error
                          : DSColors.warning,
                    ),
                    DSStatCard(
                      label: 'بانتظار التأكيد',
                      value: _money(m.commissions.pendingVerification),
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
                      values: m.revenue.byMethod,
                      labelOf: _methodLabel,
                    ),
                    _BreakdownCard(
                      title: 'الإيرادات حسب نوع الباقة (الشهر)',
                      values: m.revenue.byType,
                      labelOf: _typeLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DSSpacing.xxl),
          failedAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (ops) {
              if (ops.isEmpty) {
                return const DSCard(
                  child: DSEmptyState(
                    title: 'لا توجد عمليات فاشلة',
                    subtitle: 'جميع عمليات الدفع تعمل بشكل طبيعي',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                );
              }
              return DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'العمليات الفاشلة'),
                    const SizedBox(height: DSSpacing.lg),
                    DSDataTable<Map<String, dynamic>>(
                      columns: [
                        DSColumnDef(
                          key: 'type',
                          label: 'النوع',
                          cellBuilder: (ctx, op) => Text(
                            op['type'] as String? ??
                                op['operationType'] as String? ??
                                '—',
                            style: DSText.body(ctx),
                          ),
                        ),
                        DSColumnDef(
                          key: 'error',
                          label: 'الخطأ',
                          cellBuilder: (ctx, op) => Text(
                            op['error'] as String? ??
                                op['errorMessage'] as String? ??
                                '—',
                            style: DSText.body(ctx, color: DSColors.error),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DSColumnDef(
                          key: 'date',
                          label: 'التاريخ',
                          width: 140,
                          cellBuilder: (ctx, op) {
                            final d = op['timestamp'] ?? op['createdAt'];
                            if (d == null) {
                              return Text('—',
                                  style: DSText.body(ctx,
                                      color: DSColors.text2));
                            }
                            try {
                              final dt = d is DateTime
                                  ? d
                                  : (d as dynamic).toDate() as DateTime;
                              return Text(
                                  DateFormat('dd/MM/yyyy', 'ar').format(dt),
                                  style: DSText.body(ctx,
                                      color: DSColors.text2));
                            } catch (_) {
                              return Text('—',
                                  style: DSText.body(ctx,
                                      color: DSColors.text2));
                            }
                          },
                        ),
                      ],
                      rows: ops,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _money(double v) =>
      '${NumberFormat.decimalPattern('ar').format(v.round())} ج.م';

  static String _delta(double current, double previous) {
    if (previous == 0) return current > 0 ? 'بداية جديدة' : '';
    final pct = ((current - previous) / previous * 100).round();
    if (pct >= 0) return '▲ $pct% عن السابق';
    return '▼ ${pct.abs()}% عن السابق';
  }

  static String _methodLabel(String key) => switch (key) {
        'paymob' => 'بطاقة (Paymob)',
        'instapay' => 'إنستاباي',
        'vodafonecash' => 'فودافون كاش',
        'orangemoney' => 'أورنج موني',
        'etisalatcash' => 'اتصالات كاش',
        'wepay' => 'WE Pay',
        'cash' => 'نقدي',
        'unknown' => 'غير محدّد',
        _ => key,
      };

  static String _typeLabel(String key) => switch (key) {
        'single' => 'جلسة فردية',
        'bundle' => 'باقة',
        'subscription' => 'اشتراك',
        _ => key,
      };
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
        DSSkeletonCard(),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final Map<String, double> values;
  final String Function(String) labelOf;

  const _BreakdownCard({
    required this.title,
    required this.values,
    required this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    final total = values.values.fold<double>(0, (s, v) => s + v);
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: DSSpacing.lg),
          if (entries.isEmpty)
            const DSEmptyState(
              title: 'لا توجد إيرادات هذا الشهر',
              icon: Icons.bar_chart_rounded,
            )
          else
            ...entries.map((e) {
              final pct = total == 0 ? 0.0 : (e.value / total).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: DSSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(labelOf(e.key), style: DSText.bodyMedium(context)),
                        Text(
                          '${NumberFormat.decimalPattern('ar').format(e.value.round())} ج.م',
                          style: DSText.bodyMedium(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    DSProgressBar(value: pct, color: DSColors.primary),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
