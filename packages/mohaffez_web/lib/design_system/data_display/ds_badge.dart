import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

enum DSBadgeVariant { primary, success, warning, error, info, neutral }

class DSBadge extends StatelessWidget {
  const DSBadge({
    super.key,
    required this.label,
    this.variant = DSBadgeVariant.neutral,
    this.dot = false,
  });

  final String label;
  final DSBadgeVariant variant;
  final bool dot;

  (Color, Color) get _colors => switch (variant) {
        DSBadgeVariant.primary => (DSColors.primary.withValues(alpha: 0.1), DSColors.primary),
        DSBadgeVariant.success => (DSColors.successBg, DSColors.success),
        DSBadgeVariant.warning => (DSColors.warningBg, DSColors.warning),
        DSBadgeVariant.error   => (DSColors.errorBg, DSColors.error),
        DSBadgeVariant.info    => (DSColors.infoBg, DSColors.info),
        DSBadgeVariant.neutral => (DSColors.surfaceMuted, DSColors.text2),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DSSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: DSRadius.fullAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, borderRadius: DSRadius.fullAll),
            ),
            const SizedBox(width: 4),
          ],
          Text(label, style: DSText.micro(context, color: fg)),
        ],
      ),
    );
  }
}
