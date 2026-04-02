import 'package:flutter/material.dart';

import '../theme/app_theme_data.dart';

/// @deprecated Use AppThemeConstants and AppThemeData instead.
/// Kept for backward compatibility during migration.
class AppTheme {
  AppTheme._();

  /// @deprecated Use AppThemeConstants.primary (0xFF0B7A75)
  static const Color primaryTeal = Color(0xFF0B7A75);

  /// @deprecated Use AppThemeConstants.deepTeal (0xFF0B4A4A)
  static const Color deepTeal = Color(0xFF0B4A4A);

  /// @deprecated Use AppThemeConstants.secondary (0xFFD4A44A)
  static const Color softGold = Color(0xFFD4A44A);

  // Legacy aliases for backward compatibility
  /// @deprecated Use AppThemeConstants.primary (0xFF0B7A75)
  static const Color primaryAmber = Color(0xFF0B7A75);

  /// @deprecated Use AppThemeConstants.primaryVariant (0xFF14B8A6)
  static const Color lightAmber = Color(0xFF14B8A6);

  /// @deprecated Use AppThemeConstants.secondary (0xFFD4A44A)
  static const Color accentGreen = Color(0xFFD4A44A);

  /// @deprecated Use AppThemeConstants.textPrimary
  static const Color textPrimary = Color(0xFF1E2933);

  /// @deprecated Use AppThemeConstants.textSecondary
  static const Color textSecondary = Color(0xFF6B7280);

  /// @deprecated Use AppThemeConstants.textMuted (0xFF9CA3AF)
  static const Color textMuted = Color(0xFF9CA3AF);

  /// Notification badge color
  static const Color notificationRed = Color(0xFFDC2626);
  static const Color surfaceColor = Colors.white;

  /// @deprecated Use AppThemeConstants.success
  static const Color success = Color(0xFF16A34A);

  /// @deprecated Use AppThemeConstants.warning
  static const Color warning = Color(0xFFEA580C);

  /// @deprecated Use AppThemeConstants.background
  static const Color backgroundLight = Color(0xFFF5FAF9);

  /// @deprecated Use AppThemeConstants.surface
  static const Color cardBackground = Colors.white;

  /// @deprecated Use direct semantic token from AppThemeConstants
  static const Color complementaryBlue = Color(0xFF0B7A75);

  /// @deprecated Legacy token maintained for compatibility.
  static const Color darkBackground = Color(0xFF1A2634);

  /// @deprecated Use AppThemeData.lightTheme
  static ThemeData get lightTheme => AppThemeData.lightTheme;
}
