import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_finder_app/data/quran_challenge_generator.dart';
import 'package:mohaffez_finder_app/data/recitation_deck.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds six unique page-based cards across an assignment', () async {
    final generator = await QuranChallengeGenerator.load([2]);
    final cards = RecitationDeckBuilder(generator).build(
      const RecitationDeckConfig(
        scopes: [
          RecitationScope(
            surahNumber: 2,
            surahName: 'البقرة',
            fromAyah: 1,
            toAyah: 100,
          ),
        ],
      ),
      seed: 7,
    );

    expect(cards, hasLength(6));
    expect(cards.map((card) => card.id).toSet(), hasLength(6));
    expect(cards.every((card) => card.fromAyah >= 1), isTrue);
    expect(cards.every((card) => card.toAyah <= 100), isTrue);
    expect(cards.map((card) => card.pageNumber).toSet().length,
        greaterThanOrEqualTo(5));
  });

  test('never duplicates cards when a short scope has fewer verses', () async {
    final generator = await QuranChallengeGenerator.load([112]);
    final cards = RecitationDeckBuilder(generator).build(
      const RecitationDeckConfig(
        scopes: [
          RecitationScope(surahNumber: 112, surahName: 'الإخلاص'),
        ],
        cardCount: 8,
      ),
    );

    expect(cards, hasLength(4));
    expect(cards.map((card) => card.id).toSet(), hasLength(4));
    expect(cards.every((card) => card.fromAyah == card.toAyah), isTrue);
  });

  test('disabled and invalid scopes are ignored', () async {
    final generator = await QuranChallengeGenerator.load([1, 2]);
    final cards = RecitationDeckBuilder(generator).build(
      const RecitationDeckConfig(
        scopes: [
          RecitationScope(
            surahNumber: 1,
            surahName: 'الفاتحة',
            enabled: false,
          ),
          RecitationScope(
            surahNumber: 2,
            surahName: 'البقرة',
            fromAyah: 20,
            toAyah: 10,
          ),
        ],
      ),
    );

    expect(cards, isEmpty);
  });
}
