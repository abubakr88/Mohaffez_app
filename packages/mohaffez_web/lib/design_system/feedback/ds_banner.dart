import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

enum DSBannerVariant { info, warning, error, success }

class DSBanner extends StatelessWidget {
  const DSBanner({
    super.key,
    required this.message,
    this.variant = DSBannerVariant.info,
    this.title,
    this.action,
    this.onDismiss,
  });

  final String message;
  final DSBannerVariant variant;
  final String? title;
  final Widget? action;
  final VoidCallback? onDismiss;

  (Color, Color, IconData) get _config => switch (variant) {
        DSBannerVariant.info    => (DSColors.infoBg, DSColors.info, Icons.info_outline_rounded),
        DSBannerVariant.warning => (DSColors.warningBg, DSColors.warning, Icons.warning_amber_rounded),
        DSBannerVariant.error   => (DSColors.errorBg, DSColors.error, Icons.error_outline_rounded),
        DSBannerVariant.success => (DSColors.successBg, DSColors.success, Icons.check_circle_outline_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _config;
    return Container(
      padding: const EdgeInsets.all(DSSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DSRadius.lgAll,
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: DSSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: DSText.bodyMedium(context, color: fg)),
                  const SizedBox(height: DSSpacing.xs),
                ],
                Text(message, style: DSText.body(context, color: fg.withValues(alpha: 0.85))),
                if (action != null) ...[
                  const SizedBox(height: DSSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
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
