import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-screen quiz session state — score, streak, and used-question tracking.
///
/// Lives for the lifetime of the SessionQuizScreen so switching games keeps
/// the running tally; the screen creates a fresh controller each time.
class QuizSessionState {
  final int correct;
  final int asked;
  final int streak;
  final int bestStreak;
  final List<int> usedAyahIndices;
  final List<int> usedGroupIds;

  const QuizSessionState({
    this.correct = 0,
    this.asked = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.usedAyahIndices = const [],
    this.usedGroupIds = const [],
  });

  double get accuracy => asked == 0 ? 0 : correct / asked;
  int get accuracyPct => (accuracy * 100).round();

  QuizSessionState copyWith({
    int? correct,
    int? asked,
    int? streak,
    int? bestStreak,
    List<int>? usedAyahIndices,
    List<int>? usedGroupIds,
  }) {
    return QuizSessionState(
      correct: correct ?? this.correct,
      asked: asked ?? this.asked,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      usedAyahIndices: usedAyahIndices ?? this.usedAyahIndices,
      usedGroupIds: usedGroupIds ?? this.usedGroupIds,
    );
  }
}

class QuizSessionController extends StateNotifier<QuizSessionState> {
  QuizSessionController() : super(const QuizSessionState());

  /// Records an answer. Returns the new streak (so callers can decide whether
  /// to fire fireworks).
  int recordAnswer(bool correct) {
    if (correct) {
      final newStreak = state.streak + 1;
      state = state.copyWith(
        correct: state.correct + 1,
        asked: state.asked + 1,
        streak: newStreak,
        bestStreak: newStreak > state.bestStreak ? newStreak : state.bestStreak,
      );
      return newStreak;
    }
    state = state.copyWith(
      asked: state.asked + 1,
      streak: 0,
    );
    return 0;
  }

  void markAyahUsed(int index) {
    final list = List<int>.from(state.usedAyahIndices);
    if (list.length >= 50) list.removeAt(0); // keep recent window
    list.add(index);
    state = state.copyWith(usedAyahIndices: list);
  }

  void markGroupUsed(int groupId) {
    final list = List<int>.from(state.usedGroupIds);
    if (list.length >= 20) list.removeAt(0);
    list.add(groupId);
    state = state.copyWith(usedGroupIds: list);
  }

  void clearUsedAyahs() => state = state.copyWith(usedAyahIndices: []);
  void clearUsedGroups() => state = state.copyWith(usedGroupIds: []);
}

/// Per-screen provider — created with autoDispose so each entry into the
/// quiz screen starts fresh.
final quizSessionControllerProvider = StateNotifierProvider.autoDispose<
    QuizSessionController, QuizSessionState>(
  (ref) => QuizSessionController(),
);
