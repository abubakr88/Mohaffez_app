import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class TeacherPricingPage extends ConsumerWidget {
  const TeacherPricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid   = ref.watch(authProvider).user?.uid ?? '';
    final async = ref.watch(pricingPlansProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'التسعير',
            subtitle: 'إدارة باقاتك وأسعارك',
            actions: [
              DSButton(
                label: 'إضافة باقة',
                leading: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                onPressed: () => _showAddDialog(context, ref, uid),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          async.when(
            loading: () => const DSGrid(
              desktopColumns: 3,
              children: [DSSkeletonCard(), DSSkeletonCard(), DSSkeletonCard()],
            ),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (plans) {
              if (plans.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد باقات بعد',
                  subtitle: 'أضف باقتك الأولى لتبدأ في قبول الطلاب',
                  icon: Icons.sell_outlined,
                );
              }
              return DSGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 3,
                children: plans.map((p) => _PlanCard(plan: p, uid: uid)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, String uid) {
    DSDialog.show(
      context,
      title: 'إضافة باقة جديدة',
      child: Text('سيتم إضافة نموذج الباقة هنا', style: DSText.body(context, color: DSColors.text2)),
      actions: [
        DSButton(
          label: 'إغلاق',
          variant: DSButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan, required this.uid});
  final PricingPlanModel plan;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.title, style: DSText.h3(context))),
              DSBadge(
                label: plan.isActive ? 'نشط' : 'معطل',
                variant: plan.isActive ? DSBadgeVariant.success : DSBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.md),
          if (plan.description != null && plan.description!.isNotEmpty)
            Text(plan.description!, style: DSText.body(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.lg),
          const Divider(color: DSColors.border),
          const SizedBox(height: DSSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${plan.priceEGP.toStringAsFixed(0)} ج.م', style: DSText.h2(context, color: DSColors.primary)),
                  Text('${plan.sessionsCount} جلسة', style: DSText.caption(context, color: DSColors.text2)),
                ],
              ),
              Row(
                children: [
                  DSIconButton(
                    icon: Icons.edit_rounded,
                    variant: DSIconButtonVariant.outlined,
                    onPressed: () {},
                    tooltip: 'تعديل',
                  ),
                  const SizedBox(width: DSSpacing.xs),
                  DSIconButton(
                    icon: Icons.delete_outline_rounded,
                    color: DSColors.error,
                    onPressed: () => _confirmDelete(context, ref),
                    tooltip: 'حذف',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DSDialog.confirm(
      context,
      title: 'حذف الباقة',
      message: 'هل أنت متأكد من حذف "${plan.title}"؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(pricingActionsProvider.notifier).deletePlan(uid, plan.id ?? '');
      if (context.mounted) DSToast.show(context, 'تم حذف الباقة', type: DSToastType.success);
    } catch (e) {
      if (context.mounted) DSToast.show(context, 'خطأ: $e', type: DSToastType.error);
    }
  }
}
