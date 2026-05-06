import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/admin_repository.dart';

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

/// Server-side filtered stream — applies role/status filters via Firestore .where()
/// Only text search (name/uid contains) is done client-side since Firestore
/// doesn't support partial text search
// FIXED: BUG-6
final filteredUsersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final filter = ref.watch(userFilterProvider);

  Query<Map<String, dynamic>> query =
      FirebaseFirestore.instance.collection('users').orderBy('name');

  if (filter.roleFilter != null) {
    query = query.where('role', isEqualTo: filter.roleFilter);
  }
  if (filter.statusFilter != null) {
    query = query.where('status', isEqualTo: filter.statusFilter);
  }

  return query.limit(200).snapshots().map((snap) {
    var users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    // Apply text search on name + uid (case-insensitive) — client-side only
    // because Firestore doesn't support partial text search
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
  final AdminRepository _repository;
  final FirebaseFunctions _functions;

  AdminActionsNotifier(this._repository, this._functions)
      : super(const AsyncValue.data(null));

  void _reset() {
    if (state.hasError) state = const AsyncValue.data(null);
  }

  Future<void> _runAction(Future<void> Function() action) async {
    _reset();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(action);
  }

  Future<void> _callFunction(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    await _runAction(() async {
      await _functions.httpsCallable(functionName).call(params);
    });
  }

  Future<void> suspendUser(
      String userId, String reason, DateTime? expiresAt) async {
    await _callFunction('suspendUser', {
      'userId': userId,
      'reason': reason,
      'expiresAt': expiresAt?.toIso8601String(),
    });
  }

  Future<void> unsuspendUser(String userId) async {
    await _callFunction('unsuspendUser', {'userId': userId});
  }

  Future<void> deleteUserData(String userId) async {
    await _callFunction('deleteUserAccount', {'userId': userId});
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _callFunction('setUserRole', {
      'userId': userId,
      'newRole': newRole,
    });
  }

  Future<void> approveCredential(String userId, String credentialId) async {
    await _callFunction('approveCredential', {
      'userId': userId,
      'credentialId': credentialId,
    });
  }

  Future<void> rejectCredential(
      String userId, String credentialId, String reason) async {
    await _callFunction('rejectCredential', {
      'userId': userId,
      'credentialId': credentialId,
      'reason': reason,
    });
  }

  Future<void> dismissFailedOperation(String operationId) async {
    await _runAction(() async {
      await _repository.dismissFailedOperation(operationId);
    });
  }

  Future<void> createPromoCode(Map<String, dynamic> data) async {
    await _runAction(() async {
      await _repository.createPromoCode(data);
    });
  }

  Future<void> togglePromoCode(String promoId, bool isActive) async {
    await _runAction(() async {
      await _repository.togglePromoCode(promoId, isActive);
    });
  }

  Future<void> deletePromoCode(String promoId) async {
    await _runAction(() async {
      await _repository.deletePromoCode(promoId);
    });
  }

  Future<void> triggerCommissionJob() async {
    await _callFunction('triggerCommissionJobManually', const {});
  }

  Future<void> markCommissionPaid(
    String weeklyCommissionSummaryId, {
    double? paidAmount,
    String? adminNote,
  }) async {
    await _callFunction('markCommissionPaid', {
      'weeklyCommissionSummaryId': weeklyCommissionSummaryId,
      if (paidAmount != null) 'paidAmount': paidAmount,
      if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
    });
  }

  Future<void> rejectCommissionPayment(
    String weeklyCommissionSummaryId, {
    required String reason,
  }) async {
    await _callFunction('rejectCommissionPayment', {
      'weeklyCommissionSummaryId': weeklyCommissionSummaryId,
      'reason': reason,
    });
  }

  Future<void> triggerCleanupJob() async {
    await _callFunction('triggerCleanupJobManually', const {});
  }

  Future<void> releaseAllExpiredLocks() async {
    await _callFunction('triggerCleanupJobManually', const {});
  }
}

final adminActionsProvider =
    StateNotifierProvider<AdminActionsNotifier, AsyncValue<void>>((ref) {
  return AdminActionsNotifier(
    ref.watch(adminRepositoryProvider),
    FirebaseFunctions.instance,
  );
});
