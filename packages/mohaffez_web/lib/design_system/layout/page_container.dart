import 'package:flutter/material.dart';
import '../tokens.dart';
import '../../config/breakpoints.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1280.0,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bp = Breakpoints.of(context);
    final hPad = switch (bp) {
      Breakpoint.mobile  => DSSpacing.lg,
      Breakpoint.tablet  => DSSpacing.xl,
      Breakpoint.desktop => DSSpacing.xxl,
      Breakpoint.wide    => DSSpacing.xxxl,
    };

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: padding ??
                EdgeInsets.symmetric(horizontal: hPad, vertical: DSSpacing.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}
