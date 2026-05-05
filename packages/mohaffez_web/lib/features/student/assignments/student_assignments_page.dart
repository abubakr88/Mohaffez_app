import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class StudentAssignmentsPage extends ConsumerWidget {
  const StudentAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid       = ref.watch(authProvider).user?.uid ?? '';
    final surahsAsync = ref.watch(memorizedSurahsProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'مهامي',
            subtitle: 'متابعة مهام الحفظ والمراجعة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          surahsAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (surahs) {
              if (surahs.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد مهام بعد',
                  subtitle: 'ستظهر مهام الحفظ من محفظك هنا',
                  icon: Icons.assignment_outlined,
                );
              }
              return DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'السور المحفوظة'),
                    const SizedBox(height: DSSpacing.lg),
                    Wrap(
                      spacing: DSSpacing.sm,
                      runSpacing: DSSpacing.sm,
                      children: surahs.map((n) => DSBadge(
                        label: 'سورة $n',
                        variant: DSBadgeVariant.success,
                      )).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
