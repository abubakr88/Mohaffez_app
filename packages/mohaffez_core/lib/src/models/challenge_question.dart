import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum ChallengeType {
  completeAyah,
  nameSurah,
  tajweedRule,
  orderAyahs,
  wordMeaning,
  openQuestion,
}

enum ChallengeAnswerMode {
  multipleChoice,
  ordering,
  oral,
  teacherReview,
}

extension ChallengeAnswerModeX on ChallengeAnswerMode {
  String get firestoreKey => switch (this) {
        ChallengeAnswerMode.multipleChoice => 'multiple_choice',
        ChallengeAnswerMode.ordering => 'ordering',
        ChallengeAnswerMode.oral => 'oral',
        ChallengeAnswerMode.teacherReview => 'teacher_review',
      };

  String get label => switch (this) {
        ChallengeAnswerMode.multipleChoice => 'اختيار متعدد',
        ChallengeAnswerMode.ordering => 'ترتيب',
        ChallengeAnswerMode.oral => 'إجابة شفهية',
        ChallengeAnswerMode.teacherReview => 'مراجعة المحفّظ',
      };

  static ChallengeAnswerMode fromKey(String? key) => switch (key) {
        'multiple_choice' => ChallengeAnswerMode.multipleChoice,
        'ordering' => ChallengeAnswerMode.ordering,
        'oral' => ChallengeAnswerMode.oral,
        'teacher_review' => ChallengeAnswerMode.teacherReview,
        _ => ChallengeAnswerMode.teacherReview,
      };
}

extension ChallengeTypeX on ChallengeType {
  String get label {
    switch (this) {
      case ChallengeType.completeAyah:
        return 'أكمل الآية';
      case ChallengeType.nameSurah:
        return 'اذكر اسم السورة';
      case ChallengeType.tajweedRule:
        return 'حكم التجويد';
      case ChallengeType.orderAyahs:
        return 'رتّب الآيات';
      case ChallengeType.wordMeaning:
        return 'معنى الكلمة';
      case ChallengeType.openQuestion:
        return 'سؤال مفتوح';
    }
  }

  String get firestoreKey {
    switch (this) {
      case ChallengeType.completeAyah:
        return 'complete_ayah';
      case ChallengeType.nameSurah:
        return 'name_surah';
      case ChallengeType.tajweedRule:
        return 'tajweed_rule';
      case ChallengeType.orderAyahs:
        return 'order_ayahs';
      case ChallengeType.wordMeaning:
        return 'word_meaning';
      case ChallengeType.openQuestion:
        return 'open_question';
    }
  }

  static ChallengeType fromKey(String key) {
    switch (key) {
      case 'complete_ayah':
        return ChallengeType.completeAyah;
      case 'name_surah':
        return ChallengeType.nameSurah;
      case 'tajweed_rule':
        return ChallengeType.tajweedRule;
      case 'order_ayahs':
        return ChallengeType.orderAyahs;
      case 'word_meaning':
        return ChallengeType.wordMeaning;
      default:
        return ChallengeType.openQuestion;
    }
  }
}

class ChallengeOption {
  final String id;
  final String text;

  const ChallengeOption({required this.id, required this.text});

  factory ChallengeOption.fromMap(Map<String, dynamic> data) => ChallengeOption(
        id: data['id'] as String? ?? '',
        text: data['text'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'id': id, 'text': text};
}

class ChallengeQuestion {
  final String id;
  final ChallengeType type;
  final ChallengeAnswerMode answerMode;
  final String? source;
  final int? generatorVersion;
  final int? surahNumber;
  final int? anchorAyah;
  final String question;
  final String? hint;
  final String? answer;
  final List<ChallengeOption> options;
  final String? correctOptionId;
  final List<String> correctOrder;
  final String difficulty; // 'easy' | 'medium' | 'hard'
  final bool isActive;
  final DateTime createdAt;

  const ChallengeQuestion({
    required this.id,
    required this.type,
    this.answerMode = ChallengeAnswerMode.teacherReview,
    this.source,
    this.generatorVersion,
    this.surahNumber,
    this.anchorAyah,
    required this.question,
    this.hint,
    this.answer,
    this.options = const [],
    this.correctOptionId,
    this.correctOrder = const [],
    this.difficulty = 'medium',
    this.isActive = true,
    required this.createdAt,
  });

  factory ChallengeQuestion.fromMap(String id, Map<String, dynamic> data) {
    return ChallengeQuestion(
      id: id,
      type: ChallengeTypeX.fromKey(data['type'] as String? ?? 'open_question'),
      answerMode: ChallengeAnswerModeX.fromKey(data['answerMode'] as String?),
      source: data['source'] as String?,
      generatorVersion: (data['generatorVersion'] as num?)?.toInt(),
      surahNumber: (data['surahNumber'] as num?)?.toInt(),
      anchorAyah: (data['anchorAyah'] as num?)?.toInt(),
      question: data['question'] as String? ?? '',
      hint: data['hint'] as String?,
      answer: data['answer'] as String?,
      options: (data['options'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) => ChallengeOption.fromMap(Map<String, dynamic>.from(raw)))
          .toList(),
      correctOptionId: data['correctOptionId'] as String?,
      correctOrder: (data['correctOrder'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      difficulty: data['difficulty'] as String? ?? 'medium',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.firestoreKey,
      'answerMode': answerMode.firestoreKey,
      if (source != null && source!.isNotEmpty) 'source': source,
      if (generatorVersion != null) 'generatorVersion': generatorVersion,
      if (surahNumber != null) 'surahNumber': surahNumber,
      if (anchorAyah != null) 'anchorAyah': anchorAyah,
      'question': question,
      if (hint != null && hint!.isNotEmpty) 'hint': hint,
      if (answer != null && answer!.isNotEmpty) 'answer': answer,
      if (options.isNotEmpty)
        'options': options.map((option) => option.toMap()).toList(),
      if (correctOptionId != null && correctOptionId!.isNotEmpty)
        'correctOptionId': correctOptionId,
      if (correctOrder.isNotEmpty) 'correctOrder': correctOrder,
      'difficulty': difficulty,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ChallengeQuestion copyWith({
    String? question,
    String? hint,
    String? answer,
    ChallengeAnswerMode? answerMode,
    String? source,
    int? generatorVersion,
    int? surahNumber,
    int? anchorAyah,
    List<ChallengeOption>? options,
    String? correctOptionId,
    List<String>? correctOrder,
    String? difficulty,
    bool? isActive,
  }) {
    return ChallengeQuestion(
      id: id,
      type: type,
      answerMode: answerMode ?? this.answerMode,
      source: source ?? this.source,
      generatorVersion: generatorVersion ?? this.generatorVersion,
      surahNumber: surahNumber ?? this.surahNumber,
      anchorAyah: anchorAyah ?? this.anchorAyah,
      question: question ?? this.question,
      hint: hint ?? this.hint,
      answer: answer ?? this.answer,
      options: options ?? this.options,
      correctOptionId: correctOptionId ?? this.correctOptionId,
      correctOrder: correctOrder ?? this.correctOrder,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  ChallengeQuestion copyWithId(String value) => ChallengeQuestion(
        id: value,
        type: type,
        answerMode: answerMode,
        source: source,
        generatorVersion: generatorVersion,
        surahNumber: surahNumber,
        anchorAyah: anchorAyah,
        question: question,
        hint: hint,
        answer: answer,
        options: options,
        correctOptionId: correctOptionId,
        correctOrder: correctOrder,
        difficulty: difficulty,
        isActive: isActive,
        createdAt: createdAt,
      );

  Map<String, dynamic> toPublicMap() => {
        'id': id,
        'type': type.firestoreKey,
        'answerMode': answerMode.firestoreKey,
        if (source != null && source!.isNotEmpty) 'source': source,
        if (generatorVersion != null) 'generatorVersion': generatorVersion,
        if (surahNumber != null) 'surahNumber': surahNumber,
        if (anchorAyah != null) 'anchorAyah': anchorAyah,
        'question': question,
        if (hint != null && hint!.isNotEmpty) 'hint': hint,
        if (options.isNotEmpty)
          'options': options.map((option) => option.toMap()).toList(),
        'difficulty': difficulty,
      };

  Map<String, dynamic> toPublishMap() {
    final data = toMap()..remove('createdAt');
    return {'id': id, ...data};
  }
}
