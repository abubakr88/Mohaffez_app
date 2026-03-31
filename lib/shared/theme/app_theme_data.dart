import 'package:flutter/material.dart';

import 'app_theme_constants.dart';

/// Generates complete ThemeData using the new Turquoise/Gold design system.
class AppThemeData {
  AppThemeData._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Arabic-friendly font stack (Cairo is the primary)
      fontFamily: 'Cairo',
      fontFamilyFallback: const ['Roboto', 'Noto Sans Arabic'],
      
      // Color scheme using new Turquoise/Gold palette
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppThemeConstants.primary,
        onPrimary: AppThemeConstants.onPrimary,
        primaryContainer: AppThemeConstants.primaryVariant,
        onPrimaryContainer: AppThemeConstants.onPrimary,
        secondary: AppThemeConstants.secondary,
        onSecondary: AppThemeConstants.onSecondary,
        secondaryContainer: AppThemeConstants.secondaryContainer,
        onSecondaryContainer: AppThemeConstants.onSecondary,
        surface: AppThemeConstants.surface,
        onSurface: AppThemeConstants.textPrimary,
        surfaceContainerHighest: AppThemeConstants.background,
        onSurfaceVariant: AppThemeConstants.textSecondary,
        error: AppThemeConstants.error,
        onError: Colors.white,
        errorContainer: AppThemeConstants.errorBackground,
        onErrorContainer: AppThemeConstants.error,
        outline: AppThemeConstants.outline,
        shadow: AppThemeConstants.shadow,
      ),
      
      scaffoldBackgroundColor: AppThemeConstants.background,
      appBarTheme: AppBarTheme(
        elevation: AppThemeConstants.elevationNone,
        scrolledUnderElevation: AppThemeConstants.elevationXs,
        centerTitle: true,
        backgroundColor: AppThemeConstants.primary,
        foregroundColor: AppThemeConstants.onPrimary,
        titleTextStyle: AppThemeConstants.titleLarge.copyWith(
          color: AppThemeConstants.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(
          color: AppThemeConstants.onPrimary,
          size: AppThemeConstants.iconMd,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppThemeConstants.surface,
        elevation: AppThemeConstants.elevationSm,
        shadowColor: AppThemeConstants.shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppThemeConstants.spaceMd,
          vertical: AppThemeConstants.spaceSm,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeConstants.primary,
          foregroundColor: AppThemeConstants.onPrimary,
          minimumSize: const Size(
            AppThemeConstants.buttonMinWidthMedium,
            AppThemeConstants.buttonHeightMedium,
          ),
          padding: AppThemeConstants.buttonPaddingMedium,
          shape: const RoundedRectangleBorder(
            borderRadius: AppThemeConstants.borderRadiusMd,
          ),
          elevation: AppThemeConstants.elevationSm,
          textStyle: AppThemeConstants.labelLarge.copyWith(
            color: AppThemeConstants.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppThemeConstants.primary,
          minimumSize: const Size(
            AppThemeConstants.buttonMinWidthMedium,
            AppThemeConstants.buttonHeightMedium,
          ),
          padding: AppThemeConstants.buttonPaddingMedium,
          shape: const RoundedRectangleBorder(
            borderRadius: AppThemeConstants.borderRadiusMd,
          ),
          side: const BorderSide(
            color: AppThemeConstants.primary,
            width: 1.5,
          ),
          textStyle: AppThemeConstants.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppThemeConstants.primary,
          padding: AppThemeConstants.buttonPaddingMedium,
          textStyle: AppThemeConstants.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppThemeConstants.surface,
        border: OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: const BorderSide(color: AppThemeConstants.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: const BorderSide(color: AppThemeConstants.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: const BorderSide(color: AppThemeConstants.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
          borderSide: const BorderSide(color: AppThemeConstants.error),
        ),
        contentPadding: const EdgeInsets.all(AppThemeConstants.spaceMd),
        labelStyle: AppThemeConstants.bodyMedium,
        hintStyle: AppThemeConstants.bodyMedium.copyWith(
          color: AppThemeConstants.textDisabled,
        ),
        helperStyle: AppThemeConstants.bodySmall,
        errorStyle: AppThemeConstants.bodySmall.copyWith(
          color: AppThemeConstants.error,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppThemeConstants.onPrimary,
        unselectedLabelColor: AppThemeConstants.onPrimary.withOpacity(0.7),
        indicatorColor: AppThemeConstants.onPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppThemeConstants.titleMedium.copyWith(
          fontWeight: FontWeight.w600,
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
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppThemeConstants.textPrimary,
        contentTextStyle: AppThemeConstants.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppThemeConstants.borderRadiusMd,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppThemeConstants.surface,
        selectedItemColor: AppThemeConstants.primary,
        unselectedItemColor: AppThemeConstants.textSecondary,
        selectedLabelStyle: AppThemeConstants.labelSmall,
        unselectedLabelStyle: AppThemeConstants.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: AppThemeConstants.elevationSm,
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppThemeConstants.primary,
        foregroundColor: AppThemeConstants.onPrimary,
        elevation: AppThemeConstants.elevationMd,
        shape: const RoundedRectangleBorder(
          borderRadius: AppThemeConstants.borderRadiusRound,
        ),
      ),
    );
  }
}
