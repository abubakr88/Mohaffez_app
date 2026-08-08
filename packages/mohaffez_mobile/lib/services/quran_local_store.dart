import 'dart:convert';

import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int quranTotalPages = 604;
const int quranCachedSessionLimit = 10;

class QuranLocalScope {
  const QuranLocalScope({
    required this.userId,
    this.studentProfileId,
  });

  final String userId;
  final String? studentProfileId;

  String get learnerKey {
    final profileId = studentProfileId?.trim();
    return profileId == null || profileId.isEmpty ? 'self' : profileId;
  }
}

class QuranLocalProgress {
  const QuranLocalProgress({
    this.lastPage = 1,
    this.bookmarkedPages = const <int>[],
    this.recentPages = const <int>[],
    this.dailyGoalPages = 2,
    this.dailyPages = const <String, List<int>>{},
    this.reviewedMistakeKeys = const <String>[],
    this.updatedAt,
  });

  final int lastPage;
  final List<int> bookmarkedPages;
  final List<int> recentPages;
  final int dailyGoalPages;
  final Map<String, List<int>> dailyPages;
  final List<String> reviewedMistakeKeys;
  final DateTime? updatedAt;

  int pagesReadOn(DateTime date) => dailyPages[_dateKey(date)]?.length ?? 0;

  int get todayPagesRead => pagesReadOn(DateTime.now());

  int get currentStreak {
    var cursor = DateTime.now();
    var streak = 0;
    while (streak < 30) {
      if (pagesReadOn(cursor) == 0) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  bool isBookmarked(int page) => bookmarkedPages.contains(page);

  QuranLocalProgress recordPage(
    int page, {
    DateTime? now,
  }) {
    final safePage = page.clamp(1, quranTotalPages).toInt();
    final recordedAt = now ?? DateTime.now();
    final recent = <int>[
      safePage,
      ...recentPages.where((item) => item != safePage),
    ].take(10).toList();
    final daily = <String, List<int>>{
      for (final entry in dailyPages.entries)
        entry.key: List<int>.from(entry.value),
    };
    final todayKey = _dateKey(recordedAt);
    final todayPages = <int>{
      ...(daily[todayKey] ?? const <int>[]),
      safePage,
    }.toList()
      ..sort();
    daily[todayKey] = todayPages;

    final cutoff = DateTime(
      recordedAt.year,
      recordedAt.month,
      recordedAt.day,
    ).subtract(const Duration(days: 29));
    daily.removeWhere((key, _) {
      final date = DateTime.tryParse(key);
      return date == null || date.isBefore(cutoff);
    });

    return QuranLocalProgress(
      lastPage: safePage,
      bookmarkedPages: bookmarkedPages,
      recentPages: recent,
      dailyGoalPages: dailyGoalPages,
      dailyPages: daily,
      reviewedMistakeKeys: reviewedMistakeKeys,
      updatedAt: recordedAt,
    );
  }

  QuranLocalProgress toggleBookmark(int page) {
    final safePage = page.clamp(1, quranTotalPages).toInt();
    final bookmarks = <int>{...bookmarkedPages};
    if (!bookmarks.add(safePage)) {
      bookmarks.remove(safePage);
    }
    final sorted = bookmarks.toList()..sort();
    return QuranLocalProgress(
      lastPage: lastPage,
      bookmarkedPages: sorted,
      recentPages: recentPages,
      dailyGoalPages: dailyGoalPages,
      dailyPages: dailyPages,
      reviewedMistakeKeys: reviewedMistakeKeys,
      updatedAt: DateTime.now(),
    );
  }

  bool isMistakeReviewed(String key) => reviewedMistakeKeys.contains(key);

  QuranLocalProgress toggleMistakeReviewed(String key) {
    final reviewed = <String>{...reviewedMistakeKeys};
    if (!reviewed.add(key)) {
      reviewed.remove(key);
    }
    return QuranLocalProgress(
      lastPage: lastPage,
      bookmarkedPages: bookmarkedPages,
      recentPages: recentPages,
      dailyGoalPages: dailyGoalPages,
      dailyPages: dailyPages,
      reviewedMistakeKeys: reviewed.toList()..sort(),
      updatedAt: DateTime.now(),
    );
  }

  QuranLocalProgress clearReviewedMistakes() {
    return QuranLocalProgress(
      lastPage: lastPage,
      bookmarkedPages: bookmarkedPages,
      recentPages: recentPages,
      dailyGoalPages: dailyGoalPages,
      dailyPages: dailyPages,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lastPage': lastPage,
        'bookmarkedPages': bookmarkedPages,
        'recentPages': recentPages,
        'dailyGoalPages': dailyGoalPages,
        'dailyPages': dailyPages,
        'reviewedMistakeKeys': reviewedMistakeKeys,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory QuranLocalProgress.fromJson(Map<String, dynamic> json) {
    return QuranLocalProgress(
      lastPage: _safePage(json['lastPage']) ?? 1,
      bookmarkedPages: _safePageList(json['bookmarkedPages']),
      recentPages: _safePageList(
        json['recentPages'],
        sort: false,
      ).take(10).toList(),
      dailyGoalPages: ((json['dailyGoalPages'] as num?)?.toInt() ?? 2)
          .clamp(1, 604)
          .toInt(),
      dailyPages: _readDailyPages(json['dailyPages']),
      reviewedMistakeKeys: _safeStringList(json['reviewedMistakeKeys']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }
}

class CachedQuranSession {
  const CachedQuranSession({
    required this.sessionId,
    required this.mohaffezName,
    required this.sessionDate,
    required this.cachedAt,
    this.mohaffezId,
    this.studentProfileId,
    this.hifzAssignment,
    this.hifzFromAyah,
    this.hifzToAyah,
    this.murajaAssignment,
    this.murajaFromAyah,
    this.murajaToAyah,
    this.currentPage,
    this.pagesRead = const <int>[],
    this.mistakes = const <QuranMistake>[],
  });

  final String sessionId;
  final String? mohaffezId;
  final String mohaffezName;
  final DateTime sessionDate;
  final DateTime cachedAt;
  final String? studentProfileId;
  final String? hifzAssignment;
  final String? hifzFromAyah;
  final String? hifzToAyah;
  final String? murajaAssignment;
  final String? murajaFromAyah;
  final String? murajaToAyah;
  final int? currentPage;
  final List<int> pagesRead;
  final List<QuranMistake> mistakes;

  bool get hasHifz => _nonEmpty(hifzAssignment) != null;
  bool get hasMuraja => _nonEmpty(murajaAssignment) != null;
  bool get hasWard => hasHifz || hasMuraja;
  bool get hasMistakes => mistakes.isNotEmpty;

  factory CachedQuranSession.fromSessionMap(
    Map<String, dynamic> session, {
    String? fallbackStudentProfileId,
    DateTime? cachedAt,
  }) {
    final rawMistakes = session['mistakes'] as List<dynamic>? ?? const [];
    final mistakes = rawMistakes
        .whereType<Map>()
        .map((item) => QuranMistake.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((mistake) =>
            mistake.pageNumber >= 1 && mistake.pageNumber <= quranTotalPages)
        .toList();
    final date = _readDate(session['completedAt']) ??
        _readDate(session['sessionDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return CachedQuranSession(
      sessionId: _nonEmpty(session['id']) ?? '',
      mohaffezId: _nonEmpty(session['mohaffezId']),
      mohaffezName: _nonEmpty(session['mohaffezName']) ?? ArabicLabels.mohaffez,
      sessionDate: date,
      cachedAt: cachedAt ?? DateTime.now(),
      studentProfileId: _nonEmpty(session['studentProfileId']) ??
          _nonEmpty(fallbackStudentProfileId),
      hifzAssignment: _nonEmpty(session['hifzAssignment']),
      hifzFromAyah: _nonEmpty(session['hifzFromAyah']),
      hifzToAyah: _nonEmpty(session['hifzToAyah']),
      murajaAssignment: _nonEmpty(session['murajaAssignment']),
      murajaFromAyah: _nonEmpty(session['murajaFromAyah']),
      murajaToAyah: _nonEmpty(session['murajaToAyah']),
      currentPage: _safePage(session['currentPage']),
      pagesRead: _safePageList(session['pagesRead']),
      mistakes: mistakes,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'mohaffezId': mohaffezId,
        'mohaffezName': mohaffezName,
        'sessionDate': sessionDate.toIso8601String(),
        'cachedAt': cachedAt.toIso8601String(),
        'studentProfileId': studentProfileId,
        'hifzAssignment': hifzAssignment,
        'hifzFromAyah': hifzFromAyah,
        'hifzToAyah': hifzToAyah,
        'murajaAssignment': murajaAssignment,
        'murajaFromAyah': murajaFromAyah,
        'murajaToAyah': murajaToAyah,
        'currentPage': currentPage,
        'pagesRead': pagesRead,
        'mistakes': mistakes.map(_mistakeToJson).toList(),
      };

  factory CachedQuranSession.fromJson(Map<String, dynamic> json) {
    final rawMistakes = json['mistakes'] as List<dynamic>? ?? const [];
    return CachedQuranSession(
      sessionId: _nonEmpty(json['sessionId']) ?? '',
      mohaffezId: _nonEmpty(json['mohaffezId']),
      mohaffezName: _nonEmpty(json['mohaffezName']) ?? ArabicLabels.mohaffez,
      sessionDate: _readDate(json['sessionDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cachedAt:
          _readDate(json['cachedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      studentProfileId: _nonEmpty(json['studentProfileId']),
      hifzAssignment: _nonEmpty(json['hifzAssignment']),
      hifzFromAyah: _nonEmpty(json['hifzFromAyah']),
      hifzToAyah: _nonEmpty(json['hifzToAyah']),
      murajaAssignment: _nonEmpty(json['murajaAssignment']),
      murajaFromAyah: _nonEmpty(json['murajaFromAyah']),
      murajaToAyah: _nonEmpty(json['murajaToAyah']),
      currentPage: _safePage(json['currentPage']),
      pagesRead: _safePageList(json['pagesRead']),
      mistakes: rawMistakes
          .whereType<Map>()
          .map((item) => _mistakeFromJson(Map<String, dynamic>.from(item)))
          .where((mistake) =>
              mistake.pageNumber >= 1 && mistake.pageNumber <= quranTotalPages)
          .toList(),
    );
  }
}

class QuranLocalStore {
  QuranLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<QuranLocalStore> create() async =>
      QuranLocalStore(await SharedPreferences.getInstance());

  String _progressKey(QuranLocalScope scope) =>
      'persistent_quran_progress_v1_${Uri.encodeComponent(scope.userId)}_'
      '${Uri.encodeComponent(scope.learnerKey)}';

  String _sessionsKey(QuranLocalScope scope) =>
      'persistent_quran_sessions_v1_${Uri.encodeComponent(scope.userId)}_'
      '${Uri.encodeComponent(scope.learnerKey)}';

  QuranLocalProgress loadProgress(QuranLocalScope scope) {
    final raw = _prefs.getString(_progressKey(scope));
    if (raw == null || raw.isEmpty) return const QuranLocalProgress();
    try {
      return QuranLocalProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const QuranLocalProgress();
    }
  }

  Future<void> saveProgress(
    QuranLocalScope scope,
    QuranLocalProgress progress,
  ) async {
    await _prefs.setString(
      _progressKey(scope),
      jsonEncode(progress.toJson()),
    );
  }

  List<CachedQuranSession> loadSessions(QuranLocalScope scope) {
    final raw = _prefs.getString(_sessionsKey(scope));
    if (raw == null || raw.isEmpty) return const <CachedQuranSession>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final sessions = decoded
          .whereType<Map>()
          .map((item) =>
              CachedQuranSession.fromJson(Map<String, dynamic>.from(item)))
          .where((session) => session.sessionId.isNotEmpty)
          .toList()
        ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      return sessions.take(quranCachedSessionLimit).toList();
    } catch (_) {
      return const <CachedQuranSession>[];
    }
  }

  Future<List<CachedQuranSession>> cacheLoadedSessions(
    QuranLocalScope scope,
    Iterable<Map<String, dynamic>> loadedSessions,
  ) async {
    final byId = <String, CachedQuranSession>{
      for (final session in loadSessions(scope)) session.sessionId: session,
    };
    for (final raw in loadedSessions) {
      if (raw['status'] != 'completed') continue;
      final session = CachedQuranSession.fromSessionMap(
        raw,
        fallbackStudentProfileId: scope.studentProfileId,
      );
      if (session.sessionId.isEmpty) continue;
      byId[session.sessionId] = session;
    }

    final sessions = byId.values.toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    final limited = sessions.take(quranCachedSessionLimit).toList();
    await _prefs.setString(
      _sessionsKey(scope),
      jsonEncode(limited.map((session) => session.toJson()).toList()),
    );
    return limited;
  }

  Future<List<CachedQuranSession>> cacheSession(
    QuranLocalScope scope,
    Map<String, dynamic> session,
  ) =>
      cacheLoadedSessions(scope, [session]);

  Future<void> clearSessions(QuranLocalScope scope) async {
    await _prefs.remove(_sessionsKey(scope));
  }
}

String quranMistakeReviewKey(
  String sessionId,
  QuranMistake mistake,
) {
  final mistakeIdentity = mistake.id.trim().isNotEmpty
      ? mistake.id.trim()
      : [
          mistake.pageNumber,
          mistake.surahNumber,
          mistake.ayahNumber,
          mistake.type.name,
          mistake.xPosition.toStringAsFixed(4),
          mistake.yPosition.toStringAsFixed(4),
        ].join(':');
  return '${sessionId.trim()}:$mistakeIdentity';
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String? _nonEmpty(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _readDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value == null) return null;
  try {
    final dynamic converted = value.toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}

int? _safePage(dynamic value) {
  final page = (value as num?)?.toInt();
  if (page == null || page < 1 || page > quranTotalPages) return null;
  return page;
}

List<int> _safePageList(
  dynamic value, {
  bool sort = true,
}) {
  if (value is! List) return const <int>[];
  final pages = <int>[];
  for (final rawPage in value) {
    final page = _safePage(rawPage);
    if (page != null && !pages.contains(page)) pages.add(page);
  }
  if (sort) pages.sort();
  return pages;
}

List<String> _safeStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

Map<String, List<int>> _readDailyPages(dynamic value) {
  if (value is! Map) return const <String, List<int>>{};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: _safePageList(entry.value),
  };
}

Map<String, dynamic> _mistakeToJson(QuranMistake mistake) => {
      'id': mistake.id,
      'pageNumber': mistake.pageNumber,
      'surahNumber': mistake.surahNumber,
      'ayahNumber': mistake.ayahNumber,
      'xPosition': mistake.xPosition,
      'yPosition': mistake.yPosition,
      'type': mistake.type.name,
      'wordText': mistake.wordText,
      'correctionNote': mistake.correctionNote,
      'markedAt': mistake.markedAt?.toIso8601String(),
    };

QuranMistake _mistakeFromJson(Map<String, dynamic> json) {
  final typeName = _nonEmpty(json['type']) ?? 'other';
  return QuranMistake(
    id: _nonEmpty(json['id']) ?? '',
    pageNumber: _safePage(json['pageNumber']) ?? 1,
    surahNumber: (json['surahNumber'] as num?)?.toInt() ?? 1,
    ayahNumber: (json['ayahNumber'] as num?)?.toInt() ?? 1,
    xPosition: (json['xPosition'] as num?)?.toDouble() ?? 0,
    yPosition: (json['yPosition'] as num?)?.toDouble() ?? 0,
    type: MistakeType.values.firstWhere(
      (type) => type.name == typeName,
      orElse: () => MistakeType.other,
    ),
    wordText: _nonEmpty(json['wordText']),
    correctionNote: _nonEmpty(json['correctionNote']),
    markedAt: _readDate(json['markedAt']),
  );
}
