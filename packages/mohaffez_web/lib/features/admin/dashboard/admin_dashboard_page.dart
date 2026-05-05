import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync    = ref.watch(allUsersProvider(null));
    final pendingAsync  = ref.watch(pendingCredentialsProvider);
    final promosAsync   = ref.watch(allPromoCodesProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: 'لوحة الإدارة', subtitle: 'نظرة عامة على النظام'),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            children: [
              usersAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (u) => DSStatCard(
                  label: 'إجمالي المستخدمين',
                  value: '${u.length}',
                  icon: Icons.people_outline_rounded,
                ),
              ),
              pendingAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (p) => DSStatCard(
                  label: 'طلبات التحقق',
                  value: '${p.length}',
                  icon: Icons.verified_user_outlined,
                  iconColor: DSColors.warning,
                ),
              ),
              promosAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (pr) => DSStatCard(
                  label: 'أكواد الخصم',
                  value: '${pr.length}',
                  icon: Icons.discount_outlined,
                  iconColor: DSColors.secondary,
                ),
              ),
              const DSStatCard(
                label: 'حالة النظام',
                value: 'نشط',
                icon: Icons.check_circle_outline_rounded,
                iconColor: DSColors.success,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            tabletColumns: 1,
            desktopColumns: 2,
            children: [
              _PendingVerificationsCard(),
              _RecentUsersCard(),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingVerificationsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingCredentialsProvider);
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'طلبات التحقق المعلقة'),
          const SizedBox(height: DSSpacing.lg),
          async.when(
            loading: () => const Column(children: [DSSkeleton(height: 56), SizedBox(height: 8), DSSkeleton(height: 56)]),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(title: 'لا توجد طلبات معلقة', icon: Icons.verified_user_outlined);
              }
              return Column(
                children: items.take(4).map((item) => _VerificationTile(item: item)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VerificationTile extends StatelessWidget {
  const _VerificationTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? item['mohaffezName'] as String? ?? 'مستخدم';
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(DSSpacing.md),
        decoration: const BoxDecoration(
          color: DSColors.surfaceMuted,
          borderRadius: DSRadius.mdAll,
          border: Border.fromBorderSide(BorderSide(color: DSColors.border)),
        ),
        child: Row(
          children: [
            DSAvatar(name: name, size: 36),
            const SizedBox(width: DSSpacing.md),
            Expanded(child: Text(name, style: DSText.bodyMedium(context))),
            DSButton(label: 'مراجعة', size: DSButtonSize.sm, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}

class _RecentUsersCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allUsersProvider(null));
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المستخدمون الجدد'),
          const SizedBox(height: DSSpacing.lg),
          async.when(
            loading: () => const Column(children: [DSSkeleton(height: 56), SizedBox(height: 8), DSSkeleton(height: 56)]),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (users) {
              if (users.isEmpty) return const DSEmptyState(title: 'لا يوجد مستخدمون', icon: Icons.people_outline_rounded);
              return Column(
                children: users.take(5).map((u) => _UserTile(user: u)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name  = user['name'] as String? ?? '—';
    final role  = user['role'] as String? ?? 'student';
    final photo = user['photoUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.sm),
      child: Row(
        children: [
          DSAvatar(name: name, imageUrl: photo, size: 36),
          const SizedBox(width: DSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: DSText.bodyMedium(context)),
                Text(role, style: DSText.caption(context, color: DSColors.text3)),
              ],
            ),
          ),
          DSBadge(
            label: role == 'mohaffez' ? 'محفظ' : role == 'admin' ? 'مدير' : 'طالب',
            variant: role == 'mohaffez' ? DSBadgeVariant.primary : DSBadgeVariant.neutral,
          ),
        ],
      ),
    );
  }
}
