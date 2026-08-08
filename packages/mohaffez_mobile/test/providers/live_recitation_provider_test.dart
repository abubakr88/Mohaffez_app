import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/data/recitation_deck.dart';
import 'package:mohaffez_finder_app/providers/live_recitation_provider.dart';

void main() {
  group('activeLiveRecitationSessionFromSessions', () {
    final now = DateTime(2026, 8, 2, 12);

    test('online game stays hidden until the teacher starts the session', () {
      final session = <String, dynamic>{
        'id': 'session-1',
        'status': 'accepted',
        'sessionType': 'online',
        'studentId': 'student-1',
        'slotStart': now.subtract(const Duration(minutes: 5)),
        'slotEnd': now.add(const Duration(minutes: 55)),
      };

      expect(
        activeLiveRecitationSessionFromSessions(
          [session],
          studentId: 'student-1',
          studentProfileId: null,
          now: now,
        ),
        isNull,
      );

      session['meetingStartedAt'] = now.subtract(const Duration(minutes: 1));
      expect(
        activeLiveRecitationSessionFromSessions(
          [session],
          studentId: 'student-1',
          studentProfileId: null,
          now: now,
        )?.sessionId,
        'session-1',
      );
    });

    test('uses the existing session data and respects child profiles', () {
      final session = <String, dynamic>{
        'id': 'session-child',
        'status': 'accepted',
        'sessionType': 'inPerson',
        'studentId': 'parent-1',
        'studentProfileId': 'child-2',
        'slotStart': now.subtract(const Duration(minutes: 10)),
        'slotEnd': now.add(const Duration(minutes: 40)),
      };

      expect(
        activeLiveRecitationSessionFromSessions(
          [session],
          studentId: 'parent-1',
          studentProfileId: 'child-1',
          now: now,
        ),
        isNull,
      );
      expect(
        activeLiveRecitationSessionFromSessions(
          [session],
          studentId: 'parent-1',
          studentProfileId: 'child-2',
          now: now,
        )?.sessionId,
        'session-child',
      );
    });
  });

  test('live payload contains only compact round configuration', () {
    final payload = liveRecitationRoundPayload(
      mohaffezId: 'teacher-1',
      studentId: 'student-1',
      studentProfileId: null,
      scopes: const [
        RecitationScope(
          surahNumber: 2,
          surahName: 'البقرة',
          fromAyah: 1,
          toAyah: 20,
        ),
      ],
      cardCount: 6,
      roundId: 10,
      seed: 10,
      expiresAt: DateTime(2026, 8, 2, 15),
    );

    expect(payload['cards'], isNull);
    expect(payload['ayahText'], isNull);
    final scopes = payload['scopes'] as List<dynamic>;
    expect(scopes, hasLength(1));
    expect(scopes.single, {
      'surahNumber': 2,
      'fromAyah': 1,
      'toAyah': 20,
    });
  });

  test('parses selection and results without storing generated cards', () {
    final state = LiveRecitationState.fromMap('session-1', {
      'schemaVersion': liveRecitationSchemaVersion,
      'mohaffezId': 'teacher-1',
      'studentId': 'student-1',
      'studentProfileId': 'self',
      'status': 'playing',
      'roundId': 7,
      'seed': 7,
      'cardCount': 4,
      'scopes': [
        {'surahNumber': 1, 'fromAyah': 1, 'toAyah': 7},
      ],
      'selectedIndex': 2,
      'results': {'0': true, '1': false},
    });

    expect(state, isNotNull);
    expect(state!.selectedIndex, 2);
    expect(state.results, {0: true, 1: false});
    expect(state.studentProfileId, isNull);
  });
}
