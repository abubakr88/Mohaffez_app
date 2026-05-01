import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum ChallengeType {
  completeAyah,
  nameSurah,
  tajweedRule,
  wordMeaning,
  openQuestion,
}

extension ChallengeTypeX on ChallengeType {
  String get label {
    switch (this) {
      case ChallengeType.completeAyah:  return 'أكمل الآية';
      case ChallengeType.nameSurah:     return 'اذكر اسم السورة';
      case ChallengeType.tajweedRule:   return 'حكم التجويد';
      case ChallengeType.wordMeaning:   return 'معنى الكلمة';
      case ChallengeType.openQuestion:  return 'سؤال مفتوح';
    }
  }

  String get firestoreKey {
    switch (this) {
      case ChallengeType.completeAyah:  return 'complete_ayah';
      case ChallengeType.nameSurah:     return 'name_surah';
      case ChallengeType.tajweedRule:   return 'tajweed_rule';
      case ChallengeType.wordMeaning:   return 'word_meaning';
      case ChallengeType.openQuestion:  return 'open_question';
    }
  }

  static ChallengeType fromKey(String key) {
    switch (key) {
      case 'complete_ayah':  return ChallengeType.completeAyah;
      case 'name_surah':     return ChallengeType.nameSurah;
      case 'tajweed_rule':   return ChallengeType.tajweedRule;
      case 'word_meaning':   return ChallengeType.wordMeaning;
      default:               return ChallengeType.openQuestion;
    }
  }
}

class ChallengeQuestion {
  final String id;
  final ChallengeType type;
  final String question;
  final String? hint;
  final String? answer; // teacher reference — never shown to student
  final String difficulty; // 'easy' | 'medium' | 'hard'
  final bool isActive;
  final DateTime createdAt;

  const ChallengeQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.hint,
    this.answer,
    this.difficulty = 'medium',
    this.isActive = true,
    required this.createdAt,
  });

  factory ChallengeQuestion.fromMap(String id, Map<String, dynamic> data) {
    return ChallengeQuestion(
      id: id,
      type: ChallengeTypeX.fromKey(data['type'] as String? ?? 'open_question'),
      question: data['question'] as String? ?? '',
      hint: data['hint'] as String?,
      answer: data['answer'] as String?,
      difficulty: data['difficulty'] as String? ?? 'medium',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.firestoreKey,
      'question': question,
      if (hint != null && hint!.isNotEmpty) 'hint': hint,
      if (answer != null && answer!.isNotEmpty) 'answer': answer,
      'difficulty': difficulty,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ChallengeQuestion copyWith({
    String? question,
    String? hint,
    String? answer,
    String? difficulty,
    bool? isActive,
  }) {
    return ChallengeQuestion(
      id: id,
      type: type,
      question: question ?? this.question,
      hint: hint ?? this.hint,
      answer: answer ?? this.answer,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
