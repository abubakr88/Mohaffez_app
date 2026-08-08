import 'dart:convert';
import 'dart:io';

import 'package:quran/quran.dart' as quran;

const _outputDirectory = 'assets/quran_challenge';

void main() {
  final output = Directory(_outputDirectory)..createSync(recursive: true);
  final normalizedSurahs = <String, Set<int>>{};

  for (var surah = 1; surah <= quran.totalSurahCount; surah++) {
    for (var ayah = 1; ayah <= quran.getVerseCount(surah); ayah++) {
      final text = quran.getVerse(surah, ayah).trim();
      (normalizedSurahs[_normalize(text)] ??= <int>{}).add(surah);
    }
  }

  final catalog = <Map<String, Object>>[];
  for (var surah = 1; surah <= quran.totalSurahCount; surah++) {
    final verses = [
      for (var ayah = 1; ayah <= quran.getVerseCount(surah); ayah++)
        quran.getVerse(surah, ayah).trim(),
    ];
    final ambiguous = <int>[
      for (var index = 0; index < verses.length; index++)
        if ((normalizedSurahs[_normalize(verses[index])]?.length ?? 0) > 1)
          index + 1,
    ];
    final pages = <int>[
      for (var ayah = 1; ayah <= verses.length; ayah++)
        quran.getPageNumber(surah, ayah),
    ];
    final juzNumbers = <int>[
      for (var ayah = 1; ayah <= verses.length; ayah++)
        quran.getJuzNumber(surah, ayah),
    ];
    final number = surah.toString().padLeft(3, '0');
    File('${output.path}/s$number.json').writeAsStringSync(
      jsonEncode(<String, Object>{
        'v': verses,
        'p': pages,
        'j': juzNumbers,
        if (ambiguous.isNotEmpty) 'a': ambiguous,
      }),
      flush: true,
    );
    catalog.add(<String, Object>{
      'n': surah,
      'name': quran.getSurahNameArabic(surah),
      'count': verses.length,
    });
  }

  File('${output.path}/catalog.json').writeAsStringSync(
    jsonEncode(catalog),
    flush: true,
  );
}

String _normalize(String text) => text
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
