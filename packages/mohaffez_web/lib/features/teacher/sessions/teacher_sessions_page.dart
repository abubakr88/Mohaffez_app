import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherSessionsPage extends ConsumerStatefulWidget {
  const TeacherSessionsPage({super.key});

  @override
  ConsumerState<TeacherSessionsPage> createState() => _TeacherSessionsPageState();
}

class _TeacherSessionsPageState extends ConsumerState<TeacherSessionsPage> {
  bool _showPending = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).user?.uid ?? '';

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'الجلسات', subtitle: 'إدارة جلساتك القادمة والطلبات المعلقة'),
          const SizedBox(height: DSSpacing.xxl),
          Row(
            children: [
              DSButton(
                label: 'الجلسات القادمة',
                variant: _showPending ? DSButtonVariant.ghost : DSButtonVariant.primary,
                onPressed: () => setState(() => _showPending = false),
              ),
              const SizedBox(width: DSSpacing.sm),
              DSButton(
                label: 'الطلبات المعلقة',
                variant: _showPending ? DSButtonVariant.primary : DSButtonVariant.ghost,
                onPressed: () => setState(() => _showPending = true),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xl),
          _showPending
              ? _PendingRequestsTable(uid: uid)
              : _UpcomingSessionsTable(uid: uid),
        ],
      ),
    );
  }
}

class _UpcomingSessionsTable extends ConsumerWidget {
  const _UpcomingSessionsTable({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(upcomingSessionsProvider(uid));
    return async.when(
      loading: () => const DSSkeletonCard(),
      error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const DSEmptyState(title: 'لا توجد جلسات قادمة', icon: Icons.calendar_today_outlined);
        }
        return DSDataTable<Map<String, dynamic>>(
          columns: [
            DSColumnDef(
              key: 'student',
              label: 'الطالب',
              cellBuilder: (ctx, s) => Row(
                children: [
                  DSAvatar(name: s['studentName'] as String?, size: 32),
                  const SizedBox(width: DSSpacing.sm),
                  Text(s['studentName'] as String? ?? '—', style: DSText.bodyMedium(ctx)),
                ],
              ),
            ),
            DSColumnDef(
              key: 'date',
              label: 'التاريخ',
              width: 140,
              cellBuilder: (ctx, s) => Text(_fmt(s['sessionDate']), style: DSText.body(ctx, color: DSColors.text2)),
            ),
            DSColumnDef(
              key: 'type',
              label: 'النوع',
              width: 120,
              cellBuilder: (ctx, s) => Text(s['sessionType'] as String? ?? '—', style: DSText.body(ctx, color: DSColors.text2)),
            ),
          ],
          rows: sessions,
        );
      },
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

class _PendingRequestsTable extends ConsumerWidget {
  const _PendingRequestsTable({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingRequestsFirstPageProvider(uid));
    return async.when(
      loading: () => const DSSkeletonCard(),
      error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
      data: (requests) {
        if (requests.isEmpty) {
          return const DSEmptyState(title: 'لا توجد طلبات معلقة', icon: Icons.pending_actions_outlined);
        }
        return DSDataTable<Map<String, dynamic>>(
          columns: [
            DSColumnDef(
              key: 'student',
              label: 'الطالب',
              cellBuilder: (ctx, r) => Row(
                children: [
                  DSAvatar(name: r['studentName'] as String?, size: 32),
                  const SizedBox(width: DSSpacing.sm),
                  Text(r['studentName'] as String? ?? '—', style: DSText.bodyMedium(ctx)),
                ],
              ),
            ),
            DSColumnDef(
              key: 'date',
              label: 'تاريخ الطلب',
              width: 140,
              cellBuilder: (ctx, r) => Text(_fmt(r['createdAt']), style: DSText.body(ctx, color: DSColors.text2)),
            ),
            DSColumnDef(
              key: 'actions',
              label: 'الإجراء',
              width: 160,
              cellBuilder: (ctx, r) => Row(
                children: [
                  DSButton(label: 'قبول', size: DSButtonSize.sm, onPressed: () {}),
                  const SizedBox(width: DSSpacing.xs),
                  DSButton(label: 'رفض', size: DSButtonSize.sm, variant: DSButtonVariant.destructive, onPressed: () {}),
                ],
              ),
            ),
          ],
          rows: requests,
        );
      },
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
