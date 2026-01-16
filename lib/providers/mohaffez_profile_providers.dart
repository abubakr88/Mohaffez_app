// lib/providers/mohaffez_profile_providers.dart - NEW FILE
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_provider.dart';  // ✅ ADD THIS IMPORT

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
final credentialsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, mohaffezId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(mohaffezId)
        .collection('credentials')
        .where('status', isEqualTo: 'approved')
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

/// ✅ NEW: Provider for availability
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
