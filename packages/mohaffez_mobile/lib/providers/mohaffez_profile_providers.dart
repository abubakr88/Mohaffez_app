// lib/providers/mohaffez_profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// Live provider for mohaffez profile data.
///
/// Booking availability can be changed by the teacher while a student has the
/// profile open. Keeping this provider scoped to the screen prevents stale
/// `acceptingNewBookings` values without leaving a Firestore listener alive
/// after the profile is closed.
final mohaffezProfileProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        throw Exception('المحفظ غير موجود');
      }

      return withPublicTeacherRatingV2({
        ...doc.data()!,
        'uid': doc.id,
      });
    });
  },
);

class PublicMohaffezProfileBundle {
  final Map<String, dynamic> profile;
  final List<PricingPlanModel> plans;
  final List<Map<String, dynamic>> credentials;
  final List<Map<String, dynamic>> availability;
  final Map<String, dynamic> stats;

  const PublicMohaffezProfileBundle({
    required this.profile,
    required this.plans,
    required this.credentials,
    required this.availability,
    required this.stats,
  });
}

final publicMohaffezProfileProvider =
    FutureProvider.family<PublicMohaffezProfileBundle, String>(
  (ref, mohaffezId) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getPublicTeacherProfile');
    final result = await callable.call<Map<String, dynamic>>({
      'mohaffezId': mohaffezId,
    });
    final data = Map<String, dynamic>.from(result.data);

    final profile = Map<String, dynamic>.from(
      data['profile'] as Map? ?? const <String, dynamic>{},
    );
    final rawPlans = List<Map<String, dynamic>>.from(
      (data['plans'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final credentials = List<Map<String, dynamic>>.from(
      (data['credentials'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final availability = List<Map<String, dynamic>>.from(
      (data['availability'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final stats = Map<String, dynamic>.from(
      data['stats'] as Map? ?? const <String, dynamic>{},
    );

    return PublicMohaffezProfileBundle(
      profile: profile,
      plans: rawPlans.map(_pricingPlanFromPublicMap).toList(),
      credentials: credentials,
      availability: availability,
      stats: stats,
    );
  },
);

PricingPlanModel _pricingPlanFromPublicMap(Map<String, dynamic> data) {
  final safeData = {
    ...data,
    'priceEGP': (data['priceEGP'] as num?)?.toDouble() ?? 0.0,
    'sessionsCount': (data['sessionsCount'] as num?)?.toInt() ?? 0,
    'validityDays': (data['validityDays'] as num?)?.toInt(),
    'sessionsPerWeek': (data['sessionsPerWeek'] as num?)?.toInt(),
    'isActive': data['isActive'] == true,
    'isFreeTrialAvailable': data['isFreeTrialAvailable'] == true,
  };
  return PricingPlanModel.fromJson(safeData);
}

/// Provider for follow status
final followStatusProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, mohaffezId) async* {
    final currentUser = ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      yield false;
      return;
    }

    yield* FirebaseFirestore.instance
        .collection('follows')
        .where('studentId', isEqualTo: currentUser.uid)
        .where('mohaffezId', isEqualTo: mohaffezId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  },
);

/// Provider for credentials
///
/// Fetches all credentials then filters client-side. The COLLECTION-scope
/// single-field index for `credentials.status` was disabled by a fieldOverride,
/// so a server-side `.where('status', isEqualTo: 'approved')` throws
/// FAILED_PRECONDITION. The Firestore rules already allow `list` for all
/// authenticated users and document "rely on client query filter".
final credentialsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .collection('credentials')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    });
  },
);

/// ✅ Provider for availability
final availabilityProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    });
  },
);

/// PII-free occupied intervals for the nearby booking horizon. This is only a
/// UI optimization; the booking Cloud Function remains the conflict authority.
final bookingCalendarProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    final now = DateTime.now().toUtc();
    final rangeStart = DateTime.utc(now.year, now.month, now.day)
        .subtract(const Duration(days: 2));
    final rangeEnd = rangeStart.add(const Duration(days: 11));

    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .collection('bookingCalendar')
        .where(
          'dateUtc',
          isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart),
        )
        .where('dateUtc', isLessThan: Timestamp.fromDate(rangeEnd))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .expand((doc) => (doc.data()['intervals'] as List? ?? const []))
              .whereType<Map>()
              .map((interval) => Map<String, dynamic>.from(interval))
              .toList(),
        );
  },
);

/// Provider for mohaffez statistics — streams denormalized counters from the
/// teacher's user document so the profile updates in real-time when Cloud
/// Functions increment completedSessionsCount / studentsServedCount.
final mohaffezStatsProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return {'completedSessions': 0, 'uniqueStudents': 0};
      }
      final data = doc.data()!;
      return {
        'completedSessions':
            (data['completedSessionsCount'] as num?)?.toInt() ?? 0,
        'uniqueStudents': (data['studentsServedCount'] as num?)?.toInt() ?? 0,
      };
    });
  },
);
