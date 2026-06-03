import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

// ── Filter options ───────────────────────────────────────────────────────────
const _kFilters = <({String? key, String label})>[
  (key: null,        label: 'الكل'),
  (key: 'live',      label: 'قيد التنفيذ'),
  (key: 'completed', label: 'منجزة'),
  (key: 'cancelled', label: 'ملغاة'),
  (key: 'pending',   label: 'بانتظار الموافقة'),
];

class AdminSessionsPage extends ConsumerStatefulWidget {
  const AdminSessionsPage({super.key});

  @override
  ConsumerState<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends ConsumerState<AdminSessionsPage> {
  String? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(adminMetricsStreamProvider);
    final sessionsAsync = ref.watch(adminSessionsProvider(_filter));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'الجلسات',
            subtitle: 'مراقبة جميع جلسات المنصة في الوقت الفعلي',
          ),
          const SizedBox(height: DSSpacing.xl),

          // ── KPI row from cached metrics ──────────────────────────────
          metricsAsync.when(
            loading: () => const DSGrid(
              mobileColumns: 2,
              tabletColumns: 4,
              desktopColumns: 4,
              children: [
                DSSkeletonCard(), DSSkeletonCard(),
                DSSkeletonCard(), DSSkeletonCard(),
              ],
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (m) => DSGrid(
              mobileColumns: 2,
              tabletColumns: 4,
              desktopColumns: 4,
              children: [
                DSStatCard(
                  label: 'قيد الانتظار الآن',
                  value: '${m.sessions.pendingNow}',
                  icon: Icons.hourglass_top_rounded,
                  iconColor: m.sessions.pendingNow > 0
                      ? DSColors.warning
                      : DSColors.success,
                ),
                DSStatCard(
                  label: 'منجزة هذا الشهر',
                  value: '${m.sessions.completedThisMonth}',
                  trend: _intDelta(
                      m.sessions.completedThisMonth,
                      m.sessions.completedLastMonth),
                  trendPositive: m.sessions.completedThisMonth >=
                      m.sessions.completedLastMonth,
                  icon: Icons.event_available_rounded,
                  iconColor: DSColors.success,
                ),
                DSStatCard(
                  label: 'ملغاة هذا الشهر',
                  value: '${m.sessions.cancelledThisMonth}',
                  icon: Icons.event_busy_rounded,
                  iconColor: DSColors.error,
                ),
                DSStatCard(
                  label: 'منجزة الشهر السابق',
                  value: '${m.sessions.completedLastMonth}',
                  icon: Icons.history_rounded,
                  iconColor: DSColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: DSSpacing.xl),

          // ── Search + filter chips ────────────────────────────────────
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final search = SizedBox(
                width: wide ? 300 : double.infinity,
                child: DSSearchField(
                  hint: 'بحث بالمحفظ أو الطالب',
                  onChanged: (v) => setState(() => _query = v),
                ),
              );
              final chips = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _kFilters
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(left: DSSpacing.sm),
                            child: _FilterChip(
                              label: f.label,
                              selected: _filter == f.key,
                              onTap: () =>
                                  setState(() => _filter = f.key),
                            ),
                          ))
                      .toList(),
                ),
              );
              if (wide) {
                return Row(
                  children: [
                    search,
                    const SizedBox(width: DSSpacing.lg),
                    Expanded(child: chips),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  search,
                  const SizedBox(height: DSSpacing.md),
                  chips,
                ],
              );
            },
          ),
          const SizedBox(height: DSSpacing.xl),

          // ── Sessions table ───────────────────────────────────────────
          sessionsAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (all) {
              final rows = _filter == null && _query.isEmpty
                  ? all
                  : all.where((s) {
                      if (_query.isNotEmpty) {
                        final q = _query.toLowerCase();
                        final teacher =
                            (s['mohaffezName'] as String? ?? '').toLowerCase();
                        final student =
                            (s['studentName'] as String? ?? '').toLowerCase();
                        if (!teacher.contains(q) && !student.contains(q)) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();

              if (rows.isEmpty) {
                return const DSCard(
                  child: DSEmptyState(
                    title: 'لا توجد جلسات',
                    subtitle: 'جرّب تغيير عوامل التصفية أو البحث',
                    icon: Icons.calendar_today_outlined,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rows.length} جلسة',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.sm),
                  DSDataTable<Map<String, dynamic>>(
                    initialSortKey: 'date',
                    columns: [
                      DSColumnDef(
                        key: 'date',
                        label: 'التاريخ',
                        width: 140,
                        sortable: true,
                        sortValue: (s) =>
                            _ts(s['sessionDate'] ?? s['slotStart'])
                                ?.millisecondsSinceEpoch ??
                            0,
                        cellBuilder: (ctx, s) {
                          final dt =
                              _ts(s['sessionDate'] ?? s['slotStart']);
                          return Text(
                            dt == null
                                ? '—'
                                : DateFormat('dd/MM/yyyy', 'ar').format(dt),
                            style: DSText.body(ctx, color: DSColors.text2),
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'teacher',
                        label: 'المحفظ',
                        sortable: true,
                        sortValue: (s) =>
                            (s['mohaffezName'] as String? ?? '').toLowerCase(),
                        cellBuilder: (ctx, s) {
                          final name =
                              s['mohaffezName'] as String? ?? '—';
                          return Row(
                            children: [
                              DSAvatar(name: name, size: 28),
                              const SizedBox(width: DSSpacing.sm),
                              Flexible(
                                child: Text(name,
                                    style: DSText.bodyMedium(ctx),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'student',
                        label: 'الطالب',
                        sortable: true,
                        sortValue: (s) =>
                            (s['studentName'] as String? ?? '').toLowerCase(),
                        cellBuilder: (ctx, s) {
                          final name =
                              s['studentName'] as String? ?? '—';
                          return Row(
                            children: [
                              DSAvatar(name: name, size: 28),
                              const SizedBox(width: DSSpacing.sm),
                              Flexible(
                                child: Text(name,
                                    style: DSText.body(ctx),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'type',
                        label: 'النوع',
                        width: 110,
                        cellBuilder: (ctx, s) {
                          final t = s['sessionType'] as String? ?? '';
                          return DSBadge(
                            label: _typeLabel(t),
                            variant: _typeVariant(t),
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'status',
                        label: 'الحالة',
                        width: 110,
                        sortable: true,
                        sortValue: (s) => s['status'] as String? ?? '',
                        cellBuilder: (ctx, s) {
                          final st = s['status'] as String? ?? '';
                          return DSBadge(
                            label: _statusLabel(st),
                            variant: _statusVariant(st),
                            dot: true,
                          );
                        },
                      ),
                      DSColumnDef(
                        key: 'price',
                        label: 'السعر',
                        width: 100,
                        sortable: true,
                        sortValue: (s) =>
                            (s['sessionPrice'] as num?)?.toDouble() ?? 0.0,
                        cellBuilder: (ctx, s) {
                          final price =
                              (s['sessionPrice'] as num?)?.toDouble();
                          if (price == null || price == 0) {
                            return Text('—',
                                style:
                                    DSText.body(ctx, color: DSColors.text3));
                          }
                          return Text(
                            _money(price),
                            style: DSText.bodyMedium(ctx),
                          );
                        },
                      ),
                    ],
                    rows: rows,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static String _intDelta(int current, int previous) {
    if (previous == 0) return '';
    final diff = current - previous;
    return diff >= 0 ? '+$diff عن السابق' : '$diff عن السابق';
  }

  static String _money(double v) =>
      '${NumberFormat.decimalPattern('ar').format(v.round())} ج.م';

  static String _statusLabel(String s) => switch (s) {
        'pending'   => 'انتظار',
        'accepted'  => 'مقبولة',
        'completed' => 'منجزة',
        'cancelled' => 'ملغاة',
        _           => s,
      };

  static DSBadgeVariant _statusVariant(String s) => switch (s) {
        'pending'   => DSBadgeVariant.warning,
        'accepted'  => DSBadgeVariant.primary,
        'completed' => DSBadgeVariant.success,
        'cancelled' => DSBadgeVariant.error,
        _           => DSBadgeVariant.neutral,
      };

  static String _typeLabel(String t) => switch (t) {
        'online'  => 'أونلاين',
        'mosque'  => 'مسجد',
        'home'    => 'منزل',
        _         => t,
      };

  static DSBadgeVariant _typeVariant(String t) => switch (t) {
        'online' => DSBadgeVariant.info,
        'mosque' => DSBadgeVariant.primary,
        'home'   => DSBadgeVariant.neutral,
        _        => DSBadgeVariant.neutral,
      };
}

// ── Shared filter chip (mirrors the users page) ──────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DSDuration.fast,
          padding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.lg, vertical: DSSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? DSColors.primary : DSColors.surface,
            borderRadius: DSRadius.fullAll,
            border:
                Border.all(color: selected ? DSColors.primary : DSColors.border),
          ),
          child: Text(
            label,
            style: DSText.caption(context,
                color: selected ? Colors.white : DSColors.text2),
          ),
        ),
      ),
    );
  }
}
