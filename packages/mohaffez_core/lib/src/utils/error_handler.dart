import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme_constants.dart';

class ErrorHandler {
  /// Show error snackbar with localized message
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    final message = getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppThemeConstants.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppThemeConstants.error, // WHY: Align utility snackbar colors with app theme constants.
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppThemeConstants.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppThemeConstants.secondary, // WHY: Align utility snackbar colors with app theme constants.
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Get user-friendly error message
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return _getAuthErrorMessage(error.code);
    } else if (error is FirebaseException) {
      return _getFirestoreErrorMessage(error.code);
    } else if (error is String) {
      return error;
    } else {
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }
  }

  static String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً، استخدم 6 أحرف على الأقل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-disabled':
        return 'هذا الحساب موقوف. يرجى التواصل مع الدعم';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت وحاول مجدداً';
      case 'too-many-requests':
        return 'محاولات كثيرة. يرجى الانتظار قليلاً والمحاولة مجدداً';
      case 'requires-recent-login':
        return 'يرجى تسجيل الخروج وإعادة الدخول ثم المحاولة مجدداً';
      case 'operation-not-allowed':
        return 'هذه العملية غير مسموح بها. يرجى التواصل مع الدعم';
      case 'credential-already-in-use':
        return 'هذا الحساب مرتبط بمستخدم آخر بالفعل';
      default:
        return 'حدث خطأ. يرجى المحاولة مرة أخرى';
    }
  }

  static String _getFirestoreErrorMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return 'ليس لديك صلاحية للقيام بهذا الإجراء';
      case 'unavailable':
        return 'الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً';
      case 'not-found':
        return 'البيانات المطلوبة غير موجودة';
      case 'already-exists':
        return 'هذا العنصر موجود بالفعل';
      case 'cancelled':
        return 'تم إلغاء العملية';
      case 'deadline-exceeded':
        return 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى';
      default:
        return 'حدث خطأ. يرجى المحاولة مرة أخرى';
    }
  }
}
