import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

/// Admin queue for teacher payout requests. Reuses the typed wallet layer
/// (activePayoutsProvider streams requested + processing requests). Drives the
/// backend state machine: requested → (بدء) processing → (تأكيد) completed |
/// (فشل) failed.
class AdminPayoutsPage extends ConsumerWidget {
  const AdminPayoutsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activePayoutsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'طلبات السحب',
            subtitle: 'مراجعة وتنفيذ طلبات سحب أرصدة المحفظين',
          ),
          const SizedBox(height: DSSpacing.xxl),
          async.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد طلبات سحب نشطة',
                  subtitle: 'ستظهر طلبات سحب المحفظين هنا للتنفيذ',
                  icon: Icons.account_balance_wallet_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${items.length} طلب بحاجة إلى إجراء',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.md),
                  ...items.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: DSSpacing.lg),
                        child: _PayoutCard(payout: p),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PayoutCard extends ConsumerWidget {
  const _PayoutCard({required this.payout});
  final PayoutRequestModel payout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = payout.id ?? '';
    final name = payout.mohaffezName.isEmpty ? 'محفظ' : payout.mohaffezName;

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DSAvatar(name: name, size: 40),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DSText.bodyMedium(context)),
                    Text('طُلب في ${_date(payout.createdAt)}',
                        style: DSText.caption(context, color: DSColors.text3)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(payout.amountEgp), style: DSText.h3(context)),
                  const SizedBox(height: DSSpacing.xs),
                  DSBadge(
                      label: _statusLabel(payout.status),
                      variant: _statusVariant(payout.status)),
                ],
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          const Divider(height: 1, color: DSColors.border),
          const SizedBox(height: DSSpacing.lg),
          _row(context, 'الوسيلة', _methodLabel(payout.method)),
          _row(context, 'بيانات الحساب', payout.accountDetails),
          const SizedBox(height: DSSpacing.lg),
          _actions(context, ref, id, name),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, String id, String name) {
    if (payout.status == PayoutStatus.requested) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DSButton(
            label: 'بدء التحويل',
            size: DSButtonSize.sm,
            onPressed: () => _start(context, ref, id, name),
          ),
        ],
      );
    }
    if (payout.status == PayoutStatus.processing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DSButton(
            label: 'تعذّر التحويل',
            size: DSButtonSize.sm,
            variant: DSButtonVariant.destructive,
            onPressed: () => _fail(context, ref, id, name),
          ),
          const SizedBox(width: DSSpacing.sm),
          DSButton(
            label: 'تأكيد التحويل',
            size: DSButtonSize.sm,
            onPressed: () => _complete(context, ref, id, name),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _start(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'بدء التحويل',
      message:
          'سيتم خصم ${_money(payout.amountEgp)} من محفظة "$name" والبدء بالتحويل إلى:\n${payout.accountDetails}\n\nأرسل الحوالة البنكية بعد ذلك ثم أكّد التحويل.',
      confirmLabel: 'بدء وخصم الرصيد',
    );
    if (!ok || !context.mounted) return;
    await ref.read(adminActionsProvider.notifier).startPayout(id);
    if (!context.mounted) return;
    _toast(context, ref, 'بدأ التحويل وتم خصم الرصيد');
  }

  Future<void> _complete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final controller = TextEditingController();
    final ok = await DSDialog.show<bool>(
      context,
      title: 'تأكيد التحويل',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تأكيد وصول الحوالة إلى "$name"؟',
              style: DSText.body(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: controller,
            label: 'مرجع التحويل (اختياري)',
            hint: 'رقم العملية البنكية',
          ),
        ],
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false)),
        DSButton(
            label: 'تأكيد', onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (ok != true || !context.mounted) return;
    await ref
        .read(adminActionsProvider.notifier)
        .completePayout(id, bankReference: controller.text.trim());
    if (!context.mounted) return;
    _toast(context, ref, 'تم تأكيد التحويل');
  }

  Future<void> _fail(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final controller = TextEditingController();
    final ok = await DSDialog.show<bool>(
      context,
      title: 'تعذّر التحويل',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سيُعاد الرصيد إلى محفظة "$name". وضّح سبب الفشل:',
              style: DSText.body(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: controller,
            label: 'سبب الفشل',
            hint: 'مثال: بيانات الحساب غير صحيحة',
            maxLines: 2,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false)),
        DSButton(
            label: 'تأكيد الفشل',
            variant: DSButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (ok != true || !context.mounted) return;
    final reason = controller.text.trim().isEmpty
        ? 'فشل التحويل البنكي'
        : controller.text.trim();
    await ref.read(adminActionsProvider.notifier).failPayout(id, reason);
    if (!context.mounted) return;
    _toast(context, ref, 'تم تسجيل فشل التحويل وإعادة الرصيد');
  }

  void _toast(BuildContext context, WidgetRef ref, String msg) {
    ref.read(adminActionsProvider).when(
          data: (_) => DSToast.show(context, msg, type: DSToastType.success),
          loading: () {},
          error: (e, _) =>
              DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
        );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: DSSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: DSText.caption(context, color: DSColors.text3))),
            Expanded(child: Text(value, style: DSText.body(context))),
          ],
        ),
      );

  static String _money(double v) =>
      '${NumberFormat('#,##0', 'en').format(v)} ج.م';

  static String _date(DateTime? dt) =>
      dt == null ? '—' : DateFormat('dd/MM/yyyy', 'ar').format(dt);

  static String _methodLabel(PayoutMethod m) => switch (m) {
        PayoutMethod.instapay => 'إنستا باي',
        PayoutMethod.vodafoneCash => 'فودافون كاش',
        PayoutMethod.bankTransfer => 'تحويل بنكي',
      };

  static String _statusLabel(PayoutStatus s) => switch (s) {
        PayoutStatus.requested => 'مطلوب',
        PayoutStatus.processing => 'قيد التنفيذ',
        PayoutStatus.completed => 'مكتمل',
        PayoutStatus.failed => 'فاشل',
      };

  static DSBadgeVariant _statusVariant(PayoutStatus s) => switch (s) {
        PayoutStatus.requested => DSBadgeVariant.warning,
        PayoutStatus.processing => DSBadgeVariant.info,
        PayoutStatus.completed => DSBadgeVariant.success,
        PayoutStatus.failed => DSBadgeVariant.error,
      };
}
