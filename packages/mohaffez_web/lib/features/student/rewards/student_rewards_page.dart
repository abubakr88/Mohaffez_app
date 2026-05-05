import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class StudentRewardsPage extends ConsumerWidget {
  const StudentRewardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid            = ref.watch(authProvider).user?.uid ?? '';
    final surahsAsync    = ref.watch(memorizedSurahsProvider(uid));
    final sessionsAsync  = ref.watch(studentCompletedSessionsProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'مكافآتي',
            subtitle: 'تتبع تقدمك في الحفظ',
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            children: [
              sessionsAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (count) => DSStatCard(
                  label: 'الجلسات المكتملة',
                  value: '$count',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: DSColors.success,
                ),
              ),
              surahsAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (surahs) => DSStatCard(
                  label: 'السور المحفوظة',
                  value: '${surahs.length}',
                  icon: Icons.menu_book_rounded,
                  iconColor: DSColors.primary,
                ),
              ),
              surahsAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (surahs) => DSStatCard(
                  label: 'نسبة الإنجاز',
                  value: '${((surahs.length / 114) * 100).round()}%',
                  icon: Icons.workspace_premium_outlined,
                  iconColor: DSColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          surahsAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (surahs) => DSCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'السور المحفوظة'),
                  const SizedBox(height: DSSpacing.lg),
                  if (surahs.isEmpty)
                    const DSEmptyState(
                      title: 'لا توجد سور محفوظة بعد',
                      subtitle: 'أكمل جلساتك لتُسجَّل سورك المحفوظة',
                      icon: Icons.menu_book_outlined,
                    )
                  else
                    DSProgressBar(
                      value: surahs.length / 114,
                      label: '${surahs.length} سورة من 114',
                      showPercent: true,
                      color: DSColors.primary,
                      height: 12,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
