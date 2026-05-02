import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync    = ref.watch(allUsersProvider(null));
    final pendingAsync  = ref.watch(pendingCredentialsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'التقارير',
            subtitle: 'إحصائيات وتحليلات المنصة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            children: [
              usersAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (users) {
                  final teachers = users.where((u) => u['role'] == 'mohaffez').length;
                  final students = users.where((u) => u['role'] == 'student').length;
                  return DSCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'توزيع المستخدمين'),
                        const SizedBox(height: DSSpacing.lg),
                        DSProgressBar(
                          value: users.isEmpty ? 0 : teachers / users.length,
                          label: 'محفظون ($teachers)',
                          color: DSColors.primary,
                          showPercent: true,
                        ),
                        const SizedBox(height: DSSpacing.md),
                        DSProgressBar(
                          value: users.isEmpty ? 0 : students / users.length,
                          label: 'طلاب ($students)',
                          color: DSColors.success,
                          showPercent: true,
                        ),
                      ],
                    ),
                  );
                },
              ),
              pendingAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (p) => DSStatCard(
                  label: 'طلبات التحقق المعلقة',
                  value: '${p.length}',
                  icon: Icons.pending_actions_outlined,
                  iconColor: DSColors.warning,
                ),
              ),
              usersAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (u) => DSStatCard(
                  label: 'إجمالي المستخدمين',
                  value: '${u.length}',
                  icon: Icons.people_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          const DSCard(
            child: DSEmptyState(
              title: 'تقارير تفصيلية قريباً',
              subtitle: 'سيتم إضافة تقارير الجلسات والمدفوعات في التحديث القادم',
              icon: Icons.bar_chart_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
