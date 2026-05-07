import 'package:intl/intl.dart';

/// Converts a 24-hour time string (e.g. "08:00" or "08:00-09:00")
/// to a 12-hour Arabic format with ص/م (e.g. "8:00 ص" or "8:00-9:00 ص").
String formatTimeToArabicAmPm(String time24) {
  if (time24.isEmpty) return '';

  // Handle ranges like "08:00-09:00"
  final parts = time24.split('-');
  if (parts.length == 2) {
    final start = _formatSingleTime(parts[0].trim());
    final end = _formatSingleTime(parts[1].trim());
    return '$start-$end';
  }

  // Single time
  return _formatSingleTime(time24.trim());
}

String formatDateTimeToArabicAmPm(
  DateTime dateTime, {
  String datePattern = 'dd/MM/yyyy',
  String separator = ' - ',
  String locale = 'ar',
}) {
  return '${DateFormat(datePattern, locale).format(dateTime)}'
      '$separator${formatTimeOfDayToArabicAmPm(dateTime.hour, dateTime.minute)}';
}

String formatTimeOfDayToArabicAmPm(int hour, int minute) {
  final period = hour >= 12 ? 'م' : 'ص';
  final h12 = hour > 12
      ? hour - 12
      : hour == 0
          ? 12
          : hour;

  return '${h12.toString()}:${minute.toString().padLeft(2, '0')} $period';
}

String _formatSingleTime(String time) {
  final hm = time.split(':');
  if (hm.length < 2) return time;

  final hour = int.tryParse(hm[0]) ?? 0;
  final minute = int.tryParse(hm[1]) ?? 0;

  return formatTimeOfDayToArabicAmPm(hour, minute);
}
