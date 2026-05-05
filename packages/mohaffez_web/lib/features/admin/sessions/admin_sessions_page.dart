import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminSessionsPage extends ConsumerWidget {
  const AdminSessionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider(null));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'الجلسات',
            subtitle: 'نظرة عامة على جلسات المنصة',
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
                data: (u) {
                  final teachers = u.where((x) => x['role'] == 'mohaffez').length;
                  return DSStatCard(
                    label: 'محفظون نشطون',
                    value: '$teachers',
                    icon: Icons.person_outline_rounded,
                    iconColor: DSColors.primary,
                  );
                },
              ),
              usersAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (u) {
                  final students = u.where((x) => x['role'] == 'student').length;
                  return DSStatCard(
                    label: 'طلاب مسجلون',
                    value: '$students',
                    icon: Icons.school_outlined,
                    iconColor: DSColors.secondary,
                  );
                },
              ),
              const DSStatCard(
                label: 'إجمالي الجلسات',
                value: '—',
                icon: Icons.calendar_month_outlined,
                iconColor: DSColors.success,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          const DSCard(
            child: DSEmptyState(
              title: 'تقارير الجلسات قريباً',
              subtitle: 'سيتم إضافة عرض تفصيلي لجميع جلسات المنصة في التحديث القادم',
              icon: Icons.calendar_today_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
