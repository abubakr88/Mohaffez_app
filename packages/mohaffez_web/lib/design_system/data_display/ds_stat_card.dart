import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';
import 'ds_card.dart';

class DSStatCard extends StatelessWidget {
  const DSStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.trend,
    this.trendPositive,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final String? trend;
  final bool? trendPositive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DSCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DSText.caption(context, color: DSColors.text2),
                ),
              ),
              if (icon != null)
                Container(
                  margin: const EdgeInsetsDirectional.only(start: DSSpacing.sm),
                  padding: const EdgeInsets.all(DSSpacing.sm),
                  decoration: BoxDecoration(
                    color:
                        (iconColor ?? DSColors.primary).withValues(alpha: 0.1),
                    borderRadius: DSRadius.mdAll,
                  ),
                  child: Icon(icon,
                      size: 18, color: iconColor ?? DSColors.primary),
                ),
              if (onTap != null) ...[
                const SizedBox(width: DSSpacing.xs),
                const Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: DSColors.text3,
                ),
              ],
            ],
          ),
          const SizedBox(height: DSSpacing.sm),
          Text(value, style: DSText.h1(context)),
          if (trend != null) ...[
            const SizedBox(height: DSSpacing.xs),
            Row(
              children: [
                Icon(
                  trendPositive == true
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 14,
                  color:
                      trendPositive == true ? DSColors.success : DSColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  trend!,
                  style: DSText.caption(
                    context,
                    color: trendPositive == true
                        ? DSColors.success
                        : DSColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
