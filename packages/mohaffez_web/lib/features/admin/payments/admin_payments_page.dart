import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedAsync = ref.watch(failedOperationsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'المدفوعات',
            subtitle: 'مراقبة المدفوعات والعمليات الفاشلة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          DSGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            children: [
              failedAsync.when(
                loading: () => const DSSkeletonCard(),
                error:   (_, __) => const DSSkeletonCard(),
                data: (ops) => DSStatCard(
                  label: 'عمليات فاشلة',
                  value: '${ops.length}',
                  icon: Icons.error_outline_rounded,
                  iconColor: DSColors.error,
                ),
              ),
              const DSStatCard(
                label: 'إجمالي المدفوعات',
                value: '—',
                icon: Icons.payments_outlined,
                iconColor: DSColors.primary,
              ),
              const DSStatCard(
                label: 'إيرادات هذا الشهر',
                value: '—',
                icon: Icons.trending_up_rounded,
                iconColor: DSColors.success,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          failedAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) => DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (ops) {
              if (ops.isEmpty) {
                return const DSCard(
                  child: DSEmptyState(
                    title: 'لا توجد عمليات فاشلة',
                    subtitle: 'جميع عمليات الدفع تعمل بشكل طبيعي',
                    icon: Icons.check_circle_outline_rounded,
                  ),
                );
              }
              return DSCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'العمليات الفاشلة'),
                    const SizedBox(height: DSSpacing.lg),
                    DSDataTable<Map<String, dynamic>>(
                      columns: [
                        DSColumnDef(
                          key: 'type',
                          label: 'النوع',
                          cellBuilder: (ctx, op) => Text(
                            op['type'] as String? ?? op['operationType'] as String? ?? '—',
                            style: DSText.body(ctx),
                          ),
                        ),
                        DSColumnDef(
                          key: 'error',
                          label: 'الخطأ',
                          cellBuilder: (ctx, op) => Text(
                            op['error'] as String? ?? op['errorMessage'] as String? ?? '—',
                            style: DSText.body(ctx, color: DSColors.error),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DSColumnDef(
                          key: 'date',
                          label: 'التاريخ',
                          width: 140,
                          cellBuilder: (ctx, op) {
                            final d = op['timestamp'] ?? op['createdAt'];
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
                          label: '',
                          width: 80,
                          cellBuilder: (ctx, op) => DSIconButton(
                            icon: Icons.delete_outline_rounded,
                            color: DSColors.error,
                            onPressed: () {},
                          ),
                        ),
                      ],
                      rows: ops,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
