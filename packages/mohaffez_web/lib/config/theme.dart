import 'package:flutter/material.dart';
import '../design_system/colors.dart';
import '../design_system/tokens.dart';

class DSTheme {
  DSTheme._();

  static ThemeData light(Locale locale) {
    final isArabic = locale.languageCode == 'ar';
    final fontFamily = isArabic ? 'IBM Plex Sans Arabic' : 'Inter';

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: DSColors.surfaceMuted,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: DSColors.primary,
        onPrimary: Colors.white,
        primaryContainer: DSColors.primaryLight,
        onPrimaryContainer: Colors.white,
        secondary: DSColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFDF5E6),
        onSecondaryContainer: Color(0xFF1E2933),
        surface: DSColors.surface,
        onSurface: DSColors.text1,
        surfaceContainerHighest: DSColors.surfaceMuted,
        onSurfaceVariant: DSColors.text2,
        error: DSColors.error,
        onError: Colors.white,
        errorContainer: DSColors.errorBg,
        onErrorContainer: DSColors.error,
        outline: DSColors.border,
        shadow: Color(0x1A000000),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: DSColors.surface,
        foregroundColor: DSColors.text1,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: DSColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DSRadius.lgAll,
          side: BorderSide(color: DSColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: DSColors.surface,
        border: OutlineInputBorder(
          borderRadius: DSRadius.mdAll,
          borderSide: BorderSide(color: DSColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DSRadius.mdAll,
          borderSide: BorderSide(color: DSColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DSRadius.mdAll,
          borderSide: BorderSide(color: DSColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: DSSpacing.lg,
          vertical: DSSpacing.md,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DSColors.border,
        thickness: 1,
        space: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DSColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.xl,
            vertical: DSSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: DSRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DSColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.md,
            vertical: DSSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DSColors.primary,
          side: const BorderSide(color: DSColors.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.xl,
            vertical: DSSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: DSRadius.mdAll),
        ),
      ),
    );
  }
}
