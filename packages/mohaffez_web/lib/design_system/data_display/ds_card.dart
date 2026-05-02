import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';

class DSCard extends StatelessWidget {
  const DSCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevation = true,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevation;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding ?? const EdgeInsets.all(DSSpacing.xl),
      decoration: BoxDecoration(
        color: color ?? DSColors.surface,
        borderRadius: DSRadius.lgAll,
        border: Border.all(color: DSColors.border),
        boxShadow: elevation ? DSElevation.sm : null,
      ),
      child: child,
    );

    if (onTap != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: card),
      );
    }

    return card;
  }
}
