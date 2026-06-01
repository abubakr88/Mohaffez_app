import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/design_system.dart';
import '../../features/auth/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.path,
    this.matchPrefix = false,
  });
  final IconData icon;
  final String label;
  final String path;
  final bool matchPrefix;
}

class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({
    super.key,
    required this.items,
    this.bottomItems = const [],
    this.roleLabel,
  });

  final List<SidebarItem> items;
  final List<SidebarItem> bottomItems;
  final String? roleLabel;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = _collapsed ? 64.0 : 240.0;
    final location = GoRouterState.of(context).uri.toString();

    return AnimatedContainer(
      duration: DSDuration.base,
      width: width,
      child: Container(
        decoration: const BoxDecoration(
          color: DSColors.surfaceSidebar,
          border: Border(right: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          children: [
            _buildLogo(context),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: DSSpacing.sm),
                children: widget.items
                    .map((item) => _buildItem(context, item, location))
                    .toList(),
              ),
            ),
            if (widget.bottomItems.isNotEmpty) ...[
              const Divider(height: 1, color: Colors.white12),
              ...widget.bottomItems.map((item) => _buildItem(context, item, location)),
            ],
            const Divider(height: 1, color: Colors.white12),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: DSRadius.mdAll,
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
          ),
          if (!_collapsed) ...[
            const SizedBox(width: DSSpacing.sm),
            Expanded(
              child: Text(
                'محفظي',
                style: DSText.h3(context, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          GestureDetector(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Icon(
              _collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              color: Colors.white54,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, SidebarItem item, String location) {
    final active = item.matchPrefix
        ? location.startsWith(item.path)
        : location == item.path || location.startsWith('${item.path}/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DSSpacing.sm, vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go(item.path),
          child: AnimatedContainer(
            duration: DSDuration.fast,
            padding: EdgeInsets.symmetric(
              horizontal: _collapsed ? DSSpacing.sm : DSSpacing.md,
              vertical: DSSpacing.md,
            ),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: DSRadius.mdAll,
            ),
            child: Row(
              mainAxisAlignment:
                  _collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: active ? Colors.white : Colors.white70,
                ),
                if (!_collapsed) ...[
                  const SizedBox(width: DSSpacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: DSText.body(
                        context,
                        color: active ? Colors.white : Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.all(DSSpacing.sm),
        child: DSIconButton(
          icon: Icons.logout_rounded,
          color: Colors.white70,
          onPressed: () => ref.read(authProvider.notifier).signOut(),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(DSSpacing.md),
      child: Row(
        children: [
          const DSAvatar(size: 32, color: DSColors.secondary),
          const SizedBox(width: DSSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.user?.phoneNumber ?? '',
                  style: DSText.caption(context, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.roleLabel != null)
                  Text(
                    widget.roleLabel!,
                    style: DSText.micro(context, color: Colors.white54),
                  ),
              ],
            ),
          ),
          DSIconButton(
            icon: Icons.logout_rounded,
            color: Colors.white54,
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
