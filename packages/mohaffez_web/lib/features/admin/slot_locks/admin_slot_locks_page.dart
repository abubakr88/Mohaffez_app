import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminSlotLocksPage extends ConsumerStatefulWidget {
  const AdminSlotLocksPage({super.key});

  @override
  ConsumerState<AdminSlotLocksPage> createState() => _AdminSlotLocksPageState();
}

class _AdminSlotLocksPageState extends ConsumerState<AdminSlotLocksPage> {
  bool _releasing = false;

  Future<void> _releaseExpired() async {
    final ok = await DSDialog.confirm(
      context,
      title: 'تحرير الأقفال المنتهية',
      message:
          'سيتم تحرير جميع أقفال الفترات منتهية الصلاحية حتى تتاح للحجز من جديد. متابعة؟',
      confirmLabel: 'تحرير',
    );
    if (!ok || !mounted) return;
    setState(() => _releasing = true);
    await ref.read(adminActionsProvider.notifier).releaseAllExpiredLocks();
    if (!mounted) return;
    setState(() => _releasing = false);
    final state = ref.read(adminActionsProvider);
    state.when(
      data: (_) =>
          DSToast.show(context, 'تم تحرير الأقفال المنتهية', type: DSToastType.success),
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locksAsync = ref.watch(activeSlotLocksProvider);
    final now = DateTime.now();

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeader(
                  title: 'إدارة قفل الفترات',
                  subtitle: 'الفترات المحجوزة مؤقتًا أثناء عملية الحجز',
                ),
              ),
              DSButton(
                label: _releasing ? 'جاري التحرير…' : 'تحرير المنتهية',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.secondary,
                leading: _releasing
                    ? null
                    : const Icon(Icons.lock_open_rounded, size: 16),
                onPressed: _releasing ? null : _releaseExpired,
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.xxl),
          locksAsync.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (locks) {
              final expired = locks
                  .where((l) => _isExpired(l['expiresAt'], now))
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DSGrid(
                    mobileColumns: 1,
                    tabletColumns: 3,
                    desktopColumns: 3,
                    children: [
                      DSStatCard(
                        label: 'أقفال نشطة',
                        value: '${locks.length}',
                        icon: Icons.lock_clock_outlined,
                        iconColor: DSColors.primary,
                      ),
                      DSStatCard(
                        label: 'منتهية الصلاحية',
                        value: '$expired',
                        icon: Icons.timer_off_outlined,
                        iconColor:
                            expired > 0 ? DSColors.warning : DSColors.success,
                      ),
                      DSStatCard(
                        label: 'سارية',
                        value: '${locks.length - expired}',
                        icon: Icons.verified_outlined,
                        iconColor: DSColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: DSSpacing.xxl),
                  if (locks.isEmpty)
                    const DSCard(
                      child: DSEmptyState(
                        title: 'لا توجد أقفال نشطة',
                        subtitle: 'كل الفترات متاحة للحجز حاليًا',
                        icon: Icons.lock_open_outlined,
                      ),
                    )
                  else
                    DSDataTable<Map<String, dynamic>>(
                      initialSortKey: 'expires',
                      columns: [
                        DSColumnDef(
                          key: 'slot',
                          label: 'الفترة',
                          sortable: true,
                          sortValue: (l) =>
                              _toDate(l['slotStart'] ?? l['slotDate'])
                                  ?.millisecondsSinceEpoch ??
                              0,
                          cellBuilder: (ctx, l) {
                            final dt = _toDate(l['slotStart'] ?? l['slotDate']);
                            return Text(
                              dt == null
                                  ? '—'
                                  : DateFormat('dd/MM/yyyy • HH:mm', 'ar')
                                      .format(dt),
                              style: DSText.bodyMedium(ctx),
                            );
                          },
                        ),
                        DSColumnDef(
                          key: 'mohaffez',
                          label: 'المحفظ',
                          cellBuilder: (ctx, l) => Text(
                            (l['mohaffezId'] ?? '—').toString(),
                            style: DSText.body(ctx, color: DSColors.text2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DSColumnDef(
                          key: 'student',
                          label: 'الطالب',
                          cellBuilder: (ctx, l) => Text(
                            (l['studentId'] ?? '—').toString(),
                            style: DSText.body(ctx, color: DSColors.text2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DSColumnDef(
                          key: 'expires',
                          label: 'تنتهي',
                          width: 150,
                          sortable: true,
                          sortValue: (l) =>
                              _toDate(l['expiresAt'])?.millisecondsSinceEpoch ??
                              0,
                          cellBuilder: (ctx, l) {
                            final dt = _toDate(l['expiresAt']);
                            return Text(
                              dt == null
                                  ? '—'
                                  : DateFormat('dd/MM HH:mm', 'ar').format(dt),
                              style: DSText.body(ctx, color: DSColors.text2),
                            );
                          },
                        ),
                        DSColumnDef(
                          key: 'status',
                          label: 'الحالة',
                          width: 100,
                          cellBuilder: (ctx, l) {
                            final exp = _isExpired(l['expiresAt'], now);
                            return DSBadge(
                              label: exp ? 'منتهٍ' : 'ساري',
                              variant: exp
                                  ? DSBadgeVariant.warning
                                  : DSBadgeVariant.success,
                              dot: true,
                            );
                          },
                        ),
                      ],
                      rows: locks,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  static bool _isExpired(dynamic expiresAt, DateTime now) {
    final dt = _toDate(expiresAt);
    return dt != null && dt.isBefore(now);
  }
}
