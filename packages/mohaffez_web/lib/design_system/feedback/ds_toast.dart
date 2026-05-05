import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

enum DSToastType { success, error, warning, info }

class DSToast extends StatelessWidget {
  const DSToast({
    super.key,
    required this.message,
    this.type = DSToastType.info,
    this.onDismiss,
  });

  final String message;
  final DSToastType type;
  final VoidCallback? onDismiss;

  (Color, Color, IconData) get _config => switch (type) {
        DSToastType.success => (DSColors.successBg, DSColors.success, Icons.check_circle_outline_rounded),
        DSToastType.error   => (DSColors.errorBg, DSColors.error, Icons.error_outline_rounded),
        DSToastType.warning => (DSColors.warningBg, DSColors.warning, Icons.warning_amber_rounded),
        DSToastType.info    => (DSColors.infoBg, DSColors.info, Icons.info_outline_rounded),
      };

  static void show(
    BuildContext context,
    String message, {
    DSToastType type = DSToastType.info,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(DSSpacing.xl),
        content: DSToast(message: message, type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _config;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.lg,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DSRadius.lgAll,
        border: Border.all(color: fg.withValues(alpha: 0.3)),
        boxShadow: DSElevation.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: DSSpacing.sm),
          Expanded(child: Text(message, style: DSText.body(context, color: fg))),
          if (onDismiss != null) ...[
            const SizedBox(width: DSSpacing.sm),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: fg.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }
}
