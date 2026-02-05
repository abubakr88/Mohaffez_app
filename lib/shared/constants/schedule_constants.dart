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
  }) {
    final slots = <Map<String, String>>[];
    
    // Parse start time
    final startParts = startTime.split(':');
    int currentHour = int.parse(startParts[0]);
    int currentMinute = int.parse(startParts[1]);
    
    // Parse end time
    final endParts = endTime.split(':');
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);
    
    // Convert to total minutes for easier comparison
    int currentTotalMinutes = currentHour * 60 + currentMinute;
    final endTotalMinutes = endHour * 60 + endMinute;
    
    while (currentTotalMinutes + durationMinutes <= endTotalMinutes) {
      final startHour = currentTotalMinutes ~/ 60;
      final startMin = currentTotalMinutes % 60;
      
      final endSlotMinutes = currentTotalMinutes + durationMinutes;
      final endSlotHour = endSlotMinutes ~/ 60;
      final endSlotMin = endSlotMinutes % 60;
      
      slots.add({
        'start': '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')}',
        'end': '${endSlotHour.toString().padLeft(2, '0')}:${endSlotMin.toString().padLeft(2, '0')}',
      });
      
      currentTotalMinutes += durationMinutes;
    }
    
    return slots;
  }

  /// Default time slots (backward compatibility)
  static List<Map<String, String>> get timeSlots => generateTimeSlots();

  /// Quick slots used in MohaffezProfileScreen booking widget
  static const List<String> quickSlots = ['08:00', '10:00', '16:00'];
}
