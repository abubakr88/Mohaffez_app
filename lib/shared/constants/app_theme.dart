import 'package:flutter/material.dart';

import '../theme/app_theme_constants.dart';
import '../theme/app_theme_data.dart';

/// @deprecated Use AppThemeConstants and AppThemeData instead.
/// Kept for backward compatibility during migration.
class AppTheme {
  AppTheme._();

  /// @deprecated Use AppThemeConstants.primaryAmber
  static const Color primaryAmber = AppThemeConstants.primaryAmber;

  /// @deprecated Use AppThemeConstants.primaryAmberLight
  static const Color lightAmber = AppThemeConstants.primaryAmberLight;

  /// @deprecated Use AppThemeConstants.accentGreen
  static const Color accentGreen = AppThemeConstants.accentGreen;

  /// @deprecated Use AppThemeConstants.textPrimary
  static const Color textPrimary = AppThemeConstants.textPrimary;

  /// @deprecated Use AppThemeConstants.textSecondary
  static const Color textSecondary = AppThemeConstants.textSecondary;

  /// @deprecated Use AppThemeConstants.success
  static const Color success = AppThemeConstants.success;

  /// @deprecated Use AppThemeConstants.warning
  static const Color warning = AppThemeConstants.warning;

  /// @deprecated Use AppThemeConstants.backgroundLight
  static const Color backgroundLight = AppThemeConstants.backgroundLight;

  /// @deprecated Use AppThemeConstants.surfaceWhite
  static const Color cardBackground = AppThemeConstants.surfaceWhite;

  /// @deprecated Use direct semantic token from AppThemeConstants
  static const Color complementaryBlue = AppThemeConstants.info;

  /// @deprecated Legacy token maintained for compatibility.
  static const Color darkBackground = Color(0xFF1A2634);

  /// @deprecated Use AppThemeData.lightTheme
  static ThemeData get lightTheme => AppThemeData.lightTheme;
}
