import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_question.dart';

/// Streams all challenge questions the teacher set for a specific student.
final studentChallengesProvider = StreamProvider.autoDispose
    .family<List<ChallengeQuestion>, ({String mohaffezId, String studentId})>(
        (ref, p) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(p.mohaffezId)
      .collection('studentChallenges')
      .doc(p.studentId)
      .collection('questions')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ChallengeQuestion.fromMap(d.id, d.data()))
          .toList());
});

/// Adds a new challenge question to the teacher–student bank.
Future<void> addChallengeQuestion({
  required String mohaffezId,
  required String studentId,
  required ChallengeQuestion question,
}) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(mohaffezId)
      .collection('studentChallenges')
      .doc(studentId)
      .collection('questions')
      .add(question.toMap());
}

/// Updates an existing question's mutable fields.
Future<void> updateChallengeQuestion({
  required String mohaffezId,
  required String studentId,
  required String questionId,
  required Map<String, dynamic> fields,
}) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(mohaffezId)
      .collection('studentChallenges')
      .doc(studentId)
      .collection('questions')
      .doc(questionId)
      .update(fields);
}

/// Deletes a question permanently.
Future<void> deleteChallengeQuestion({
  required String mohaffezId,
  required String studentId,
  required String questionId,
}) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(mohaffezId)
      .collection('studentChallenges')
      .doc(studentId)
      .collection('questions')
      .doc(questionId)
      .delete();
}
