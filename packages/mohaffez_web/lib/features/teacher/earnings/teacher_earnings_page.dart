import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherEarningsPage extends ConsumerWidget {
  const TeacherEarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid           = ref.watch(authProvider).user?.uid ?? '';
    final completedAsync = ref.watch(completedSessionsCountProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'الأرباح', subtitle: 'ملخص أرباحك ومدفوعاتك'),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            children: [
              completedAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (c) => DSStatCard(
                  label: 'جلسات مكتملة',
                  value: '$c',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: DSColors.success,
                ),
              ),
              const DSStatCard(
                label: 'إجمالي الأرباح',
                value: '—',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: DSColors.secondary,
              ),
              const DSStatCard(
                label: 'هذا الشهر',
                value: '—',
                icon: Icons.trending_up_rounded,
                iconColor: DSColors.primary,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          const DSCard(
            child: DSEmptyState(
              title: 'تفاصيل الأرباح قريباً',
              subtitle: 'سيتم إضافة تقارير مفصلة للأرباح في التحديث القادم',
              icon: Icons.bar_chart_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
