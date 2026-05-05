import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminApprovalsPage extends ConsumerWidget {
  const AdminApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingCredentialsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'طلبات التحقق',
            subtitle: 'مراجعة وثائق المحفظين المتقدمين',
          ),
          const SizedBox(height: DSSpacing.xxl),
          async.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد طلبات معلقة',
                  subtitle: 'ستظهر طلبات المحفظين الجدد هنا للمراجعة',
                  icon: Icons.verified_user_outlined,
                );
              }
              return DSDataTable<Map<String, dynamic>>(
                columns: [
                  DSColumnDef(
                    key: 'name',
                    label: 'المحفظ',
                    cellBuilder: (ctx, item) {
                      final name = item['name'] as String? ?? item['mohaffezName'] as String? ?? 'مستخدم';
                      return Row(
                        children: [
                          DSAvatar(name: name, size: 32),
                          const SizedBox(width: DSSpacing.sm),
                          Text(name, style: DSText.bodyMedium(ctx)),
                        ],
                      );
                    },
                  ),
                  DSColumnDef(
                    key: 'date',
                    label: 'تاريخ الطلب',
                    width: 140,
                    cellBuilder: (ctx, item) {
                      final d = item['createdAt'];
                      if (d == null) return Text('—', style: DSText.body(ctx, color: DSColors.text2));
                      try {
                        final dt = d is DateTime ? d : (d as dynamic).toDate() as DateTime;
                        return Text('${dt.day}/${dt.month}/${dt.year}', style: DSText.body(ctx, color: DSColors.text2));
                      } catch (_) {
                        return Text('—', style: DSText.body(ctx, color: DSColors.text2));
                      }
                    },
                  ),
                  DSColumnDef(
                    key: 'actions',
                    label: 'الإجراء',
                    width: 200,
                    cellBuilder: (ctx, item) => Row(
                      children: [
                        DSButton(label: 'قبول',  size: DSButtonSize.sm, onPressed: () {}),
                        const SizedBox(width: DSSpacing.xs),
                        DSButton(label: 'رفض', size: DSButtonSize.sm, variant: DSButtonVariant.destructive, onPressed: () {}),
                      ],
                    ),
                  ),
                ],
                rows: items,
              );
            },
          ),
        ],
      ),
    );
  }
}
