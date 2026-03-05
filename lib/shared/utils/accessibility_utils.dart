import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class AccessibilityUtils {
  AccessibilityUtils._();

 /// Announce message to screen readers
  static void announce(BuildContext context, String message) {
    final view = View.of(context);
    SemanticsService.sendAnnouncement(view, message, TextDirection.rtl);
  }
  
  /// Check if screen reader is enabled
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Get recommended minimum tap target size
  static double get minTouchTarget => 48.0;

  /// Get recommended text scale limits
  static double get minTextScale => 0.8;
  static double get maxTextScale => 2.0;

  /// Clamp text scale factor within accessible range
  static double clampTextScale(double textScale) {
    return textScale.clamp(minTextScale, maxTextScale);
  }

  /// Create semantic label for rating
  static String ratingLabel(double rating, int maxRating) {
    return 'التقييم $rating من $maxRating نجوم';
  }

  /// Create semantic label for date
  static String dateLabel(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم في الساعة ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Create semantic label for distance
  static String distanceLabel(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()} متر';
    }
    return '${distance.toStringAsFixed(1)} كيلومتر';
  }

  /// Create semantic label for button with icon
  static String buttonLabel(String text, IconData icon) {
    return text; // Screen reader will read the text
  }

  /// Create semantic hint for actions
  static String actionHint(String action) {
    return 'اضغط مرتين $action';
  }
}

/// Extension on Widget for easier semantics
extension AccessibleWidget on Widget {
  /// Wrap widget with semantic label
  Widget withSemantics({
    required String label,
    String? hint,
    bool? button,
    bool? header,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: button ?? false,
      header: header ?? false,
      onTap: onTap,
      child: this,
    );
  }

  /// Make widget excludeFromSemantics
  Widget excludeSemantics() {
    return ExcludeSemantics(child: this);
  }
}
