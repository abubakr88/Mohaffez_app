// lib/services/quran_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class QuranService {
  static final QuranService _instance = QuranService._internal();
  factory QuranService() => _instance;
  QuranService._internal();

  Map<String, dynamic>? _quranData;
  bool _isLoaded = false;
  bool _usingMockData = false;

  // ✅ CDN base URL for Quran images (quran.com CDN)
  // ignore: unused_field
  static const String _imageCdnBase = 'https://cdn.quran.com/images/w';
  // ignore: unused_field
  static const int _imageWidth = 1024; // Resolution: 1024px width

  /// Get page image URL.
  /// Mobile: quran.islam-db.com (no CORS restriction on native).
  /// Web: quran.ksu.edu.sa (sends CORS headers, required by browsers).
  String getPageImageUrl(int pageNumber) {
    final padded = pageNumber.toString().padLeft(3, '0');
    if (kIsWeb) {
      return 'https://quran.ksu.edu.sa/images/png/$padded.png';
    }
    return 'https://quran.islam-db.com/data/pages/quranpages_1024/images/page$padded.png';
  }

  Future<Map<String, dynamic>> getPageData(int pageNumber) async {
    if (!_isLoaded) {
      await _loadQuranData();
    }

    final juz = _getJuzForPage(pageNumber);
    final verses = _getVersesForPage(pageNumber);

    return {
      'pageNumber': pageNumber,
      'juz': juz,
      'verses': verses,
      'usingMockData': _usingMockData,
    };
  }

  Future<Map<String, dynamic>> getPageInfo(int pageNumber) async {
    final pageData = await getPageData(pageNumber);
    
    return {
      ...pageData,
      'imageUrl': getPageImageUrl(pageNumber), // CDN URL
    };
  }

  /// Load ONLY the JSON data (not images)
  Future<void> _loadQuranData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/quran_data.json');
      _quranData = json.decode(jsonString);
      _isLoaded = true;
      _usingMockData = false;
      debugPrint('✅ Quran data loaded from JSON');
    } catch (e) {
      debugPrint('⚠️ Using mock data: $e');
      _quranData = _generateBasicQuranData();
      _isLoaded = true;
      _usingMockData = true;
    }
  }

  int _getJuzForPage(int pageNumber) {
    final juzBoundaries = {
      1: 1, 22: 2, 42: 3, 62: 4, 82: 5, 102: 6, 121: 7, 142: 8,
      162: 9, 182: 10, 201: 11, 222: 12, 242: 13, 262: 14, 282: 15,
      302: 16, 322: 17, 342: 18, 362: 19, 382: 20, 402: 21, 422: 22,
      442: 23, 462: 24, 482: 25, 502: 26, 522: 27, 542: 28, 562: 29, 582: 30
    };

    for (var entry in juzBoundaries.entries.toList().reversed) {
      if (pageNumber >= entry.key) return entry.value;
    }
    return 1;
  }

  List<Map<String, dynamic>> _getVersesForPage(int pageNumber) {
    if (_quranData == null) return [];

    try {
      final pages = _quranData!['pages'] as List?;
      if (pages == null) return [];

      final matchingPages = pages
          .cast<Map<String, dynamic>>()
          .where((p) => p['page'] == pageNumber)
          .toList();

      if (matchingPages.isEmpty) return _generateMockVersesForPage(pageNumber);

      final pageData = matchingPages.first;
      final verses = pageData['verses'] as List?;
      if (verses == null) return [];

      return verses
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
    } catch (e) {
      debugPrint('Error getting verses for page $pageNumber: $e');
      return _generateMockVersesForPage(pageNumber);
    }
  }

  Map<String, dynamic> _generateBasicQuranData() {
    final pages = <Map<String, dynamic>>[];
    for (int i = 1; i <= 604; i++) {
      pages.add({'page': i, 'verses': _generateMockVersesForPage(i)});
    }
    return {'pages': pages};
  }

  List<Map<String, dynamic>> _generateMockVersesForPage(int pageNumber) {
    const versesPerPage = 15;
    final startVerse = ((pageNumber - 1) * versesPerPage) + 1;

    return List.generate(versesPerPage, (index) {
      final verseNumber = startVerse + index;
      return {
        'verse': verseNumber,
        'surah': _getSurahForVerse(verseNumber),
        'ayahNumber': verseNumber,
        'text': 'الآية رقم $verseNumber',
      };
    });
  }

  int _getSurahForVerse(int absoluteVerseNumber) {
    if (absoluteVerseNumber <= 7) return 1;
    if (absoluteVerseNumber <= 293) return 2;
    if (absoluteVerseNumber <= 493) return 3;
    return ((absoluteVerseNumber - 1) ~/ 50) + 1;
  }

  String getSurahName(int surahNumber) {
    final surahNames = {
      1: 'الفاتحة', 2: 'البقرة', 3: 'آل عمران', 4: 'النساء',
      5: 'المائدة', 6: 'الأنعام', 7: 'الأعراف', 8: 'الأنفال',
      9: 'التوبة', 10: 'يونس', 11: 'هود', 12: 'يوسف',
    };
    return surahNames[surahNumber] ?? 'سورة $surahNumber';
  }

  String getJuzName(int juzNumber) {
    if (juzNumber < 1 || juzNumber > 30) return 'جزء غير صالح';
    return 'الجزء $juzNumber';
  }

  bool isValidPage(int pageNumber) => pageNumber >= 1 && pageNumber <= totalPages;
  int? getNextPage(int currentPage) => currentPage >= totalPages ? null : currentPage + 1;
  int? getPreviousPage(int currentPage) => currentPage <= 1 ? null : currentPage - 1;

  bool get isLoaded => _isLoaded;
  bool get usingMockData => _usingMockData;

  static const int totalPages = 604;
  static const int totalJuz = 30;
  static const int totalSurahs = 114;
// lib/services/quran_service.dart

  static const Map<int, int> surahStartPages = {
    1: 1,   2: 2,   3: 50,  4: 77,  5: 106, 6: 128, 7: 151, 8: 177,
    9: 187, 10: 208,11: 221,12: 235,13: 249,14: 255,15: 262,16: 267,
    17: 282,18: 293,19: 305,20: 312,21: 322,22: 332,23: 342,24: 350,
    25: 359,26: 367,27: 377,28: 385,29: 396,30: 404,31: 411,32: 415,
    33: 418,34: 428,35: 434,36: 440,37: 446,38: 453,39: 458,40: 467,
    41: 477,42: 483,43: 489,44: 496,45: 499,46: 502,47: 507,48: 511,
    49: 515,50: 518,51: 520,52: 523,53: 526,54: 528,55: 531,56: 534,
    57: 537,58: 542,59: 545,60: 549,61: 551,62: 553,63: 554,64: 556,
    65: 558,66: 560,67: 562,68: 564,69: 566,70: 568,71: 570,72: 572,
    73: 574,74: 575,75: 577,76: 578,77: 580,78: 582,79: 583,80: 585,
    81: 586,82: 587,83: 587,84: 589,85: 590,86: 591,87: 591,88: 592,
    89: 593,90: 594,91: 595,92: 595,93: 596,94: 596,95: 597,96: 597,
    97: 598,98: 598,99: 599,100:599,101:600,102:600,103:601,104:601,
    105:601,106:602,107:602,108:602,109:603,110:603,111:603,112:604,
    113:604,114:604,
  };

  static const Map<int, String> surahNames = {
    1:'الفاتحة',   2:'البقرة',     3:'آل عمران',  4:'النساء',
    5:'المائدة',   6:'الأنعام',    7:'الأعراف',   8:'الأنفال',
    9:'التوبة',    10:'يونس',      11:'هود',       12:'يوسف',
    13:'الرعد',    14:'إبراهيم',   15:'الحجر',     16:'النحل',
    17:'الإسراء',  18:'الكهف',     19:'مريم',      20:'طه',
    21:'الأنبياء', 22:'الحج',      23:'المؤمنون',  24:'النور',
    25:'الفرقان',  26:'الشعراء',   27:'النمل',     28:'القصص',
    29:'العنكبوت', 30:'الروم',     31:'لقمان',     32:'السجدة',
    33:'الأحزاب',  34:'سبأ',       35:'فاطر',      36:'يس',
    37:'الصافات',  38:'ص',         39:'الزمر',     40:'غافر',
    41:'فصلت',     42:'الشورى',    43:'الزخرف',    44:'الدخان',
    45:'الجاثية',  46:'الأحقاف',   47:'محمد',      48:'الفتح',
    49:'الحجرات',  50:'ق',         51:'الذاريات',  52:'الطور',
    53:'النجم',    54:'القمر',     55:'الرحمن',    56:'الواقعة',
    57:'الحديد',   58:'المجادلة',  59:'الحشر',     60:'الممتحنة',
    61:'الصف',     62:'الجمعة',    63:'المنافقون', 64:'التغابن',
    65:'الطلاق',   66:'التحريم',   67:'الملك',     68:'القلم',
    69:'الحاقة',   70:'المعارج',   71:'نوح',       72:'الجن',
    73:'المزمل',   74:'المدثر',    75:'القيامة',   76:'الإنسان',
    77:'المرسلات', 78:'النبأ',     79:'النازعات',  80:'عبس',
    81:'التكوير',  82:'الانفطار',  83:'المطففين',  84:'الانشقاق',
    85:'البروج',   86:'الطارق',    87:'الأعلى',    88:'الغاشية',
    89:'الفجر',    90:'البلد',     91:'الشمس',     92:'الليل',
    93:'الضحى',    94:'الشرح',     95:'التين',     96:'العلق',
    97:'القدر',    98:'البينة',    99:'الزلزلة',   100:'العاديات',
    101:'القارعة', 102:'التكاثر',  103:'العصر',    104:'الهمزة',
    105:'الفيل',   106:'قريش',     107:'الماعون',  108:'الكوثر',
    109:'الكافرون',110:'النصر',    111:'المسد',    112:'الإخلاص',
    113:'الفلق',   114:'الناس',
  };

  static const Map<int, int> juzStartPages = {
    1:1,  2:22, 3:42, 4:62, 5:82,  6:102, 7:121, 8:142, 9:162, 10:182,
    11:201,12:221,13:242,14:262,15:282,16:302,17:322,18:342,19:362,20:382,
    21:402,22:422,23:442,24:462,25:482,26:502,27:522,28:542,29:562,30:582,
  };

}
