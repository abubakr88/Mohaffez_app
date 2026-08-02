import 'quran_challenge_generator.dart';

class RecitationScope {
  final int surahNumber;
  final String surahName;
  final int? fromAyah;
  final int? toAyah;
  final bool enabled;

  const RecitationScope({
    required this.surahNumber,
    required this.surahName,
    this.fromAyah,
    this.toAyah,
    this.enabled = true,
  });

  RecitationScope copyWith({
    int? surahNumber,
    String? surahName,
    int? fromAyah,
    int? toAyah,
    bool? enabled,
    bool clearRange = false,
  }) {
    return RecitationScope(
      surahNumber: surahNumber ?? this.surahNumber,
      surahName: surahName ?? this.surahName,
      fromAyah: clearRange ? null : fromAyah ?? this.fromAyah,
      toAyah: clearRange ? null : toAyah ?? this.toAyah,
      enabled: enabled ?? this.enabled,
    );
  }
}

class RecitationCard {
  final String id;
  final int surahNumber;
  final String surahName;
  final int fromAyah;
  final int toAyah;
  final int pageNumber;
  final int juzNumber;

  const RecitationCard({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    required this.fromAyah,
    required this.toAyah,
    required this.pageNumber,
    required this.juzNumber,
  });
}

class RecitationDeckConfig {
  final List<RecitationScope> scopes;
  final int cardCount;

  const RecitationDeckConfig({
    required this.scopes,
    this.cardCount = 6,
  }) : assert(cardCount == 4 || cardCount == 6 || cardCount == 8);
}

class RecitationDeckBuilder {
  final QuranChallengeGenerator generator;

  const RecitationDeckBuilder(this.generator);

  List<RecitationCard> build(RecitationDeckConfig config, {int seed = 0}) {
    final candidates = <RecitationCard>[];
    final seen = <String>{};
    for (final scope in config.scopes.where((item) => item.enabled)) {
      final count = generator.verseCount(scope.surahNumber);
      final from = (scope.fromAyah ?? 1).clamp(1, count).toInt();
      final to = (scope.toAyah ?? count).clamp(1, count).toInt();
      if (from > to) continue;
      final ranges = generator.pageRangesForSurah(
        scope.surahNumber,
        scope: QuranChallengeScope(fromAyah: from, toAyah: to),
      );
      for (final range in ranges) {
        final id = _id(scope.surahNumber, range.fromAyah, range.toAyah);
        if (!seen.add(id)) continue;
        candidates.add(
          RecitationCard(
            id: id,
            surahNumber: scope.surahNumber,
            surahName: scope.surahName,
            fromAyah: range.fromAyah,
            toAyah: range.toAyah,
            pageNumber: range.pageNumber,
            juzNumber: range.juzNumber,
          ),
        );
      }
    }
    if (candidates.isEmpty) return const [];

    while (candidates.length < config.cardCount) {
      candidates.sort(
        (left, right) => (right.toAyah - right.fromAyah)
            .compareTo(left.toAyah - left.fromAyah),
      );
      final sourceIndex = candidates.indexWhere(
        (card) => card.toAyah > card.fromAyah,
      );
      if (sourceIndex == -1) break;
      final source = candidates.removeAt(sourceIndex);
      final midpoint = (source.fromAyah + source.toAyah) ~/ 2;
      candidates.addAll([
        _copyRange(source, source.fromAyah, midpoint),
        _copyRange(source, midpoint + 1, source.toAyah),
      ]);
    }

    candidates.sort((left, right) {
      final surah = left.surahNumber.compareTo(right.surahNumber);
      return surah != 0 ? surah : left.fromAyah.compareTo(right.fromAyah);
    });
    final selected = candidates.length <= config.cardCount
        ? List<RecitationCard>.from(candidates)
        : _sampleEvenly(candidates, config.cardCount);
    _shuffle(selected, seed);
    return List.unmodifiable(selected);
  }

  static RecitationCard _copyRange(
    RecitationCard source,
    int from,
    int to,
  ) {
    return RecitationCard(
      id: _id(source.surahNumber, from, to),
      surahNumber: source.surahNumber,
      surahName: source.surahName,
      fromAyah: from,
      toAyah: to,
      pageNumber: source.pageNumber,
      juzNumber: source.juzNumber,
    );
  }

  static List<RecitationCard> _sampleEvenly(
    List<RecitationCard> values,
    int count,
  ) {
    if (count == 1) return [values[values.length ~/ 2]];
    return [
      for (var index = 0; index < count; index++)
        values[((index * (values.length - 1)) / (count - 1)).round()],
    ];
  }

  static void _shuffle(List<RecitationCard> cards, int seed) {
    var state = (seed.abs() + 1) % 2147483647;
    for (var index = cards.length - 1; index > 0; index--) {
      state = (state * 48271) % 2147483647;
      final swapIndex = state % (index + 1);
      final value = cards[index];
      cards[index] = cards[swapIndex];
      cards[swapIndex] = value;
    }
  }

  static String _id(int surah, int from, int to) =>
      'recitation-s$surah-a$from-$to';
}
