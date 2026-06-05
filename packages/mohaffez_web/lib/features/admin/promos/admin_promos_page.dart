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
                onPressed: () => _openCreate(context, ref),
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
                initialSortKey: 'code',
                columns: [
                  DSColumnDef(
                    key: 'code',
                    label: 'الكود',
                    sortable: true,
                    sortValue: (p) => (p['code'] as String? ?? '').toLowerCase(),
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
                    sortable: true,
                    sortValue: (p) => (p['usedCount'] as num?)?.toInt() ?? 0,
                    cellBuilder: (ctx, p) {
                      final used  = (p['usedCount'] as num?)?.toInt() ?? 0;
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
                    width: 56,
                    cellBuilder: (ctx, p) => _PromoActions(promo: p),
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

  void _openCreate(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _PromoFormDialog(ref: ref),
    );
  }
}

class _PromoActions extends ConsumerWidget {
  const _PromoActions({required this.promo});
  final Map<String, dynamic> promo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = promo['id'] as String? ?? '';
    final code = promo['code'] as String? ?? '';
    final active = promo['isActive'] as bool? ?? false;

    return DSDropdownMenu(
      items: [
        DSDropdownItem(
          label: active ? 'تعطيل' : 'تفعيل',
          icon: active ? Icons.pause_circle_outline : Icons.play_circle_outline,
          onTap: () async {
            await ref
                .read(adminActionsProvider.notifier)
                .togglePromoCode(id, !active);
            if (!context.mounted) return;
            _toast(context, ref, active ? 'تم التعطيل' : 'تم التفعيل');
          },
        ),
        DSDropdownItem(
          label: 'حذف',
          icon: Icons.delete_outline_rounded,
          onTap: () async {
            final ok = await DSDialog.confirm(
              context,
              title: 'حذف الكود',
              message: 'حذف الكود "$code" نهائيًا؟',
              confirmLabel: 'حذف',
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            await ref.read(adminActionsProvider.notifier).deletePromoCode(id);
            if (!context.mounted) return;
            _toast(context, ref, 'تم حذف الكود');
          },
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(DSSpacing.xs),
        child: Icon(Icons.more_vert_rounded, size: 18, color: DSColors.text2),
      ),
    );
  }

  void _toast(BuildContext context, WidgetRef ref, String msg) {
    final state = ref.read(adminActionsProvider);
    state.when(
      data: (_) => DSToast.show(context, msg, type: DSToastType.success),
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
    );
  }
}

class _PromoFormDialog extends StatefulWidget {
  const _PromoFormDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_PromoFormDialog> createState() => _PromoFormDialogState();
}

class _PromoFormDialogState extends State<_PromoFormDialog> {
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _limit = TextEditingController();
  String _type = 'percent';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim().toUpperCase();
    final value = double.tryParse(_value.text.trim());
    if (code.isEmpty || value == null || value <= 0) {
      setState(() => _error = 'أدخل كودًا وقيمة خصم صحيحة');
      return;
    }
    if (_type == 'percent' && value > 100) {
      setState(() => _error = 'نسبة الخصم لا تتجاوز 100%');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final limit = int.tryParse(_limit.text.trim());
    await widget.ref.read(adminActionsProvider.notifier).createPromoCode({
      'code': code,
      'discountType': _type,
      'discountValue': value,
      if (limit != null) 'usageLimit': limit,
      'isActive': true,
    });
    if (!mounted) return;
    final state = widget.ref.read(adminActionsProvider);
    state.when(
      data: (_) {
        Navigator.of(context).pop();
        DSToast.show(context, 'تم إنشاء الكود', type: DSToastType.success);
      },
      loading: () {},
      error: (e, _) => setState(() {
        _saving = false;
        _error = 'فشل الإنشاء: $e';
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSDialog(
      title: 'كود خصم جديد',
      actions: [
        DSButton(
          label: 'إلغاء',
          variant: DSButtonVariant.ghost,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        DSButton(
          label: _saving ? 'جاري الحفظ…' : 'إنشاء',
          onPressed: _saving ? null : _submit,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DSTextField(controller: _code, label: 'الكود', hint: 'مثال: RAMADAN25', autofocus: true),
          const SizedBox(height: DSSpacing.md),
          DSSelect<String>(
            label: 'نوع الخصم',
            value: _type,
            items: const [
              DSSelectItem(value: 'percent', label: 'نسبة مئوية (%)'),
              DSSelectItem(value: 'fixed', label: 'مبلغ ثابت (ج.م)'),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'percent'),
          ),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: _value,
            label: _type == 'percent' ? 'قيمة الخصم (%)' : 'قيمة الخصم (ج.م)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: _limit,
            label: 'حد الاستخدام (اختياري)',
            hint: 'اتركه فارغًا لعدد غير محدود',
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: DSSpacing.md),
            Text(_error!, style: DSText.caption(context, color: DSColors.error)),
          ],
        ],
      ),
    );
  }
}
