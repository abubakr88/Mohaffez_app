import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherStudentsPage extends ConsumerWidget {
  const TeacherStudentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).user?.uid ?? '';
    final studentsAsync = ref.watch(mohaffezStudentsProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'طلابي', subtitle: 'جميع الطلاب الذين درّستهم'),
          const SizedBox(height: DSSpacing.xxl),
          studentsAsync.when(
            loading: () => const Column(children: [DSSkeletonCard(), SizedBox(height: DSSpacing.sm), DSSkeletonCard()]),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (students) {
              if (students.isEmpty) {
                return const DSEmptyState(
                  title: 'لا يوجد طلاب بعد',
                  subtitle: 'سيظهر طلابك هنا بعد قبول أول جلسة',
                  icon: Icons.people_outline_rounded,
                );
              }
              return DSDataTable<MohaffezStudentSummary>(
                columns: [
                  DSColumnDef(
                    key: 'name',
                    label: 'الطالب',
                    sortable: true,
                    cellBuilder: (ctx, s) => Row(
                      children: [
                        DSAvatar(name: s.studentName, size: 32),
                        const SizedBox(width: DSSpacing.sm),
                        Text(s.studentName, style: DSText.bodyMedium(ctx)),
                      ],
                    ),
                  ),
                  DSColumnDef(
                    key: 'sessions',
                    label: 'الجلسات',
                    width: 100,
                    cellBuilder: (ctx, s) => Text('${s.sessionCount}', style: DSText.body(ctx, color: DSColors.text2)),
                  ),
                  DSColumnDef(
                    key: 'hifz',
                    label: 'مهمة الحفظ',
                    cellBuilder: (ctx, s) => Text(
                      s.hifzAssignment.isEmpty ? '—' : s.hifzAssignment,
                      style: DSText.body(ctx, color: DSColors.text2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DSColumnDef(
                    key: 'date',
                    label: 'آخر جلسة',
                    width: 130,
                    cellBuilder: (ctx, s) => Text(
                      _fmt(s.lastSessionDate),
                      style: DSText.body(ctx, color: DSColors.text2),
                    ),
                  ),
                  DSColumnDef(
                    key: 'rating',
                    label: 'التقييم',
                    width: 100,
                    cellBuilder: (ctx, s) => Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: DSColors.secondary),
                        const SizedBox(width: 4),
                        Text('${s.sessionRating}/10', style: DSText.body(ctx, color: DSColors.text2)),
                      ],
                    ),
                  ),
                ],
                rows: students,
              );
            },
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}
