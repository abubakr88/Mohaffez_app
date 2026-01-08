class ValidationUtils {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'البريد مطلوب';
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value)) return 'بريد غير صالح';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    return null;
  }

  static String? required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }
}
