import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mohaffez_model.dart';
import 'server_clock_provider.dart';

// Provider للحصول على قائمة المحفظين
final nearbyMohaffezProvider = FutureProvider.autoDispose
    .family<List<MohaffezModel>, NearbyParams>((ref, params) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // استعلام للحصول على المحفظين فقط
    final snapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'mohaffez')
        .where('status', isEqualTo: 'active')
        .where('addressLat', isNotEqualTo: null)
        .limit(50) // حد أقصى للنتائج
        .get()
        .timeout(const Duration(seconds: 15));

    List<MohaffezModel> mohaffezList = snapshot.docs
        .map((doc) => MohaffezModel.fromFirestore(doc))
        .where((mohaffez) {
      // تصفية المحفظين الذين لديهم إحداثيات صحيحة
      return mohaffez.addressLat != null && mohaffez.addressLng != null;
    }).toList();

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

    // تصفية حسب البحث بالاسم
    if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
      final query = params.searchQuery!.toLowerCase();
      mohaffezList = mohaffezList.where((mohaffez) {
        return mohaffez.name.toLowerCase().contains(query);
      }).toList();
    }

    // تصفية حسب التخصص
    if (params.specialization != null && params.specialization!.isNotEmpty) {
      mohaffezList = mohaffezList.where((mohaffez) {
        final spec = mohaffez.specialization?.toLowerCase() ?? '';
        return spec.contains(params.specialization!.toLowerCase());
      }).toList();
    }

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
      final now = serverNowFromRef(ref);
      final slotEntries = await Future.wait(
        mohaffezList.map((mohaffez) async {
          final hasAvailableSlot = await _hasUpcomingAvailableSlot(
            firestore,
            mohaffez.id,
            now,
            sessionTypeFilter: params.sessionTypeFilter,
          );
          return MapEntry(mohaffez.id, hasAvailableSlot);
        }),
      );
      final slotById = Map.fromEntries(slotEntries);

      final planEntries = await Future.wait(
        mohaffezList.map((mohaffez) async {
          final hasActivePlan = await _hasActivePricingPlan(
            firestore,
            mohaffez.id,
            sessionTypeFilter: params.sessionTypeFilter,
          );
          return MapEntry(mohaffez.id, hasActivePlan);
        }),
      );
      final activePlanById = Map.fromEntries(planEntries);

      mohaffezList = mohaffezList.where((mohaffez) {
        final hasMatchingPlan = activePlanById[mohaffez.id] ?? false;
        final isBookable = (slotById[mohaffez.id] ?? false) && hasMatchingPlan;

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
  final foundingCompare = _compareFoundingTeacherBadge(a, b);
  if (foundingCompare != 0) return foundingCompare;

  final selectedSortCompare = switch (params.sortBy) {
    SortType.distance => _compareDistance(a, b, params),
    SortType.rating => b.rating.compareTo(a.rating),
    SortType.followers => b.followerCount.compareTo(a.followerCount),
  };
  if (selectedSortCompare != 0) return selectedSortCompare;

  final ratingCompare = b.rating.compareTo(a.rating);
  if (ratingCompare != 0) return ratingCompare;

  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

class NearbyParams {
  final double? userLat;
  final double? userLng;
  final double radiusKm;
  final bool distanceFilterEnabled;
  final SortType sortBy;
  final String? searchQuery;
  final String? specialization;
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
          availabilityFilter == other.availabilityFilter &&
          genderFilter == other.genderFilter &&
          trialSessionFilter == other.trialSessionFilter &&
          sessionTypeFilter == other.sessionTypeFilter;

  @override
  int get hashCode => Object.hash(
        userLat,
        userLng,
        radiusKm,
        distanceFilterEnabled,
        sortBy,
        searchQuery,
        specialization,
        availabilityFilter,
        genderFilter,
        trialSessionFilter,
        sessionTypeFilter,
      );
}

enum SortType { distance, rating, followers }

enum TeacherAvailabilityFilter { availableOnly, all, unavailableOnly }

enum TeacherGenderFilter { all, male, female }

enum TeacherTrialSessionFilter { all, enabledOnly }

enum TeacherSessionTypeFilter { all, online, offline }

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
