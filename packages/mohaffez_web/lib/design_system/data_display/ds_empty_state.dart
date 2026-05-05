import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';
import '../buttons/ds_button.dart';

class DSEmptyState extends StatelessWidget {
  const DSEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DSSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(DSSpacing.xl),
              decoration: const BoxDecoration(
                color: DSColors.surfaceMuted,
                borderRadius: DSRadius.fullAll,
              ),
              child: Icon(icon, size: 40, color: DSColors.text3),
            ),
            const SizedBox(height: DSSpacing.lg),
            Text(title, style: DSText.h3(context, color: DSColors.text1)),
            if (subtitle != null) ...[
              const SizedBox(height: DSSpacing.xs),
              Text(
                subtitle!,
                style: DSText.body(context, color: DSColors.text2),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DSSpacing.xl),
              DSButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
