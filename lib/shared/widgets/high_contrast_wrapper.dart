import 'package:flutter/material.dart';

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
            bodyColor: Colors.black,
            displayColor: Colors.black,
          ),
          
          // Increase border widths
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
          
          // Higher contrast colors
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.light,
            primary: Colors.amber.shade800,
            secondary: Colors.green.shade800,
          ),
          
          // Higher contrast for buttons
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
          
          // Higher contrast for outlined buttons
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2),
              foregroundColor: Colors.black,
            ),
          ),
          
          // Higher contrast for input fields
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 3),
            ),
          ),
          
          // Higher contrast dividers
          dividerColor: Colors.black,
          dividerTheme: const DividerThemeData(
            color: Colors.black,
            thickness: 2,
          ),
        ),
        child: child,
      );
    }

    return child;
  }
}
