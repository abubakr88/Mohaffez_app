import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSProgressBar extends StatelessWidget {
  const DSProgressBar({
    super.key,
    required this.value,
    this.label,
    this.color,
    this.height = 8.0,
    this.showPercent = false,
  });

  final double value; // 0.0 – 1.0
  final String? label;
  final Color? color;
  final double height;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? DSColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || showPercent) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(label!, style: DSText.caption(context, color: DSColors.text2)),
              if (showPercent)
                Text(
                  '${(value * 100).round()}%',
                  style: DSText.caption(context, color: DSColors.text2),
                ),
            ],
          ),
          const SizedBox(height: DSSpacing.xs),
        ],
        ClipRRect(
          borderRadius: DSRadius.fullAll,
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: DSColors.border,
            valueColor: AlwaysStoppedAnimation(fg),
          ),
        ),
      ],
    );
  }
}
