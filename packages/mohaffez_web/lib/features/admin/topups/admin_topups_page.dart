import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

/// Admin queue for manual wallet top-up requests (pendingTopUpsProvider).
/// اعتماد → verifyWalletTopUp (credits the wallet) · رفض → rejectWalletTopUp.
class AdminTopUpsPage extends ConsumerWidget {
  const AdminTopUpsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingTopUpsProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'طلبات الشحن',
            subtitle: 'مراجعة واعتماد طلبات شحن المحافظ',
          ),
          const SizedBox(height: DSSpacing.xxl),
          async.when(
            loading: () => const DSSkeletonCard(),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد طلبات شحن معلّقة',
                  subtitle: 'ستظهر طلبات شحن المحافظ هنا للمراجعة',
                  icon: Icons.account_balance_wallet_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${items.length} طلب بانتظار المراجعة',
                      style: DSText.caption(context, color: DSColors.text3)),
                  const SizedBox(height: DSSpacing.md),
                  ...items.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: DSSpacing.lg),
                        child: _TopUpCard(topup: t),
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

class _TopUpCard extends ConsumerWidget {
  const _TopUpCard({required this.topup});
  final Map<String, dynamic> topup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = topup['id'] as String? ?? '';
    final userId = topup['userId'] as String? ?? '';
    final amount = (topup['amountEgp'] as num?)?.toDouble() ?? 0;
    final method = topup['method'] as String? ?? '';
    final reference = topup['referenceNumber'] as String? ?? '—';
    final ownerType = topup['ownerType'] as String? ?? 'student';
    final proofUrl = topup['proofUrl'] as String?;

    // Resolve the requester's name (cached per user).
    final userAsync = ref.watch(adminUserProvider(userId));
    final name = userAsync.maybeWhen(
      data: (u) => (u?['name'] as String?) ?? '—',
      orElse: () => '…',
    );

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DSAvatar(name: name == '…' ? '؟' : name, size: 40),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                            child: Text(name,
                                style: DSText.bodyMedium(context),
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: DSSpacing.sm),
                        DSBadge(
                            label: ownerType == 'mohaffez' ? 'محفظ' : 'طالب',
                            variant: ownerType == 'mohaffez'
                                ? DSBadgeVariant.primary
                                : DSBadgeVariant.neutral),
                      ],
                    ),
                    Text('طُلب في ${_date(topup['createdAt'])}',
                        style:
                            DSText.caption(context, color: DSColors.text3)),
                  ],
                ),
              ),
              Text(_money(amount), style: DSText.h3(context)),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          const Divider(height: 1, color: DSColors.border),
          const SizedBox(height: DSSpacing.lg),
          _row(context, 'الوسيلة', _methodLabel(method)),
          _row(context, 'الرقم المرجعي', reference),
          if (proofUrl != null && proofUrl.isNotEmpty) ...[
            const SizedBox(height: DSSpacing.sm),
            Text('إثبات التحويل',
                style: DSText.caption(context, color: DSColors.text2)),
            const SizedBox(height: DSSpacing.sm),
            _Proof(url: proofUrl),
          ],
          const SizedBox(height: DSSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DSButton(
                label: 'رفض',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.destructive,
                onPressed: () => _reject(context, ref, id, name),
              ),
              const SizedBox(width: DSSpacing.sm),
              DSButton(
                label: 'اعتماد الشحن',
                size: DSButtonSize.sm,
                onPressed: () => _verify(context, ref, id, name, amount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _verify(BuildContext context, WidgetRef ref, String id,
      String name, double requested) async {
    final controller =
        TextEditingController(text: requested.toStringAsFixed(0));
    final ok = await DSDialog.show<bool>(
      context,
      title: 'اعتماد الشحن',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سيتم شحن محفظة "$name". أكّد المبلغ الفعلي المُحوَّل:',
              style: DSText.body(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: controller,
            label: 'المبلغ (ج.م)',
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false)),
        DSButton(
            label: 'اعتماد',
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true)),
      ],
    );
    if (ok != true || !context.mounted) return;
    final entered = double.tryParse(controller.text.trim());
    // Only send an override when it differs from the requested amount.
    final override =
        (entered != null && entered > 0 && entered != requested) ? entered : null;
    await ref
        .read(adminActionsProvider.notifier)
        .verifyTopUp(id, paidAmountEgp: override);
    if (!context.mounted) return;
    _toast(context, ref, 'تم اعتماد الشحن');
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final controller = TextEditingController();
    final ok = await DSDialog.show<bool>(
      context,
      title: 'رفض الطلب',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سيتم إشعار "$name" بسبب الرفض.',
              style: DSText.body(context, color: DSColors.text2)),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: controller,
            label: 'سبب الرفض',
            hint: 'مثال: لم نستلم التحويل، الرقم المرجعي غير صحيح',
            maxLines: 2,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        DSButton(
            label: 'إلغاء',
            variant: DSButtonVariant.ghost,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false)),
        DSButton(
            label: 'رفض',
            variant: DSButtonVariant.destructive,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true)),
      ],
    );
    if (ok != true || !context.mounted) return;
    final reason = controller.text.trim().isEmpty
        ? 'تعذّر التحقق من التحويل'
        : controller.text.trim();
    await ref.read(adminActionsProvider.notifier).rejectTopUp(id, reason);
    if (!context.mounted) return;
    _toast(context, ref, 'تم رفض الطلب');
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

  static String _date(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = v is DateTime ? v : (v as dynamic).toDate() as DateTime;
      return DateFormat('dd/MM/yyyy', 'ar').format(dt);
    } catch (_) {
      return '—';
    }
  }

  static String _methodLabel(String m) => switch (m) {
        'instapay' => 'إنستا باي',
        'vodafone_cash' => 'فودافون كاش',
        'bank_transfer' => 'تحويل بنكي',
        _ => m,
      };
}

class _Proof extends StatelessWidget {
  const _Proof({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.85),
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(DSSpacing.xxl),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: DSRadius.mdAll,
          child: Container(
            width: 96,
            height: 96,
            color: DSColors.surfaceMuted,
            child: Image.network(url, fit: BoxFit.cover,
                errorBuilder: (ctx, _, __) => const Icon(
                    Icons.broken_image_outlined,
                    color: DSColors.text3)),
          ),
        ),
      ),
    );
  }
}
