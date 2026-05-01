import 'package:flutter/material.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

/// Wrapper that adapts colors for high contrast mode
class HighContrastWrapper extends StatelessWidget {
  final Widget child;

  const HighContrastWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.of(context).highContrast;

    if (highContrast) {
      return Theme(
        data: Theme.of(context).copyWith(
          // Increase contrast for text
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: AppThemeConstants.black,
            displayColor: AppThemeConstants.black,
          ),
          
          // Increase border widths
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppThemeConstants.black, width: 2),
            ),
          ),
          
          // Higher contrast colors
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppThemeConstants.accentAmber,
            brightness: Brightness.light,
            primary: AppThemeConstants.accentAmberDark,
            secondary: AppThemeConstants.successDark,
          ),
          
          // Higher contrast for buttons
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeConstants.accentAmberDark,
              foregroundColor: AppThemeConstants.white,
              side: const BorderSide(color: AppThemeConstants.black, width: 2),
            ),
          ),
          
          // Higher contrast for outlined buttons
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppThemeConstants.black, width: 2),
              foregroundColor: AppThemeConstants.black,
            ),
          ),
          
          // Higher contrast for input fields
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppThemeConstants.black, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppThemeConstants.black, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppThemeConstants.black, width: 3),
            ),
          ),
          
          // Higher contrast dividers
          dividerColor: AppThemeConstants.black,
          dividerTheme: const DividerThemeData(
            color: AppThemeConstants.black,
            thickness: 2,
          ),
        ),
        child: child,
      );
    }

    return child;
  }
}
