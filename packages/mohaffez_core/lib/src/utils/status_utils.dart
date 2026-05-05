import 'package:flutter/material.dart';
import '../theme/app_theme_constants.dart';

class StatusUtils {
  static Color color(String status) {
    switch (status) {
      case 'accepted':
        return AppThemeConstants.success;
      case 'rejected':
        return AppThemeConstants.error;
      default:
        return AppThemeConstants.warning;
    }
  }

  static String label(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'قيد المراجعة';
    }
  }
}
