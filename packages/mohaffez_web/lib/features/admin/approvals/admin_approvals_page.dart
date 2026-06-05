import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminApprovalsPage extends ConsumerWidget {
  const AdminApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingTeachersProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'طلبات التحقق',
            subtitle: 'مراجعة حسابات المحفظين المتقدمين واعتمادها',
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
                  subtitle: 'ستظهر حسابات المحفظين الجدد هنا للمراجعة',
                  icon: Icons.verified_user_outlined,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${items.length} محفظ بانتظار المراجعة',
                    style: DSText.caption(context, color: DSColors.text3),
                  ),
                  const SizedBox(height: DSSpacing.md),
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: DSSpacing.lg),
                        child: _TeacherCard(teacher: item),
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

class _TeacherCard extends ConsumerWidget {
  const _TeacherCard({required this.teacher});
  final Map<String, dynamic> teacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = teacher['id'] as String? ?? '';
    final name = teacher['name'] as String? ?? 'محفظ';
    final photo = teacher['photoUrl'] as String?;
    final specialization = teacher['specialization'] as String? ?? '';
    final bio = teacher['bio'] as String? ?? '';
    final videoUrl = teacher['youtubeVideoUrl'] as String? ?? '';

    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: teacher + status badge
          Row(
            children: [
              DSAvatar(name: name, imageUrl: photo, size: 40),
              const SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DSText.bodyMedium(context)),
                    Text(
                        'تاريخ التقديم: ${_date(teacher['approvalSubmittedAt'] ?? teacher['createdAt'])}',
                        style: DSText.caption(context, color: DSColors.text3)),
                  ],
                ),
              ),
              const DSBadge(
                  label: 'بانتظار المراجعة', variant: DSBadgeVariant.warning),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          const Divider(height: 1, color: DSColors.border),
          const SizedBox(height: DSSpacing.lg),

          // Profile details
          if (specialization.isNotEmpty)
            _DetailRow(label: 'التخصص', value: specialization),
          if (bio.isNotEmpty) _DetailRow(label: 'نبذة', value: bio),
          if (videoUrl.isNotEmpty)
            _DetailRow(label: 'فيديو تعريفي', value: videoUrl),

          // Submitted credentials
          const SizedBox(height: DSSpacing.lg),
          _CredentialsSection(userId: userId),

          const SizedBox(height: DSSpacing.lg),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DSButton(
                label: 'رفض',
                size: DSButtonSize.sm,
                variant: DSButtonVariant.destructive,
                onPressed: () => _reject(context, ref, userId, name),
              ),
              const SizedBox(width: DSSpacing.sm),
              DSButton(
                label: 'اعتماد الحساب',
                size: DSButtonSize.sm,
                onPressed: () => _approve(context, ref, userId, name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
      BuildContext context, WidgetRef ref, String userId, String name) async {
    final ok = await DSDialog.confirm(
      context,
      title: 'اعتماد الحساب',
      message:
          'اعتماد حساب "$name"؟ سيتمكّن من استقبال الطلاب وسيتم إشعاره بالقبول.',
      confirmLabel: 'اعتماد',
    );
    if (!ok || !context.mounted) return;
    await ref.read(adminActionsProvider.notifier).approveTeacher(userId);
    if (!context.mounted) return;
    _toastResult(context, ref, 'تم اعتماد الحساب');
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, String userId, String name) async {
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
            hint: 'مثال: الوثائق غير واضحة، البيانات غير مكتملة…',
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
        ? 'لم يستوفِ الطلب متطلبات التحقق'
        : controller.text.trim();
    await ref.read(adminActionsProvider.notifier).rejectTeacher(userId, reason);
    if (!context.mounted) return;
    _toastResult(context, ref, 'تم رفض الطلب');
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

  static String _date(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = v is DateTime ? v : (v as dynamic).toDate() as DateTime;
      return DateFormat('dd/MM/yyyy', 'ar').format(dt);
    } catch (_) {
      return '—';
    }
  }
}

/// Lists a pending teacher's submitted credentials with thumbnails.
class _CredentialsSection extends ConsumerWidget {
  const _CredentialsSection({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherCredentialsProvider(userId));
    return async.when(
      loading: () => Text('جارٍ تحميل الوثائق…',
          style: DSText.caption(context, color: DSColors.text3)),
      error: (e, _) => Text('تعذّر تحميل الوثائق',
          style: DSText.caption(context, color: DSColors.text3)),
      data: (creds) {
        final images = <String>[
          for (final c in creds)
            ...((c['imageUrls'] as List?)?.cast<String>() ?? const []),
        ];
        if (creds.isEmpty) {
          return Text('لم يُرفق أي وثيقة',
              style: DSText.caption(context, color: DSColors.text3));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الوثائق المقدّمة (${creds.length})',
                style: DSText.caption(context, color: DSColors.text2)),
            const SizedBox(height: DSSpacing.sm),
            ...creds.map((c) {
              final title = c['title'] as String? ?? '—';
              final org = c['organization'] as String? ?? '';
              final imgs =
                  (c['imageUrls'] as List?)?.cast<String>() ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: DSSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.isEmpty ? title : '$title — $org',
                        style: DSText.body(context, color: DSColors.text2)),
                    if (imgs.isNotEmpty) ...[
                      const SizedBox(height: DSSpacing.xs),
                      Wrap(
                        spacing: DSSpacing.sm,
                        runSpacing: DSSpacing.sm,
                        children: imgs
                            .map((url) => _Thumbnail(
                                  url: url,
                                  onTap: () =>
                                      _openViewer(context, images, url),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _openViewer(BuildContext context, List<String> images, String current) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _ImageViewer(images: images, initial: current),
    );
  }
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
