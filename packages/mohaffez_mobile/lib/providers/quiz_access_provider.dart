import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// The unlock info returned when a teacher enables quiz access for a session.
typedef QuizUnlockInfo = ({String sessionId, String mohaffezId});

class SessionChallengeInfo {
  final String sessionId;
  final String mohaffezId;
  final String mohaffezName;
  final String studentId;
  final String? studentProfileId;
  final String? studentProfileName;
  final String setVersion;
  final DateTime? expiresAt;
  final List<ChallengeQuestion> questions;
  final Map<String, dynamic>? result;

  const SessionChallengeInfo({
    required this.sessionId,
    required this.mohaffezId,
    required this.mohaffezName,
    required this.studentId,
    required this.studentProfileId,
    required this.studentProfileName,
    required this.setVersion,
    required this.expiresAt,
    required this.questions,
    required this.result,
  });

  bool get hasScoredAttempt {
    final attemptId = result?['scoredAttemptId'];
    return attemptId is String && attemptId.isNotEmpty;
  }
}

DateTime? _challengeDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String? _cleanProfileId(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'self') return null;
  return text;
}

SessionChallengeInfo? sessionChallengeFromMap(
  Map<String, dynamic> session, {
  required String studentId,
  required String? studentProfileId,
  DateTime? now,
}) {
  final sessionStudentId = session['studentId'] as String? ?? studentId;
  if (sessionStudentId != studentId) return null;

  final expectedProfile = _cleanProfileId(studentProfileId);
  final sessionProfile = _cleanProfileId(session['studentProfileId']);
  if (expectedProfile != sessionProfile) return null;

  final accessRaw = session['challengeAccess'];
  if (accessRaw is! Map) return null;
  final access = Map<String, dynamic>.from(accessRaw);
  final accessStatus = access['status'] as String?;
  if (accessStatus != 'open' && accessStatus != 'completed') return null;
  final accessProfile = _cleanProfileId(access['studentProfileId']);
  if (accessProfile != expectedProfile) return null;

  final expiresAt = _challengeDate(access['expiresAt']);
  if (expiresAt != null && expiresAt.isBefore(now ?? DateTime.now())) {
    return null;
  }

  final rawSet = session['challengeSet'] as List<dynamic>? ?? const [];
  final questions = rawSet
      .whereType<Map>()
      .map((raw) {
        final map = Map<String, dynamic>.from(raw);
        return ChallengeQuestion.fromMap(map['id'] as String? ?? '', map);
      })
      .where((question) =>
          question.id.isNotEmpty && question.question.trim().isNotEmpty)
      .take(maxPublishedChallengeQuestions)
      .toList();
  if (questions.isEmpty) return null;

  final resultRaw = session['challengeResult'];
  final result = resultRaw is Map ? Map<String, dynamic>.from(resultRaw) : null;
  if (accessStatus == 'completed') {
    final attemptId = result?['scoredAttemptId'];
    if (attemptId is! String || attemptId.isEmpty) return null;
  }
  return SessionChallengeInfo(
    sessionId: session['id'] as String? ?? '',
    mohaffezId: session['mohaffezId'] as String? ?? '',
    mohaffezName: session['mohaffezName'] as String? ?? '',
    studentId: sessionStudentId,
    studentProfileId: sessionProfile,
    studentProfileName: session['studentProfileName'] as String? ??
        session['studentName'] as String?,
    setVersion: access['setVersion'] as String? ?? '',
    expiresAt: expiresAt,
    questions: questions,
    result: result,
  );
}

/// Selects the latest open challenge from the accepted sessions already loaded
/// by the student home. No additional Firestore listener or query is created.
SessionChallengeInfo? activeChallengeFromSessions(
  List<Map<String, dynamic>> sessions, {
  required String studentId,
  required String? studentProfileId,
  DateTime? now,
}) {
  final candidates = sessions
      .map((session) => sessionChallengeFromMap(
            session,
            studentId: studentId,
            studentProfileId: studentProfileId,
            now: now,
          ))
      .whereType<SessionChallengeInfo>()
      .toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final aExpiry = a.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bExpiry = b.expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bExpiry.compareTo(aExpiry);
  });
  return candidates.first;
}

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

Future<Map<String, dynamic>> publishSessionChallenge({
  required String sessionId,
  required String studentId,
  required String? studentProfileId,
  List<ChallengeQuestion>? questions,
  List<String>? questionIds,
}) async {
  if ((questions == null || questions.isEmpty) &&
      (questionIds == null || questionIds.isEmpty)) {
    throw ArgumentError('Questions or legacy question IDs are required');
  }
  final callable =
      FirebaseFunctions.instance.httpsCallable('publishSessionChallenge');
  final response = await callable.call<Map<String, dynamic>>(
    sessionChallengePublishPayload(
      sessionId: sessionId,
      studentId: studentId,
      studentProfileId: studentProfileId,
      questions: questions,
      questionIds: questionIds,
    ),
  );
  return Map<String, dynamic>.from(response.data);
}

Map<String, dynamic> sessionChallengePublishPayload({
  required String sessionId,
  required String studentId,
  required String? studentProfileId,
  List<ChallengeQuestion>? questions,
  List<String>? questionIds,
}) {
  return {
    'sessionId': sessionId,
    'studentId': studentId,
    'studentProfileId': studentProfileId ?? 'self',
    if (questions != null)
      'questions': questions
          .map(
            (question) => (question.source == null
                    ? question.copyWith(source: 'teacher_bank')
                    : question)
                .toPublishMap(),
          )
          .toList(),
    if (questionIds != null) 'questionIds': questionIds,
  };
}

Future<Map<String, dynamic>> submitSessionChallenge({
  required String sessionId,
  required String setVersion,
  required String? studentProfileId,
  required String clientAttemptId,
  required List<Map<String, dynamic>> responses,
}) async {
  final callable =
      FirebaseFunctions.instance.httpsCallable('submitSessionChallenge');
  final response = await callable.call<Map<String, dynamic>>({
    'sessionId': sessionId,
    'setVersion': setVersion,
    'studentProfileId': studentProfileId ?? 'self',
    'clientAttemptId': clientAttemptId,
    'responses': responses,
  });
  return Map<String, dynamic>.from(response.data);
}

Future<Map<String, dynamic>> reviewSessionChallenge({
  required String sessionId,
  required Map<String, bool> verdicts,
}) async {
  final callable =
      FirebaseFunctions.instance.httpsCallable('reviewSessionChallenge');
  final response = await callable.call<Map<String, dynamic>>({
    'sessionId': sessionId,
    'verdicts': verdicts,
  });
  return Map<String, dynamic>.from(response.data);
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
