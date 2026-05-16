import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/suspension_model.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

final currentUserSuspensionProvider = StreamProvider<SuspensionModel?>(
  (ref) {
    final user = ref.watch(currentUserProvider).value;
    final uid = user?.uid;

    if (uid == null || uid.isEmpty) {
      // WHY: Unauthenticated users cannot have a suspension document.
      return Stream.value(null);
    }

    return FirebaseFirestore.instance
        .collection('userSuspensions')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      final isActive = data != null && data['isActive'] == true;
      return doc.exists && isActive
          ? SuspensionModel.fromFirestore(doc)
          : null;
    });
  },
  dependencies: [currentUserProvider],
);

final isUserSuspendedProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(false);

  // WHY: Keep a live bool stream for router guards without relying on autoDispose state.
  return FirebaseFirestore.instance
      .collection('userSuspensions')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists && (doc.data()?['isActive'] == true));
});
