import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/locale_provider.dart';
import '../../design_system/design_system.dart';

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
            message: locale.languageCode == 'ar' ? 'Switch to English' : 'التبديل إلى العربية',
            child: DSIconButton(
              icon: Icons.translate_rounded,
              onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
            ),
          ),
          const SizedBox(width: DSSpacing.sm),
          DSIconButton(
            icon: Icons.notifications_none_rounded,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
