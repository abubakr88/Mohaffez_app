import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../platform/web_download.dart';
import '../payments/admin_payment_formatters.dart';

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(adminMetricsStreamProvider);
    final insightsAsync = ref.watch(adminInsightsStreamProvider);
    final insights = insightsAsync.asData?.value;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeader(
                  title: 'التقارير',
                  subtitle: 'تحليلات الإيرادات والجلسات والمستخدمين',
                ),
              ),
              metricsAsync.maybeWhen(
                data: (m) => _ExportMenu(metrics: m, insights: insights),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          metricsAsync.when(
            loading: () => const _SkeletonGrid(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (m) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.generatedAt != null)
                  Text(
                    'آخر تحديث دقيق: ${adminExactTimestamp(m.generatedAt)} (${adminBrowserTimezoneLabel()})',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                const SizedBox(height: DSSpacing.md),
                DSBanner(
                  title: 'تقارير مجمعة منخفضة التكلفة',
                  message:
                      'هذه المؤشرات تقرأ مستندات ملخصة مسبقاً. راجع المعاملات أو مسار أحداث الدفع فقط عند التحقيق في عملية محددة.',
                  variant: DSBannerVariant.info,
                  action: Wrap(
                    spacing: DSSpacing.sm,
                    runSpacing: DSSpacing.sm,
                    children: [
                      DSButton(
                        label: 'مراقبة المعاملات',
                        onPressed: () => context.go('/admin/payments'),
                        size: DSButtonSize.sm,
                        variant: DSButtonVariant.secondary,
                        leading:
                            const Icon(Icons.receipt_long_outlined, size: 16),
                      ),
                      DSButton(
                        label: 'أحداث الدفع',
                        onPressed: () => context.go('/admin/payment-events'),
                        size: DSButtonSize.sm,
                        variant: DSButtonVariant.secondary,
                        leading: const Icon(Icons.timeline_rounded, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DSSpacing.xl),

                // Period comparison KPIs ─────────────────────────────────
                _ComparisonRow(metrics: m),
                const SizedBox(height: DSSpacing.xxl),

                _InsightsReport(
                  insights: insights,
                  loading: insightsAsync.isLoading,
                  hasError: insightsAsync.hasError,
                ),
                const SizedBox(height: DSSpacing.xxl),

                DSGrid(
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 3,
                  children: [
                    _UsersBreakdownCard(users: m.users),
                    _SessionsCard(sessions: m.sessions),
                    _SubscriptionsCard(subs: m.subscriptions),
                  ],
                ),
                const SizedBox(height: DSSpacing.xxl),
                _RevenueLineCard(months: m.revenue.last12Months),
                const SizedBox(height: DSSpacing.xxl),
                const _TopTeachersCard(),
                const SizedBox(height: DSSpacing.xxl),
                if (insights?.generatedAt != null)
                  _FinanceLedgerCard(finance: insights!.finance)
                else
                  const DSBanner(
                    message:
                        'سيظهر الملخص المالي المرصود بعد نشر دوال التحليلات وتحديث المؤشرات.',
                    variant: DSBannerVariant.info,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Export ────────────────────────────────────────────────────────────────
class _ExportMenu extends StatelessWidget {
  const _ExportMenu({required this.metrics, required this.insights});
  final AdminMetrics metrics;
  final AdminInsights? insights;

  String get _stamp => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _exportMonthly() {
    final csv = buildCsv(
      ['الشهر', 'الإيراد (ج.م)'],
      metrics.revenue.last12Months
          .map((m) => [m.month, m.total.round()])
          .toList(),
    );
    downloadCsv('mohafezy-revenue-$_stamp.csv', csv);
  }

  void _exportSummary() {
    final r = metrics.revenue;
    final s = metrics.sessions;
    final sub = metrics.subscriptions;
    final u = metrics.users;
    final finance = insights?.finance;
    final csv = buildCsv(
      ['المؤشر', 'القيمة'],
      [
        ['إيرادات هذا الشهر', r.thisMonth.round()],
        ['إيرادات الشهر السابق', r.lastMonth.round()],
        ['إيرادات السنة', r.ytd.round()],
        if (finance != null) ...[
          ['إجمالي المدفوعات المرصودة', finance.grossRevenueEgp],
          ['صافي المدفوعات المرصودة', finance.netRevenueEgp],
          ['استردادات مرصودة', finance.refundedAmountEgp],
          ['عمولة المنصة المرصودة', finance.commissionAccruedEgp],
          ['عكس عمولة مرصود', finance.commissionReversedEgp],
          ['شحن محافظ مرصود', finance.walletTopUpsEgp],
        ],
        ['جلسات منجزة (الشهر)', s.completedThisMonth],
        ['جلسات منجزة (الشهر السابق)', s.completedLastMonth],
        ['جلسات ملغاة (الشهر)', s.cancelledThisMonth],
        ['جلسات قيد الانتظار', s.pendingNow],
        ['اشتراكات نشطة', sub.active],
        ['اشتراكات ملغاة (الشهر)', sub.cancelledThisMonth],
        ['إجمالي الطلاب', u.totalStudents],
        ['إجمالي المحفظين', u.totalTeachers],
        ['محفظون نشطون (30 يوم)', u.activeTeachers30d],
        ['تسجيلات جديدة (الشهر)', u.newSignupsThisMonth],
        ['طلبات محفظ معلقة', u.pendingTeacherApprovals],
      ],
    );
    downloadCsv('mohafezy-summary-$_stamp.csv', csv);
  }

  void _exportInsights() {
    final value = insights;
    if (value == null || value.generatedAt == null) return;
    final growth = value.growth;
    final operations = value.operations;
    final finance = value.finance;
    final csv = buildCsv(
      ['المؤشر', 'القيمة'],
      [
        ['الفترة', value.period],
        ['تسجيلات جديدة', growth.signups],
        ['طلبات حجز', growth.requestsCreated],
        ['طلبات مقبولة', growth.requestsAccepted],
        ['دفعات مكتملة', growth.paymentsCompleted],
        ['جلسات مكتملة', growth.sessionsCompleted],
        ['عمليات فاشلة', operations.failedOperations],
        ['تنبيهات غير معالجة', operations.unresolvedAlerts],
        ['مدفوعات معلقة', operations.pendingPayments],
        ['تحويلات مباشرة معلقة', operations.pendingDirectPayments],
        ['إجمالي مدفوعات مرصودة', finance.grossRevenueEgp],
        ['صافي مدفوعات مرصودة', finance.netRevenueEgp],
        ['استردادات مرصودة', finance.refundedAmountEgp],
        ['عمولة منصة مرصودة', finance.commissionAccruedEgp],
        ['عكس عمولة مرصود', finance.commissionReversedEgp],
        ['شحن محافظ مرصود', finance.walletTopUpsEgp],
      ],
    );
    downloadCsv('mohafezy-insights-$_stamp.csv', csv);
  }

  @override
  Widget build(BuildContext context) {
    return DSDropdownMenu(
      items: [
        DSDropdownItem(
          label: 'ملخص شامل (CSV)',
          icon: Icons.summarize_outlined,
          onTap: _exportSummary,
        ),
        DSDropdownItem(
          label: 'الإيرادات الشهرية (CSV)',
          icon: Icons.show_chart_rounded,
          onTap: _exportMonthly,
        ),
        if (insights?.generatedAt != null)
          DSDropdownItem(
            label: 'مؤشرات التسويق والتشغيل (CSV)',
            icon: Icons.analytics_outlined,
            onTap: _exportInsights,
          ),
      ],
      child: DSButton(
        label: 'تصدير',
        size: DSButtonSize.sm,
        variant: DSButtonVariant.secondary,
        leading: const Icon(Icons.download_rounded, size: 16),
        onPressed: () {},
      ),
    );
  }
}

// ── Comparison KPIs ─────────────────────────────────────────────────────────
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.metrics});
  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final r = metrics.revenue;
    final s = metrics.sessions;
    return DSGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 4,
      children: [
        DSStatCard(
          label: 'إيرادات هذا الشهر',
          value: _money(r.thisMonth),
          trend: _delta(r.thisMonth, r.lastMonth),
          trendPositive: r.thisMonth >= r.lastMonth,
          icon: Icons.trending_up_rounded,
          iconColor: DSColors.success,
        ),
        DSStatCard(
          label: 'إيرادات السنة',
          value: _money(r.ytd),
          icon: Icons.calendar_today_rounded,
          iconColor: DSColors.primary,
        ),
        DSStatCard(
          label: 'جلسات منجزة (الشهر)',
          value: '${s.completedThisMonth}',
          trend: _intDelta(s.completedThisMonth, s.completedLastMonth),
          trendPositive: s.completedThisMonth >= s.completedLastMonth,
          icon: Icons.event_available_rounded,
          iconColor: DSColors.success,
        ),
        DSStatCard(
          label: 'اشتراكات نشطة',
          value: '${metrics.subscriptions.active}',
          icon: Icons.card_membership_outlined,
          iconColor: DSColors.secondary,
        ),
      ],
    );
  }

  static String _money(double v) =>
      '${NumberFormat.decimalPattern('ar').format(v.round())} ج.م';

  static String _delta(double current, double previous) {
    if (previous == 0) return current > 0 ? 'بداية جديدة' : '—';
    final pct = ((current - previous) / previous * 100).round();
    return pct >= 0 ? '▲ $pct% عن السابق' : '▼ ${pct.abs()}% عن السابق';
  }

  static String _intDelta(int current, int previous) {
    if (previous == 0) return current > 0 ? 'بداية جديدة' : '—';
    final diff = current - previous;
    return diff >= 0 ? '+$diff عن السابق' : '$diff عن السابق';
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return const DSGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 3,
      children: [DSSkeletonCard(), DSSkeletonCard(), DSSkeletonCard()],
    );
  }
}

class _InsightsReport extends StatelessWidget {
  const _InsightsReport({
    required this.insights,
    required this.loading,
    required this.hasError,
  });

  final AdminInsights? insights;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final value = insights;
    if (loading && value == null) {
      return const _SkeletonGrid();
    }
    if (hasError) {
      return const DSBanner(
        message: 'تعذر تحميل مؤشرات التسويق والتشغيل.',
        variant: DSBannerVariant.error,
      );
    }
    if (value == null || value.generatedAt == null) {
      return const DSBanner(
        message:
            'تبدأ مؤشرات التسويق والتشغيل في الظهور بعد نشر دوال التحليلات.',
        variant: DSBannerVariant.info,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'التسويق والأداء التشغيلي'),
        const SizedBox(height: DSSpacing.md),
        Text(
          'الفترة الحالية: ${value.period}',
          style: DSText.caption(context, color: DSColors.text3),
        ),
        const SizedBox(height: DSSpacing.lg),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          children: [
            _ConversionFunnelCard(growth: value.growth),
            _SignupBreakdownCard(growth: value.growth),
            _OperationalHealthCard(operations: value.operations),
          ],
        ),
      ],
    );
  }
}

class _ConversionFunnelCard extends StatelessWidget {
  const _ConversionFunnelCard({required this.growth});

  final GrowthInsights growth;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'مسار التحويل'),
          const SizedBox(height: DSSpacing.lg),
          _ProgressMetric(
            label: 'طلبات الحجز',
            count: growth.requestsCreated,
            value: growth.requestsCreated > 0 ? 1 : 0,
            color: DSColors.primary,
          ),
          _ProgressMetric(
            label: 'تم قبولها',
            count: growth.requestsAccepted,
            value: _ratio(
              growth.requestsAccepted,
              growth.requestsCreated,
            ),
            color: DSColors.success,
          ),
          _ProgressMetric(
            label: 'اكتمل دفعها',
            count: growth.paymentsCompleted,
            value: _ratio(
              growth.paymentsCompleted,
              growth.requestsAccepted,
            ),
            color: DSColors.secondary,
          ),
          _ProgressMetric(
            label: 'اكتملت جلساتها',
            count: growth.sessionsCompleted,
            value: _ratio(
              growth.sessionsCompleted,
              growth.paymentsCompleted,
            ),
            color: DSColors.success,
          ),
        ],
      ),
    );
  }
}

class _SignupBreakdownCard extends StatelessWidget {
  const _SignupBreakdownCard({required this.growth});

  final GrowthInsights growth;

  @override
  Widget build(BuildContext context) {
    final entries = growth.signupsByRole.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'التسجيلات الجديدة'),
          const SizedBox(height: DSSpacing.sm),
          Text(
            '${growth.signups} حساب خلال الفترة',
            style: DSText.caption(context, color: DSColors.text3),
          ),
          const SizedBox(height: DSSpacing.lg),
          if (entries.isEmpty)
            Text(
              'لا توجد تسجيلات مرصودة بعد.',
              style: DSText.body(context, color: DSColors.text3),
            )
          else
            ...entries.map(
              (entry) => _ProgressMetric(
                label: _roleLabel(entry.key),
                count: entry.value,
                value: _ratio(entry.value, growth.signups),
                color: _roleColor(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class _OperationalHealthCard extends StatelessWidget {
  const _OperationalHealthCard({required this.operations});

  final OperationsInsights operations;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المشكلات والمتابعة'),
          const SizedBox(height: DSSpacing.lg),
          _Row(
            label: 'عمليات فاشلة تحتاج متابعة',
            value: '${operations.failedOperations}',
            color: operations.failedOperations > 0 ? DSColors.error : null,
          ),
          _Row(
            label: 'تنبيهات غير معالجة',
            value: '${operations.unresolvedAlerts}',
            color: operations.unresolvedAlerts > 0 ? DSColors.warning : null,
          ),
          _Row(
            label: 'مدفوعات إلكترونية معلقة',
            value: '${operations.pendingPayments}',
            color: operations.pendingPayments > 0 ? DSColors.warning : null,
          ),
          _Row(
            label: 'تحويلات مباشرة معلقة',
            value: '${operations.pendingDirectPayments}',
            color:
                operations.pendingDirectPayments > 0 ? DSColors.warning : null,
          ),
          _Row(
            label: 'دفعات فاشلة هذا الشهر',
            value: '${operations.failedPaymentsThisMonth}',
            color:
                operations.failedPaymentsThisMonth > 0 ? DSColors.error : null,
          ),
          _Row(
            label: 'جلسات ملغاة هذا الشهر',
            value: '${operations.cancelledSessionsThisMonth}',
          ),
          _Row(
            label: 'غياب طالب / محفظ',
            value:
                '${operations.studentNoShowsThisMonth} / ${operations.teacherNoShowsThisMonth}',
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.count,
    required this.value,
    required this.color,
  });

  final String label;
  final int count;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.md),
      child: DSProgressBar(
        label: '$label ($count)',
        value: value.clamp(0, 1),
        color: color,
        showPercent: true,
      ),
    );
  }
}

double _ratio(num numerator, num denominator) {
  if (denominator <= 0) return 0;
  return numerator / denominator;
}

String _roleLabel(String role) => switch (role) {
      'student' => 'طلاب',
      'parent' => 'أولياء أمور',
      'mohaffez' => 'محفظون',
      'admin' => 'مديرون',
      _ => 'أخرى',
    };

Color _roleColor(String role) => switch (role) {
      'student' => DSColors.success,
      'parent' => DSColors.secondary,
      'mohaffez' => DSColors.primary,
      _ => DSColors.text3,
    };

class _UsersBreakdownCard extends StatelessWidget {
  final UserMetrics users;
  const _UsersBreakdownCard({required this.users});

  @override
  Widget build(BuildContext context) {
    final total = users.totalStudents + users.totalTeachers + users.totalAdmins;
    double pct(int n) => total == 0 ? 0 : n / total;

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'توزيع المستخدمين'),
          const SizedBox(height: DSSpacing.lg),
          DSProgressBar(
            label: 'طلاب (${users.totalStudents})',
            value: pct(users.totalStudents),
            color: DSColors.success,
            showPercent: true,
          ),
          const SizedBox(height: DSSpacing.md),
          DSProgressBar(
            label: 'محفظون (${users.totalTeachers})',
            value: pct(users.totalTeachers),
            color: DSColors.primary,
            showPercent: true,
          ),
          const SizedBox(height: DSSpacing.md),
          DSProgressBar(
            label: 'مديرون (${users.totalAdmins})',
            value: pct(users.totalAdmins),
            color: DSColors.secondary,
            showPercent: true,
          ),
          const SizedBox(height: DSSpacing.lg),
          Text(
            'محفظون نشطون آخر ٣٠ يوم: ${users.activeTeachers30d} / ${users.totalTeachers}',
            style: DSText.caption(context, color: DSColors.text2),
          ),
          if (users.pendingTeacherApprovals > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'طلبات محفظ معلقة: ${users.pendingTeacherApprovals}',
                style: DSText.caption(context, color: DSColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  final SessionMetrics sessions;
  const _SessionsCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الجلسات'),
          const SizedBox(height: DSSpacing.lg),
          _Row(
              label: 'منجزة هذا الشهر',
              value: '${sessions.completedThisMonth}'),
          _Row(
              label: 'منجزة الشهر السابق',
              value: '${sessions.completedLastMonth}'),
          _Row(
              label: 'ملغاة هذا الشهر',
              value: '${sessions.cancelledThisMonth}'),
          _Row(
              label: 'قيد الإنتظار الآن',
              value: '${sessions.pendingNow}',
              color: sessions.pendingNow > 0 ? DSColors.warning : null),
        ],
      ),
    );
  }
}

class _SubscriptionsCard extends StatelessWidget {
  final SubscriptionMetrics subs;
  const _SubscriptionsCard({required this.subs});

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الاشتراكات'),
          const SizedBox(height: DSSpacing.lg),
          _Row(label: 'نشطة', value: '${subs.active}'),
          _Row(
              label: 'ملغاة هذا الشهر',
              value: '${subs.cancelledThisMonth}',
              color: subs.cancelledThisMonth > 0 ? DSColors.warning : null),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Row({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: DSText.body(context, color: color ?? DSColors.text2)),
          Text(value, style: DSText.bodyMedium(context, color: color)),
        ],
      ),
    );
  }
}

class _RevenueLineCard extends StatelessWidget {
  final List<MonthlyRevenue> months;
  const _RevenueLineCard({required this.months});

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return const DSCard(
        child: DSEmptyState(
          title: 'لا توجد بيانات إيرادات',
          icon: Icons.show_chart_rounded,
        ),
      );
    }
    final maxValue =
        months.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    final upper = maxValue == 0 ? 1.0 : maxValue * 1.2;

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'اتجاه الإيرادات — آخر ١٢ شهرًا'),
          const SizedBox(height: DSSpacing.lg),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: upper,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: upper / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: DSColors.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: upper / 4,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000
                            ? '${(v / 1000).toStringAsFixed(0)}K'
                            : v.toStringAsFixed(0),
                        style: const TextStyle(
                            fontSize: 10, color: DSColors.text3),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = months[i].month.split('-');
                        final mn = int.tryParse(parts.last) ?? 1;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _shortMonth(mn),
                            style: const TextStyle(
                                fontSize: 10, color: DSColors.text3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: DSColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: DSColors.primary.withValues(alpha: 0.12),
                    ),
                    spots: List.generate(
                      months.length,
                      (i) => FlSpot(i.toDouble(), months[i].total),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortMonth(int m) {
    const names = [
      'ينا',
      'فبر',
      'مار',
      'أبر',
      'ماي',
      'يون',
      'يول',
      'أغس',
      'سبت',
      'أكت',
      'نوف',
      'ديس',
    ];
    if (m < 1 || m > 12) return '';
    return names[m - 1];
  }
}

class _TopTeachersCard extends ConsumerStatefulWidget {
  const _TopTeachersCard();

  @override
  ConsumerState<_TopTeachersCard> createState() => _TopTeachersCardState();
}

class _TopTeachersCardState extends ConsumerState<_TopTeachersCard> {
  int _days = 30;

  void _export(List<TeacherRanking> rows) {
    final csv = buildCsv(
      ['#', 'المحفظ', 'المعرّف', 'جلسات منجزة', 'الإيراد (ج.م)'],
      [
        for (var i = 0; i < rows.length; i++)
          [
            i + 1,
            rows[i].name,
            rows[i].mohaffezId,
            rows[i].sessionCount,
            rows[i].revenue.round()
          ],
      ],
    );
    downloadCsv(
        'mohafezy-top-teachers-${_days}d-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        csv);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(topTeachersProvider(_days));

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'أفضل المحفظين')),
              _PeriodToggle(
                value: _days,
                onChanged: (d) => setState(() => _days = d),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(DSSpacing.xl),
              child: Center(
                  child: CircularProgressIndicator(color: DSColors.primary)),
            ),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (rows) {
              if (rows.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد جلسات منجزة في هذه الفترة',
                  icon: Icons.emoji_events_outlined,
                );
              }
              final maxCount = rows.first.sessionCount;
              return Column(
                children: [
                  ...rows.asMap().entries.map((e) => _TeacherRow(
                        rank: e.key + 1,
                        ranking: e.value,
                        maxCount: maxCount,
                      )),
                  const SizedBox(height: DSSpacing.md),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DSButton(
                      label: 'تصدير CSV',
                      size: DSButtonSize.sm,
                      variant: DSButtonVariant.ghost,
                      leading: const Icon(Icons.download_rounded, size: 16),
                      onPressed: () => _export(rows),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = {30: '٣٠ يوم', 90: '٩٠ يوم', 365: 'سنة'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _options.entries.map((e) {
          final selected = e.key == value;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: DSDuration.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: DSSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? DSColors.surface : Colors.transparent,
                borderRadius: DSRadius.fullAll,
                boxShadow: selected ? DSElevation.sm : null,
              ),
              child: Text(
                e.value,
                style: DSText.caption(
                  context,
                  color: selected ? DSColors.primary : DSColors.text3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({
    required this.rank,
    required this.ranking,
    required this.maxCount,
  });
  final int rank;
  final TeacherRanking ranking;
  final int maxCount;

  static String _money(double v) =>
      '${NumberFormat.decimalPattern('ar').format(v.round())} ج.م';

  Color get _rankColor => switch (rank) {
        1 => const Color(0xFFD4A44A),
        2 => const Color(0xFF9AA0A6),
        3 => const Color(0xFFB08D57),
        _ => DSColors.text3,
      };

  @override
  Widget build(BuildContext context) {
    final pct = maxCount == 0 ? 0.0 : ranking.sessionCount / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: DSText.bodyMedium(context, color: _rankColor),
            ),
          ),
          const SizedBox(width: DSSpacing.sm),
          DSAvatar(name: ranking.name, size: 32),
          const SizedBox(width: DSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ranking.name,
                    style: DSText.bodyMedium(context),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                DSProgressBar(value: pct, color: DSColors.primary),
              ],
            ),
          ),
          const SizedBox(width: DSSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${ranking.sessionCount} جلسة',
                  style: DSText.bodyMedium(context)),
              if (ranking.revenue > 0)
                Text(_money(ranking.revenue),
                    style: DSText.caption(context, color: DSColors.text3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceLedgerCard extends StatelessWidget {
  const _FinanceLedgerCard({required this.finance});

  final FinanceInsights finance;

  String _money(double value) =>
      '${NumberFormat.decimalPattern('ar').format(value.round())} ج.م';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'الملخص المالي المرصود'),
        const SizedBox(height: DSSpacing.md),
        Text(
          'يعتمد على أحداث الدفع ودفتر المحفظة غير القابل للتعديل خلال الفترة الحالية.',
          style: DSText.caption(context, color: DSColors.text3),
        ),
        const SizedBox(height: DSSpacing.lg),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          children: [
            DSStatCard(
              label: 'إجمالي المدفوعات',
              value: _money(finance.grossRevenueEgp),
              icon: Icons.payments_outlined,
              iconColor: DSColors.primary,
            ),
            DSStatCard(
              label: 'صافي المدفوعات',
              value: _money(finance.netRevenueEgp),
              trend: finance.refundedAmountEgp > 0
                  ? 'استردادات: ${_money(finance.refundedAmountEgp)}'
                  : 'لا توجد استردادات مرصودة',
              trendPositive: finance.refundedAmountEgp == 0,
              icon: Icons.account_balance_outlined,
              iconColor: DSColors.success,
            ),
            DSStatCard(
              label: 'عمولة المنصة',
              value: _money(finance.commissionAccruedEgp),
              trend: finance.commissionReversedEgp > 0
                  ? 'عكس عمولة: ${_money(finance.commissionReversedEgp)}'
                  : 'بعد التسويات المسجلة',
              trendPositive: finance.commissionReversedEgp == 0,
              icon: Icons.percent_rounded,
              iconColor: DSColors.secondary,
            ),
            DSStatCard(
              label: 'شحن المحافظ',
              value: _money(finance.walletTopUpsEgp),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: DSColors.warning,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.lg),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          children: [
            _FinancialBreakdownCard(
              title: 'الإيراد حسب وسيلة الدفع',
              values: finance.revenueByMethod,
              labelForKey: _paymentMethodLabel,
              color: DSColors.primary,
            ),
            _FinancialBreakdownCard(
              title: 'الإيراد حسب نوع الخطة',
              values: finance.revenueByPlanType,
              labelForKey: _planTypeLabel,
              color: DSColors.secondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _FinancialBreakdownCard extends StatelessWidget {
  const _FinancialBreakdownCard({
    required this.title,
    required this.values,
    required this.labelForKey,
    required this.color,
  });

  final String title;
  final Map<String, double> values;
  final String Function(String) labelForKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.where((entry) => entry.value > 0).toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: DSSpacing.lg),
          if (entries.isEmpty)
            Text(
              'لا توجد بيانات مرصودة بعد.',
              style: DSText.body(context, color: DSColors.text3),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: DSSpacing.md),
                child: DSProgressBar(
                  label:
                      '${labelForKey(entry.key)} (${NumberFormat.decimalPattern('ar').format(entry.value.round())} ج.م)',
                  value: total <= 0 ? 0 : entry.value / total,
                  color: color,
                  showPercent: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _paymentMethodLabel(String value) => switch (value) {
      'paymob' || 'card' => 'بطاقة / Paymob',
      'wallet' => 'محفظة التطبيق',
      'instapay' => 'InstaPay',
      'vodafone_cash' => 'Vodafone Cash',
      'cash' || 'direct' => 'دفع مباشر',
      _ => value == 'unknown' ? 'غير محدد' : value,
    };

String _planTypeLabel(String value) => switch (value) {
      'single' => 'جلسة واحدة',
      'bundle' => 'باقة جلسات',
      'subscription' => 'اشتراك',
      _ => value == 'unknown' ? 'غير محدد' : value,
    };
