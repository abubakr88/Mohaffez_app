import 'package:flutter/material.dart';

import 'app_theme_constants.dart';

/// Generates complete ThemeData using centralized constants.
class AppThemeData {
  AppThemeData._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // CHANGED: Arabic-friendly app font stack.
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['Roboto', 'Noto Sans Arabic'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 240, 171, 67),
        primary: AppThemeConstants.primaryAmber,
        secondary: AppThemeConstants.accentGreen,
        error: AppThemeConstants.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppThemeConstants.backgroundLight,
      appBarTheme: AppBarTheme(
        elevation: AppThemeConstants.elevationNone,
        centerTitle: true,
        backgroundColor: AppThemeConstants.primaryAmber,
        foregroundColor: AppThemeConstants.textOnPrimary,
        titleTextStyle: AppThemeConstants.titleLarge.copyWith(
          color: AppThemeConstants.textOnPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppThemeConstants.textOnPrimary,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppThemeConstants.surfaceWhite,
        elevation: AppThemeConstants.elevationSm,
        shape: RoundedRectangleBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
        ),
        margin: EdgeInsets.all(AppThemeConstants.spaceSm),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeConstants.primaryAmber,
          foregroundColor: AppThemeConstants.textOnPrimary,
          minimumSize: const Size(
            AppThemeConstants.buttonMinWidthMedium,
            AppThemeConstants.buttonHeightMedium,
          ),
          padding: AppThemeConstants.buttonPaddingMedium,
          shape: const RoundedRectangleBorder(
            borderRadius: AppThemeConstants.borderRadiusMd,
          ),
          elevation: AppThemeConstants.elevationSm,
          textStyle: AppThemeConstants.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppThemeConstants.primaryAmber,
          minimumSize: const Size(
            AppThemeConstants.buttonMinWidthMedium,
            AppThemeConstants.buttonHeightMedium,
          ),
          padding: AppThemeConstants.buttonPaddingMedium,
          shape: const RoundedRectangleBorder(
            borderRadius: AppThemeConstants.borderRadiusMd,
          ),
          side: const BorderSide(
            color: AppThemeConstants.primaryAmber,
            width: 2,
          ),
          textStyle: AppThemeConstants.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppThemeConstants.primaryAmber,
          padding: AppThemeConstants.buttonPaddingMedium,
          textStyle: AppThemeConstants.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppThemeConstants.surfaceWhite,
        border: const OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: BorderSide(color: AppThemeConstants.divider),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: BorderSide(color: AppThemeConstants.divider),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: BorderSide(color: AppThemeConstants.primaryAmber, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: BorderSide(color: AppThemeConstants.error),
        ),
        contentPadding: const EdgeInsets.all(AppThemeConstants.spaceMd),
        labelStyle: AppThemeConstants.bodyMedium,
        hintStyle: AppThemeConstants.bodyMedium.copyWith(
          color: AppThemeConstants.textSecondary,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppThemeConstants.textOnPrimary,
        unselectedLabelColor:
            AppThemeConstants.textOnPrimary.withValues(alpha: 0.7),
        indicatorColor: AppThemeConstants.textOnPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppThemeConstants.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AppThemeConstants.titleMedium,
      ),
      dividerTheme: const DividerThemeData(
        color: AppThemeConstants.divider,
        thickness: 1,
        space: AppThemeConstants.spaceMd,
      ),
      iconTheme: const IconThemeData(
        size: AppThemeConstants.iconMd,
        color: AppThemeConstants.textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: AppThemeConstants.displayLarge,
        displayMedium: AppThemeConstants.displayMedium,
        displaySmall: AppThemeConstants.displaySmall,
        headlineLarge: AppThemeConstants.headlineLarge,
        headlineMedium: AppThemeConstants.headlineMedium,
        headlineSmall: AppThemeConstants.headlineSmall,
        titleLarge: AppThemeConstants.titleLarge,
        titleMedium: AppThemeConstants.titleMedium,
        titleSmall: AppThemeConstants.titleSmall,
        bodyLarge: AppThemeConstants.bodyLarge,
        bodyMedium: AppThemeConstants.bodyMedium,
        bodySmall: AppThemeConstants.bodySmall,
        labelLarge: AppThemeConstants.labelLarge,
        labelMedium: AppThemeConstants.labelMedium,
        labelSmall: AppThemeConstants.labelSmall,
      ),
    );
  }
}
