import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class StudentSessionsPage extends ConsumerWidget {
  const StudentSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).user?.uid ?? '';
    final sessionsAsync = ref.watch(studentSessionsFirstPageProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'جلساتي',
            subtitle: 'سجل جميع جلساتك مع المحفظين',
          ),
          const SizedBox(height: DSSpacing.xxl),
          sessionsAsync.when(
            loading: () => const Column(
              children: [DSSkeletonCard(), SizedBox(height: DSSpacing.sm), DSSkeletonCard()],
            ),
            error: (e, _) => DSBanner(message: 'خطأ في تحميل الجلسات: $e', variant: DSBannerVariant.error),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد جلسات',
                  subtitle: 'ابحث عن محفظ لحجز جلستك الأولى',
                  icon: Icons.video_call_outlined,
                  actionLabel: 'ابحث عن محفظ',
                );
              }
              return DSDataTable<Map<String, dynamic>>(
                columns: [
                  DSColumnDef(
                    key: 'teacher',
                    label: 'المحفظ',
                    cellBuilder: (ctx, s) => Row(
                      children: [
                        DSAvatar(name: s['mohaffezName'] as String?, size: 32),
                        const SizedBox(width: DSSpacing.sm),
                        Text(s['mohaffezName'] as String? ?? '—', style: DSText.bodyMedium(ctx)),
                      ],
                    ),
                  ),
                  DSColumnDef(
                    key: 'date',
                    label: 'التاريخ',
                    width: 140,
                    cellBuilder: (ctx, s) => Text(
                      _fmt(s['sessionDate']),
                      style: DSText.body(ctx, color: DSColors.text2),
                    ),
                  ),
                  DSColumnDef(
                    key: 'status',
                    label: 'الحالة',
                    width: 120,
                    cellBuilder: (ctx, s) {
                      final status = s['status'] as String? ?? '';
                      return DSBadge(
                        label: _label(status),
                        variant: _variant(status),
                        dot: true,
                      );
                    },
                  ),
                ],
                rows: sessions,
              );
            },
          ),
        ],
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
        RequestStatus.pending   => 'معلق',
        RequestStatus.accepted  => 'مقبول',
        'completed'             => 'مكتمل',
        RequestStatus.cancelled => 'ملغي',
        _                       => s,
      };

  DSBadgeVariant _variant(String s) => switch (s) {
        RequestStatus.pending   => DSBadgeVariant.warning,
        RequestStatus.accepted  => DSBadgeVariant.success,
        'completed'             => DSBadgeVariant.info,
        RequestStatus.cancelled => DSBadgeVariant.error,
        _                       => DSBadgeVariant.neutral,
      };
}
