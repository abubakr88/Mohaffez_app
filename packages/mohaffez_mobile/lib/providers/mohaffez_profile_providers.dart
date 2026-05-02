// lib/providers/mohaffez_profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mohaffez_core/mohaffez_core.dart';

/// Provider for mohaffez profile data
final mohaffezProfileProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, mohaffezId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .get();

    if (!doc.exists) {
      throw Exception('المحفظ غير موجود');
    }

    return {
      ...doc.data()!,
      'uid': doc.id,
    };
  },
);

/// Provider for follow status
final followStatusProvider = StreamProvider.family<bool, String>(
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
final credentialsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
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
final availabilityProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
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

/// Provider for mohaffez statistics — streams denormalized counters from the
/// teacher's user document so the profile updates in real-time when Cloud
/// Functions increment completedSessionsCount / studentsServedCount.
final mohaffezStatsProvider = StreamProvider.family<Map<String, dynamic>, String>(
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
            'completedSessions': (data['completedSessionsCount'] as num?)?.toInt() ?? 0,
            'uniqueStudents': (data['studentsServedCount'] as num?)?.toInt() ?? 0,
          };
        });
  },
);
