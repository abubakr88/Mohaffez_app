class ScheduleConstants {
  // ✅ CONFIGURABLE START/END TIMES
  static const String defaultStartTime = '08:00';
  static const String defaultEndTime = '20:45';
  static const int defaultSessionDurationMinutes = 45;
  static const int slotStartIntervalMinutes = 15;
  static const List<int> supportedSessionDurations = [
    15,
    30,
    45,
    60,
    75,
    90,
    120,
  ];

  static const Map<String, int> defaultBreakMinutesBySessionType = {
    'online': 10,
    'mosque': 15,
    'home': 30,
  };

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

  /// Generates every candidate start on a fixed grid inside an availability
  /// window. Unlike [generateTimeSlots], candidates may overlap each other;
  /// the booking backend decides which candidate is still free.
  static List<Map<String, String>> generateWindowCandidates({
    required String startTime,
    required String endTime,
    required int durationMinutes,
    int startIntervalMinutes = slotStartIntervalMinutes,
    List<Map<String, String>> exclusionRanges = const [],
  }) {
    if (!supportedSessionDurations.contains(durationMinutes) ||
        startIntervalMinutes <= 0) {
      return const [];
    }

    final windowStart = _minutesFromTime(startTime);
    final windowEnd = _minutesFromTime(endTime);
    if (windowStart == null || windowEnd == null || windowStart >= windowEnd) {
      return const [];
    }

    final ranges = exclusionRanges
        .map((range) => (
              start: _minutesFromTime(range['start'] ?? ''),
              end: _minutesFromTime(range['end'] ?? ''),
            ))
        .where((range) =>
            range.start != null &&
            range.end != null &&
            range.start! < range.end!)
        .toList();

    final firstStart =
        ((windowStart + startIntervalMinutes - 1) ~/ startIntervalMinutes) *
            startIntervalMinutes;
    final slots = <Map<String, String>>[];

    for (var start = firstStart;
        start + durationMinutes <= windowEnd;
        start += startIntervalMinutes) {
      final end = start + durationMinutes;
      final excluded = ranges.any(
        (range) => start < range.end! && end > range.start!,
      );
      if (excluded) continue;

      slots.add({
        'start': _timeFromMinutes(start),
        'end': _timeFromMinutes(end),
      });
    }

    return slots;
  }

  static int? _minutesFromTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static String _timeFromMinutes(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';

  /// Default time slots (backward compatibility)
  static List<Map<String, String>> get timeSlots => generateTimeSlots();

  /// Quick slots used in MohaffezProfileScreen booking widget
  static const List<String> quickSlots = ['08:00', '10:00', '16:00'];
}
