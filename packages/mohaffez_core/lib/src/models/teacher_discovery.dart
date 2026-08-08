class TeacherDiscoveryOption {
  final String id;
  final String labelAr;
  final String labelEn;

  const TeacherDiscoveryOption({
    required this.id,
    required this.labelAr,
    required this.labelEn,
  });
}

class TeacherDiscoveryTaxonomy {
  TeacherDiscoveryTaxonomy._();

  static const int schemaVersion = 2;

  static const services = <TeacherDiscoveryOption>[
    TeacherDiscoveryOption(
      id: 'memorization',
      labelAr: 'تحفيظ',
      labelEn: 'Memorization',
    ),
    TeacherDiscoveryOption(
      id: 'review',
      labelAr: 'مراجعة',
      labelEn: 'Revision',
    ),
    TeacherDiscoveryOption(
      id: 'foundation',
      labelAr: 'تأسيس وتقوية القراءة',
      labelEn: 'Reading foundations',
    ),
    TeacherDiscoveryOption(
      id: 'tajweed',
      labelAr: 'تجويد',
      labelEn: 'Tajweed',
    ),
    TeacherDiscoveryOption(
      id: 'recitation_correction',
      labelAr: 'تصحيح التلاوة',
      labelEn: 'Recitation correction',
    ),
    TeacherDiscoveryOption(
      id: 'ijazah',
      labelAr: 'إجازة',
      labelEn: 'Ijazah',
    ),
    TeacherDiscoveryOption(
      id: 'qiraat',
      labelAr: 'قراءات',
      labelEn: 'Qiraat',
    ),
  ];

  static const ageGroups = <TeacherDiscoveryOption>[
    TeacherDiscoveryOption(
      id: 'children',
      labelAr: 'أطفال',
      labelEn: 'Children',
    ),
    TeacherDiscoveryOption(
      id: 'teens',
      labelAr: 'مراهقون',
      labelEn: 'Teenagers',
    ),
    TeacherDiscoveryOption(
      id: 'adults',
      labelAr: 'بالغون',
      labelEn: 'Adults',
    ),
  ];

  static const learnerGenders = <TeacherDiscoveryOption>[
    TeacherDiscoveryOption(
      id: 'male',
      labelAr: 'طلاب',
      labelEn: 'Male students',
    ),
    TeacherDiscoveryOption(
      id: 'female',
      labelAr: 'طالبات',
      labelEn: 'Female students',
    ),
  ];

  static const levels = <TeacherDiscoveryOption>[
    TeacherDiscoveryOption(
      id: 'beginner',
      labelAr: 'مبتدئ',
      labelEn: 'Beginner',
    ),
    TeacherDiscoveryOption(
      id: 'intermediate',
      labelAr: 'متوسط',
      labelEn: 'Intermediate',
    ),
    TeacherDiscoveryOption(
      id: 'advanced',
      labelAr: 'متقدم',
      labelEn: 'Advanced',
    ),
  ];

  static const languages = <TeacherDiscoveryOption>[
    TeacherDiscoveryOption(id: 'ar', labelAr: 'العربية', labelEn: 'Arabic'),
    TeacherDiscoveryOption(
      id: 'en',
      labelAr: 'الإنجليزية',
      labelEn: 'English',
    ),
    TeacherDiscoveryOption(
      id: 'id',
      labelAr: 'الإندونيسية',
      labelEn: 'Indonesian',
    ),
    TeacherDiscoveryOption(
      id: 'fr',
      labelAr: 'الفرنسية',
      labelEn: 'French',
    ),
    TeacherDiscoveryOption(
      id: 'tr',
      labelAr: 'التركية',
      labelEn: 'Turkish',
    ),
    TeacherDiscoveryOption(id: 'ur', labelAr: 'الأردية', labelEn: 'Urdu'),
  ];

  static TeacherDiscoveryOption? find(
    List<TeacherDiscoveryOption> options,
    String? id,
  ) {
    if (id == null) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  static String label(
    List<TeacherDiscoveryOption> options,
    String id, {
    bool english = false,
  }) {
    final option = find(options, id);
    if (option == null) return id;
    return english ? option.labelEn : option.labelAr;
  }

  static String? ageGroupForAge(
    int? age, {
    int childrenMaxAge = 10,
    int teenMaxAge = 15,
  }) {
    if (age == null || age < 0) return null;
    final validRanges =
        childrenMaxAge >= 0 && childrenMaxAge < teenMaxAge && teenMaxAge <= 30;
    final resolvedChildrenMaxAge = validRanges ? childrenMaxAge : 10;
    final resolvedTeenMaxAge = validRanges ? teenMaxAge : 15;
    if (age <= resolvedChildrenMaxAge) return 'children';
    if (age <= resolvedTeenMaxAge) return 'teens';
    return 'adults';
  }

  static String? normalizeLevel(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (const {'beginner', 'مبتدئ', 'مبتدئة', 'complete_beginner'}
        .contains(normalized)) {
      return 'beginner';
    }
    if (const {'intermediate', 'متوسط', 'متوسطة'}.contains(normalized)) {
      return 'intermediate';
    }
    if (const {'advanced', 'متقدم', 'متقدمة'}.contains(normalized)) {
      return 'advanced';
    }
    return null;
  }

  static Set<String> legacyServiceIds(String? specialization) {
    final text = specialization?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return const {};
    return {
      if (text.contains('حفظ') || text.contains('تحفيظ')) 'memorization',
      if (text.contains('مراجعة')) 'review',
      if (text.contains('تأسيس') || text.contains('تقوية')) 'foundation',
      if (text.contains('تجويد')) 'tajweed',
      if (text.contains('تصحيح')) 'recitation_correction',
      if (text.contains('إجاز') || text.contains('اجاز')) 'ijazah',
      if (text.contains('قراءات') || text.contains('قراءة عشر')) 'qiraat',
    };
  }
}

Map<String, bool> parseDiscoveryFacet(Object? value) {
  if (value is! Map) return const {};
  return Map.unmodifiable({
    for (final entry in value.entries)
      if (entry.value == true) entry.key.toString(): true,
  });
}

Map<String, bool> discoveryFacetFromIds(Iterable<String> ids) {
  return {for (final id in ids.where((id) => id.trim().isNotEmpty)) id: true};
}

bool discoveryFacetContains(Map<String, bool> facet, String? id) {
  return id != null && facet[id] == true;
}

typedef LearnerAudienceMatrix = Map<String, Map<String, bool>>;

LearnerAudienceMatrix parseLearnerAudiences(Object? value) {
  if (value is! Map) return const {};
  final parsed = <String, Map<String, bool>>{};
  for (final ageGroup in TeacherDiscoveryTaxonomy.ageGroups) {
    final rawGenders = value[ageGroup.id];
    if (rawGenders is! Map) continue;
    final genders = <String, bool>{};
    for (final gender in TeacherDiscoveryTaxonomy.learnerGenders) {
      if (rawGenders[gender.id] == true) genders[gender.id] = true;
    }
    if (genders.isNotEmpty) parsed[ageGroup.id] = Map.unmodifiable(genders);
  }
  return Map.unmodifiable(parsed);
}

LearnerAudienceMatrix learnerAudiencesFromLegacy(
  Map<String, bool> ageGroups,
  Map<String, bool> learnerGenders,
) {
  if (ageGroups.isEmpty || learnerGenders.isEmpty) return const {};
  final audiences = <String, Map<String, bool>>{};
  for (final ageGroup in TeacherDiscoveryTaxonomy.ageGroups) {
    if (ageGroups[ageGroup.id] != true) continue;
    final genders = <String, bool>{};
    for (final gender in TeacherDiscoveryTaxonomy.learnerGenders) {
      if (learnerGenders[gender.id] == true) genders[gender.id] = true;
    }
    if (genders.isNotEmpty) {
      audiences[ageGroup.id] = Map<String, bool>.unmodifiable(genders);
    }
  }
  return Map<String, Map<String, bool>>.unmodifiable(audiences);
}

bool learnerAudienceContains(
  LearnerAudienceMatrix audiences,
  String? ageGroup,
  String? learnerGender,
) {
  if (ageGroup == null || learnerGender == null) return false;
  return audiences[ageGroup]?[learnerGender] == true;
}

Set<String> learnerAudienceAgeGroups(LearnerAudienceMatrix audiences) =>
    audiences.entries
        .where((entry) => entry.value.values.any((enabled) => enabled))
        .map((entry) => entry.key)
        .toSet();

Set<String> learnerAudienceGenders(LearnerAudienceMatrix audiences) => {
      for (final genders in audiences.values)
        for (final entry in genders.entries)
          if (entry.value) entry.key,
    };

bool learnerAudiencesAreEmpty(LearnerAudienceMatrix audiences) =>
    !audiences.values.any(
      (genders) => genders.values.any((enabled) => enabled),
    );

class TeacherDiscoverySelection {
  final Set<String> services;
  final LearnerAudienceMatrix learnerAudiences;
  final Set<String> levels;
  final Set<String> languages;
  final String? primaryLanguage;

  const TeacherDiscoverySelection({
    this.services = const {},
    this.learnerAudiences = const {},
    this.levels = const {},
    this.languages = const {},
    this.primaryLanguage,
  });

  factory TeacherDiscoverySelection.fromData(Map<String, dynamic> data) {
    final services = parseDiscoveryFacet(data['teachingServices']).keys.toSet();
    if (services.isEmpty) {
      services.addAll(
        TeacherDiscoveryTaxonomy.legacyServiceIds(
          data['specialization'] is String
              ? data['specialization'] as String
              : null,
        ),
      );
    }
    var audiences = parseLearnerAudiences(data['learnerAudiences']);
    if (learnerAudiencesAreEmpty(audiences)) {
      audiences = learnerAudiencesFromLegacy(
        parseDiscoveryFacet(data['learnerAgeGroups']),
        parseDiscoveryFacet(data['learnerGenders']),
      );
    }
    return TeacherDiscoverySelection(
      services: services,
      learnerAudiences: audiences,
      levels: parseDiscoveryFacet(data['learnerLevels']).keys.toSet(),
      languages: parseDiscoveryFacet(data['teachingLanguages']).keys.toSet(),
      primaryLanguage: data['primaryTeachingLanguage'] as String?,
    );
  }

  bool get isComplete =>
      services.isNotEmpty &&
      !learnerAudiencesAreEmpty(learnerAudiences) &&
      levels.isNotEmpty &&
      languages.isNotEmpty &&
      primaryLanguage != null &&
      languages.contains(primaryLanguage);

  String? get validationMessage {
    if (services.isEmpty) return 'اختر نوع تدريس واحدًا على الأقل';
    if (learnerAudiencesAreEmpty(learnerAudiences)) {
      return 'حدد فئة وجنس الطلاب الذين يمكنك تدريسهم';
    }
    if (levels.isEmpty) return 'اختر مستوى واحدًا على الأقل';
    if (languages.isEmpty) return 'اختر لغة تدريس واحدة على الأقل';
    if (primaryLanguage == null || !languages.contains(primaryLanguage)) {
      return 'اختر لغة التدريس الأساسية';
    }
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'teachingServices': discoveryFacetFromIds(services),
        'learnerAudiences': learnerAudiences,
        'learnerLevels': discoveryFacetFromIds(levels),
        'teachingLanguages': discoveryFacetFromIds(languages),
        'primaryTeachingLanguage': primaryLanguage,
        'discoveryProfileVersion': TeacherDiscoveryTaxonomy.schemaVersion,
      };

  Set<String> get ageGroups => learnerAudienceAgeGroups(learnerAudiences);
  Set<String> get learnerGenders => learnerAudienceGenders(learnerAudiences);
}
