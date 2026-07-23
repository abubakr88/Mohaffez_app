class TrialPreparationOption {
  const TrialPreparationOption(this.id, this.label);

  final String id;
  final String label;
}

const trialCurrentLevelOptions = <TrialPreparationOption>[
  TrialPreparationOption('complete_beginner', 'مبتدئ تمامًا'),
  TrialPreparationOption('letters_foundation', 'أتعلم الحروف والأساسيات'),
  TrialPreparationOption('reads_with_errors', 'أقرأ مع وجود أخطاء'),
  TrialPreparationOption('fluent_reader', 'أقرأ بطلاقة'),
  TrialPreparationOption('memorizing_or_reviewing', 'أحفظ أو أراجع القرآن'),
];

const trialLearningGoalOptions = <TrialPreparationOption>[
  TrialPreparationOption('reading_foundation', 'تأسيس القراءة'),
  TrialPreparationOption('recitation_correction', 'تصحيح التلاوة'),
  TrialPreparationOption('new_memorization', 'حفظ جديد'),
  TrialPreparationOption('memorization_review', 'مراجعة الحفظ'),
  TrialPreparationOption('tajweed', 'تعلم التجويد'),
  TrialPreparationOption('exam_or_ijazah', 'اختبار أو إجازة'),
];

const trialMemorizationLevelOptions = <TrialPreparationOption>[
  TrialPreparationOption('none', 'لا أحفظ حاليًا'),
  TrialPreparationOption('short_surahs', 'السور القصيرة'),
  TrialPreparationOption('less_than_one_juz', 'أقل من جزء'),
  TrialPreparationOption('one_to_five_juz', 'من جزء إلى 5 أجزاء'),
  TrialPreparationOption('more_than_five_juz', 'أكثر من 5 أجزاء'),
  TrialPreparationOption('full_quran', 'القرآن كاملًا'),
];

String trialPreparationLabel(
  List<TrialPreparationOption> options,
  Object? value,
) {
  final id = value is String ? value : '';
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return 'غير محدد';
}
