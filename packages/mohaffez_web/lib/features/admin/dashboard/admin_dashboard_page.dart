import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        refreshAdminMetricsNow(),
        refreshAdminInsightsNow(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الإحصائيات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DSColors.error,
          content: Text('تعذّر التحديث: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(adminMetricsStreamProvider);
    final insightsAsync = ref.watch(adminInsightsStreamProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeader(
                  title: 'لوحة الإدارة',
                  subtitle: 'نظرة عامة على الإيرادات والجلسات والمستخدمين',
                ),
              ),
              DSButton(
                label: _refreshing ? 'جاري التحديث…' : 'تحديث الإحصائيات',
                size: DSButtonSize.sm,
                onPressed: _refreshing ? null : _refresh,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          metricsAsync.when(
            loading: () => const _LoadingGrid(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (m) => _MetricsView(
              metrics: m,
              insights: insightsAsync.asData?.value ?? AdminInsights.empty(),
              insightsLoading: insightsAsync.isLoading,
              insightsError: insightsAsync.hasError,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

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

class _MetricsView extends StatelessWidget {
  final AdminMetrics metrics;
  final AdminInsights insights;
  final bool insightsLoading;
  final bool insightsError;

  const _MetricsView({
    required this.metrics,
    required this.insights,
    required this.insightsLoading,
    required this.insightsError,
  });

  @override
  Widget build(BuildContext context) {
    final r = metrics.revenue;
    final c = metrics.commissions;
    final s = metrics.sessions;
    final u = metrics.users;
    final hasData = metrics.generatedAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasData)
          const DSBanner(
            message:
                'لم يتم احتساب الإحصائيات بعد. اضغط "تحديث الإحصائيات" لإنشاء أول لقطة.',
            variant: DSBannerVariant.warning,
          ),
        if (hasData) ...[
          Text(
            'آخر تحديث: ${DateFormat('dd MMM yyyy HH:mm', 'ar').format(metrics.generatedAt!)}',
            style: DSText.caption(context, color: DSColors.text3),
          ),
          const SizedBox(height: DSSpacing.md),
        ],
        _ActionQueuesSection(metrics: metrics),
        const SizedBox(height: DSSpacing.xxl),
        _AdminInsightsSection(
          insights: insights,
          loading: insightsLoading,
          hasError: insightsError,
        ),
        const SizedBox(height: DSSpacing.xxl),

        // Top KPIs ─────────────────────────────────────────────────────────
        DSGrid(
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
              label: 'مستحقات معلقة',
              value: _money(c.outstanding),
              trend: c.overdue > 0
                  ? 'متأخرة: ${_money(c.overdue)}'
                  : 'لا توجد متأخرات',
              trendPositive: c.overdue == 0,
              icon: Icons.payments_outlined,
              iconColor: c.overdue > 0 ? DSColors.error : DSColors.warning,
            ),
            DSStatCard(
              label: 'بانتظار التأكيد',
              value: _money(c.pendingVerification),
              trend: 'إيداعات محفظين تحتاج مراجعة',
              icon: Icons.fact_check_outlined,
              iconColor: DSColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.xxl),

        // Revenue chart + commission state ────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (!wide) {
              return Column(
                children: [
                  _RevenueChartCard(months: r.last12Months),
                  const SizedBox(height: DSSpacing.md),
                  _CommissionsCard(commissions: c),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _RevenueChartCard(months: r.last12Months),
                ),
                const SizedBox(width: DSSpacing.md),
                Expanded(child: _CommissionsCard(commissions: c)),
              ],
            );
          },
        ),
        const SizedBox(height: DSSpacing.xxl),

        // Sessions + users ────────────────────────────────────────────────
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          children: [
            DSStatCard(
              label: 'جلسات منجزة (الشهر)',
              value: '${s.completedThisMonth}',
              trend: _intDelta(s.completedThisMonth, s.completedLastMonth),
              trendPositive: s.completedThisMonth >= s.completedLastMonth,
              icon: Icons.event_available_rounded,
              iconColor: DSColors.success,
            ),
            DSStatCard(
              label: 'جلسات قيد الإنتظار',
              value: '${s.pendingNow}',
              icon: Icons.hourglass_empty_rounded,
              iconColor: DSColors.warning,
            ),
            DSStatCard(
              label: 'محفظون نشطون (٣٠ يوم)',
              value: '${u.activeTeachers30d} / ${u.totalTeachers}',
              icon: Icons.school_outlined,
              iconColor: DSColors.primary,
            ),
            DSStatCard(
              label: 'تسجيلات جديدة هذا الشهر',
              value: '${u.newSignupsThisMonth}',
              trend: u.pendingTeacherApprovals > 0
                  ? '${u.pendingTeacherApprovals} طلب محفظ معلق'
                  : null,
              trendPositive: u.pendingTeacherApprovals == 0,
              icon: Icons.person_add_alt_1_rounded,
              iconColor: DSColors.secondary,
            ),
          ],
        ),
      ],
    );
  }

  static String _money(double v) =>
      '${NumberFormat.decimalPattern('ar').format(v.round())} ج.م';

  static String _delta(double current, double previous) {
    if (previous == 0) return current > 0 ? 'بداية جديدة' : '';
    final pct = ((current - previous) / previous * 100).round();
    if (pct >= 0) return '▲ $pct% عن الشهر السابق';
    return '▼ ${pct.abs()}% عن الشهر السابق';
  }

  static String _intDelta(int current, int previous) {
    if (previous == 0) return current > 0 ? 'بداية جديدة' : '—';
    final diff = current - previous;
    if (diff >= 0) return '+$diff عن الشهر السابق';
    return '$diff عن الشهر السابق';
  }
}

class _AdminInsightsSection extends StatelessWidget {
  const _AdminInsightsSection({
    required this.insights,
    required this.loading,
    required this.hasError,
  });

  final AdminInsights insights;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (loading && insights.generatedAt == null) {
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

    if (hasError) {
      return const DSBanner(
        message: 'تعذر تحميل مؤشرات الأداء التراكمية.',
        variant: DSBannerVariant.error,
      );
    }

    if (insights.generatedAt == null) {
      return const DSBanner(
        message:
            'ستظهر مؤشرات التسويق والتشغيل بعد نشر دوال التحليلات ووصول أول أحداث جديدة.',
        variant: DSBannerVariant.info,
      );
    }

    final growth = insights.growth;
    final operations = insights.operations;
    final finance = insights.finance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'مسار التحويل هذا الشهر'),
        const SizedBox(height: DSSpacing.md),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          children: [
            DSStatCard(
              label: 'طلبات الحجز',
              value: '${growth.requestsCreated}',
              trend: '${growth.signups} تسجيل جديد',
              icon: Icons.send_outlined,
              iconColor: DSColors.primary,
            ),
            DSStatCard(
              label: 'طلبات مقبولة',
              value: '${growth.requestsAccepted}',
              trend: _percent(growth.requestAcceptanceRate),
              trendPositive: growth.requestAcceptanceRate >= 0.5,
              icon: Icons.task_alt_rounded,
              iconColor: DSColors.success,
            ),
            DSStatCard(
              label: 'دفعات مكتملة',
              value: '${growth.paymentsCompleted}',
              trend: _percent(growth.paymentConversionRate),
              trendPositive: growth.paymentConversionRate >= 0.5,
              icon: Icons.credit_card_rounded,
              iconColor: DSColors.secondary,
            ),
            DSStatCard(
              label: 'جلسات مكتملة',
              value: '${growth.sessionsCompleted}',
              trend: _percent(growth.sessionCompletionRate),
              trendPositive: growth.sessionCompletionRate >= 0.7,
              icon: Icons.event_available_outlined,
              iconColor: DSColors.success,
            ),
          ],
        ),
        const SizedBox(height: DSSpacing.xxl),
        const SectionHeader(title: 'الصحة التشغيلية والمالية'),
        const SizedBox(height: DSSpacing.md),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          children: [
            DSStatCard(
              label: 'عمليات تحتاج تدخلاً',
              value:
                  '${operations.failedOperations + operations.unresolvedAlerts}',
              trend:
                  '${operations.failedOperations} فاشلة، ${operations.unresolvedAlerts} تنبيه',
              trendPositive: operations.failedOperations == 0 &&
                  operations.unresolvedAlerts == 0,
              icon: Icons.health_and_safety_outlined,
              iconColor: operations.failedOperations > 0
                  ? DSColors.error
                  : DSColors.success,
            ),
            DSStatCard(
              label: 'مدفوعات معلقة',
              value:
                  '${operations.pendingPayments + operations.pendingDirectPayments}',
              trend:
                  '${operations.pendingDirectPayments} تحويل مباشر بانتظار التأكيد',
              trendPositive: operations.pendingPayments == 0 &&
                  operations.pendingDirectPayments == 0,
              icon: Icons.hourglass_top_rounded,
              iconColor: DSColors.warning,
            ),
            DSStatCard(
              label: 'صافي المدفوعات المرصودة',
              value: _money(finance.netRevenueEgp),
              trend: finance.refundedAmountEgp > 0
                  ? 'استردادات: ${_money(finance.refundedAmountEgp)}'
                  : 'لا توجد استردادات مرصودة',
              trendPositive: finance.refundedAmountEgp == 0,
              icon: Icons.account_balance_outlined,
              iconColor: DSColors.primary,
            ),
            DSStatCard(
              label: 'عمولة المنصة المرصودة',
              value: _money(finance.commissionAccruedEgp),
              trend: finance.commissionReversedEgp > 0
                  ? 'عكس عمولة: ${_money(finance.commissionReversedEgp)}'
                  : '${insights.activeTeachers30d} محفظ نشط خلال 30 يومًا',
              trendPositive: finance.commissionReversedEgp == 0,
              icon: Icons.percent_rounded,
              iconColor: DSColors.secondary,
            ),
          ],
        ),
      ],
    );
  }

  static String _percent(double value) =>
      '${(value * 100).clamp(0, 999).toStringAsFixed(1)}% من المرحلة السابقة';

  static String _money(double value) =>
      '${NumberFormat.decimalPattern('ar').format(value.round())} ج.م';
}

class _ActionQueuesSection extends ConsumerWidget {
  const _ActionQueuesSection({required this.metrics});

  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(currentAdminAccessProvider).valueOrNull ??
        AdminAccessState.none();
    final canOpenUsers = access.isSuperAdmin ||
        access.can(AdminPermission.manageUsers) ||
        access.can(AdminPermission.manageUserRoles) ||
        access.can(AdminPermission.deleteUsers);

    final cards = <Widget>[];

    if (access.can(AdminPermission.reviewTeachers)) {
      final approvals = ref.watch(pendingTeachersProvider);
      final count = _asyncCount(
        approvals,
        fallback: metrics.users.pendingTeacherApprovals,
      );
      cards.add(
        _QueueTile(
          title: 'محفظون بانتظار المراجعة',
          count: count.label,
          subtitle: count.hasError
              ? 'تعذر تحميل صف المراجعة'
              : count.value > 0
                  ? 'راجع الشهادات والتوفر والخطط السعرية'
                  : 'لا توجد طلبات معلقة',
          icon: Icons.verified_user_outlined,
          color: DSColors.warning,
          path: '/admin/approvals',
          active: count.value > 0,
          error: count.hasError,
        ),
      );
    }

    if (access.can(AdminPermission.manageFinance)) {
      final topUps = ref.watch(pendingTopUpsProvider);
      final topUpCount = _asyncCount(topUps);
      cards.add(
        _QueueTile(
          title: 'طلبات شحن معلقة',
          count: topUpCount.label,
          subtitle: topUpCount.hasError
              ? 'تعذر تحميل طلبات الشحن'
              : topUpCount.value > 0
                  ? 'تحقق من إثباتات التحويل قبل الشحن'
                  : 'لا توجد طلبات شحن',
          icon: Icons.add_card_outlined,
          color: DSColors.secondary,
          path: '/admin/topups',
          active: topUpCount.value > 0,
          error: topUpCount.hasError,
        ),
      );

      final payouts = ref.watch(activePayoutsProvider);
      final payoutCount = _asyncCount(payouts);
      final amount = payouts.when(
        data: (items) => items.fold<double>(
          0,
          (sum, payout) => sum + payout.amountEgp,
        ),
        loading: () => null,
        error: (_, __) => null,
      );
      cards.add(
        _QueueTile(
          title: 'طلبات سحب نشطة',
          count: payoutCount.label,
          subtitle: payoutCount.hasError
              ? 'تعذر تحميل طلبات السحب'
              : amount == null
                  ? 'جاري تحميل المبالغ'
                  : payoutCount.value > 0
                      ? '${_queueMoney(amount)} قيد التنفيذ أو بانتظار البدء'
                      : 'لا توجد طلبات سحب',
          icon: Icons.account_balance_wallet_outlined,
          color: DSColors.primary,
          path: '/admin/payouts',
          active: payoutCount.value > 0,
          error: payoutCount.hasError,
        ),
      );
    }

    if (access.can(AdminPermission.runMaintenance) &&
        access.can(AdminPermission.manageFinance)) {
      final failed = ref.watch(failedOperationsProvider);
      final count = _asyncCount(failed);
      cards.add(
        _QueueTile(
          title: 'عمليات فاشلة',
          count: count.label,
          subtitle: count.hasError
              ? 'تعذر تحميل العمليات الفاشلة'
              : count.value > 0
                  ? 'راجع السبب قبل إعادة المحاولة أو الإغلاق'
                  : 'لا توجد عمليات فاشلة',
          icon: Icons.error_outline_rounded,
          color: DSColors.error,
          path: '/admin/payments',
          active: count.value > 0,
          error: count.hasError,
        ),
      );
    }

    if (canOpenUsers) {
      final flagged = ref.watch(flaggedUsersProvider);
      final count = _asyncCount(flagged);
      cards.add(
        _QueueTile(
          title: 'حسابات تحتاج مراجعة',
          count: count.label,
          subtitle: count.hasError
              ? 'تعذر تحميل الحسابات المعلّمة'
              : count.value > 0
                  ? 'افتح قائمة المستخدمين لمراجعة العلامات'
                  : 'لا توجد حسابات معلّمة',
          icon: Icons.policy_outlined,
          color: DSColors.info,
          path: '/admin/users',
          active: count.value > 0,
          error: count.hasError,
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'صفوف العمل'),
        const SizedBox(height: DSSpacing.md),
        DSGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 4,
          wideColumns: 4,
          children: cards,
        ),
      ],
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.title,
    required this.count,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.path,
    required this.active,
    required this.error,
  });

  final String title;
  final String count;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? path;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = error ? DSColors.error : color;
    final child = Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(DSSpacing.xl),
      decoration: BoxDecoration(
        color: DSColors.surface,
        borderRadius: DSRadius.lgAll,
        border: Border.all(
          color: active || error
              ? effectiveColor.withValues(alpha: 0.35)
              : DSColors.border,
        ),
        boxShadow: DSElevation.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.1),
                  borderRadius: DSRadius.mdAll,
                ),
                child: Icon(icon, size: 20, color: effectiveColor),
              ),
              const Spacer(),
              DSBadge(
                label: error
                    ? 'خطأ'
                    : active
                        ? 'مطلوب'
                        : 'مستقر',
                variant: error
                    ? DSBadgeVariant.error
                    : active
                        ? DSBadgeVariant.warning
                        : DSBadgeVariant.success,
                dot: active || error,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          Text(count, style: DSText.h1(context, color: DSColors.text1)),
          const SizedBox(height: DSSpacing.xs),
          Text(title, style: DSText.bodyMedium(context, color: DSColors.text1)),
          const SizedBox(height: DSSpacing.xs),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DSText.caption(context, color: DSColors.text3),
          ),
        ],
      ),
    );

    if (path == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(path!),
        child: child,
      ),
    );
  }
}

class _QueueCount {
  const _QueueCount({
    required this.value,
    required this.label,
    this.hasError = false,
  });

  final int value;
  final String label;
  final bool hasError;
}

_QueueCount _asyncCount<T>(
  AsyncValue<List<T>> async, {
  int? fallback,
}) {
  return async.when(
    data: (items) => _QueueCount(value: items.length, label: '${items.length}'),
    loading: () => fallback == null
        ? const _QueueCount(value: 0, label: '...')
        : _QueueCount(value: fallback, label: '$fallback'),
    error: (_, __) => const _QueueCount(value: 0, label: '!', hasError: true),
  );
}

String _queueMoney(double value) {
  return '${NumberFormat.decimalPattern('ar').format(value.round())} ج.م';
}

class _RevenueChartCard extends StatelessWidget {
  final List<MonthlyRevenue> months;
  const _RevenueChartCard({required this.months});

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الإيرادات الشهرية — آخر ١٢ شهرًا'),
          const SizedBox(height: DSSpacing.lg),
          SizedBox(
            height: 240,
            child: months.isEmpty
                ? const DSEmptyState(
                    title: 'لا توجد بيانات بعد',
                    icon: Icons.bar_chart_rounded,
                  )
                : _RevenueBars(months: months),
          ),
        ],
      ),
    );
  }
}

class _RevenueBars extends StatelessWidget {
  final List<MonthlyRevenue> months;
  const _RevenueBars({required this.months});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        months.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    final upper = maxValue == 0 ? 1.0 : maxValue * 1.2;

    return BarChart(
      BarChartData(
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
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) {
              final m = months[group.x];
              return BarTooltipItem(
                '${m.month}\n${NumberFormat.decimalPattern('ar').format(rod.toY.round())} ج.م',
                const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: upper / 4,
              getTitlesWidget: (value, _) => Text(
                value >= 1000
                    ? '${(value / 1000).toStringAsFixed(0)}K'
                    : value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: DSColors.text3),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                final parts = months[i].month.split('-');
                final monthNumber = int.tryParse(parts.last) ?? 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortMonth(monthNumber),
                    style: const TextStyle(fontSize: 10, color: DSColors.text3),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(months.length, (i) {
          final m = months[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: m.total,
                color: DSColors.primary,
                width: 14,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
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

class _CommissionsCard extends StatelessWidget {
  final CommissionMetrics commissions;
  const _CommissionsCard({required this.commissions});

  @override
  Widget build(BuildContext context) {
    final totalKnown = commissions.outstanding +
        commissions.paidThisMonth +
        commissions.paidLastMonth;

    double pct(double v) =>
        totalKnown == 0 ? 0 : (v / totalKnown).clamp(0.0, 1.0);

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'حالة العمولات'),
          const SizedBox(height: DSSpacing.lg),
          DSProgressBar(
            label: 'مدفوع هذا الشهر',
            value: pct(commissions.paidThisMonth),
            color: DSColors.success,
          ),
          const SizedBox(height: DSSpacing.sm),
          Text(
            '${NumberFormat.decimalPattern('ar').format(commissions.paidThisMonth.round())} ج.م',
            style: DSText.caption(context),
          ),
          const SizedBox(height: DSSpacing.md),
          DSProgressBar(
            label: 'بانتظار التأكيد',
            value: pct(commissions.pendingVerification),
            color: DSColors.secondary,
          ),
          const SizedBox(height: DSSpacing.sm),
          Text(
            '${NumberFormat.decimalPattern('ar').format(commissions.pendingVerification.round())} ج.م',
            style: DSText.caption(context),
          ),
          const SizedBox(height: DSSpacing.md),
          DSProgressBar(
            label: 'متأخرات',
            value: pct(commissions.overdue),
            color: DSColors.error,
          ),
          const SizedBox(height: DSSpacing.sm),
          Text(
            '${NumberFormat.decimalPattern('ar').format(commissions.overdue.round())} ج.م',
            style: DSText.caption(context),
          ),
        ],
      ),
    );
  }
}
