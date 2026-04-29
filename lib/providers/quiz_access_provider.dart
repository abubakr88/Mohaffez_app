import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The unlock info returned when a teacher enables quiz access for a session.
typedef QuizUnlockInfo = ({String sessionId, String mohaffezId});

/// Streams quiz unlock info for [studentId] when a teacher unlocks a session.
/// Returns null when no active unlock exists.
final quizUnlockedSessionProvider = StreamProvider.autoDispose
    .family<QuizUnlockInfo?, String>((ref, studentId) {
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'accepted')
      .where('quizUnlocked', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final mohaffezId = doc.data()['mohaffezId'] as String? ?? '';
    return (sessionId: doc.id, mohaffezId: mohaffezId);
  });
});

/// Streams the live quizUnlocked bool for a specific session document.
/// Used by the teacher on the session completion screen.
final sessionQuizStateProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, sessionId) {
  return FirebaseFirestore.instance
      .collection('hafizSessions')
      .doc(sessionId)
      .snapshots()
      .map((doc) => (doc.data()?['quizUnlocked'] as bool?) == true);
});

/// Persists the quiz session results to `hafizSessions/{sessionId}`.
/// Safe to call fire-and-forget; only writes when [asked] > 0.
Future<void> saveQuizResults({
  required String sessionId,
  required int correct,
  required int asked,
  required int bestStreak,
  required int accuracyPct,
}) async {
  if (asked == 0) return;
  await FirebaseFirestore.instance
      .collection('hafizSessions')
      .doc(sessionId)
      .update({
    'quizCorrect': correct,
    'quizAsked': asked,
    'quizBestStreak': bestStreak,
    'quizAccuracyPct': accuracyPct,
  });
}

/// Writes [unlocked] to `hafizSessions/{sessionId}.quizUnlocked`.
/// When enabling, atomically clears quizUnlocked on all other sessions for the
/// same student+teacher pair so only one session can be unlocked at a time.
Future<void> setQuizUnlocked({
  required String sessionId,
  required bool unlocked,
}) async {
  final firestore = FirebaseFirestore.instance;

  if (!unlocked) {
    return firestore
        .collection('hafizSessions')
        .doc(sessionId)
        .update({'quizUnlocked': false});
  }

  // Fetch the session to get studentId + mohaffezId for cleanup.
  final sessionSnap =
      await firestore.collection('hafizSessions').doc(sessionId).get();
  final data = sessionSnap.data();
  final studentId = data?['studentId'] as String?;
  final mohaffezId = data?['mohaffezId'] as String?;

  if (studentId == null || mohaffezId == null) {
    // Fallback: just set this session if metadata is missing.
    return firestore
        .collection('hafizSessions')
        .doc(sessionId)
        .update({'quizUnlocked': true});
  }

  // Find all sessions for this student+teacher that are currently unlocked.
  final stale = await firestore
      .collection('hafizSessions')
      .where('studentId', isEqualTo: studentId)
      .where('mohaffezId', isEqualTo: mohaffezId)
      .where('quizUnlocked', isEqualTo: true)
      .get();

  final batch = firestore.batch();
  for (final doc in stale.docs) {
    if (doc.id != sessionId) {
      batch.update(doc.reference, {'quizUnlocked': false});
    }
  }
  batch.update(
    firestore.collection('hafizSessions').doc(sessionId),
    {'quizUnlocked': true},
  );
  return batch.commit();
}
