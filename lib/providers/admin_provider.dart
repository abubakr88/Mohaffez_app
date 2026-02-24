import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/admin_repository.dart';
import 'user_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

final allUsersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, roleFilter) {
  return ref.watch(adminRepositoryProvider).getAllUsers(roleFilter: roleFilter);
});

final pendingCredentialsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingCredentials();
});

final failedOperationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchFailedOperations();
});

final allPromoCodesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllPromoCodes();
});

final activeSlotLocksProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchActiveSlotLocks();
});

class AdminActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final AdminRepository _repository;
  final FirebaseFunctions _functions;

  AdminActionsNotifier(this._ref, this._repository, this._functions)
      : super(const AsyncValue.data(null));

  String get _adminUid => _ref.read(currentUserProvider).value?.uid ?? '';

  Future<void> suspendUser(
      String userId, String reason, DateTime? expiresAt) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.suspendUser(userId, _adminUid, reason, expiresAt);
    });
  }

  Future<void> unsuspendUser(String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.unsuspendUser(userId, _adminUid);
    });
  }

  Future<void> deleteUserData(String userId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('deleteUserAccount');
      await callable.call({'userId': userId});
    });
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('setUserRole');
      await callable.call({'userId': userId, 'newRole': newRole});
    });
  }

  Future<void> approveCredential(String userId, String credentialId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.approveCredential(userId, credentialId);
    });
  }

  Future<void> rejectCredential(
      String userId, String credentialId, String reason) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.rejectCredential(userId, credentialId, reason);
    });
  }

  Future<void> dismissFailedOperation(String operationId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.dismissFailedOperation(operationId);
    });
  }

  Future<void> createPromoCode(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createPromoCode(data);
    });
  }

  Future<void> togglePromoCode(String promoId, bool isActive) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.togglePromoCode(promoId, isActive);
    });
  }

  Future<void> deletePromoCode(String promoId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deletePromoCode(promoId);
    });
  }

  Future<void> triggerCommissionJob() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('triggerCommissionJobManually');
      await callable.call();
    });
  }

  Future<void> triggerCleanupJob() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('triggerCleanupJobManually');
      await callable.call();
    });
  }

  Future<void> releaseAllExpiredLocks() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('triggerCleanupJobManually');
      await callable.call();
    });
  }
}

final adminActionsProvider =
    StateNotifierProvider<AdminActionsNotifier, AsyncValue<void>>((ref) {
  return AdminActionsNotifier(
    ref,
    ref.watch(adminRepositoryProvider),
    FirebaseFunctions.instance,
  );
});
