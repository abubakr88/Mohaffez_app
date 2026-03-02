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

// Sentinel value for copyWith nullable fields
class _Sentinel {
  const _Sentinel();
}

const _sentinel = _Sentinel();

/// Filter state for admin users list
class UserFilterState {
  final String searchQuery;
  final String? roleFilter; // null | 'student' | 'mohaffez' | 'admin'
  final String? statusFilter; // null | 'active' | 'suspended'

  const UserFilterState({
    this.searchQuery = '',
    this.roleFilter,
    this.statusFilter,
  });

  UserFilterState copyWith({
    String? searchQuery,
    Object? roleFilter = _sentinel,
    Object? statusFilter = _sentinel,
  }) {
    return UserFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: roleFilter == _sentinel ? this.roleFilter : roleFilter as String?,
      statusFilter: statusFilter == _sentinel ? this.statusFilter : statusFilter as String?,
    );
  }
}

/// Notifier for user filter state
class UserFilterNotifier extends StateNotifier<UserFilterState> {
  UserFilterNotifier() : super(const UserFilterState());

  void setSearch(String q) => state = state.copyWith(searchQuery: q);
  void setRole(String? role) => state = state.copyWith(roleFilter: role);
  void setStatus(String? status) => state = state.copyWith(statusFilter: status);
  void reset() => state = const UserFilterState();
}

/// Provider for user filter state
final userFilterProvider = StateNotifierProvider<UserFilterNotifier, UserFilterState>(
  (ref) => UserFilterNotifier(),
);

/// Client-side filtered stream — streams all users then filters in memory
/// (Firestore doesn't support partial text search)
final filteredUsersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final filter = ref.watch(userFilterProvider);
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('name')
      .snapshots()
      .map((snap) {
        var users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        // Apply role filter
        if (filter.roleFilter != null) {
          users = users.where((u) => u['role'] == filter.roleFilter).toList();
        }
        // Apply status filter
        if (filter.statusFilter != null) {
          users = users.where((u) => u['status'] == filter.statusFilter).toList();
        }
        // Apply text search on name + uid (case-insensitive)
        if (filter.searchQuery.isNotEmpty) {
          final q = filter.searchQuery.toLowerCase();
          users = users.where((u) {
            final name = (u['name'] as String? ?? '').toLowerCase();
            final uid = (u['id'] as String? ?? '').toLowerCase();
            return name.contains(q) || uid.contains(q);
          }).toList();
        }
        return users;
      });
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

final auditLogProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('adminAuditLog')
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList());
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
      final callable = _functions.httpsCallable('approveCredential');
      await callable.call({'userId': userId, 'credentialId': credentialId});
    });
  }

  Future<void> rejectCredential(
      String userId, String credentialId, String reason) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('rejectCredential');
      await callable.call({'userId': userId, 'credentialId': credentialId, 'reason': reason});
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

  Future<void> markCommissionPaid(String commissionId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final callable = _functions.httpsCallable('markCommissionPaid');
      await callable.call({'commissionId': commissionId});
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
      final callable = _functions.httpsCallable('releaseExpiredSlotLocks');
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
