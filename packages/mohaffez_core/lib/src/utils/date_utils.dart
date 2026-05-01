class AppDateUtils {
  static String formatDateTime(DateTime date) {
    final d = '${date.day}/${date.month}/${date.year}';
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$d - $h:$m';
  }

  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
