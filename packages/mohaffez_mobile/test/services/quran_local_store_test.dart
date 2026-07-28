import 'package:flutter_test/flutter_test.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:mohaffez_finder_app/services/quran_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('progress is saved locally with bookmarks, recents, and daily pages',
      () async {
    final store = await QuranLocalStore.create();
    const scope = QuranLocalScope(userId: 'student-1');
    final now = DateTime(2026, 7, 28, 10);

    var progress = const QuranLocalProgress()
        .recordPage(12, now: now)
        .recordPage(15, now: now)
        .recordPage(12, now: now)
        .toggleBookmark(15);
    await store.saveProgress(scope, progress);

    progress = store.loadProgress(scope);
    expect(progress.lastPage, 12);
    expect(progress.recentPages, [12, 15]);
    expect(progress.bookmarkedPages, [15]);
    expect(progress.pagesReadOn(now), 2);
  });

  test('cached sessions are updated, sorted, and limited to ten', () async {
    final store = await QuranLocalStore.create();
    const scope = QuranLocalScope(userId: 'student-1');

    final sessions = List.generate(
      12,
      (index) => _session(
        id: 'session-$index',
        date: DateTime(2026, 7, index + 1),
        hifz: index == 11 ? 'سورة الملك' : null,
      ),
    );
    await store.cacheLoadedSessions(scope, sessions);

    var cached = store.loadSessions(scope);
    expect(cached, hasLength(10));
    expect(cached.first.sessionId, 'session-11');
    expect(cached.first.hasHifz, isTrue);
    expect(cached.last.sessionId, 'session-2');

    await store.cacheSession(
      scope,
      _session(
        id: 'session-11',
        date: DateTime(2026, 7, 12),
        hifz: 'سورة القلم',
      ),
    );
    cached = store.loadSessions(scope);
    expect(cached, hasLength(10));
    expect(cached.first.hifzAssignment, 'سورة القلم');
  });

  test('completed session with ward and no mistakes is retained', () async {
    final store = await QuranLocalStore.create();
    const scope = QuranLocalScope(userId: 'student-1');

    await store.cacheSession(
      scope,
      _session(
        id: 'ward-only',
        date: DateTime(2026, 7, 28),
        hifz: 'سورة النبأ',
        muraja: 'سورة الملك',
      ),
    );

    final cached = store.loadSessions(scope);
    expect(cached.single.hasWard, isTrue);
    expect(cached.single.hasMistakes, isFalse);
  });

  test('teacher mistake details survive local serialization', () async {
    final store = await QuranLocalStore.create();
    const scope = QuranLocalScope(userId: 'student-1');

    await store.cacheSession(
      scope,
      {
        ..._session(id: 'with-note', date: DateTime(2026, 7, 28)),
        'mistakes': [
          {
            'id': 'mistake-1',
            'pageNumber': 42,
            'surahNumber': 2,
            'ayahNumber': 253,
            'xPosition': 0.4,
            'yPosition': 0.6,
            'type': 'tajweed',
            'wordText': 'الحي',
            'correctionNote': 'انتبه إلى المد',
            'markedAt': DateTime(2026, 7, 28, 9),
          },
        ],
      },
    );

    final mistake = store.loadSessions(scope).single.mistakes.single;
    expect(mistake.pageNumber, 42);
    expect(mistake.wordText, 'الحي');
    expect(mistake.correctionNote, 'انتبه إلى المد');
    expect(mistake.type.name, 'tajweed');
  });

  test('non-completed sessions are not cached', () async {
    final store = await QuranLocalStore.create();
    const scope = QuranLocalScope(userId: 'student-1');
    final session = _session(id: 'pending', date: DateTime(2026, 7, 28))
      ..['status'] = 'accepted';

    await store.cacheSession(scope, session);

    expect(store.loadSessions(scope), isEmpty);
  });

  test('local data is isolated per child profile', () async {
    final store = await QuranLocalStore.create();
    const firstChild = QuranLocalScope(
      userId: 'parent-1',
      studentProfileId: 'child-a',
    );
    const secondChild = QuranLocalScope(
      userId: 'parent-1',
      studentProfileId: 'child-b',
    );

    await store.saveProgress(
      firstChild,
      const QuranLocalProgress(lastPage: 77),
    );
    await store.cacheSession(
      firstChild,
      _session(id: 'a', date: DateTime(2026, 7, 28)),
    );

    expect(store.loadProgress(firstChild).lastPage, 77);
    expect(store.loadProgress(secondChild).lastPage, 1);
    expect(store.loadSessions(firstChild), hasLength(1));
    expect(store.loadSessions(secondChild), isEmpty);
  });

  test('corrupted local data falls back without throwing', () async {
    SharedPreferences.setMockInitialValues({
      'persistent_quran_progress_v1_student-1_self': '{invalid',
      'persistent_quran_sessions_v1_student-1_self': 'not-json',
    });
    final store = await QuranLocalStore.create();
    const scope = QuranLocalScope(userId: 'student-1');

    expect(store.loadProgress(scope).lastPage, 1);
    expect(store.loadSessions(scope), isEmpty);
  });

  test('reviewed teacher mistakes are persisted locally and profile-scoped',
      () async {
    final store = await QuranLocalStore.create();
    const firstChild = QuranLocalScope(
      userId: 'parent-1',
      studentProfileId: 'child-a',
    );
    const secondChild = QuranLocalScope(
      userId: 'parent-1',
      studentProfileId: 'child-b',
    );
    const mistake = QuranMistake(
      id: 'mistake-1',
      pageNumber: 42,
      surahNumber: 2,
      ayahNumber: 253,
      xPosition: 0.4,
      yPosition: 0.6,
      type: MistakeType.tajweed,
    );
    final key = quranMistakeReviewKey('session-1', mistake);

    var progress = const QuranLocalProgress().toggleMistakeReviewed(key);
    await store.saveProgress(firstChild, progress);

    progress = store.loadProgress(firstChild);
    expect(progress.isMistakeReviewed(key), isTrue);
    expect(store.loadProgress(secondChild).isMistakeReviewed(key), isFalse);

    progress = progress.toggleMistakeReviewed(key);
    expect(progress.isMistakeReviewed(key), isFalse);

    progress = progress
        .toggleMistakeReviewed(key)
        .toggleBookmark(42)
        .clearReviewedMistakes();
    expect(progress.isMistakeReviewed(key), isFalse);
    expect(progress.bookmarkedPages, [42]);
  });
}

Map<String, dynamic> _session({
  required String id,
  required DateTime date,
  String? hifz,
  String? muraja,
}) {
  return {
    'id': id,
    'status': 'completed',
    'mohaffezId': 'teacher-1',
    'mohaffezName': 'المعلم أحمد',
    'sessionDate': date,
    'hifzAssignment': hifz,
    'murajaAssignment': muraja,
    'mistakes': const <Map<String, dynamic>>[],
  };
}
