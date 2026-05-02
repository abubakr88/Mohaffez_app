import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid              = ref.watch(authProvider).user?.uid ?? '';
    final upcomingAsync    = ref.watch(upcomingSessionsProvider(uid));
    final pendingAsync     = ref.watch(pendingRequestsFirstPageProvider(uid));
    final completedAsync   = ref.watch(completedSessionsCountProvider(uid));
    final studentsAsync    = ref.watch(mohaffezStudentsProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'لوحة تحكم المحفظ',
            subtitle: 'نظرة عامة على نشاطك التعليمي',
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            children: [
              upcomingAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (s) => DSStatCard(
                  label: 'الجلسات القادمة',
                  value: '${s.length}',
                  icon: Icons.calendar_today_outlined,
                  iconColor: DSColors.primary,
                ),
              ),
              pendingAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (r) => DSStatCard(
                  label: 'الطلبات المعلقة',
                  value: '${r.length}',
                  icon: Icons.pending_actions_outlined,
                  iconColor: DSColors.warning,
                ),
              ),
              completedAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (c) => DSStatCard(
                  label: 'الجلسات المكتملة',
                  value: '$c',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: DSColors.success,
                ),
              ),
              studentsAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (s) => DSStatCard(
                  label: 'طلابي',
                  value: '${s.length}',
                  icon: Icons.people_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            tabletColumns: 1,
            desktopColumns: 2,
            children: [
              _UpcomingSessionsCard(uid: uid),
              _PendingRequestsCard(uid: uid),
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
    final async = ref.watch(upcomingSessionsProvider(uid));
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الجلسات القادمة'),
          const SizedBox(height: DSSpacing.lg),
          async.when(
            loading: () => const Column(children: [DSSkeleton(height: 60), SizedBox(height: 8), DSSkeleton(height: 60)]),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const DSEmptyState(title: 'لا توجد جلسات قادمة', icon: Icons.calendar_today_outlined);
              }
              return Column(
                children: sessions.take(4).map((s) => _SessionRow(session: s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingRequestsCard extends ConsumerWidget {
  const _PendingRequestsCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingRequestsFirstPageProvider(uid));
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الطلبات المعلقة'),
          const SizedBox(height: DSSpacing.lg),
          async.when(
            loading: () => const Column(children: [DSSkeleton(height: 60), SizedBox(height: 8), DSSkeleton(height: 60)]),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (requests) {
              if (requests.isEmpty) {
                return const DSEmptyState(title: 'لا توجد طلبات معلقة', icon: Icons.pending_actions_outlined);
              }
              return Column(
                children: requests.take(4).map((r) => _RequestRow(request: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final name = session['studentName'] as String? ?? 'طالب';
    final date = session['sessionDate'];
    return _RowTile(
      name: name,
      sub: _fmt(date),
      icon: Icons.person_outline_rounded,
      badge: const DSBadge(label: 'مقبول', variant: DSBadgeVariant.success, dot: true),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = d is DateTime ? d : (d as dynamic).toDate() as DateTime;
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return '—'; }
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final name = request['studentName'] as String? ?? 'طالب';
    final date = request['createdAt'];
    return _RowTile(
      name: name,
      sub: _fmt(date),
      icon: Icons.person_add_outlined,
      badge: const DSBadge(label: 'معلق', variant: DSBadgeVariant.warning, dot: true),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = d is DateTime ? d : (d as dynamic).toDate() as DateTime;
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return '—'; }
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.name, required this.sub, required this.icon, required this.badge});
  final String name;
  final String sub;
  final IconData icon;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
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
            DSAvatar(name: name, size: 36),
            const SizedBox(width: DSSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: DSText.bodyMedium(context)),
                  Text(sub, style: DSText.caption(context, color: DSColors.text2)),
                ],
              ),
            ),
            badge,
          ],
        ),
      ),
    );
  }
}
