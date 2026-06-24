import 'package:flutter/material.dart';

class FoundingTeacherBadge extends StatelessWidget {
  const FoundingTeacherBadge({
    super.key,
    this.enabled = true,
    this.compact = true,
    this.showLabel = true,
    this.useFullLabel = false,
    this.size = 20,
    this.semanticLabel,
    this.onTap,
    this.showTooltip = true,
  });

  static const assetPath = 'assets/badges/founding_teacher_badge.png';

  final bool enabled;
  final bool compact;
  final bool showLabel;
  final bool useFullLabel;
  final double size;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final bool showTooltip;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? 'المحفّظ المؤسس' : 'Founding Teacher';
    final shortTitle = isArabic ? 'مؤسس' : 'Founding';
    final description = isArabic
        ? 'من أوائل المحفظين المنضمين إلى محفّظي خلال مرحلة الإطلاق الأولى.'
        : 'One of the first teachers to join Mohafezy during its initial launch phase.';

    final icon = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.workspace_premium_rounded,
        size: size,
        color: const Color(0xFFE8A020),
      ),
    );

    final content = compact
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 7 : 4,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE8A020).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Text(
                    useFullLabel ? title : shortTitle,
                    style: const TextStyle(
                      color: Color(0xFF085041),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCF7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE8A020).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF085041),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF52605C),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    final interactiveContent = onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: content,
          );

    return Semantics(
      label: semanticLabel ?? title,
      button: onTap != null,
      child: showTooltip
          ? Tooltip(message: title, child: interactiveContent)
          : interactiveContent,
    );
  }
}
