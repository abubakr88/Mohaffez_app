class ValidationUtils {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'البريد مطلوب';
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value)) return 'بريد غير صالح';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال كلمة المرور';
    }
    if (value.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    // Moderate strength: require at least one letter and one digit so
    // dummy passwords like "12345678" or "aaaaaaaa" are rejected, without
    // forcing symbols/uppercase that frustrate users.
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'يجب أن تحتوي كلمة المرور على حروف وأرقام';
    }
    return null;
  }

  static String? required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }
}
