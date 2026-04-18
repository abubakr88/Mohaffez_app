import 'package:flutter/material.dart';

import 'app_theme_constants.dart';

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => theme.colorScheme;

  TextTheme get textTheme => theme.textTheme;

  Type get constants => AppThemeConstants;
}

extension SpacingExtensions on num {
  SizedBox get vSpace => SizedBox(height: toDouble());

  SizedBox get hSpace => SizedBox(width: toDouble());
}

class Spacing {
  Spacing._();

  static const vXs = SizedBox(height: AppThemeConstants.spaceXs);
  static const vSm = SizedBox(height: AppThemeConstants.spaceSm);
  static const vMd = SizedBox(height: AppThemeConstants.spaceMd);
  static const vLg = SizedBox(height: AppThemeConstants.spaceLg);
  static const vXl = SizedBox(height: AppThemeConstants.spaceXl);

  static const hXs = SizedBox(width: AppThemeConstants.spaceXs);
  static const hSm = SizedBox(width: AppThemeConstants.spaceSm);
  static const hMd = SizedBox(width: AppThemeConstants.spaceMd);
  static const hLg = SizedBox(width: AppThemeConstants.spaceLg);
  static const hXl = SizedBox(width: AppThemeConstants.spaceXl);
}
