import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminPromosPage extends ConsumerWidget {
  const AdminPromosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allPromoCodesProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'أكواد الخصم',
            subtitle: 'إنشاء وإدارة أكواد الخصم',
            actions: [
              DSButton(
                label: 'إضافة كود',
                leading: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          async.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (promos) {
              if (promos.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد أكواد خصم',
                  subtitle: 'أنشئ أول كود خصم لتشجيع التسجيل',
                  icon: Icons.discount_outlined,
                );
              }
              return DSDataTable<Map<String, dynamic>>(
                columns: [
                  DSColumnDef(
                    key: 'code',
                    label: 'الكود',
                    cellBuilder: (ctx, p) => Text(
                      p['code'] as String? ?? '—',
                      style: DSText.bodyMedium(ctx).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                  DSColumnDef(
                    key: 'discount',
                    label: 'الخصم',
                    width: 120,
                    cellBuilder: (ctx, p) {
                      final v = p['discountValue'];
                      final t = p['discountType'] as String? ?? 'fixed';
                      final label = t == 'percent'
                          ? '${v ?? 0}%'
                          : '${v ?? 0} ج.م';
                      return Text(label, style: DSText.body(ctx, color: DSColors.primary));
                    },
                  ),
                  DSColumnDef(
                    key: 'uses',
                    label: 'الاستخدامات',
                    width: 130,
                    cellBuilder: (ctx, p) {
                      final used  = p['usedCount'] as int? ?? 0;
                      final limit = p['usageLimit'];
                      return Text(
                        limit != null ? '$used / $limit' : '$used',
                        style: DSText.body(ctx, color: DSColors.text2),
                      );
                    },
                  ),
                  DSColumnDef(
                    key: 'active',
                    label: 'الحالة',
                    width: 100,
                    cellBuilder: (ctx, p) {
                      final active = p['isActive'] as bool? ?? false;
                      return DSBadge(
                        label: active ? 'نشط' : 'معطل',
                        variant: active ? DSBadgeVariant.success : DSBadgeVariant.neutral,
                        dot: true,
                      );
                    },
                  ),
                  DSColumnDef(
                    key: 'actions',
                    label: '',
                    width: 80,
                    cellBuilder: (ctx, p) => DSIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: DSColors.error,
                      onPressed: () {},
                    ),
                  ),
                ],
                rows: promos,
              );
            },
          ),
        ],
      ),
    );
  }
}
