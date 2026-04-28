import 'package:flutter/material.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Design tokens shared across all quiz games.
///
/// Kept playful but reverent — soft teal/gold base palette aligned with
/// the rest of the app, plus accent colors for per-game theming.
class QuizDS {
  QuizDS._();

  // Brand
  static const teal700  = AppThemeConstants.deepTeal;
  static const teal600  = AppThemeConstants.primary;
  static const teal500  = AppThemeConstants.primaryVariant;
  static const teal100  = AppThemeConstants.accentBackground;
  static const teal50   = AppThemeConstants.background;

  // Per-game accents
  static const amber    = AppThemeConstants.accentOrange;
  static const amberBg  = AppThemeConstants.accentOrangeLight;
  static const purple   = AppThemeConstants.accentPurple;
  static const purpleBg = AppThemeConstants.accentPurpleLight;
  static const blue     = AppThemeConstants.accentBlue;
  static const blueBg   = AppThemeConstants.accentBlueLight;

  // Status
  static const green    = AppThemeConstants.success;
  static const greenBg  = AppThemeConstants.successBackground;
  static const red      = AppThemeConstants.error;
  static const redBg    = AppThemeConstants.errorBackground;

  // Surface
  static const bg       = AppThemeConstants.background;
  static const text1    = AppThemeConstants.textPrimary;
  static const text2    = AppThemeConstants.textSecondary;
  static const text3    = AppThemeConstants.textMuted;
  static const border   = AppThemeConstants.outline;

  // Confetti palette — bright but limited so it stays tasteful
  static const confettiColors = <Color>[
    teal500,
    amber,
    purple,
    blue,
    green,
    Color(0xFFFFD54F), // soft gold
  ];

  // Radii
  static const r12 = AppThemeConstants.borderRadiusMd;
  static const r16 = AppThemeConstants.borderRadiusLg;
  static const r20 = BorderRadius.all(Radius.circular(20));
  static const r24 = AppThemeConstants.borderRadiusXl;
}
