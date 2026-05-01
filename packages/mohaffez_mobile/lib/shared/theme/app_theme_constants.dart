import 'package:flutter/material.dart';

/// Centralized theme constants following Material Design 3.
/// Teal/Green Islamic theme matching LoginScreen design.
class AppThemeConstants {
  AppThemeConstants._();

  // ─── Primary Colors (Teal Gradient from Login) ────────────────────────────
  static const Color deepTeal = Color(0xFF0B4A4A);          // Darkest teal
  static const Color midTeal = Color(0xFF0D5C5C);           // Mid teal
  static const Color primary = Color(0xFF0B7A75);           // Primary teal (from login)
  static const Color primaryVariant = Color(0xFF14B8A6);      // Light teal
  static const Color onPrimary = Colors.white;

  // ─── Secondary Colors (Soft Gold from Login) ─────────────────────────────
  static const Color secondary = Color(0xFFD4A44A);         // Soft gold
  static const Color secondaryContainer = Color(0xFFFDF5E6); // Light cream/gold bg
  static const Color onSecondary = Color(0xFF1E2933);

  // ─── Accent & Background Colors ──────────────────────────────────────────
  static const Color accentBackground = Color(0xFFE8F4F3);  // Pale teal-gray
  static const Color background = Color(0xFFF5FAF9);          // Very light teal tint
  static const Color surface = Colors.white;
  static const Color surfaceCream = Color(0xFFFDF9F3);       // Cream card background

  // ─── Text Colors ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E2933);       // Dark bluish gray
  static const Color textSecondary = Color(0xFF6B7280);     // Medium gray
  static const Color textMuted = Color(0xFF9CA3AF);         // From login
  static const Color textDisabled = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // ─── Semantic Colors ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successBackground = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFEA580C);
  static const Color warningBackground = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0B7A75);

  // ─── Utility Colors ──────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);           // Very subtle shadow

  // ─── Pure neutrals (use these instead of Colors.white/black/transparent) ──
  // Centralized so a future dark-mode / rebrand only needs to flip these
  // here, never in screens.
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;

  // Material's opacity-named neutral aliases (kept as named constants so
  // screens never reach for `Colors.white70` etc).
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color black54 = Color(0x8A000000);
  static const Color black87 = Color(0xDD000000);

  // ─── Greys (Material-equivalent neutral scale) ───────────────────────────
  static const Color grey50  = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // ─── Semantic light/dark variants ────────────────────────────────────────
  // Used for lighter chip backgrounds and stronger headline accents.
  static const Color successLight = Color(0xFFDCFCE7); // alias of successBackground
  static const Color successDark  = Color(0xFF15803D);
  static const Color errorLight   = Color(0xFFFEE2E2); // alias of errorBackground
  static const Color errorDark    = Color(0xFF991B1B);
  static const Color warningLight = Color(0xFFFFF3E0); // alias of warningBackground
  static const Color warningDark  = Color(0xFFC2410C);
  static const Color infoLight    = Color(0xFFE3F2FD);
  static const Color infoDark     = Color(0xFF1E40AF);

  // ─── Accent palette (per-domain UI: badges, chips, info cards) ───────────
  static const Color accentPurple     = Color(0xFF7A5AF8);
  static const Color accentPurpleLight = Color(0xFFF0EEFF);
  static const Color accentPurpleDark  = Color(0xFF5B3FB8);
  static const Color accentBlue        = Color(0xFF2563EB);
  static const Color accentBlueLight   = Color(0xFFE3F2FD);
  static const Color accentBlueDark    = Color(0xFF1E40AF);
  static const Color accentAmber       = Color(0xFFFFB300);
  static const Color accentAmberLight  = Color(0xFFFFF8E1);
  static const Color accentAmberDark   = Color(0xFFFF8F00);
  static const Color accentOrange      = Color(0xFFE67E22);
  static const Color accentOrangeLight = Color(0xFFFFF3E0);
  static const Color accentOrangeDark  = Color(0xFFC2410C);
  static const Color accentRed         = Color(0xFFE53935);
  static const Color accentRedLight    = Color(0xFFFFEBEE);
  static const Color accentRedDark     = Color(0xFFB91C1C);
  static const Color accentGreenAlt    = Color(0xFF2E8B57);
  static const Color accentGreenAltLight = Color(0xFFE8F5E9);
  static const Color accentGreenAltDark  = Color(0xFF1B5E20);

  // ─── Legacy aliases for backwards compatibility ─────────────────────────
  @Deprecated('Use deepTeal instead')
  static const Color primaryTeal = deepTeal;
  @Deprecated('Use primary instead')
  static const Color primaryAmber = primary;
  @Deprecated('Use primaryVariant instead')
  static const Color primaryAmberDark = primaryVariant;
  @Deprecated('Use primaryVariant instead')
  static const Color primaryAmberLight = primaryVariant;
  @Deprecated('Use secondary instead')
  static const Color accentGreen = secondary;
  @Deprecated('Use secondary instead')
  static const Color accentGreenDark = secondary;
  @Deprecated('Use secondary instead')
  static const Color accentGreenLight = secondary;
  @Deprecated('Use background instead')
  static const Color backgroundLight = background;
  @Deprecated('Use surface instead')
  static const Color surfaceWhite = surface;
  @Deprecated('Use surfaceCream instead')
  static const Color surfaceLight = surfaceCream;

  // ─── Gradient for AppBar/Backgrounds ─────────────────────────────────────
  static const List<Color> tealGradient = [deepTeal, midTeal, primary];

  // Spacing (8pt grid)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;
  static const double space3xl = 64.0;

  // ─── Border radius (8-12px per spec) ─────────────────────────────────────
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

  // ─── Elevation (very light as per spec) ─────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationXs = 1.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 3.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // ─── Typography (matching spec: Cairo/IBM Plex Sans Arabic) ───────────────
  // Titles (H1/H2 / main screen titles): 20–22, semi-bold
  static const TextStyle displayLarge = TextStyle(
    fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.2, color: textPrimary,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.25, color: textPrimary,
  );
  static const TextStyle displaySmall = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.3, color: textPrimary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.25, color: textPrimary,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.3, color: textPrimary,
  );
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0, height: 1.35, color: textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.27, color: textPrimary,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15, height: 1.50, color: textPrimary,
  );
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.43, color: textPrimary,
  );

  // Body/description: 13–14, regular
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.50, color: textSecondary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.43, color: textSecondary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33, color: textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.43, color: textPrimary,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.33, color: textSecondary,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, height: 1.45, color: textSecondary,
  );

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
