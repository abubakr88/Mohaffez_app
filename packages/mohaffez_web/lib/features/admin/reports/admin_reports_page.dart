import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../platform/web_download.dart';

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(adminMetricsStreamProvider);

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
                data: (m) => _ExportMenu(metrics: m),
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
                    'آخر تحديث: ${DateFormat('dd MMM yyyy HH:mm', 'ar').format(m.generatedAt!)}',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                const SizedBox(height: DSSpacing.md),

                // Period comparison KPIs ─────────────────────────────────
                _ComparisonRow(metrics: m),
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
                _CommissionsSummaryCard(c: m.commissions),
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
  const _ExportMenu({required this.metrics});
  final AdminMetrics metrics;

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
    final c = metrics.commissions;
    final s = metrics.sessions;
    final sub = metrics.subscriptions;
    final u = metrics.users;
    final csv = buildCsv(
      ['المؤشر', 'القيمة'],
      [
        ['إيرادات هذا الشهر', r.thisMonth.round()],
        ['إيرادات الشهر السابق', r.lastMonth.round()],
        ['إيرادات السنة', r.ytd.round()],
        ['عمولات مستحقة', c.outstanding.round()],
        ['عمولات متأخرة', c.overdue.round()],
        ['بانتظار التأكيد', c.pendingVerification.round()],
        ['مدفوع هذا الشهر', c.paidThisMonth.round()],
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
          _Row(label: 'منجزة هذا الشهر', value: '${sessions.completedThisMonth}'),
          _Row(label: 'منجزة الشهر السابق', value: '${sessions.completedLastMonth}'),
          _Row(label: 'ملغاة هذا الشهر', value: '${sessions.cancelledThisMonth}'),
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
    final maxValue = months.fold<double>(0, (m, e) => e.total > m ? e.total : m);
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
      'ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون',
      'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس',
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
          [i + 1, rows[i].name, rows[i].mohaffezId, rows[i].sessionCount, rows[i].revenue.round()],
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

class _CommissionsSummaryCard extends StatelessWidget {
  final CommissionMetrics c;
  const _CommissionsSummaryCard({required this.c});

  String _money(double v) =>
      '${NumberFormat.decimalPattern('ar').format(v.round())} ج.م';

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ملخص العمولات'),
          const SizedBox(height: DSSpacing.lg),
          DSGrid(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 5,
            children: [
              DSStatCard(
                  label: 'إجمالي مستحق',
                  value: _money(c.outstanding),
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: DSColors.warning),
              DSStatCard(
                  label: 'متأخرات',
                  value: _money(c.overdue),
                  icon: Icons.report_outlined,
                  iconColor: DSColors.error),
              DSStatCard(
                  label: 'بانتظار التأكيد',
                  value: _money(c.pendingVerification),
                  icon: Icons.fact_check_outlined,
                  iconColor: DSColors.secondary),
              DSStatCard(
                  label: 'مدفوع هذا الشهر',
                  value: _money(c.paidThisMonth),
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: DSColors.success),
              DSStatCard(
                  label: 'مدفوع الشهر السابق',
                  value: _money(c.paidLastMonth),
                  icon: Icons.history_rounded,
                  iconColor: DSColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}
