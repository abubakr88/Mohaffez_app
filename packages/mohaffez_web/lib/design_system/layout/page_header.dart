import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.breadcrumbs,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<String>? breadcrumbs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breadcrumbs != null && breadcrumbs!.isNotEmpty) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: breadcrumbs!.asMap().entries.expand((e) {
              final isLast = e.key == breadcrumbs!.length - 1;
              return [
                Text(
                  e.value,
                  style: DSText.caption(
                    context,
                    color: isLast ? DSColors.text1 : DSColors.text3,
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: DSSpacing.xs),
                    child: Icon(Icons.chevron_right_rounded, size: 14, color: DSColors.text3),
                  ),
              ];
            }).toList(),
          ),
          const SizedBox(height: DSSpacing.sm),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DSText.h1(context)),
                  if (subtitle != null) ...[
                    const SizedBox(height: DSSpacing.xs),
                    Text(subtitle!, style: DSText.body(context, color: DSColors.text2)),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: DSSpacing.lg),
              Row(
                children: actions!
                    .expand((a) => [a, const SizedBox(width: DSSpacing.sm)])
                    .toList()
                  ..removeLast(),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: DSText.h3(context))),
        if (trailing != null) trailing!,
      ],
    );
  }
}
