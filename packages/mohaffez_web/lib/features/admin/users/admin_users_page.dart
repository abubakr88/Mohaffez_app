import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider(null));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'المستخدمون',
            subtitle: 'إدارة جميع مستخدمي المنصة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          Row(
            children: [
              DSButton(label: 'الكل',    variant: DSButtonVariant.primary, onPressed: () {}),
              const SizedBox(width: DSSpacing.sm),
              DSButton(label: 'محفظون', variant: DSButtonVariant.ghost,   onPressed: () {}),
              const SizedBox(width: DSSpacing.sm),
              DSButton(label: 'طلاب',   variant: DSButtonVariant.ghost,   onPressed: () {}),
            ],
          ),
          const SizedBox(height: DSSpacing.xl),
          usersAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (users) {
              if (users.isEmpty) {
                return const DSEmptyState(
                  title: 'لا يوجد مستخدمون',
                  icon: Icons.people_outline_rounded,
                );
              }
              return DSDataTable<Map<String, dynamic>>(
                columns: [
                  DSColumnDef(
                    key: 'name',
                    label: 'الاسم',
                    sortable: true,
                    cellBuilder: (ctx, u) {
                      final name  = u['name']     as String? ?? '—';
                      final photo = u['photoUrl'] as String?;
                      return Row(
                        children: [
                          DSAvatar(name: name, imageUrl: photo, size: 32),
                          const SizedBox(width: DSSpacing.sm),
                          Text(name, style: DSText.bodyMedium(ctx)),
                        ],
                      );
                    },
                  ),
                  DSColumnDef(
                    key: 'role',
                    label: 'الدور',
                    width: 120,
                    cellBuilder: (ctx, u) {
                      final role = u['role'] as String? ?? 'student';
                      return DSBadge(
                        label: role == 'mohaffez' ? 'محفظ' : role == 'admin' ? 'مدير' : 'طالب',
                        variant: role == 'mohaffez' ? DSBadgeVariant.primary : DSBadgeVariant.neutral,
                      );
                    },
                  ),
                  DSColumnDef(
                    key: 'status',
                    label: 'الحالة',
                    width: 100,
                    cellBuilder: (ctx, u) {
                      final status = u['status'] as String? ?? 'active';
                      return DSBadge(
                        label: status == 'active' ? 'نشط' : 'معلق',
                        variant: status == 'active' ? DSBadgeVariant.success : DSBadgeVariant.warning,
                        dot: true,
                      );
                    },
                  ),
                  DSColumnDef(
                    key: 'joined',
                    label: 'تاريخ التسجيل',
                    width: 140,
                    cellBuilder: (ctx, u) {
                      final d = u['createdAt'];
                      String label = '—';
                      if (d != null) {
                        try {
                          final dt = d is DateTime ? d : (d as dynamic).toDate() as DateTime;
                          label = '${dt.day}/${dt.month}/${dt.year}';
                        } catch (_) {}
                      }
                      return Text(label, style: DSText.body(ctx, color: DSColors.text2));
                    },
                  ),
                  DSColumnDef(
                    key: 'actions',
                    label: '',
                    width: 80,
                    cellBuilder: (ctx, u) => DSIconButton(
                      icon: Icons.more_vert_rounded,
                      onPressed: () {},
                    ),
                  ),
                ],
                rows: users,
              );
            },
          ),
        ],
      ),
    );
  }
}
