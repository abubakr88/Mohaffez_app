import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  group('ScheduleConstants.generateWindowCandidates', () {
    test('supports a 15-minute plan on the 15-minute start grid', () {
      final slots = ScheduleConstants.generateWindowCandidates(
        startTime: '09:00',
        endTime: '10:00',
        durationMinutes: 15,
      );

      expect(slots, [
        {'start': '09:00', 'end': '09:15'},
        {'start': '09:15', 'end': '09:30'},
        {'start': '09:30', 'end': '09:45'},
        {'start': '09:45', 'end': '10:00'},
      ]);
    });

    test('creates overlapping 45-minute candidates every 15 minutes', () {
      final slots = ScheduleConstants.generateWindowCandidates(
        startTime: '09:00',
        endTime: '10:30',
        durationMinutes: 45,
      );

      expect(slots, [
        {'start': '09:00', 'end': '09:45'},
        {'start': '09:15', 'end': '10:00'},
        {'start': '09:30', 'end': '10:15'},
        {'start': '09:45', 'end': '10:30'},
      ]);
    });

    test('removes every candidate overlapping an exclusion range', () {
      final slots = ScheduleConstants.generateWindowCandidates(
        startTime: '09:00',
        endTime: '11:00',
        durationMinutes: 30,
        exclusionRanges: const [
          {'start': '09:40', 'end': '10:10'},
        ],
      );

      bool hasSlot(String start, String end) => slots.any(
            (slot) => slot['start'] == start && slot['end'] == end,
          );

      expect(hasSlot('09:15', '09:45'), isFalse);
      expect(hasSlot('10:00', '10:30'), isFalse);
      expect(hasSlot('10:15', '10:45'), isTrue);
    });

    test('rejects unsupported durations and invalid windows', () {
      expect(
        ScheduleConstants.generateWindowCandidates(
          startTime: '09:00',
          endTime: '10:00',
          durationMinutes: 20,
        ),
        isEmpty,
      );
      expect(
        ScheduleConstants.generateWindowCandidates(
          startTime: '10:00',
          endTime: '09:00',
          durationMinutes: 30,
        ),
        isEmpty,
      );
    });
  });
}
