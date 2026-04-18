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

  /// Notification badge color
  static const Color notificationRed = Color(0xFFDC2626);
  static const Color surfaceColor = Colors.white;

  /// @deprecated Use direct semantic token from AppThemeConstants
  static const Color complementaryBlue = Color(0xFF0B7A75);

  /// @deprecated Legacy token maintained for compatibility.
  static const Color darkBackground = Color(0xFF1A2634);

  /// @deprecated Use AppThemeData.lightTheme
  static ThemeData get lightTheme => AppThemeData.lightTheme;
}
