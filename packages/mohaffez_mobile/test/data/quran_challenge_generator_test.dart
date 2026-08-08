import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/data/quran_challenge_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranChallengeGenerator generator;

  setUpAll(() async {
    generator = await QuranChallengeGenerator.load(
      List.generate(114, (index) => index + 1),
    );
  });

  test('all 114 surahs expose at least five objective questions', () {
    for (var surah = 1; surah <= 114; surah++) {
      final questions = generator.candidatesForSurah(surah);
      expect(
        questions.length,
        greaterThanOrEqualTo(5),
        reason: 'Surah $surah does not have enough generated questions',
      );
      expect(
        questions.map((question) => question.id).toSet(),
        hasLength(questions.length),
        reason: 'Surah $surah contains duplicate question IDs',
      );
    }
  });

  test('asset store deduplicates concurrent catalog and surah loads', () async {
    final bundle = _CountingAssetBundle();
    final store = QuranChallengeAssetStore(bundle);

    await Future.wait([
      QuranChallengeGenerator.load([1], store: store),
      QuranChallengeGenerator.load([1, 2], store: store),
    ]);

    expect(bundle.loads['assets/quran_challenge/catalog.json'], 1);
    expect(bundle.loads['assets/quran_challenge/s001.json'], 1);
    expect(bundle.loads['assets/quran_challenge/s002.json'], 1);
    expect(bundle.loads['assets/quran_challenge/s036.json'], 1);
  });

  test('Al-Baqarah candidates cover pages and support Juz scope', () async {
    final baqarah = await QuranChallengeGenerator.load([2]);
    final all = baqarah.candidatesForSurah(2);

    expect(all.length, greaterThan(27));
    expect(
      all
          .map((question) =>
              baqarah.locationFor(2, question.anchorAyah!).pageNumber)
          .toSet()
          .length,
      greaterThanOrEqualTo(40),
    );
    expect(
      all
          .map((question) =>
              baqarah.locationFor(2, question.anchorAyah!).juzNumber)
          .toSet(),
      containsAll(<int>{1, 2, 3}),
    );

    final juzTwo = baqarah.candidatesForSurah(
      2,
      scope: const QuranChallengeScope(juzNumber: 2),
    );
    expect(juzTwo, isNotEmpty);
    expect(
      juzTwo.every(
        (question) =>
            baqarah.locationFor(2, question.anchorAyah!).juzNumber == 2,
      ),
      isTrue,
    );

    final suggestion = baqarah.suggest(
      surahNumbers: const [2],
      types: QuranChallengeGenerator.generatedTypes,
      count: 10,
      seed: 'baqarah-pages',
    );
    expect(
      suggestion
          .map((question) =>
              baqarah.locationFor(2, question.anchorAyah!).pageNumber)
          .toSet(),
      hasLength(10),
    );
  });

  test('generated questions contain real text and valid objective keys', () {
    for (var surah = 1; surah <= 114; surah++) {
      for (final question in generator.candidatesForSurah(surah)) {
        expect(question.source, quranGeneratedQuestionSource);
        expect(question.generatorVersion, quranChallengeGeneratorVersion);
        expect(question.surahNumber, surah);
        expect(question.anchorAyah, isNotNull);
        expect(question.question, isNot(contains(RegExp(r'آية\s+\d+'))));
        expect(question.question.length, lessThanOrEqualTo(1200));
        expect(
          question.type,
          isIn(QuranChallengeGenerator.generatedTypes),
        );

        if (question.answerMode == ChallengeAnswerMode.multipleChoice) {
          expect(question.options, hasLength(4));
          expect(
            question.options.map((option) => option.id).toSet(),
            hasLength(4),
          );
          expect(
            question.options.any(
              (option) => option.id == question.correctOptionId,
            ),
            isTrue,
          );
        } else {
          expect(question.answerMode, ChallengeAnswerMode.ordering);
          expect(question.options, hasLength(3));
          expect(question.correctOrder, hasLength(3));
          expect(
            question.correctOrder.toSet(),
            question.options.map((option) => option.id).toSet(),
          );
        }
        expect(
          question.options.every(
            (option) => option.text.isNotEmpty && option.text.length <= 500,
          ),
          isTrue,
        );
      }
    }
  });

  test('suggestions are deterministic, balanced, and support exclusions', () {
    final first = generator.suggest(
      surahNumbers: const [1, 2, 112],
      types: QuranChallengeGenerator.generatedTypes,
      count: 10,
      seed: 'session-a:0',
    );
    final second = generator.suggest(
      surahNumbers: const [112, 2, 1],
      types: QuranChallengeGenerator.generatedTypes,
      count: 10,
      seed: 'session-a:0',
    );

    expect(first.map((question) => question.id), second.map((q) => q.id));
    expect(first.map((question) => question.id).toSet(), hasLength(10));
    expect(first.map((question) => question.type).toSet().length, 3);
    expect(first.map((question) => question.surahNumber).toSet().length, 3);

    final replacement = generator.suggest(
      surahNumbers: const [1, 2, 112],
      types: QuranChallengeGenerator.generatedTypes,
      count: 1,
      seed: 'session-a:replacement',
      excludedIds: first.map((question) => question.id).toSet(),
    );
    expect(replacement, hasLength(1));
    expect(first.map((question) => question.id),
        isNot(contains(replacement.single.id)));
  });

  test('publish maps omit timestamps and preserve source metadata', () {
    final question = generator.candidatesForSurah(1).first;
    final map = question.toPublishMap();

    expect(map['id'], question.id);
    expect(map['source'], quranGeneratedQuestionSource);
    expect(map['generatorVersion'], quranChallengeGeneratorVersion);
    expect(map['surahNumber'], 1);
    expect(map, isNot(contains('createdAt')));
  });
}

class _CountingAssetBundle extends CachingAssetBundle {
  final Map<String, int> loads = {};

  @override
  Future<ByteData> load(String key) {
    loads.update(key, (count) => count + 1, ifAbsent: () => 1);
    return rootBundle.load(key);
  }
}
