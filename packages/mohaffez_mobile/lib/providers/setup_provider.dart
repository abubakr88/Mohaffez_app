// lib/providers/setup_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// ─── Exam Questions Provider ────────────────────────────────────
// Fetches random active questions from Firestore.
// Strategy: fetch all active, shuffle client-side, pick balanced set.
final examQuestionsProvider =
    FutureProvider.autoDispose<List<ExamQuestion>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('examQuestions')
      .where('isActive', isEqualTo: true)
      .get();

  final allQuestions = snap.docs
      .map((doc) => ExamQuestion.fromFirestore(doc))
      .toList()
    ..shuffle();

  // Pick balanced set: 3 easy, 4 medium, 3 hard
  final easy =
      allQuestions.where((q) => q.difficulty == 'easy').take(3).toList();
  final medium =
      allQuestions.where((q) => q.difficulty == 'medium').take(4).toList();
  final hard =
      allQuestions.where((q) => q.difficulty == 'hard').take(3).toList();

  final selected = [...easy, ...medium, ...hard];

  // If not enough per-difficulty, fill from remaining
  if (selected.length < 10) {
    final selectedIds = selected.map((q) => q.id).toSet();
    final remaining =
        allQuestions.where((q) => !selectedIds.contains(q.id)).toList();
    selected.addAll(remaining.take(10 - selected.length));
  }

  selected.shuffle(); // Randomize presentation order
  return selected;
});

// ─── Setup Completion Service ───────────────────────────────────
class SetupService {
  /// Complete student setup — writes profile fields + sets setupCompleted.
  static Future<void> completeStudentSetup({
    required String uid,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required String city,
    required String addressText,
    required double addressLat,
    required double addressLng,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'phoneNumber': phoneNumber,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'city': city,
      'addressText': addressText,
      'addressLat': addressLat,
      'addressLng': addressLng,
      'setupCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Complete mohaffez setup — writes profile + exam results in a batch.
  /// Returns the exam score for navigation decisions.
  static Future<ExamResult> completeMohaffezSetup({
    required String uid,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required String city,
    required String addressText,
    required double addressLat,
    required double addressLng,
    required double examScore,
    required int totalQuestions,
    required int correctAnswers,
    required List<Map<String, dynamic>> answers,
    required DateTime examStartedAt,
    required bool timedOut,
    required double passingScore,
    required int maxRetries,
    required int retryCooldownDays,
    required int currentRetryCount,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final examRef = userRef.collection('examResults').doc();
    final now = DateTime.now();

    final bool passed = examScore >= passingScore;
    final int newRetryCount = passed ? currentRetryCount : currentRetryCount + 1;
    final DateTime? nextRetryAt = passed
        ? null
        : newRetryCount < maxRetries
            ? now.add(Duration(days: retryCooldownDays))
            : null;

    batch.update(userRef, {
      'phoneNumber': phoneNumber,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'city': city,
      'addressText': addressText,
      'addressLat': addressLat,
      'addressLng': addressLng,
      'examScore': examScore,
      'examTakenAt': Timestamp.fromDate(now),
      'examQuestionCount': totalQuestions,
      'examCorrectCount': correctAnswers,
      'examPassed': passed,
      'examRetryCount': newRetryCount,
      'examNextRetryAt': nextRetryAt != null ? Timestamp.fromDate(nextRetryAt) : null,
      // setupCompleted remains false after exam — it is set to true in
      // TeacherCertificatesScreen after the teacher uploads certificates.
      // status remains 'active' here; it becomes 'pending_approval' in
      // TeacherCertificatesScreen after the full registration is submitted.
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(examRef, {
      'score': examScore,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'answers': answers,
      'startedAt': Timestamp.fromDate(examStartedAt),
      'completedAt': Timestamp.fromDate(now),
      'durationSeconds': now.difference(examStartedAt).inSeconds,
      'timedOut': timedOut,
      'passed': passed,
    });

    await batch.commit();

    return ExamResult(
      score: examScore,
      passed: passed,
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      retryCount: newRetryCount,
      nextRetryAt: nextRetryAt,
    );
  }
}

class ExamResult {
  final double score;
  final bool passed;
  final int correctAnswers;
  final int totalQuestions;
  final int retryCount;
  final DateTime? nextRetryAt;

  const ExamResult({
    required this.score,
    required this.passed,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.retryCount,
    this.nextRetryAt,
  });
}
