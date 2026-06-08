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
    if (params.userLat != null && params.userLng != null) {
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

    // تصفية حسب قابلية الحجز: وقت قادم مفعّل + خطة سعر نشطة
    if (params.availabilityFilter != TeacherAvailabilityFilter.all) {
      final now = serverNowFromRef(ref);
      final slotEntries = await Future.wait(
        mohaffezList.map((mohaffez) async {
          final hasAvailableSlot = await _hasUpcomingAvailableSlot(
            firestore,
            mohaffez.id,
            now,
          );
          return MapEntry(mohaffez.id, hasAvailableSlot);
        }),
      );
      final slotById = Map.fromEntries(slotEntries);

      final planEntries = await Future.wait(
        mohaffezList
            .where((mohaffez) => slotById[mohaffez.id] == true)
            .map((mohaffez) async {
          final hasActivePlan = await _hasActivePricingPlan(
            firestore,
            mohaffez.id,
          );
          return MapEntry(mohaffez.id, hasActivePlan);
        }),
      );
      final activePlanById = Map.fromEntries(planEntries);

      mohaffezList = mohaffezList.where((mohaffez) {
        final isBookable = (slotById[mohaffez.id] ?? false) &&
            (activePlanById[mohaffez.id] ?? false);
        return params.availabilityFilter ==
                TeacherAvailabilityFilter.availableOnly
            ? isBookable
            : !isBookable;
      }).toList();
    }

    switch (params.sortBy) {
      case SortType.distance:
        if (params.userLat != null && params.userLng != null) {
          mohaffezList.sort((a, b) {
            final distA = a.getDistanceFrom(params.userLat, params.userLng) ??
                double.infinity;
            final distB = b.getDistanceFrom(params.userLat, params.userLng) ??
                double.infinity;
            return distA.compareTo(distB);
          });
        }
        break;
      case SortType.rating:
        mohaffezList.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortType.followers:
        mohaffezList.sort((a, b) => b.followerCount.compareTo(a.followerCount));
        break;
    }

    return mohaffezList;
  } catch (e) {
    throw Exception('خطأ في جلب المحفظين القريبين: $e');
  }
});

// معاملات البحث
Future<bool> _hasUpcomingAvailableSlot(
  FirebaseFirestore firestore,
  String mohaffezId,
  DateTime now,
) async {
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
  String mohaffezId,
) async {
  final snapshot = await firestore
      .collection('users')
      .doc(mohaffezId)
      .collection('pricingPlans')
      .where('isActive', isEqualTo: true)
      .limit(1)
      .get()
      .timeout(const Duration(seconds: 10));

  return snapshot.docs.isNotEmpty;
}

int? _normalizeDayOfWeek(Object? value) {
  final day = value is num ? value.toInt() : null;
  if (day == null) return null;
  if (day >= DateTime.monday && day <= DateTime.sunday) return day;
  if (day >= 0 && day <= 6) return day + 1;
  return null;
}

class NearbyParams {
  final double? userLat;
  final double? userLng;
  final double radiusKm;
  final SortType sortBy;
  final String? searchQuery;
  final String? specialization;
  final TeacherAvailabilityFilter availabilityFilter;

  NearbyParams({
    this.userLat,
    this.userLng,
    this.radiusKm = 50.0, // 50 كم افتراضياً
    this.sortBy = SortType.distance,
    this.searchQuery,
    this.specialization,
    this.availabilityFilter = TeacherAvailabilityFilter.availableOnly,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyParams &&
          runtimeType == other.runtimeType &&
          userLat == other.userLat &&
          userLng == other.userLng &&
          radiusKm == other.radiusKm &&
          sortBy == other.sortBy &&
          searchQuery == other.searchQuery &&
          specialization == other.specialization &&
          availabilityFilter == other.availabilityFilter;

  @override
  int get hashCode => Object.hash(
        userLat,
        userLng,
        radiusKm,
        sortBy,
        searchQuery,
        specialization,
        availabilityFilter,
      );
}

enum SortType { distance, rating, followers }

enum TeacherAvailabilityFilter { availableOnly, all, unavailableOnly }

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
