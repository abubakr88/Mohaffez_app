class ScheduleConstants {
  // ✅ CONFIGURABLE START/END TIMES
  static const String defaultStartTime = '08:00';
  static const String defaultEndTime = '20:45';
  static const int defaultSessionDurationMinutes = 45;

  static const List<String> arabicDays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  /// Generate time slots dynamically based on configuration
  /// [startTime] format: 'HH:MM' (e.g., '08:00')
  /// [endTime] format: 'HH:MM' (e.g., '20:45')
  /// [durationMinutes] session duration (default: 45)
  static List<Map<String, String>> generateTimeSlots({
    String startTime = defaultStartTime,
    String endTime = defaultEndTime,
    int durationMinutes = defaultSessionDurationMinutes,
    int breakMinutes = 0,
  }) {
    final slots = <Map<String, String>>[];

    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    int currentTotalMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endTotalMinutes =
        int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    while (currentTotalMinutes + durationMinutes <= endTotalMinutes) {
      final slotEnd = currentTotalMinutes + durationMinutes;
      slots.add({
        'start':
            '${(currentTotalMinutes ~/ 60).toString().padLeft(2, '0')}:${(currentTotalMinutes % 60).toString().padLeft(2, '0')}',
        'end':
            '${(slotEnd ~/ 60).toString().padLeft(2, '0')}:${(slotEnd % 60).toString().padLeft(2, '0')}',
      });
      currentTotalMinutes += durationMinutes + breakMinutes;
    }

    return slots;
  }

  /// Default time slots (backward compatibility)
  static List<Map<String, String>> get timeSlots => generateTimeSlots();

  /// Quick slots used in MohaffezProfileScreen booking widget
  static const List<String> quickSlots = ['08:00', '10:00', '16:00'];
}
