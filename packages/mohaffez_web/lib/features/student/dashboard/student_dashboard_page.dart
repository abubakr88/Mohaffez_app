import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).user?.uid ?? '';
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'مرحباً بك',
            subtitle: 'تابع رحلة حفظك اليوم',
            actions: [
              DSButton(
                label: 'احجز جلسة',
                leading: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          sessionsAsync.when(
            loading: () => const DSGrid(
              desktopColumns: 4,
              children: [DSSkeletonCard(), DSSkeletonCard(), DSSkeletonCard(), DSSkeletonCard()],
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (sessions) {
              final completed = sessions.where((s) => s['status'] == 'completed').length;
              final upcoming  = sessions.where((s) => s['status'] == RequestStatus.accepted || s['status'] == RequestStatus.pending).length;
              return DSGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 4,
                children: [
                  DSStatCard(
                    label: 'الجلسات المكتملة',
                    value: '$completed',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: DSColors.success,
                  ),
                  DSStatCard(
                    label: 'الجلسات القادمة',
                    value: '$upcoming',
                    icon: Icons.calendar_month_outlined,
                  ),
                  const DSStatCard(
                    label: 'المهام المعلقة',
                    value: '—',
                    icon: Icons.assignment_outlined,
                    iconColor: DSColors.warning,
                  ),
                  const DSStatCard(
                    label: 'نقاط المكافآت',
                    value: '—',
                    icon: Icons.workspace_premium_outlined,
                    iconColor: DSColors.secondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            tabletColumns: 1,
            desktopColumns: 2,
            children: [
              _UpcomingSessionsCard(uid: uid),
              const DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(title: 'المهام المعلقة'),
                    SizedBox(height: DSSpacing.lg),
                    DSEmptyState(
                      title: 'لا توجد مهام معلقة',
                      subtitle: 'ستظهر هنا المهام المعيّنة من محفظك',
                      icon: Icons.assignment_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingSessionsCard extends ConsumerWidget {
  const _UpcomingSessionsCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(uid));

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'الجلسات القادمة',
            trailing: TextButton(
              onPressed: () {},
              child: Text('عرض الكل', style: DSText.caption(context, color: DSColors.primary)),
            ),
          ),
          const SizedBox(height: DSSpacing.lg),
          sessionsAsync.when(
            loading: () => const Column(
              children: [
                DSSkeleton(height: 60),
                SizedBox(height: DSSpacing.sm),
                DSSkeleton(height: 60),
              ],
            ),
            error: (e, _) => DSBanner(message: 'خطأ: $e', variant: DSBannerVariant.error),
            data: (sessions) {
              final upcoming = sessions
                  .where((s) =>
                      s['status'] == RequestStatus.accepted ||
                      s['status'] == RequestStatus.pending)
                  .take(3)
                  .toList();
              if (upcoming.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد جلسات قادمة',
                  subtitle: 'ابحث عن محفظ لحجز جلستك الأولى',
                  icon: Icons.calendar_month_outlined,
                );
              }
              return Column(
                children: upcoming.map((s) => _SessionTile(session: s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final name   = session['mohaffezName'] as String? ?? 'محفظ';
    final status = session['status'] as String? ?? '';
    final date   = session['sessionDate'];

    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(DSSpacing.md),
        decoration: const BoxDecoration(
          color: DSColors.surfaceMuted,
          borderRadius: DSRadius.mdAll,
          border: Border.fromBorderSide(BorderSide(color: DSColors.border)),
        ),
        child: Row(
          children: [
            const _SessionIcon(),
            const SizedBox(width: DSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: DSText.bodyMedium(context)),
                  const SizedBox(height: 2),
                  Text(_fmt(date), style: DSText.caption(context, color: DSColors.text2)),
                ],
              ),
            ),
            DSBadge(label: _label(status), variant: _variant(status), dot: true),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = d is DateTime ? d : (d as dynamic).toDate() as DateTime;
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  String _label(String s) => switch (s) {
        RequestStatus.pending  => 'معلق',
        RequestStatus.accepted => 'مقبول',
        'completed'            => 'مكتمل',
        RequestStatus.cancelled => 'ملغي',
        _                      => s,
      };

  DSBadgeVariant _variant(String s) => switch (s) {
        RequestStatus.pending  => DSBadgeVariant.warning,
        RequestStatus.accepted => DSBadgeVariant.success,
        'completed'            => DSBadgeVariant.info,
        RequestStatus.cancelled => DSBadgeVariant.error,
        _                      => DSBadgeVariant.neutral,
      };
}

class _SessionIcon extends StatelessWidget {
  const _SessionIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: DSColors.primary,
        borderRadius: DSRadius.mdAll,
      ),
      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
    );
  }
}
