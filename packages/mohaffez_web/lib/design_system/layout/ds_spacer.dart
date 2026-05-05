import 'package:flutter/material.dart';
import '../tokens.dart';

class DSSpacer {
  DSSpacer._();
  static const Widget xs   = SizedBox(height: DSSpacing.xs,   width: DSSpacing.xs);
  static const Widget sm   = SizedBox(height: DSSpacing.sm,   width: DSSpacing.sm);
  static const Widget md   = SizedBox(height: DSSpacing.md,   width: DSSpacing.md);
  static const Widget lg   = SizedBox(height: DSSpacing.lg,   width: DSSpacing.lg);
  static const Widget xl   = SizedBox(height: DSSpacing.xl,   width: DSSpacing.xl);
  static const Widget xxl  = SizedBox(height: DSSpacing.xxl,  width: DSSpacing.xxl);
  static const Widget xxxl = SizedBox(height: DSSpacing.xxxl, width: DSSpacing.xxxl);

  static Widget h(double height) => SizedBox(height: height);
  static Widget w(double width)  => SizedBox(width: width);
}
