import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../../design_system/design_system.dart';

class AdminBroadcastPage extends ConsumerStatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  ConsumerState<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends ConsumerState<AdminBroadcastPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _target = 'all';
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      DSToast.show(context, 'يرجى إدخال العنوان والنص',
          type: DSToastType.error);
      return;
    }

    final audience =
        ref.read(broadcastAudienceCountProvider(_target)).valueOrNull;
    final audienceText = audience != null ? ' إلى $audience مستلم' : '';
    final ok = await DSDialog.confirm(
      context,
      title: 'إرسال الإشعار',
      message:
          'سيتم إرسال هذا الإشعار$audienceText (${_targetLabel(_target)}). متابعة؟',
      confirmLabel: 'إرسال',
    );
    if (!ok || !mounted) return;

    setState(() => _sending = true);
    await ref
        .read(systemConfigNotifierProvider.notifier)
        .sendBroadcastNotification(title, body, _target);
    if (!mounted) return;
    setState(() => _sending = false);

    final state = ref.read(systemConfigNotifierProvider);
    state.when(
      data: (_) {
        _title.clear();
        _body.clear();
        DSToast.show(context, 'تم إرسال الإشعار', type: DSToastType.success);
      },
      loading: () {},
      error: (e, _) =>
          DSToast.show(context, 'فشل الإرسال: $e', type: DSToastType.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audienceAsync = ref.watch(broadcastAudienceCountProvider(_target));
    final historyAsync = ref.watch(broadcastHistoryProvider);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'إشعارات جماعية',
            subtitle: 'إرسال إشعار لجميع المستخدمين أو فئة محددة',
          ),
          const SizedBox(height: DSSpacing.xxl),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final composer = _Composer(
                titleController: _title,
                bodyController: _body,
                target: _target,
                onTargetChanged: (v) => setState(() => _target = v),
                audienceAsync: audienceAsync,
                sending: _sending,
                onSend: _send,
              );
              final history = _HistoryCard(historyAsync: historyAsync);
              if (!wide) {
                return Column(
                  children: [
                    composer,
                    const SizedBox(height: DSSpacing.xl),
                    history,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: composer),
                  const SizedBox(width: DSSpacing.xl),
                  Expanded(flex: 2, child: history),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static String _targetLabel(String t) => switch (t) {
        'parent' => 'أولياء الأمور',
        'student' => 'الطلاب',
        'mohaffez' => 'المحفظون',
        _ => 'الجميع',
      };
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.titleController,
    required this.bodyController,
    required this.target,
    required this.onTargetChanged,
    required this.audienceAsync,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController titleController;
  final TextEditingController bodyController;
  final String target;
  final ValueChanged<String> onTargetChanged;
  final AsyncValue<int> audienceAsync;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'إنشاء إشعار'),
          const SizedBox(height: DSSpacing.lg),
          DSTextField(
            controller: titleController,
            label: 'عنوان الإشعار',
            hint: 'مثال: تحديث جديد متاح',
          ),
          const SizedBox(height: DSSpacing.md),
          DSTextField(
            controller: bodyController,
            label: 'نص الإشعار',
            hint: 'اكتب رسالتك هنا…',
            maxLines: 4,
          ),
          const SizedBox(height: DSSpacing.md),
          DSSelect<String>(
            label: 'الفئة المستهدفة',
            value: target,
            items: const [
              DSSelectItem(value: 'all', label: 'الجميع'),
              DSSelectItem(value: 'student', label: 'الطلاب'),
              DSSelectItem(value: 'parent', label: 'أولياء الأمور'),
              DSSelectItem(value: 'mohaffez', label: 'المحفظون'),
            ],
            onChanged: (v) => onTargetChanged(v ?? 'all'),
          ),
          const SizedBox(height: DSSpacing.md),
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 16, color: DSColors.text3),
              const SizedBox(width: DSSpacing.xs),
              audienceAsync.when(
                loading: () => Text('جاري حساب عدد المستلمين…',
                    style: DSText.caption(context, color: DSColors.text3)),
                error: (_, __) => Text('تعذّر حساب عدد المستلمين',
                    style: DSText.caption(context, color: DSColors.text3)),
                data: (count) => Text(
                  'سيصل إلى $count مستلم لديهم إشعارات مفعّلة',
                  style: DSText.caption(context, color: DSColors.text2),
                ),
              ),
            ],
          ),
          const SizedBox(height: DSSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DSButton(
              label: sending ? 'جاري الإرسال…' : 'إرسال الإشعار',
              leading: sending
                  ? null
                  : const Icon(Icons.send_rounded,
                      size: 16, color: Colors.white),
              onPressed: sending ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.historyAsync});
  final AsyncValue<List<BroadcastModel>> historyAsync;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'سجل الإرسال'),
          const SizedBox(height: DSSpacing.lg),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(DSSpacing.xl),
              child: Center(
                  child: CircularProgressIndicator(color: DSColors.primary)),
            ),
            error: (e, _) =>
                DSBanner(message: '$e', variant: DSBannerVariant.error),
            data: (items) {
              if (items.isEmpty) {
                return const DSEmptyState(
                  title: 'لم يتم إرسال أي إشعارات بعد',
                  icon: Icons.campaign_outlined,
                );
              }
              return Column(
                children: items
                    .map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: DSSpacing.md),
                          child: _HistoryItem(broadcast: b),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.broadcast});
  final BroadcastModel broadcast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: const BoxDecoration(
        color: DSColors.surfaceMuted,
        borderRadius: DSRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(broadcast.title,
                    style: DSText.bodyMedium(context),
                    overflow: TextOverflow.ellipsis),
              ),
              DSBadge(
                label: _targetLabel(broadcast.targetRole),
                variant: DSBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(broadcast.body,
              style: DSText.caption(context, color: DSColors.text2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: DSSpacing.sm),
          Row(
            children: [
              const Icon(Icons.people_alt_outlined,
                  size: 12, color: DSColors.text3),
              const SizedBox(width: 4),
              Text('${broadcast.recipientCount} مستلم',
                  style: DSText.micro(context, color: DSColors.text3)),
              const Spacer(),
              if (broadcast.sentAt != null)
                Text(
                  DateFormat('dd/MM HH:mm', 'ar').format(broadcast.sentAt!),
                  style: DSText.micro(context, color: DSColors.text3),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _targetLabel(String t) => switch (t) {
        'parent' => 'أولياء الأمور',
        'student' => 'الطلاب',
        'mohaffez' => 'المحفظون',
        _ => 'الجميع',
      };
}
