import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_question.dart';

const int maxChallengeBankQuestions = 30;
const int minPublishedChallengeQuestions = 5;
const int maxPublishedChallengeQuestions = 10;

String challengeLearnerKey(String studentId, String? studentProfileId) {
  final profileId = studentProfileId?.trim();
  final suffix = profileId == null || profileId.isEmpty || profileId == 'self'
      ? 'self'
      : profileId.replaceAll('/', '_');
  return '${studentId}__$suffix';
}

String legacyUnassignedChallengeLearnerKey(String studentId) =>
    '${studentId}__legacy_unassigned';

typedef ChallengeBankParams = ({
  String mohaffezId,
  String studentId,
  String? studentProfileId,
});

DocumentReference<Map<String, dynamic>> _bankRef(ChallengeBankParams params) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(params.mohaffezId)
      .collection('studentChallengeBanks')
      .doc(challengeLearnerKey(params.studentId, params.studentProfileId));
}

List<ChallengeQuestion> _questionsFromBank(
  Map<String, dynamic>? data,
) {
  final rawQuestions = data?['questions'] as List<dynamic>? ?? const [];
  return rawQuestions
      .whereType<Map>()
      .map((raw) {
        final map = Map<String, dynamic>.from(raw);
        return ChallengeQuestion.fromMap(
          map['id'] as String? ?? '',
          map,
        );
      })
      .where((question) =>
          question.id.isNotEmpty && question.question.trim().isNotEmpty)
      .take(maxChallengeBankQuestions)
      .toList();
}

/// One document read per screen open. The provider intentionally does not
/// subscribe to snapshots; the editor keeps a local draft and invalidates this
/// provider only after a successful batched save.
final studentChallengeBankProvider = FutureProvider.autoDispose
    .family<List<ChallengeQuestion>, ChallengeBankParams>((ref, params) async {
  final snapshot = await _bankRef(params).get();
  return _questionsFromBank(snapshot.data());
});

/// Parent-account legacy questions cannot safely be assigned to a child during
/// migration. They stay in a separate bank and are read only when the teacher
/// explicitly chooses to import them.
Future<List<ChallengeQuestion>> loadLegacyUnassignedChallengeBank({
  required String mohaffezId,
  required String studentId,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(mohaffezId)
      .collection('studentChallengeBanks')
      .doc(legacyUnassignedChallengeLearnerKey(studentId))
      .get();
  return _questionsFromBank(snapshot.data());
}

Future<void> saveChallengeBank({
  required ChallengeBankParams params,
  required List<ChallengeQuestion> questions,
}) async {
  if (questions.length > maxChallengeBankQuestions) {
    throw ArgumentError(
      'Challenge bank cannot exceed $maxChallengeBankQuestions questions',
    );
  }

  await _bankRef(params).set({
    'studentId': params.studentId,
    'studentProfileId': params.studentProfileId?.trim().isEmpty ?? true
        ? 'self'
        : params.studentProfileId!.trim(),
    'learnerKey':
        challengeLearnerKey(params.studentId, params.studentProfileId),
    'schemaVersion': 2,
    'templates': const <Map<String, dynamic>>[],
    'questionOrder': questions.map((question) => question.id).toList(),
    'questions': questions
        .map((question) => {
              ...question.toMap(),
              'id': question.id,
            })
        .toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// Compatibility provider for the existing quiz selector. It now reads the
/// consolidated self-profile bank once instead of opening a listener over N
/// question documents.
final studentChallengesProvider = FutureProvider.autoDispose
    .family<List<ChallengeQuestion>, ({String mohaffezId, String studentId})>(
        (ref, params) {
  return ref.watch(
    studentChallengeBankProvider((
      mohaffezId: params.mohaffezId,
      studentId: params.studentId,
      studentProfileId: null,
    )).future,
  );
});

Future<List<ChallengeQuestion>> _loadLegacyCompatibleBank({
  required String mohaffezId,
  required String studentId,
}) async {
  final params = (
    mohaffezId: mohaffezId,
    studentId: studentId,
    studentProfileId: null,
  );
  final snapshot = await _bankRef(params).get();
  return _questionsFromBank(snapshot.data());
}

/// Legacy editor compatibility. New UI batches all mutations through
/// [saveChallengeBank]; these helpers still perform correctly for old routes.
Future<void> addChallengeQuestion({
  required String mohaffezId,
  required String studentId,
  required ChallengeQuestion question,
}) async {
  final params = (
    mohaffezId: mohaffezId,
    studentId: studentId,
    studentProfileId: null,
  );
  final existing = await _loadLegacyCompatibleBank(
    mohaffezId: mohaffezId,
    studentId: studentId,
  );
  if (existing.length >= maxChallengeBankQuestions) {
    throw StateError('تم الوصول إلى الحد الأقصى للأسئلة');
  }
  final id = question.id.isEmpty
      ? FirebaseFirestore.instance.collection('_ids').doc().id
      : question.id;
  await saveChallengeBank(
    params: params,
    questions: [...existing, question.copyWithId(id)],
  );
}

Future<void> updateChallengeQuestion({
  required String mohaffezId,
  required String studentId,
  required String questionId,
  required Map<String, dynamic> fields,
}) async {
  final params = (
    mohaffezId: mohaffezId,
    studentId: studentId,
    studentProfileId: null,
  );
  final existing = await _loadLegacyCompatibleBank(
    mohaffezId: mohaffezId,
    studentId: studentId,
  );
  final updated = existing.map((question) {
    if (question.id != questionId) return question;
    return ChallengeQuestion.fromMap(
      question.id,
      {...question.toMap(), ...fields},
    );
  }).toList();
  await saveChallengeBank(params: params, questions: updated);
}

Future<void> deleteChallengeQuestion({
  required String mohaffezId,
  required String studentId,
  required String questionId,
}) async {
  final params = (
    mohaffezId: mohaffezId,
    studentId: studentId,
    studentProfileId: null,
  );
  final existing = await _loadLegacyCompatibleBank(
    mohaffezId: mohaffezId,
    studentId: studentId,
  );
  await saveChallengeBank(
    params: params,
    questions: existing.where((question) => question.id != questionId).toList(),
  );
}
