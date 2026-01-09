import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ErrorHandler {
  /// Show error snackbar with localized message
  static void showError(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    final message = getErrorMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
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
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
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
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-disabled':
        return 'هذا الحساب معطل';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت';
      default:
        return 'حدث خطأ في المصادقة: $code';
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
      case 'data-loss':
        return 'فقدان البيانات';
      case 'deadline-exceeded':
        return 'انتهت مهلة العملية';
      default:
        return 'حدث خطأ في قاعدة البيانات: $code';
    }
  }
}
