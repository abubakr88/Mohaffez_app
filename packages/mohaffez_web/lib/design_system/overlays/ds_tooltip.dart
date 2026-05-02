import 'package:flutter/material.dart';
import '../colors.dart';
import '../tokens.dart';
import '../typography.dart';

class DSTooltip extends StatelessWidget {
  const DSTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      decoration: BoxDecoration(
        color: DSColors.text1,
        borderRadius: DSRadius.smAll,
        boxShadow: DSElevation.sm,
      ),
      textStyle: DSText.caption(context, color: Colors.white),
      waitDuration: DSDuration.slow,
      child: child,
    );
  }
}
