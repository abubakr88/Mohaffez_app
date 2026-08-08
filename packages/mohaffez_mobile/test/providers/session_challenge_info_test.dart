import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/data/practice_challenge_bank.dart';
import 'package:mohaffez_finder_app/providers/quiz_access_provider.dart';
import 'package:mohaffez_finder_app/screens/student/student_challenge_screen.dart';

void main() {
  test('materialized publish payload carries keys without Firestore timestamps',
      () {
    final question = ChallengeQuestion(
      id: 'qv1-s1-name-a1',
      type: ChallengeType.nameSurah,
      answerMode: ChallengeAnswerMode.multipleChoice,
      source: 'quran_generated',
      generatorVersion: 1,
      surahNumber: 1,
      anchorAyah: 1,
      question: 'من أي سورة؟',
      options: const [
        ChallengeOption(id: 'a', text: 'الفاتحة'),
        ChallengeOption(id: 'b', text: 'البقرة'),
      ],
      correctOptionId: 'a',
      createdAt: DateTime.utc(2026),
    );

    final payload = sessionChallengePublishPayload(
      sessionId: 'session-a',
      studentId: 'student-a',
      studentProfileId: null,
      questions: [question],
    );
    final published =
        Map<String, dynamic>.from((payload['questions'] as List).single as Map);

    expect(payload, isNot(contains('questionIds')));
    expect(payload['studentProfileId'], 'self');
    expect(published['source'], 'quran_generated');
    expect(published['correctOptionId'], 'a');
    expect(published, isNot(contains('createdAt')));
  });

  test('attempt IDs use web-safe random bounds', () {
    final random = Random(42);
    final now = DateTime.utc(2026);
    final ids = List.generate(
      100,
      (_) => createChallengeAttemptId(random: random, now: now),
    );

    expect(ids.toSet(), hasLength(100));
    expect(
      ids.every(
        (id) => RegExp(r'^\d+-[0-9a-z]{8}$').hasMatch(id),
      ),
      isTrue,
    );
  });

  test('offline practice has three local questions for every type', () {
    expect(practiceChallengeQuestions, hasLength(18));
    for (final type in ChallengeType.values) {
      expect(
        practiceChallengeQuestions.where((question) => question.type == type),
        hasLength(3),
        reason: 'Expected three practice questions for ${type.name}',
      );
    }
    expect(
      practiceChallengeQuestions.map((question) => question.id).toSet(),
      hasLength(18),
    );
    expect(
      practiceChallengeQuestions.every(
        (question) =>
            (question.answerMode == ChallengeAnswerMode.multipleChoice &&
                question.correctOptionId != null) ||
            (question.answerMode == ChallengeAnswerMode.ordering &&
                question.correctOrder.isNotEmpty),
      ),
      isTrue,
    );
  });

  testWidgets('practice intro uses encouraging student-facing language',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StudentChallengeScreen()),
    );

    expect(find.text('جاهز لمغامرة التحديات؟'), findsOneWidget);
    expect(find.text('اختر المغامرة التي تحبها وابدأ التحدي!'), findsOneWidget);
    expect(find.textContaining('18 سؤالًا'), findsNothing);
    expect(find.textContaining('يصمم لك محفّظك تحديات خاصة'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
  });

  testWidgets('student solves one type then returns to choose another',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StudentChallengeScreen()),
    );

    await tester.tap(find.text('أكمل الآية'));
    await tester.pumpAndSettle();
    expect(find.text('التحدي 1 من 3'), findsOneWidget);

    await tester.tap(find.text('الْفَلَقِ'));
    await tester.pump();
    await tester.tap(find.text('التحدي التالي'));
    await tester.pumpAndSettle();
    expect(find.text('التحدي 2 من 3'), findsOneWidget);

    await tester.tap(find.text('الْكَوْثَرَ'));
    await tester.pump();
    await tester.tap(find.text('التحدي التالي'));
    await tester.pumpAndSettle();
    expect(find.text('التحدي 3 من 3'), findsOneWidget);

    await tester.tap(find.text('خُسْرٍ'));
    await tester.pump();
    await tester.tap(find.text('إنهاء المغامرة'));
    await tester.pump();

    final leftFireworks = tester.widget<ConfettiWidget>(
      find.byKey(const Key('challenge-fireworks-left')),
    );
    final rightFireworks = tester.widget<ConfettiWidget>(
      find.byKey(const Key('challenge-fireworks-right')),
    );
    expect(
      leftFireworks.confettiController.state,
      ConfettiControllerState.playing,
    );
    expect(
      rightFireworks.confettiController.state,
      ConfettiControllerState.playing,
    );

    // Confetti particles can keep scheduling frames longer than the
    // controller duration, so advance past the animation deterministically.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('اختر مغامرة أخرى'), findsOneWidget);

    await tester.tap(find.text('اختر مغامرة أخرى'));
    await tester.pump();
    expect(find.text('جاهز لمغامرة التحديات؟'), findsOneWidget);
    expect(find.text('اسم السورة'), findsOneWidget);
  });

  test('active challenge is filtered by the active child profile', () {
    final session = <String, dynamic>{
      'id': 'session-a',
      'studentId': 'parent-a',
      'studentProfileId': 'child-a',
      'mohaffezId': 'teacher-a',
      'mohaffezName': 'المحفّظ',
      'challengeAccess': {
        'status': 'open',
        'studentProfileId': 'child-a',
        'setVersion': 'v1',
        'expiresAt': DateTime.now().add(const Duration(hours: 1)),
      },
      'challengeSet': [
        {
          'id': 'q1',
          'type': 'name_surah',
          'answerMode': 'multiple_choice',
          'question': 'ما اسم السورة؟',
          'options': [
            {'id': 'a', 'text': 'الإخلاص'},
            {'id': 'b', 'text': 'الفلق'},
          ],
        },
      ],
    };

    expect(
      activeChallengeFromSessions(
        [session],
        studentId: 'parent-a',
        studentProfileId: 'child-a',
      ),
      isNotNull,
    );
    expect(
      activeChallengeFromSessions(
        [session],
        studentId: 'parent-a',
        studentProfileId: 'child-b',
      ),
      isNull,
    );
  });

  test('closed or expired challenges are not exposed on the home card', () {
    final base = <String, dynamic>{
      'id': 'session-a',
      'studentId': 'student-a',
      'mohaffezId': 'teacher-a',
      'challengeSet': [
        {
          'id': 'q1',
          'type': 'open_question',
          'answerMode': 'teacher_review',
          'question': 'سؤال',
        },
      ],
    };

    expect(
      activeChallengeFromSessions(
        [
          {
            ...base,
            'challengeAccess': {
              'status': 'closed',
              'studentProfileId': 'self',
              'setVersion': 'v1',
            },
          },
        ],
        studentId: 'student-a',
        studentProfileId: null,
      ),
      isNull,
    );

    expect(
      activeChallengeFromSessions(
        [
          {
            ...base,
            'challengeAccess': {
              'status': 'open',
              'studentProfileId': 'self',
              'setVersion': 'v1',
              'expiresAt': DateTime(2025),
            },
          },
        ],
        studentId: 'student-a',
        studentProfileId: null,
        now: DateTime(2026),
      ),
      isNull,
    );
  });

  test('a scored challenge remains available only as local replay', () {
    final challenge = activeChallengeFromSessions(
      [
        {
          'id': 'session-a',
          'studentId': 'student-a',
          'mohaffezId': 'teacher-a',
          'challengeAccess': {
            'status': 'completed',
            'studentProfileId': 'self',
            'setVersion': 'v1',
            'expiresAt': DateTime.now().add(const Duration(hours: 1)),
          },
          'challengeResult': {
            'scoredAttemptId': 'attempt-1',
          },
          'challengeSet': [
            {
              'id': 'q1',
              'type': 'open_question',
              'answerMode': 'teacher_review',
              'question': 'سؤال',
            },
          ],
        },
      ],
      studentId: 'student-a',
      studentProfileId: null,
    );

    expect(challenge, isNotNull);
    expect(challenge!.hasScoredAttempt, isTrue);
  });
}
