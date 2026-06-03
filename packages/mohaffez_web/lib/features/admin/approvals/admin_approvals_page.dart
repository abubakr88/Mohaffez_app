import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(
                  title: 'لا توجد طلبات معلقة',
                  subtitle: 'ستظهر طلبات المحفظين الجدد هنا للمراجعة',
                  icon: Icons.verified_user_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${items.length} طلب بانتظار المراجعة',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.md),
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: DSSpacing.lg),
                        child: _CredentialCard(item: item),
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

class _CredentialCard extends ConsumerWidget {
  const _CredentialCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = item['userId'] as String? ?? '';
    final credentialId = item['id'] as String? ?? '';
    final name = item['name'] as String? ??
        item['mohaffezName'] as String? ??
        'محفظ';
    final title = item['title'] as String? ?? '—';
    final org = item['organization'] as String? ?? '';
    final type = item['type'] as String? ?? '';
    final images = (item['imageUrls'] as List?)?.cast<String>() ?? const [];

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: teacher + type badge
          Row(
            children: [
              DSAvatar(name: name, size: 40),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DSText.bodyMedium(context)),
                    Text('تاريخ التقديم: ${_date(item['uploadedAt'] ?? item['createdAt'])}',
                        style: DSText.caption(context, color: DSColors.text3)),
                  ],
                ),
              ),
              if (type.isNotEmpty)
                DSBadge(label: _typeLabel(type), variant: DSBadgeVariant.primary),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          const Divider(height: 1, color: DSColors.border),
          const SizedBox(height: DSSpacing.lg),

          // Details
          _DetailRow(label: 'اسم الوثيقة', value: title),
          if (org.isNotEmpty) _DetailRow(label: 'الجهة المانحة', value: org),
          _DetailRow(label: 'تاريخ الإصدار', value: _date(item['issueDate'])),
          if (item['expiryDate'] != null)
            _DetailRow(
                label: 'تاريخ الانتهاء', value: _date(item['expiryDate'])),

          // Document images
          if (images.isNotEmpty) ...[
            const SizedBox(height: DSSpacing.lg),
            Text('المستندات (${images.length})',
                style: DSText.caption(context, color: DSColors.text2)),
            const SizedBox(height: DSSpacing.sm),
            Wrap(
              spacing: DSSpacing.sm,
              runSpacing: DSSpacing.sm,
              children: images
                  .map((url) => _Thumbnail(
                        url: url,
                        onTap: () => _openViewer(context, images, url),
                      ))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: DSSpacing.lg),
            Text('لم يُرفق أي مستند',
                style: DSText.caption(context, color: DSColors.text3)),
          ],

          const SizedBox(height: DSSpacing.lg),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DSButton(
                label: 'رفض',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.destructive,
                onPressed: () =>
                    _reject(context, ref, userId, credentialId, name),
              ),
              const SizedBox(width: DSSpacing.sm),
              DSButton(
                label: 'قبول',
                size: DSButtonSize.sm,
                onPressed: () =>
                    _approve(context, ref, userId, credentialId, name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String userId,
      String credentialId, String name) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'قبول الوثيقة',
      message: 'اعتماد وثيقة "$name"؟ سيتم إشعار المحفظ بالقبول.',
      confirmLabel: 'قبول',
    );
    if (!ok || !context.mounted) return;
    await ref
        .read(adminActionsProvider.notifier)
        .approveCredential(userId, credentialId);
    if (!context.mounted) return;
    _toastResult(context, ref, 'تم اعتماد الوثيقة');
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, String userId,
      String credentialId, String name) async {
    final controller = TextEditingController();
    final ok = await DSDialog.show<bool>(
      context,
      title: 'رفض الوثيقة',
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
            hint: 'مثال: الصورة غير واضحة، الوثيقة منتهية…',
            maxLines: 3,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        DSButton(
          label: 'إلغاء',
          variant: DSButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        DSButton(
          label: 'رفض',
          variant: DSButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (ok != true || !context.mounted) return;
    final reason = controller.text.trim().isEmpty
        ? 'لم تستوفِ الوثيقة المتطلبات'
        : controller.text.trim();
    await ref
        .read(adminActionsProvider.notifier)
        .rejectCredential(userId, credentialId, reason);
    if (!context.mounted) return;
    _toastResult(context, ref, 'تم رفض الوثيقة');
  }

  void _toastResult(BuildContext context, WidgetRef ref, String successMsg) {
    final state = ref.read(adminActionsProvider);
    state.when(
      data: (_) => DSToast.show(context, successMsg, type: DSToastType.success),
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل العملية: $e', type: DSToastType.error),
    );
  }

  void _openViewer(BuildContext context, List<String> images, String current) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _ImageViewer(images: images, initial: current),
    );
  }

  static String _date(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = v is DateTime ? v : (v as dynamic).toDate() as DateTime;
      return DateFormat('dd/MM/yyyy', 'ar').format(dt);
    } catch (_) {
      return '—';
    }
  }

  static String _typeLabel(String type) => switch (type) {
        'certificate' => 'شهادة',
        'ijazah' => 'إجازة',
        'diploma' => 'دبلوم',
        'degree' => 'مؤهل علمي',
        _ => type,
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DSSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: DSText.caption(context, color: DSColors.text3)),
          ),
          Expanded(
            child: Text(value, style: DSText.body(context)),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: DSRadius.mdAll,
          child: Container(
            width: 88,
            height: 88,
            color: DSColors.surfaceMuted,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: DSColors.primary),
                      ),
                    ),
              errorBuilder: (ctx, _, __) => const Icon(
                  Icons.broken_image_outlined,
                  color: DSColors.text3),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});
  final List<String> images;
  final String initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late int _index = widget.images.indexOf(widget.initial).clamp(0, widget.images.length - 1);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(DSSpacing.xxl),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.network(widget.images[_index], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.images.length > 1) ...[
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 32),
                  onPressed: () => setState(() =>
                      _index = (_index + 1) % widget.images.length),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: Colors.white, size: 32),
                  onPressed: () => setState(() => _index =
                      (_index - 1 + widget.images.length) %
                          widget.images.length),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
