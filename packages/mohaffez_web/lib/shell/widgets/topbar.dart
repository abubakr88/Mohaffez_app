import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import '../../config/locale_provider.dart';
import '../../design_system/design_system.dart';
import '../../features/auth/auth_provider.dart' as auth;

class AppTopbar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopbar({
    super.key,
    required this.title,
    this.actions,
  });

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: DSColors.surface,
        border: Border(bottom: BorderSide(color: DSColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DSSpacing.xl),
      child: Row(
        children: [
          Text(title, style: DSText.h3(context)),
          const Spacer(),
          if (actions != null) ...actions!,
          const SizedBox(width: DSSpacing.sm),
          DSTooltip(
            message: locale.languageCode == 'ar'
                ? 'Switch to English'
                : 'التبديل إلى العربية',
            child: DSIconButton(
              icon: Icons.translate_rounded,
              onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
            ),
          ),
          const SizedBox(width: DSSpacing.sm),
          const _NotificationsBell(),
        ],
      ),
    );
  }
}

class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(auth.authProvider).user?.uid;
    if (uid == null) {
      return DSIconButton(
          icon: Icons.notifications_none_rounded, onPressed: () {});
    }

    final unread = ref.watch(unreadNotificationsCountProvider(uid)).value ?? 0;
    final notifsAsync = ref.watch(notificationsFirstPageProvider(uid));

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(DSColors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: DSRadius.lgAll),
        ),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      menuChildren: [
        SizedBox(
          width: 360,
          child: _Panel(notifsAsync: notifsAsync),
        ),
      ],
      builder: (context, controller, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          DSIconButton(
            icon: Icons.notifications_none_rounded,
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
          if (unread > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: DSColors.error,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.notifsAsync});
  final AsyncValue<List<NotificationModel>> notifsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(DSSpacing.md),
            child: Text('الإشعارات', style: DSText.bodyMedium(context)),
          ),
          const Divider(height: 1, color: DSColors.border),
          Flexible(
            child: notifsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(DSSpacing.xl),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: DSColors.primary))),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(DSSpacing.lg),
                child: Text('تعذّر تحميل الإشعارات',
                    style: DSText.caption(context, color: DSColors.text3)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(DSSpacing.xl),
                    child: Text('لا توجد إشعارات',
                        textAlign: TextAlign.center,
                        style: DSText.caption(context, color: DSColors.text3)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: DSColors.border),
                  itemBuilder: (ctx, i) => _NotifTile(notif: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends ConsumerWidget {
  const _NotifTile({required this.notif});
  final NotificationModel notif;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notif.isRead;

    return InkWell(
      onTap: () async {
        final id = notif.id;
        if (!isRead && id != null && id.isNotEmpty) {
          await ref
              .read(notificationActionsProvider)
              .markAsRead(notif.userId, id);
        }
        if (!context.mounted) return;
        final dest = _routeForType(notif.type);
        if (dest != null) context.go(dest);
      },
      child: Container(
        color: isRead ? null : DSColors.primary.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(DSSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: isRead ? Colors.transparent : DSColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DSSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.title,
                      style: DSText.bodyMedium(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (notif.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notif.body,
                        style: DSText.caption(context, color: DSColors.text2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(_time(notif.createdAt),
                      style: DSText.caption(context, color: DSColors.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _routeForType(String type) => switch (type) {
        'payout_requested' => '/admin/payouts',
        'credential_pending' || 'teacher_pending' => '/admin/approvals',
        'topup_requested' => '/admin/topups',
        'admin_payment_failed' => '/admin/payment-events',
        'admin_wallet_negative' => '/admin/users',
        _ => null,
      };

  static String _time(DateTime? dt) =>
      dt == null ? '' : DateFormat('dd/MM HH:mm', 'ar').format(dt);
}
