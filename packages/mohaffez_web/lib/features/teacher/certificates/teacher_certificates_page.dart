import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherCertificatesPage extends ConsumerWidget {
  const TeacherCertificatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid          = ref.watch(authProvider).user?.uid ?? '';
    final studentsAsync = ref.watch(mohaffezStudentsProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'الشهادات',
            subtitle: 'شهادات الحفظ الممنوحة لطلابك',
          ),
          const SizedBox(height: DSSpacing.xxl),
          studentsAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (students) {
              final certified = students.where((s) => s.hifzAssignment.isNotEmpty).toList();
              if (certified.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد شهادات بعد',
                  subtitle: 'ستظهر شهادات الطلاب الذين أكملوا مهام الحفظ هنا',
                  icon: Icons.workspace_premium_outlined,
                );
              }
              return Column(
                children: [
                  DSGrid(
                    mobileColumns: 1,
                    tabletColumns: 2,
                    desktopColumns: 3,
                    children: certified.map((s) => _CertificateCard(student: s)).toList(),
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

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.student});
  final MohaffezStudentSummary student;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DSAvatar(name: student.studentName, size: 40),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.studentName, style: DSText.bodyMedium(context)),
                    Text(
                      '${student.sessionCount} جلسة مكتملة',
                      style: DSText.caption(context, color: DSColors.text3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.workspace_premium_rounded, color: DSColors.secondary, size: 24),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: DSSpacing.sm),
            decoration: const BoxDecoration(
              color: DSColors.surfaceMuted,
              borderRadius: DSRadius.smAll,
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 14, color: DSColors.primary),
                const SizedBox(width: DSSpacing.xs),
                Expanded(
                  child: Text(
                    student.hifzAssignment,
                    style: DSText.caption(context, color: DSColors.text2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DSSpacing.md),
          SizedBox(
            width: double.infinity,
            child: DSButton(
              label: 'طباعة الشهادة',
              variant: DSButtonVariant.ghost,
              leading: const Icon(Icons.print_outlined, size: 14),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
