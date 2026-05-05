import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';
import '../../../features/auth/auth_provider.dart';

class StudentSubscriptionsPage extends ConsumerWidget {
  const StudentSubscriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).user?.uid ?? '';
    final subsAsync = ref.watch(allStudentSubscriptionsProvider(uid));

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'اشتراكاتي',
            subtitle: 'إدارة باقات الجلسات الخاصة بك',
          ),
          const SizedBox(height: DSSpacing.xxl),
          subsAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (subs) {
              final active = subs.where((s) => s.isActive).toList();
              if (active.isEmpty) {
                return DSCard(
                  child: DSEmptyState(
                    title: 'لا يوجد اشتراك نشط',
                    subtitle: 'احجز باقة جلسات للحصول على سعر مخفّض',
                    icon: Icons.card_membership_outlined,
                    actionLabel: 'استعرض الباقات',
                    onAction: () {},
                  ),
                );
              }
              return Column(
                children: active.map((s) => _SubscriptionCard(sub: s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub});
  final SubscriptionModel sub;

  @override
  Widget build(BuildContext context) {
    final used      = sub.usedSessions;
    final total     = sub.totalSessions;
    final remaining = sub.remainingSessions;
    final progress  = total > 0 ? used / total : 0.0;

    return DSGrid(
      desktopColumns: 2,
      children: [
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SectionHeader(title: sub.planTitle)),
                  DSBadge(
                    label: sub.isActive ? 'نشط' : 'منتهي',
                    variant: sub.isActive ? DSBadgeVariant.success : DSBadgeVariant.neutral,
                    dot: true,
                  ),
                ],
              ),
              const SizedBox(height: DSSpacing.lg),
              Text(
                'متبقي $remaining من $total جلسة',
                style: DSText.body(context, color: DSColors.text2),
              ),
              const SizedBox(height: DSSpacing.lg),
              DSProgressBar(
                value: progress,
                label: 'الجلسات المستخدمة',
                showPercent: true,
              ),
              const SizedBox(height: DSSpacing.xl),
              if (sub.expiryDate != null)
                Text(
                  'تنتهي في: ${_fmt(sub.expiryDate)}',
                  style: DSText.caption(context, color: DSColors.text3),
                ),
            ],
          ),
        ),
        DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'تفاصيل الباقة'),
              const SizedBox(height: DSSpacing.xl),
              _DetailRow(label: 'إجمالي الجلسات', value: '$total'),
              _DetailRow(label: 'الجلسات المستخدمة', value: '$used'),
              _DetailRow(label: 'الجلسات المتبقية', value: '$remaining'),
              _DetailRow(label: 'المحفظ', value: sub.mohaffezName),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DSText.body(context, color: DSColors.text2)),
          Text(value, style: DSText.bodyMedium(context)),
        ],
      ),
    );
  }
}
