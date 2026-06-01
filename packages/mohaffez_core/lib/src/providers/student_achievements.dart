// lib/src/providers/student_achievements.dart
//
// Unified, fully-trackable achievement layer for students. Everything here is
// DERIVED from data already in Firestore (completed sessions + their saved quiz
// fields, and the memorizedSurahs subcollection) — no extra counters to keep in
// sync, so progress can never drift out of date.
//
// Surfaces four achievement families requested for the rewards revamp:
//   • attendance streak  (consecutive weeks with a completed session)
//   • quiz mastery       (correct answers / accuracy / best streak)
//   • juz milestones     (completed ajzaa + memorization milestones)
//   • points / XP        (a single currency aggregating all activity)
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, Timestamp;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── XP / points system ────────────────────────────────────────────────────────
/// Points awarded per unit of activity. Tuned so a memorized surah feels far
/// more valuable than a single quiz answer, while sessions are the steady core.
const int xpPerSession = 50;
const int xpPerSurah = 100;
const int xpPerQuizCorrect = 10;

int computeXp({
  required int sessions,
  required int surahs,
  required int quizCorrect,
}) =>
    sessions * xpPerSession + surahs * xpPerSurah + quizCorrect * xpPerQuizCorrect;

/// A cosmetic XP tier (separate from the session-based [StudentLevel] so the two
/// progress tracks can coexist — one rewards attendance, one rewards everything).
class XpTier {
  final String name;
  final String emoji;
  final int min;
  final int next; // -1 = max
  final int rank; // 0-based

  const XpTier({
    required this.name,
    required this.emoji,
    required this.min,
    required this.next,
    required this.rank,
  });

  double progress(int xp) {
    if (next == -1) return 1.0;
    final range = next - min;
    if (range <= 0) return 1.0;
    return ((xp - min) / range).clamp(0.0, 1.0);
  }

  int toNext(int xp) => next == -1 ? 0 : (next - xp).clamp(0, next);
}

const List<XpTier> xpTiers = [
  XpTier(name: 'برعم', emoji: '🌱', min: 0, next: 300, rank: 0),
  XpTier(name: 'مجتهد', emoji: '🌿', min: 300, next: 800, rank: 1),
  XpTier(name: 'متألق', emoji: '⭐', min: 800, next: 1800, rank: 2),
  XpTier(name: 'بطل الحفظ', emoji: '🏅', min: 1800, next: 3500, rank: 3),
  XpTier(name: 'نجم القرآن', emoji: '🌟', min: 3500, next: 6000, rank: 4),
  XpTier(name: 'الأسطورة', emoji: '👑', min: 6000, next: -1, rank: 5),
];

XpTier resolveXpTier(int xp) {
  XpTier current = xpTiers.first;
  for (final t in xpTiers) {
    if (xp >= t.min) current = t;
  }
  return current;
}

// ─── Juz milestones (reused by screen + achievements) ──────────────────────────
/// Which juz each surah (1-114) *starts* in. A juz is treated as "completed" when
/// every surah starting in it is memorized — matching the existing rewards UI.
const List<int> surahStartJuz = <int>[
  1, 1, 3, 4, 6, 7, 8, 9, 10, 11, 11, 12, 13, 13, 14, 14, 15, 15, 16, 16,
  17, 17, 18, 18, 18, 19, 19, 20, 20, 21, 21, 21, 21, 22, 22, 22, 23, 23, 23, 24,
  24, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 27, 27, 27, 27, 27, 27, 28, 28, 28,
  28, 28, 28, 28, 28, 28, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 29, 30, 30, 30,
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
  30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30,
];

/// Number of fully-memorized ajzaa given a set of memorized surah numbers.
int completedJuzCount(Set<int> memorized) {
  final total = <int, int>{};
  final done = <int, int>{};
  for (var n = 1; n <= 114; n++) {
    final juz = surahStartJuz[n - 1];
    total[juz] = (total[juz] ?? 0) + 1;
    if (memorized.contains(n)) done[juz] = (done[juz] ?? 0) + 1;
  }
  var count = 0;
  total.forEach((juz, t) {
    if ((done[juz] ?? 0) == t) count++;
  });
  return count;
}

// ─── Weekly attendance streak ──────────────────────────────────────────────────
/// Consecutive ISO-week streak counting back from the most recent session.
/// The streak only counts as "current" if the latest session is in the current
/// or previous week; otherwise it has lapsed and returns 0.
int computeWeeklyStreak(List<DateTime> sessionDates) {
  if (sessionDates.isEmpty) return 0;

  // Reduce each date to the Monday of its week (local), as a comparable key.
  int weekKey(DateTime d) {
    final monday = DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: (d.weekday - DateTime.monday) % 7));
    return monday.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  final weeks = sessionDates.map(weekKey).toSet().toList()..sort();
  final nowWeek = weekKey(DateTime.now());
  final latest = weeks.last;

  // Lapsed if the most recent activity is older than last week.
  if (nowWeek - latest > 7) return 0;

  var streak = 1;
  for (var i = weeks.length - 1; i > 0; i--) {
    if (weeks[i] - weeks[i - 1] == 7) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

// ─── Aggregated student progress (single Firestore read) ───────────────────────
class QuizStats {
  final int totalCorrect;
  final int totalAsked;
  final int bestStreak;
  final int sessionsWithQuiz;

  const QuizStats({
    this.totalCorrect = 0,
    this.totalAsked = 0,
    this.bestStreak = 0,
    this.sessionsWithQuiz = 0,
  });

  int get accuracyPct => totalAsked == 0 ? 0 : ((totalCorrect / totalAsked) * 100).round();
}

class StudentProgress {
  final int sessions;
  final List<DateTime> sessionDates;
  final QuizStats quiz;

  const StudentProgress({
    this.sessions = 0,
    this.sessionDates = const [],
    this.quiz = const QuizStats(),
  });

  int get weeklyStreak => computeWeeklyStreak(sessionDates);
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// One read of the student's completed sessions, yielding session count, dates
/// (for streaks) and aggregated quiz stats (for mastery). Replaces several
/// single-purpose queries with one. Auto-disposes per student.
final studentProgressProvider =
    FutureProvider.autoDispose.family<StudentProgress, String>((ref, studentId) async {
  final snap = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'completed')
      .get();

  final dates = <DateTime>[];
  var totalCorrect = 0;
  var totalAsked = 0;
  var bestStreak = 0;
  var sessionsWithQuiz = 0;

  for (final doc in snap.docs) {
    final d = doc.data();
    final date = _toDateTime(d['completedAt']) ??
        _toDateTime(d['sessionDate']) ??
        _toDateTime(d['date']) ??
        _toDateTime(d['updatedAt']);
    if (date != null) dates.add(date);

    final asked = (d['quizAsked'] as num?)?.toInt() ?? 0;
    if (asked > 0) {
      sessionsWithQuiz++;
      totalAsked += asked;
      totalCorrect += (d['quizCorrect'] as num?)?.toInt() ?? 0;
      final bs = (d['quizBestStreak'] as num?)?.toInt() ?? 0;
      if (bs > bestStreak) bestStreak = bs;
    }
  }

  return StudentProgress(
    sessions: snap.size,
    sessionDates: dates,
    quiz: QuizStats(
      totalCorrect: totalCorrect,
      totalAsked: totalAsked,
      bestStreak: bestStreak,
      sessionsWithQuiz: sessionsWithQuiz,
    ),
  );
});

// ─── Achievement model + catalog ───────────────────────────────────────────────
enum AchievementCategory { session, streak, memorization, juz, quiz }

extension AchievementCategoryX on AchievementCategory {
  String get label => switch (this) {
        AchievementCategory.session => 'الحلقات',
        AchievementCategory.streak => 'المواظبة',
        AchievementCategory.memorization => 'الحفظ',
        AchievementCategory.juz => 'الأجزاء',
        AchievementCategory.quiz => 'التحديات',
      };
}

/// A single, progress-bearing achievement. Always carries [current]/[target] so
/// the UI can show how close a *locked* badge is — that's what makes the badges
/// "trackable" rather than just on/off.
class Achievement {
  final String id;
  final String title;
  final String emoji;
  final String hint; // how to earn it
  final int current;
  final int target;
  final AchievementCategory category;

  const Achievement({
    required this.id,
    required this.title,
    required this.emoji,
    required this.hint,
    required this.current,
    required this.target,
    required this.category,
  });

  bool get earned => current >= target;
  double get progress => target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
  int get remaining => (target - current).clamp(0, target);
}

/// Full catalogue including juz milestones (needs the memorized set).
List<Achievement> buildAchievementsFull({
  required int sessions,
  required Set<int> memorizedSet,
  required int weeklyStreak,
  required QuizStats quiz,
}) {
  return _build(
    sessions: sessions,
    memorizedCount: memorizedSet.length,
    completedJuz: completedJuzCount(memorizedSet),
    weeklyStreak: weeklyStreak,
    quiz: quiz,
  );
}

List<Achievement> _build({
  required int sessions,
  required int memorizedCount,
  required int completedJuz,
  required int weeklyStreak,
  required QuizStats quiz,
}) {
  return [
    // Sessions
    Achievement(id: 'sess_1', title: 'أول خطوة', emoji: '🌟', hint: 'أكمل أول حلقة', current: sessions, target: 1, category: AchievementCategory.session),
    Achievement(id: 'sess_5', title: 'المداوم', emoji: '🔥', hint: '5 حلقات مكتملة', current: sessions, target: 5, category: AchievementCategory.session),
    Achievement(id: 'sess_15', title: 'الحريص', emoji: '💎', hint: '15 حلقة مكتملة', current: sessions, target: 15, category: AchievementCategory.session),
    Achievement(id: 'sess_30', title: 'المثابر', emoji: '⚡', hint: '30 حلقة مكتملة', current: sessions, target: 30, category: AchievementCategory.session),
    Achievement(id: 'sess_60', title: 'المتفوق', emoji: '🏅', hint: '60 حلقة مكتملة', current: sessions, target: 60, category: AchievementCategory.session),
    // Streak
    Achievement(id: 'streak_2', title: 'بداية موفقة', emoji: '✨', hint: 'أسبوعان متتاليان', current: weeklyStreak, target: 2, category: AchievementCategory.streak),
    Achievement(id: 'streak_4', title: 'ملتزم', emoji: '🔥', hint: '4 أسابيع متتالية', current: weeklyStreak, target: 4, category: AchievementCategory.streak),
    Achievement(id: 'streak_8', title: 'لا يتوقف', emoji: '🚀', hint: '8 أسابيع متتالية', current: weeklyStreak, target: 8, category: AchievementCategory.streak),
    Achievement(id: 'streak_12', title: 'فولاذي', emoji: '🛡️', hint: '12 أسبوعاً متتالياً', current: weeklyStreak, target: 12, category: AchievementCategory.streak),
    // Quiz mastery
    Achievement(id: 'quiz_correct_10', title: 'رامي السهام', emoji: '🎯', hint: '10 إجابات صحيحة', current: quiz.totalCorrect, target: 10, category: AchievementCategory.quiz),
    Achievement(id: 'quiz_correct_50', title: 'قنّاص', emoji: '🏹', hint: '50 إجابة صحيحة', current: quiz.totalCorrect, target: 50, category: AchievementCategory.quiz),
    Achievement(id: 'quiz_streak_5', title: 'سلسلة ذهبية', emoji: '⚡', hint: 'سلسلة 5 إجابات صحيحة', current: quiz.bestStreak, target: 5, category: AchievementCategory.quiz),
    Achievement(id: 'quiz_acc_90', title: 'الدقة العالية', emoji: '💯', hint: 'دقة 90% أو أعلى', current: quiz.accuracyPct, target: 90, category: AchievementCategory.quiz),
    // Memorization
    Achievement(id: 'mem_1', title: 'أول سورة', emoji: '🌸', hint: 'احفظ أول سورة', current: memorizedCount, target: 1, category: AchievementCategory.memorization),
    Achievement(id: 'mem_20', title: 'حافظ الجزء', emoji: '📜', hint: 'حفظ 20 سورة', current: memorizedCount, target: 20, category: AchievementCategory.memorization),
    Achievement(id: 'mem_57', title: 'حافظ النصف', emoji: '🌙', hint: 'حفظ 57 سورة', current: memorizedCount, target: 57, category: AchievementCategory.memorization),
    Achievement(id: 'mem_114', title: 'الحافظ الكريم', emoji: '👑', hint: 'حفظ القرآن كاملاً', current: memorizedCount, target: 114, category: AchievementCategory.memorization),
    // Juz
    Achievement(id: 'juz_1', title: 'جزء كامل', emoji: '📗', hint: 'أتمم أول جزء', current: completedJuz, target: 1, category: AchievementCategory.juz),
    Achievement(id: 'juz_3', title: 'ثلاثة أجزاء', emoji: '📚', hint: 'أتمم 3 أجزاء', current: completedJuz, target: 3, category: AchievementCategory.juz),
    Achievement(id: 'juz_10', title: 'عشرة أجزاء', emoji: '🏆', hint: 'أتمم 10 أجزاء', current: completedJuz, target: 10, category: AchievementCategory.juz),
    Achievement(id: 'juz_30', title: 'ختمة كاملة', emoji: '🕌', hint: 'أتمم 30 جزءاً', current: completedJuz, target: 30, category: AchievementCategory.juz),
  ];
}
