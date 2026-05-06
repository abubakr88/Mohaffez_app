import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      await refreshAdminMetricsNow();
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
            data: (m) => _MetricsView(metrics: m),
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
  const _MetricsView({required this.metrics});

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
    final maxValue = months.fold<double>(
        0, (m, e) => e.total > m ? e.total : m);
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
                    style:
                        const TextStyle(fontSize: 10, color: DSColors.text3),
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
