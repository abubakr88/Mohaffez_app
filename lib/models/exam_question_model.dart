// lib/models/exam_question_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ExamQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String category;
  final String difficulty;

  ExamQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.category,
    required this.difficulty,
  });

  factory ExamQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamQuestion(
      id: doc.id,
      questionText: data['questionText'] as String,
      options: List<String>.from(data['options'] as List),
      correctOptionIndex: (data['correctOptionIndex'] as num).toInt(),
      category: data['category'] as String? ?? 'general',
      difficulty: data['difficulty'] as String? ?? 'medium',
    );
  }
}
