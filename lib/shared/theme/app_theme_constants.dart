import 'package:flutter/material.dart';

/// Centralized theme constants following Material Design 3.
/// Single source of truth for design tokens.
class AppThemeConstants {
  AppThemeConstants._();

  // Color palette
  static const Color primaryAmber = Color.fromARGB(255, 196, 143, 64);
  static const Color primaryAmberDark = Color.fromARGB(255, 163, 109, 56);
  static const Color primaryAmberLight = Color.fromARGB(255, 179, 125, 45);

  static const Color accentGreen = Color(0xFF66BB6A);
  static const Color accentGreenDark = Color(0xFF388E3C);
  static const Color accentGreenLight = Color(0xFF81C784);

  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceWhite = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Colors.white;

  // Spacing (8pt grid)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;
  static const double space3xl = 64.0;

  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusRound = 999.0;

  static const BorderRadius borderRadiusXs = BorderRadius.all(Radius.circular(radiusXs));
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusRound = BorderRadius.all(Radius.circular(radiusRound));

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationXs = 1.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // Typography
  static const TextStyle displayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, height: 1.12);
  static const TextStyle displayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.16);
  static const TextStyle displaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.22);

  static const TextStyle headlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.25);
  static const TextStyle headlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.29);
  static const TextStyle headlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.33);

  static const TextStyle titleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.27);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, height: 1.50);
  static const TextStyle titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.43);

  static const TextStyle bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.50);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.43);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33);

  static const TextStyle labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.43);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.33);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.45);

  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double icon2xl = 64.0;
  static const double icon3xl = 80.0;

  // Button dimensions
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 48.0;
  static const double buttonHeightLarge = 56.0;

  static const double buttonMinWidthSmall = 64.0;
  static const double buttonMinWidthMedium = 88.0;
  static const double buttonMinWidthLarge = 120.0;

  static const EdgeInsets buttonPaddingSmall = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  static const EdgeInsets buttonPaddingMedium = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets buttonPaddingLarge = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

  // Container sizes
  static const double cardMinHeight = 120.0;
  static const double listItemHeight = 72.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 80.0;

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // Opacity values
  static const double opacityDisabled = 0.38;
  static const double opacityHover = 0.04;
  static const double opacityFocus = 0.12;
  static const double opacitySelected = 0.08;
  static const double opacityPressed = 0.12;
}