import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

const int quranChallengeGeneratorVersion = 2;
const String quranGeneratedQuestionSource = 'quran_generated';

class QuranLocation {
  final int pageNumber;
  final int juzNumber;

  const QuranLocation({
    required this.pageNumber,
    required this.juzNumber,
  });
}

class QuranAyahRange {
  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final int pageNumber;
  final int juzNumber;

  const QuranAyahRange({
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
    required this.pageNumber,
    required this.juzNumber,
  });
}

class QuranChallengeScope {
  final int? juzNumber;
  final int? fromAyah;
  final int? toAyah;

  const QuranChallengeScope({
    this.juzNumber,
    this.fromAyah,
    this.toAyah,
  }) : assert(
          (fromAyah == null && toAyah == null) ||
              (fromAyah != null && toAyah != null),
        );

  const QuranChallengeScope.entire()
      : juzNumber = null,
        fromAyah = null,
        toAyah = null;
}

class QuranChallengeAssetStore {
  static const _assetRoot = 'assets/quran_challenge';

  final AssetBundle bundle;
  Future<Map<int, _SurahCatalogEntry>>? _catalogFuture;
  final Map<int, Future<_SurahText>> _surahFutures = {};

  QuranChallengeAssetStore(this.bundle);

  Future<Map<int, _SurahCatalogEntry>> _loadCatalog() =>
      _catalogFuture ??= _readCatalog();

  Future<_SurahText> _loadSurah(int number) =>
      _surahFutures.putIfAbsent(number, () => _readSurah(number));

  Future<Map<int, _SurahCatalogEntry>> _readCatalog() async {
    final rawCatalog =
        jsonDecode(await bundle.loadString('$_assetRoot/catalog.json')) as List;
    return {
      for (final raw in rawCatalog)
        if (raw is Map)
          (raw['n'] as num).toInt(): _SurahCatalogEntry(
            number: (raw['n'] as num).toInt(),
            name: raw['name'] as String,
            verseCount: (raw['count'] as num).toInt(),
          ),
    };
  }

  Future<_SurahText> _readSurah(int number) async {
    final padded = number.toString().padLeft(3, '0');
    final raw = jsonDecode(
      await bundle.loadString('$_assetRoot/s$padded.json'),
    ) as Map<String, dynamic>;
    final verses = (raw['v'] as List).cast<String>();
    final pages = (raw['p'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toList();
    final juzNumbers = (raw['j'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toList();
    if (pages.length != verses.length || juzNumbers.length != verses.length) {
      throw StateError('Missing Quran location metadata for Surah $number');
    }
    return _SurahText(
      verses: verses,
      pages: pages,
      juzNumbers: juzNumbers,
      ambiguousAyahs: {
        for (final value in raw['a'] as List<dynamic>? ?? const [])
          (value as num).toInt(),
      },
    );
  }
}

class QuranChallengeGenerator {
  static const generatedTypes = <ChallengeType>{
    ChallengeType.nameSurah,
    ChallengeType.completeAyah,
    ChallengeType.orderAyahs,
  };

  static const _fallbackDistractorSurah = 36;
  static const _maxNameQuestions = 10;
  static const _maxContinuationQuestions = 10;
  static const _maxOrderingQuestions = 8;
  static final _createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  static final QuranChallengeAssetStore _defaultStore =
      QuranChallengeAssetStore(rootBundle);

  final Map<int, _SurahCatalogEntry> _catalog;
  final Map<int, _SurahText> _loadedSurahs;
  late final List<_VerseRef> _distractorVerses = _buildDistractorVerses();

  QuranChallengeGenerator._(this._catalog, this._loadedSurahs);

  /// Loads only the selected surahs plus one compact distractor surah.
  ///
  /// On Web every surah remains a separate lazy asset, so Quran text is not
  /// embedded in main.dart.js or retained for unselected surahs.
  static Future<QuranChallengeGenerator> load(
    Iterable<int> surahNumbers, {
    AssetBundle? bundle,
    QuranChallengeAssetStore? store,
  }) async {
    final selected = surahNumbers.toSet();
    if (selected.isEmpty) {
      throw ArgumentError.value(selected, 'surahNumbers', 'Cannot be empty');
    }
    for (final number in selected) {
      _validateSurahNumber(number);
    }

    final assetStore = store ??
        (bundle == null ? _defaultStore : QuranChallengeAssetStore(bundle));
    final catalog = await assetStore._loadCatalog();

    final required = {...selected, _fallbackDistractorSurah}.toList()..sort();
    final entries = await Future.wait(
      required.map(
        (number) async => MapEntry(number, await assetStore._loadSurah(number)),
      ),
    );
    return QuranChallengeGenerator._(catalog, Map.fromEntries(entries));
  }

  String surahName(int surahNumber) {
    _validateSurah(surahNumber);
    return _catalog[surahNumber]!.name;
  }

  int verseCount(int surahNumber) {
    _validateSurah(surahNumber);
    return _catalog[surahNumber]!.verseCount;
  }

  QuranLocation locationFor(int surahNumber, int ayahNumber) {
    _validateSurah(surahNumber);
    final text = _loadedSurahs[surahNumber];
    if (text == null) {
      throw StateError('Surah $surahNumber has not been loaded');
    }
    if (ayahNumber < 1 || ayahNumber > text.verses.length) {
      throw RangeError.range(
        ayahNumber,
        1,
        text.verses.length,
        'ayahNumber',
      );
    }
    return QuranLocation(
      pageNumber: text.pages[ayahNumber - 1],
      juzNumber: text.juzNumbers[ayahNumber - 1],
    );
  }

  Set<int> juzNumbersForSurah(int surahNumber) {
    final text = _loadedSurahs[surahNumber];
    if (text == null) {
      throw StateError('Surah $surahNumber has not been loaded');
    }
    return text.juzNumbers.toSet();
  }

  List<QuranAyahRange> pageRangesForSurah(
    int surahNumber, {
    QuranChallengeScope scope = const QuranChallengeScope.entire(),
  }) {
    final text = _loadedSurahs[surahNumber];
    if (text == null) {
      throw StateError('Surah $surahNumber has not been loaded');
    }
    final eligible = _eligibleAyahs(surahNumber, scope);
    final byPage = <int, List<int>>{};
    for (final ayah in eligible) {
      (byPage[text.pages[ayah - 1]] ??= []).add(ayah);
    }
    return byPage.entries.map((entry) {
      final ayahs = entry.value..sort();
      return QuranAyahRange(
        surahNumber: surahNumber,
        fromAyah: ayahs.first,
        toAyah: ayahs.last,
        pageNumber: entry.key,
        juzNumber: text.juzNumbers[ayahs.first - 1],
      );
    }).toList()
      ..sort((left, right) => left.pageNumber.compareTo(right.pageNumber));
  }

  List<ChallengeQuestion> candidatesForSurah(
    int surahNumber, {
    Set<ChallengeType> types = generatedTypes,
    QuranChallengeScope scope = const QuranChallengeScope.entire(),
  }) {
    _validateSurah(surahNumber);
    if (!_loadedSurahs.containsKey(surahNumber)) {
      throw StateError('Surah $surahNumber has not been loaded');
    }
    final eligible = _eligibleAyahs(surahNumber, scope);
    final questions = <ChallengeQuestion>[
      if (types.contains(ChallengeType.nameSurah))
        ..._nameSurahQuestions(
          surahNumber,
          _anchorsForType(
            surahNumber,
            eligible,
            ChallengeType.nameSurah,
          ),
        ),
      if (types.contains(ChallengeType.completeAyah))
        ..._continuationQuestions(
          surahNumber,
          _anchorsForType(
            surahNumber,
            eligible,
            ChallengeType.completeAyah,
          ),
        ),
      if (types.contains(ChallengeType.orderAyahs))
        ..._orderingQuestions(
          surahNumber,
          _anchorsForType(
            surahNumber,
            eligible,
            ChallengeType.orderAyahs,
          ),
        ),
    ];
    questions.sort((left, right) => left.id.compareTo(right.id));
    return List.unmodifiable(questions);
  }

  List<ChallengeQuestion> suggest({
    required Iterable<int> surahNumbers,
    required Set<ChallengeType> types,
    required int count,
    required String seed,
    QuranChallengeScope scope = const QuranChallengeScope.entire(),
    Set<String> excludedIds = const {},
  }) {
    if (count < 1 || count > 10) {
      throw ArgumentError.value(count, 'count', 'Must be between 1 and 10');
    }
    final surahs = surahNumbers.toSet().toList()..sort();
    if (surahs.isEmpty || types.isEmpty) return const [];

    final buckets = <String, List<ChallengeQuestion>>{};
    for (final surah in surahs) {
      for (final type in types) {
        final candidates = candidatesForSurah(
          surah,
          types: {type},
          scope: scope,
        ).where((question) => !excludedIds.contains(question.id)).toList();
        if (candidates.isEmpty) continue;
        _shuffle(
          candidates,
          _DeterministicRandom('$seed:$surah:${type.firestoreKey}'),
        );
        buckets['$surah:${type.firestoreKey}'] = candidates;
      }
    }

    final keys = buckets.keys.toList();
    _shuffle(keys, _DeterministicRandom('$seed:buckets'));
    final result = <ChallengeQuestion>[];
    final usedPages = <String>{};
    var madeProgress = true;
    while (result.length < count && madeProgress) {
      madeProgress = false;
      for (final key in keys) {
        final bucket = buckets[key]!;
        if (bucket.isEmpty) continue;
        var selectedIndex = bucket.length - 1;
        for (var index = bucket.length - 1; index >= 0; index--) {
          final question = bucket[index];
          final location = locationFor(
            question.surahNumber!,
            question.anchorAyah!,
          );
          final pageKey = '${question.surahNumber}:${location.pageNumber}';
          if (!usedPages.contains(pageKey)) {
            selectedIndex = index;
            break;
          }
        }
        final selected = bucket.removeAt(selectedIndex);
        final location = locationFor(
          selected.surahNumber!,
          selected.anchorAyah!,
        );
        usedPages.add('${selected.surahNumber}:${location.pageNumber}');
        result.add(selected);
        madeProgress = true;
        if (result.length == count) break;
      }
    }
    return List.unmodifiable(result);
  }

  List<ChallengeQuestion> _nameSurahQuestions(
    int surahNumber,
    List<int> anchors,
  ) {
    final text = _loadedSurahs[surahNumber]!;
    final result = <ChallengeQuestion>[];
    for (final ayah in anchors) {
      final verse = _verse(surahNumber, ayah);
      if (_isPlaceholder(verse) || text.ambiguousAyahs.contains(ayah)) {
        continue;
      }
      final correctId = 'surah:$surahNumber';
      final optionSurahs = <int>{surahNumber};
      final random = _DeterministicRandom('name:$surahNumber:$ayah');
      while (optionSurahs.length < 4) {
        optionSurahs.add(random.nextInt(114) + 1);
      }
      final options = optionSurahs
          .map(
            (number) => ChallengeOption(
              id: 'surah:$number',
              text: surahName(number),
            ),
          )
          .toList();
      _shuffle(options, random);
      result.add(
        ChallengeQuestion(
          id: _id(surahNumber, 'name', ayah),
          type: ChallengeType.nameSurah,
          answerMode: ChallengeAnswerMode.multipleChoice,
          source: quranGeneratedQuestionSource,
          generatorVersion: quranChallengeGeneratorVersion,
          surahNumber: surahNumber,
          anchorAyah: ayah,
          question: '﴿${_excerpt(verse, 260)}﴾ من أي سورة؟',
          options: options,
          correctOptionId: correctId,
          difficulty: 'easy',
          createdAt: _createdAt,
        ),
      );
    }
    return result;
  }

  List<ChallengeQuestion> _continuationQuestions(
    int surahNumber,
    List<int> anchors,
  ) {
    final count = verseCount(surahNumber);
    if (count < 2) return const [];
    final result = <ChallengeQuestion>[];
    for (final ayah in anchors) {
      final prompt = _verse(surahNumber, ayah);
      final correct = _verse(surahNumber, ayah + 1);
      if (_isPlaceholder(prompt) ||
          _isPlaceholder(correct) ||
          correct.length > 500) {
        continue;
      }
      final correctId = 'verse:$surahNumber:${ayah + 1}';
      final options = <ChallengeOption>[
        ChallengeOption(id: correctId, text: correct),
      ];
      final usedTexts = <String>{_normalizeVerse(correct)};
      final random = _DeterministicRandom('next:$surahNumber:$ayah');
      var cursor = random.nextInt(_distractorVerses.length);
      while (options.length < 4) {
        final candidate = _distractorVerses[cursor];
        cursor = (cursor + 1) % _distractorVerses.length;
        final normalized = _normalizeVerse(candidate.text);
        if (candidate.surahNumber == surahNumber &&
            (candidate.ayahNumber == ayah ||
                candidate.ayahNumber == ayah + 1)) {
          continue;
        }
        if (!usedTexts.add(normalized)) continue;
        options.add(
          ChallengeOption(
            id: 'verse:${candidate.surahNumber}:${candidate.ayahNumber}',
            text: candidate.text,
          ),
        );
      }
      _shuffle(options, random);
      result.add(
        ChallengeQuestion(
          id: _id(surahNumber, 'next', ayah),
          type: ChallengeType.completeAyah,
          answerMode: ChallengeAnswerMode.multipleChoice,
          source: quranGeneratedQuestionSource,
          generatorVersion: quranChallengeGeneratorVersion,
          surahNumber: surahNumber,
          anchorAyah: ayah,
          question: 'في سورة ${surahName(surahNumber)}، ما الآية التي تلي:\n'
              '﴿${_excerpt(prompt, 260)}﴾؟',
          options: options,
          correctOptionId: correctId,
          difficulty: 'medium',
          createdAt: _createdAt,
        ),
      );
    }
    return result;
  }

  List<ChallengeQuestion> _orderingQuestions(
    int surahNumber,
    List<int> starts,
  ) {
    final count = verseCount(surahNumber);
    if (count < 3) return const [];
    final result = <ChallengeQuestion>[];
    for (final start in starts) {
      final verses = List.generate(
        3,
        (index) => _VerseRef(
          surahNumber,
          start + index,
          _verse(surahNumber, start + index),
        ),
      );
      if (verses.any(
        (verse) => _isPlaceholder(verse.text) || verse.text.length > 500,
      )) {
        continue;
      }
      final correctOrder = verses
          .map((verse) => 'verse:${verse.surahNumber}:${verse.ayahNumber}')
          .toList();
      final options = verses
          .map(
            (verse) => ChallengeOption(
              id: 'verse:${verse.surahNumber}:${verse.ayahNumber}',
              text: verse.text,
            ),
          )
          .toList();
      _shuffle(
        options,
        _DeterministicRandom('order:$surahNumber:$start'),
      );
      result.add(
        ChallengeQuestion(
          id: _id(surahNumber, 'order', start),
          type: ChallengeType.orderAyahs,
          answerMode: ChallengeAnswerMode.ordering,
          source: quranGeneratedQuestionSource,
          generatorVersion: quranChallengeGeneratorVersion,
          surahNumber: surahNumber,
          anchorAyah: start,
          question: 'رتّب الآيات التالية من سورة ${surahName(surahNumber)} '
              'حسب ترتيبها الصحيح.',
          options: options,
          correctOrder: correctOrder,
          difficulty: 'hard',
          createdAt: _createdAt,
        ),
      );
    }
    return result;
  }

  List<int> _eligibleAyahs(int surahNumber, QuranChallengeScope scope) {
    final text = _loadedSurahs[surahNumber]!;
    final from = scope.fromAyah ?? 1;
    final to = scope.toAyah ?? text.verses.length;
    if (from < 1 || to > text.verses.length || from > to) {
      throw RangeError(
        'Invalid ayah range $from–$to for Surah $surahNumber',
      );
    }
    return [
      for (var ayah = from; ayah <= to; ayah++)
        if (scope.juzNumber == null ||
            text.juzNumbers[ayah - 1] == scope.juzNumber)
          ayah,
    ];
  }

  List<int> _anchorsForType(
    int surahNumber,
    List<int> eligible,
    ChallengeType type,
  ) {
    if (eligible.isEmpty) return const [];
    final eligibleSet = eligible.toSet();
    final valid = eligible
        .where((ayah) => _isValidAnchor(surahNumber, ayah, type, eligibleSet))
        .toList();
    final text = _loadedSurahs[surahNumber]!;
    final pageCount = valid.map((ayah) => text.pages[ayah - 1]).toSet().length;
    if (valid.length <= 20 || pageCount <= 2) {
      final limit = switch (type) {
        ChallengeType.nameSurah => _maxNameQuestions,
        ChallengeType.completeAyah => _maxContinuationQuestions,
        ChallengeType.orderAyahs => _maxOrderingQuestions,
        _ => valid.length,
      };
      return _sampleValues(valid, limit);
    }

    final byPage = <int, List<int>>{};
    for (final ayah in valid) {
      (byPage[text.pages[ayah - 1]] ??= []).add(ayah);
    }
    final pages = byPage.keys.toList()..sort();
    return [
      for (final page in pages) byPage[page]![byPage[page]!.length ~/ 2],
    ];
  }

  bool _isValidAnchor(
    int surahNumber,
    int ayah,
    ChallengeType type,
    Set<int> eligible,
  ) {
    final text = _loadedSurahs[surahNumber]!;
    final verse = _verse(surahNumber, ayah);
    if (_isPlaceholder(verse)) return false;
    switch (type) {
      case ChallengeType.nameSurah:
        return !text.ambiguousAyahs.contains(ayah);
      case ChallengeType.completeAyah:
        if (!eligible.contains(ayah + 1)) return false;
        final next = _verse(surahNumber, ayah + 1);
        return !_isPlaceholder(next) && next.length <= 500;
      case ChallengeType.orderAyahs:
        if (!eligible.contains(ayah + 1) || !eligible.contains(ayah + 2)) {
          return false;
        }
        for (var offset = 0; offset < 3; offset++) {
          final candidate = _verse(surahNumber, ayah + offset);
          if (_isPlaceholder(candidate) || candidate.length > 500) return false;
        }
        return true;
      default:
        return false;
    }
  }

  List<_VerseRef> _buildDistractorVerses() {
    final result = <_VerseRef>[];
    for (final entry in _loadedSurahs.entries) {
      for (var index = 0; index < entry.value.verses.length; index++) {
        final text = entry.value.verses[index];
        if (!_isPlaceholder(text) && text.length <= 500) {
          result.add(_VerseRef(entry.key, index + 1, text));
        }
      }
    }
    return result;
  }

  String _verse(int surahNumber, int ayahNumber) =>
      _loadedSurahs[surahNumber]!.verses[ayahNumber - 1];

  String _id(int surah, String type, int ayah) =>
      'qv$quranChallengeGeneratorVersion-s$surah-$type-a$ayah';

  static List<int> _samplePositions(int count, int limit) {
    if (count <= 0) return const [];
    if (count <= limit) {
      return List.generate(count, (index) => index + 1);
    }
    final values = <int>{};
    for (var index = 0; index < limit; index++) {
      values.add(1 + ((index * (count - 1)) / (limit - 1)).round());
    }
    return values.toList()..sort();
  }

  static List<int> _sampleValues(List<int> values, int limit) {
    if (values.length <= limit) return List<int>.from(values);
    return _samplePositions(values.length, limit)
        .map((position) => values[position - 1])
        .toList();
  }

  static String _excerpt(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final candidate = text.substring(0, maxLength);
    final lastSpace = candidate.lastIndexOf(' ');
    return '${candidate.substring(0, lastSpace > 0 ? lastSpace : maxLength)}…';
  }

  static String _normalizeVerse(String text) => text
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _isPlaceholder(String text) =>
      RegExp(r'^آية\s+\d+$').hasMatch(text.trim());

  void _validateSurah(int surahNumber) {
    _validateSurahNumber(surahNumber);
    if (!_catalog.containsKey(surahNumber)) {
      throw StateError('Missing catalog entry for Surah $surahNumber');
    }
  }

  static void _validateSurahNumber(int surahNumber) {
    if (surahNumber < 1 || surahNumber > 114) {
      throw RangeError.range(surahNumber, 1, 114, 'surahNumber');
    }
  }

  static void _shuffle<T>(List<T> items, _DeterministicRandom random) {
    for (var index = items.length - 1; index > 0; index--) {
      final swapIndex = random.nextInt(index + 1);
      final value = items[index];
      items[index] = items[swapIndex];
      items[swapIndex] = value;
    }
  }
}

class _SurahCatalogEntry {
  final int number;
  final String name;
  final int verseCount;

  const _SurahCatalogEntry({
    required this.number,
    required this.name,
    required this.verseCount,
  });
}

class _SurahText {
  final List<String> verses;
  final List<int> pages;
  final List<int> juzNumbers;
  final Set<int> ambiguousAyahs;

  const _SurahText({
    required this.verses,
    required this.pages,
    required this.juzNumbers,
    required this.ambiguousAyahs,
  });
}

class _VerseRef {
  final int surahNumber;
  final int ayahNumber;
  final String text;

  const _VerseRef(this.surahNumber, this.ayahNumber, this.text);
}

class _DeterministicRandom {
  static const int _modulus = 2147483647;
  static const int _multiplier = 48271;

  int _state;

  _DeterministicRandom(String seed) : _state = _hash(seed);

  int nextInt(int max) {
    if (max <= 0) {
      throw RangeError.range(max, 1, _modulus, 'max');
    }
    _state = (_state * _multiplier) % _modulus;
    return _state % max;
  }

  static int _hash(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) % _modulus;
    }
    return hash == 0 ? 1 : hash;
  }
}
