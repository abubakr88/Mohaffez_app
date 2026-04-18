import 'package:flutter/material.dart';
import '../theme/app_theme_constants.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const AdminAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: AppThemeConstants.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }
}
