import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

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

DateTime? bookingDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Uses the canonical instant for time-zone-aware bookings and preserves the
/// legacy clock string for older documents.
String formatBookingTimeToArabicAmPm(
  Map<String, dynamic> booking, {
  String fallback = '',
}) {
  final version = (booking['bookingTimeZoneVersion'] as num?)?.toInt() ?? 0;
  if (version == 1) {
    final start = bookingDateTime(booking['slotStart'])?.toLocal();
    final end = bookingDateTime(booking['slotEnd'])?.toLocal();
    if (start != null && end != null) {
      return '${formatTimeOfDayToArabicAmPm(start.hour, start.minute)}-'
          '${formatTimeOfDayToArabicAmPm(end.hour, end.minute)}';
    }
  }
  final legacy = fallback.isNotEmpty
      ? fallback
      : booking['preferredTimeSlot'] as String? ??
          booking['timeSlot'] as String? ??
          '';
  return formatTimeToArabicAmPm(legacy);
}

String formatCanonicalBookingTime({
  required int bookingTimeZoneVersion,
  required Object? slotStart,
  required Object? slotEnd,
  required String legacyTimeSlot,
}) {
  return formatTimeToArabicAmPm(canonicalBookingLocalTimeSlot(
    bookingTimeZoneVersion: bookingTimeZoneVersion,
    slotStart: slotStart,
    slotEnd: slotEnd,
    legacyTimeSlot: legacyTimeSlot,
  ));
}

String canonicalBookingLocalTimeSlot({
  required int bookingTimeZoneVersion,
  required Object? slotStart,
  required Object? slotEnd,
  required String legacyTimeSlot,
}) {
  if (bookingTimeZoneVersion == 1) {
    final start = bookingDateTime(slotStart)?.toLocal();
    final end = bookingDateTime(slotEnd)?.toLocal();
    if (start != null && end != null) {
      String clock(DateTime value) =>
          '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}';
      return '${clock(start)}-${clock(end)}';
    }
  }
  return legacyTimeSlot;
}

DateTime? canonicalBookingLocalDate({
  required int bookingTimeZoneVersion,
  required Object? slotStart,
  required Object? legacyDate,
}) {
  if (bookingTimeZoneVersion == 1) {
    return bookingDateTime(slotStart)?.toLocal();
  }
  return bookingDateTime(legacyDate);
}

DateTime? bookingLocalStart(Map<String, dynamic> booking) {
  final version = (booking['bookingTimeZoneVersion'] as num?)?.toInt() ?? 0;
  if (version == 1) {
    return bookingDateTime(booking['slotStart'])?.toLocal();
  }
  return bookingDateTime(booking['sessionDate'] ?? booking['slotDate']);
}
