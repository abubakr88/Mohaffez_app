import 'package:flutter/material.dart';

enum Breakpoint { mobile, tablet, desktop, wide }

class Breakpoints {
  Breakpoints._();

  static const double mobileMax  = 640;
  static const double tabletMax  = 1024;
  static const double desktopMax = 1440;

  static Breakpoint of(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < mobileMax)  return Breakpoint.mobile;
    if (w < tabletMax)  return Breakpoint.tablet;
    if (w < desktopMax) return Breakpoint.desktop;
    return Breakpoint.wide;
  }

  static bool isMobile(BuildContext context)  => of(context) == Breakpoint.mobile;
  static bool isTablet(BuildContext context)   => of(context) == Breakpoint.tablet;
  static bool isDesktop(BuildContext context)  =>
      of(context) == Breakpoint.desktop || of(context) == Breakpoint.wide;
  static bool isWide(BuildContext context)     => of(context) == Breakpoint.wide;
}
