import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

void main() {
  test('public challenge map never exposes answer keys', () {
    final question = ChallengeQuestion(
      id: 'q1',
      type: ChallengeType.nameSurah,
      answerMode: ChallengeAnswerMode.multipleChoice,
      question: 'ما اسم السورة؟',
      answer: 'إجابة مرجعية',
      options: const [
        ChallengeOption(id: 'a', text: 'الإخلاص'),
        ChallengeOption(id: 'b', text: 'الفلق'),
      ],
      correctOptionId: 'a',
      correctOrder: const ['a', 'b'],
      createdAt: DateTime(2026),
    );

    final public = question.toPublicMap();

    expect(public.containsKey('answer'), isFalse);
    expect(public.containsKey('correctOptionId'), isFalse);
    expect(public.containsKey('correctOrder'), isFalse);
    expect(public['options'], isNotEmpty);
  });

  test('learner keys isolate self and child profiles', () {
    expect(
      challengeLearnerKey('student', null),
      'student__self',
    );
    expect(
      challengeLearnerKey('student', 'child-a'),
      'student__child-a',
    );
    expect(
      challengeLearnerKey('student', 'child-a'),
      isNot(challengeLearnerKey('student', 'child-b')),
    );
  });
}
