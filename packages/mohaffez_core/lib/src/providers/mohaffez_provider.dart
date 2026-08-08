import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mohaffez_model.dart';
import 'server_clock_provider.dart';

const _teacherDirectoryCacheDuration = Duration(minutes: 5);

/// Shared directory read. Changing local search filters reuses this result
/// instead of downloading every active teacher again.
final activeMohaffezDirectoryProvider =
    FutureProvider.autoDispose<List<MohaffezModel>>((ref) async {
  final keepAlive = ref.keepAlive();
  final timer = Timer(_teacherDirectoryCacheDuration, keepAlive.close);
  ref.onDispose(timer.cancel);

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'mohaffez')
      .where('status', isEqualTo: 'active')
      .where('addressLat', isNotEqualTo: null)
      .get()
      .timeout(const Duration(seconds: 15));

  return snapshot.docs
      .map((doc) => MohaffezModel.fromFirestore(doc))
      .where(
        (mohaffez) =>
            mohaffez.addressLat != null && mohaffez.addressLng != null,
      )
      .toList(growable: false);
});

class _TeacherBookability {
  final bool hasAvailableSlot;
  final bool hasMatchingPlan;

  const _TeacherBookability({
    required this.hasAvailableSlot,
    required this.hasMatchingPlan,
  });
}

final _teacherBookabilityProvider = FutureProvider.autoDispose.family<
    _TeacherBookability,
    ({
      String teacherId,
      TeacherSessionTypeFilter sessionType
    })>((ref, args) async {
  final keepAlive = ref.keepAlive();
  final timer = Timer(_teacherDirectoryCacheDuration, keepAlive.close);
  ref.onDispose(timer.cancel);

  final firestore = FirebaseFirestore.instance;
  final now = serverNowFromRef(ref);
  final results = await Future.wait<bool>([
    _hasUpcomingAvailableSlot(
      firestore,
      args.teacherId,
      now,
      sessionTypeFilter: args.sessionType,
    ),
    _hasActivePricingPlan(
      firestore,
      args.teacherId,
      sessionTypeFilter: args.sessionType,
    ),
  ]);
  return _TeacherBookability(
    hasAvailableSlot: results[0],
    hasMatchingPlan: results[1],
  );
});

// Provider للحصول على قائمة المحفظين
final nearbyMohaffezProvider = FutureProvider.autoDispose
    .family<List<MohaffezModel>, NearbyParams>((ref, params) async {
  try {
    // Keep local filter changes on the cached directory rather than repeating
    // the same Firestore query for every NearbyParams combination.
    List<MohaffezModel> mohaffezList = [
      ...await ref.watch(activeMohaffezDirectoryProvider.future),
    ];

    // تصفية حسب نطاق المسافة إذا كان موقع المستخدم متاحاً
    if (params.distanceFilterEnabled &&
        params.userLat != null &&
        params.userLng != null) {
      mohaffezList = mohaffezList.where((mohaffez) {
        final distance =
            mohaffez.getDistanceFrom(params.userLat, params.userLng);
        return distance != null && distance <= params.radiusKm;
      }).toList();
    }

    // تصفية بحث موسعة: الاسم، النبذة، التخصصات، ونصوص خطط الأسعار النشطة.
    final searchTerms = _searchTerms(params.searchQuery);
    if (searchTerms.isNotEmpty) {
      mohaffezList = mohaffezList.where((mohaffez) {
        return _matchesMohaffezSearch(mohaffez, searchTerms);
      }).toList();
    }

    // تصفية حسب التخصص
    if (params.specialization != null && params.specialization!.isNotEmpty) {
      mohaffezList = mohaffezList.where((mohaffez) {
        final spec = mohaffez.specialization?.toLowerCase() ?? '';
        return spec.contains(params.specialization!.toLowerCase());
      }).toList();
    }

    // Structured discovery filters are explicit choices made by the learner.
    // They are therefore strict, unlike the suggested profile values which
    // only influence ranking below.
    mohaffezList = mohaffezList.where((mohaffez) {
      return _matchesExplicitDiscoveryFilters(mohaffez, params);
    }).toList();

    if (params.genderFilter != TeacherGenderFilter.all) {
      mohaffezList = mohaffezList.where((mohaffez) {
        final gender = mohaffez.gender?.toLowerCase().trim();
        return params.genderFilter == TeacherGenderFilter.male
            ? gender == 'male'
            : gender == 'female';
      }).toList();
    }

    if (params.trialSessionFilter == TeacherTrialSessionFilter.enabledOnly) {
      mohaffezList = mohaffezList
          .where((mohaffez) => mohaffez.trialSessionEnabled)
          .toList();
    }

    // تصفية حسب قابلية الحجز: وقت قادم مفعّل + خطة سعر نشطة
    if (params.availabilityFilter != TeacherAvailabilityFilter.all ||
        params.sessionTypeFilter != TeacherSessionTypeFilter.all) {
      final bookabilityFutures = <Future<_TeacherBookability>>[
        for (final mohaffez in mohaffezList)
          ref.watch(
            _teacherBookabilityProvider((
              teacherId: mohaffez.id,
              sessionType: params.sessionTypeFilter,
            )).future,
          ),
      ];
      final bookabilityResults = await Future.wait(bookabilityFutures);
      final bookabilityById = <String, _TeacherBookability>{
        for (var index = 0; index < mohaffezList.length; index++)
          mohaffezList[index].id: bookabilityResults[index],
      };

      mohaffezList = mohaffezList.where((mohaffez) {
        final bookability = bookabilityById[mohaffez.id];
        final hasMatchingPlan = bookability?.hasMatchingPlan ?? false;
        final isBookable =
            (bookability?.hasAvailableSlot ?? false) && hasMatchingPlan;

        switch (params.availabilityFilter) {
          case TeacherAvailabilityFilter.availableOnly:
            return isBookable;
          case TeacherAvailabilityFilter.unavailableOnly:
            if (params.sessionTypeFilter == TeacherSessionTypeFilter.all) {
              return !isBookable;
            }
            return hasMatchingPlan && !isBookable;
          case TeacherAvailabilityFilter.all:
            return params.sessionTypeFilter == TeacherSessionTypeFilter.all
                ? true
                : hasMatchingPlan;
        }
      }).toList();
    }

    mohaffezList.sort((a, b) => _compareMohaffezResults(a, b, params));

    return mohaffezList;
  } catch (e) {
    throw Exception('خطأ في جلب المحفظين القريبين: $e');
  }
});

// معاملات البحث
Future<bool> _hasUpcomingAvailableSlot(
  FirebaseFirestore firestore,
  String mohaffezId,
  DateTime now, {
  TeacherSessionTypeFilter sessionTypeFilter = TeacherSessionTypeFilter.all,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final currentDayOfWeek = today.weekday;

  final snapshot = await firestore
      .collection('users')
      .doc(mohaffezId)
      .collection('availability')
      .get()
      .timeout(const Duration(seconds: 10));

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final dayOfWeek = _normalizeDayOfWeek(data['dayOfWeek']);
    if (dayOfWeek == null) continue;

    var daysUntil = dayOfWeek - currentDayOfWeek;
    if (daysUntil < 0) daysUntil += 7;
    final isToday = daysUntil == 0;

    final timeSlots = List<Map<String, dynamic>>.from(
      data['timeSlots'] ?? const [],
    );

    for (final slot in timeSlots) {
      if (slot['enabled'] != true) continue;
      if (!_matchesSessionTypeFilter(slot['sessionType'], sessionTypeFilter)) {
        continue;
      }
      if (!isToday) return true;

      final startTime = slot['startTime'] as String?;
      if (startTime == null) continue;
      final parts = startTime.split(':');
      final hour = int.tryParse(parts.elementAtOrNull(0) ?? '');
      final minute = int.tryParse(parts.elementAtOrNull(1) ?? '');
      if (hour == null || minute == null) continue;

      final slotStart = DateTime(
        today.year,
        today.month,
        today.day,
        hour,
        minute,
      );
      if (slotStart.isAfter(now)) return true;
    }
  }

  return false;
}

Future<bool> _hasActivePricingPlan(
  FirebaseFirestore firestore,
  String mohaffezId, {
  TeacherSessionTypeFilter sessionTypeFilter = TeacherSessionTypeFilter.all,
}) async {
  final snapshot = await firestore
      .collection('users')
      .doc(mohaffezId)
      .collection('pricingPlans')
      .where('isActive', isEqualTo: true)
      .get()
      .timeout(const Duration(seconds: 10));

  if (sessionTypeFilter == TeacherSessionTypeFilter.all) {
    return snapshot.docs.isNotEmpty;
  }

  return snapshot.docs.any(
    (doc) => _matchesSessionTypeFilter(
      doc.data()['mode'],
      sessionTypeFilter,
    ),
  );
}

int? _normalizeDayOfWeek(Object? value) {
  final day = value is num ? value.toInt() : null;
  if (day == null) return null;
  if (day >= DateTime.monday && day <= DateTime.sunday) return day;
  if (day >= 0 && day <= 6) return day + 1;
  return null;
}

bool _matchesSessionTypeFilter(
  Object? rawSessionType,
  TeacherSessionTypeFilter filter,
) {
  if (filter == TeacherSessionTypeFilter.all) return true;

  final sessionType = rawSessionType?.toString().trim().toLowerCase();
  if (sessionType == null || sessionType.isEmpty) return false;

  return switch (filter) {
    TeacherSessionTypeFilter.all => true,
    TeacherSessionTypeFilter.online => sessionType == 'online',
    TeacherSessionTypeFilter.home => sessionType == 'home',
    TeacherSessionTypeFilter.mosque => sessionType == 'mosque',
    TeacherSessionTypeFilter.offline => sessionType == 'home' ||
        sessionType == 'mosque' ||
        sessionType == 'in_person',
  };
}

int _compareMohaffezResults(
  MohaffezModel a,
  MohaffezModel b,
  NearbyParams params,
) {
  final matchCompare =
      _teacherMatchScore(b, params).compareTo(_teacherMatchScore(a, params));
  if (matchCompare != 0) return matchCompare;

  final foundingCompare = _compareFoundingTeacherBadge(a, b);
  if (foundingCompare != 0) return foundingCompare;

  final selectedSortCompare = switch (params.sortBy) {
    SortType.distance => _compareDistance(a, b, params),
    SortType.rating => b.reputationScore.compareTo(a.reputationScore),
    SortType.followers => b.followerCount.compareTo(a.followerCount),
  };
  if (selectedSortCompare != 0) return selectedSortCompare;

  final ratingCompare = b.reputationScore.compareTo(a.reputationScore);
  if (ratingCompare != 0) return ratingCompare;

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

bool _matchesExplicitDiscoveryFilters(
  MohaffezModel teacher,
  NearbyParams params,
) {
  final matchesExplicitFilters = teacher.matchesDiscoveryFilters(
    service: params.teachingService,
    learnerLevel: params.learnerLevel,
    teachingLanguage: params.teachingLanguage,
  );
  if (!matchesExplicitFilters) return false;
  if (!params.enforceAudienceMatching) return true;
  return teacher.teachesAudience(
    params.requiredLearnerAgeGroup,
    params.requiredLearnerGender,
    allowIncomplete: params.allowIncompleteTeacherAudience,
  );
}

int _teacherMatchScore(MohaffezModel teacher, NearbyParams params) {
  return teacher.discoveryMatchScore(
    service: params.suggestedTeachingService,
    learnerLevel: params.suggestedLearnerLevel,
    teachingLanguage: params.suggestedTeachingLanguage,
  );
}

int _compareFoundingTeacherBadge(MohaffezModel a, MohaffezModel b) {
  final aFounder = a.badges.foundingTeacher.enabled;
  final bFounder = b.badges.foundingTeacher.enabled;
  if (aFounder == bFounder) return 0;
  return aFounder ? -1 : 1;
}

int _compareDistance(MohaffezModel a, MohaffezModel b, NearbyParams params) {
  if (params.userLat == null || params.userLng == null) return 0;

  final distA =
      a.getDistanceFrom(params.userLat, params.userLng) ?? double.infinity;
  final distB =
      b.getDistanceFrom(params.userLat, params.userLng) ?? double.infinity;
  return distA.compareTo(distB);
}

String _normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('ـ', '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\w\u0600-\u06FF]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _searchTerms(String? rawQuery) {
  final normalized = _normalizeSearchText(rawQuery ?? '');
  if (normalized.isEmpty) return const [];
  return normalized
      .split(' ')
      .where((term) => term.trim().isNotEmpty)
      .toSet()
      .toList(growable: false);
}

bool _matchesMohaffezSearch(
  MohaffezModel mohaffez,
  List<String> terms,
) {
  final searchableText = _normalizeSearchText(
    [
      mohaffez.displayName,
      mohaffez.bio,
      mohaffez.specialization,
      ...mohaffez.discoveryBadges(max: 12),
      mohaffez.addressText,
      _genderSearchAliases(mohaffez.gender),
      if (mohaffez.trialSessionEnabled)
        'حلقة تجريبية حصة تجريبية جلسة تجريبية تجربة مجانية اختبار',
      if (mohaffez.badges.foundingTeacher.enabled)
        'محفظ مؤسس معلم مؤسس شارة مؤسس',
      mohaffez.pricingSearchText,
    ].whereType<Object>().join(' '),
  );

  return terms.every(searchableText.contains);
}

String _genderSearchAliases(String? gender) {
  return switch (gender?.trim().toLowerCase()) {
    'male' => 'معلم محفظ رجل ذكر male',
    'female' => 'معلمة محفظة امرأة انثى female',
    _ => '',
  };
}

class NearbyParams {
  final double? userLat;
  final double? userLng;
  final double radiusKm;
  final bool distanceFilterEnabled;
  final SortType sortBy;
  final String? searchQuery;
  final String? specialization;
  final String? teachingService;
  final String? requiredLearnerAgeGroup;
  final String? requiredLearnerGender;
  final bool enforceAudienceMatching;
  final bool allowIncompleteTeacherAudience;
  final String? learnerLevel;
  final String? teachingLanguage;
  final String? suggestedTeachingService;
  final String? suggestedLearnerLevel;
  final String? suggestedTeachingLanguage;
  final TeacherAvailabilityFilter availabilityFilter;
  final TeacherGenderFilter genderFilter;
  final TeacherTrialSessionFilter trialSessionFilter;
  final TeacherSessionTypeFilter sessionTypeFilter;

  NearbyParams({
    this.userLat,
    this.userLng,
    this.radiusKm = 50.0, // 50 كم افتراضياً
    this.distanceFilterEnabled = true,
    this.sortBy = SortType.distance,
    this.searchQuery,
    this.specialization,
    this.teachingService,
    this.requiredLearnerAgeGroup,
    this.requiredLearnerGender,
    this.enforceAudienceMatching = false,
    this.allowIncompleteTeacherAudience = true,
    this.learnerLevel,
    this.teachingLanguage,
    this.suggestedTeachingService,
    this.suggestedLearnerLevel,
    this.suggestedTeachingLanguage,
    this.availabilityFilter = TeacherAvailabilityFilter.availableOnly,
    this.genderFilter = TeacherGenderFilter.all,
    this.trialSessionFilter = TeacherTrialSessionFilter.all,
    this.sessionTypeFilter = TeacherSessionTypeFilter.all,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyParams &&
          runtimeType == other.runtimeType &&
          userLat == other.userLat &&
          userLng == other.userLng &&
          radiusKm == other.radiusKm &&
          distanceFilterEnabled == other.distanceFilterEnabled &&
          sortBy == other.sortBy &&
          searchQuery == other.searchQuery &&
          specialization == other.specialization &&
          teachingService == other.teachingService &&
          requiredLearnerAgeGroup == other.requiredLearnerAgeGroup &&
          requiredLearnerGender == other.requiredLearnerGender &&
          enforceAudienceMatching == other.enforceAudienceMatching &&
          allowIncompleteTeacherAudience ==
              other.allowIncompleteTeacherAudience &&
          learnerLevel == other.learnerLevel &&
          teachingLanguage == other.teachingLanguage &&
          suggestedTeachingService == other.suggestedTeachingService &&
          suggestedLearnerLevel == other.suggestedLearnerLevel &&
          suggestedTeachingLanguage == other.suggestedTeachingLanguage &&
          availabilityFilter == other.availabilityFilter &&
          genderFilter == other.genderFilter &&
          trialSessionFilter == other.trialSessionFilter &&
          sessionTypeFilter == other.sessionTypeFilter;

  @override
  int get hashCode => Object.hashAll([
        userLat,
        userLng,
        radiusKm,
        distanceFilterEnabled,
        sortBy,
        searchQuery,
        specialization,
        teachingService,
        requiredLearnerAgeGroup,
        requiredLearnerGender,
        enforceAudienceMatching,
        allowIncompleteTeacherAudience,
        learnerLevel,
        teachingLanguage,
        suggestedTeachingService,
        suggestedLearnerLevel,
        suggestedTeachingLanguage,
        availabilityFilter,
        genderFilter,
        trialSessionFilter,
        sessionTypeFilter,
      ]);
}

enum SortType { distance, rating, followers }

enum TeacherAvailabilityFilter { availableOnly, all, unavailableOnly }

enum TeacherGenderFilter { all, male, female }

enum TeacherTrialSessionFilter { all, enabledOnly }

enum TeacherSessionTypeFilter { all, online, offline, home, mosque }

/// Provider for mohaffez session counts (for search results)
final mohaffezSessionCountProvider = FutureProvider.family<int, String>(
  (ref, mohaffezId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('hafizSessions')
          .where('mohaffezId', isEqualTo: mohaffezId)
          .where('status', isEqualTo: 'completed')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  },
);
