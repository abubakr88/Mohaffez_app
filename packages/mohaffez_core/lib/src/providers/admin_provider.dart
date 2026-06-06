import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/broadcast_model.dart';
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
  final String? statusFilter; // null | 'active' | 'suspended' | 'pending_approval' | 'rejected'

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

/// Teachers awaiting account verification (status == 'pending_approval').
/// This is the real "طلبات التحقق" queue.
final pendingTeachersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingTeachers();
});

/// A single pending teacher's submitted credentials (for the review card).
final teacherCredentialsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getUserCredentials(userId);
});

/// A single user document by id (admin profile/detail page).
final adminUserProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getUserById(userId);
});

/// Aggregated teaching statistics for one mohaffez, computed from hafizSessions.
class TeacherStats {
  final int total;
  final int completed;
  final int upcoming; // pending + accepted
  final int cancelled;
  final int studentCount; // distinct students
  final double revenue; // sum of sessionPrice over completed sessions
  final double? avgRating; // mean teacherRating over rated sessions
  final int ratingCount;
  final List<Map<String, dynamic>> recentSessions; // newest first

  const TeacherStats({
    required this.total,
    required this.completed,
    required this.upcoming,
    required this.cancelled,
    required this.studentCount,
    required this.revenue,
    required this.avgRating,
    required this.ratingCount,
    required this.recentSessions,
  });
}

/// Teaching statistics for a mohaffez, for the admin profile page.
final teacherStatsProvider =
    FutureProvider.autoDispose.family<TeacherStats, String>((ref, teacherId) async {
  final sessions =
      await ref.watch(adminRepositoryProvider).getTeacherSessions(teacherId);

  var completed = 0, upcoming = 0, cancelled = 0, ratingCount = 0;
  var revenue = 0.0, ratingSum = 0.0;
  final students = <String>{};

  for (final s in sessions) {
    final status = (s['status'] as String? ?? '').toLowerCase();
    final sid = s['studentId'] as String?;
    if (sid != null && sid.isNotEmpty) students.add(sid);

    if (status == 'completed') {
      completed++;
      revenue += (s['sessionPrice'] as num?)?.toDouble() ?? 0;
    } else if (status == 'pending' || status == 'accepted') {
      upcoming++;
    } else if (status.contains('cancel') || status.contains('no_show') ||
        status.contains('noshow')) {
      cancelled++;
    }

    final r = (s['teacherRating'] as num?)?.toDouble();
    if (r != null && r > 0) {
      ratingSum += r;
      ratingCount++;
    }
  }

  final recent = [...sessions]
    ..sort((a, b) => _compareTs(b['sessionDate'] ?? b['slotStart'],
        a['sessionDate'] ?? a['slotStart']));

  return TeacherStats(
    total: sessions.length,
    completed: completed,
    upcoming: upcoming,
    cancelled: cancelled,
    studentCount: students.length,
    revenue: revenue,
    avgRating: ratingCount > 0 ? ratingSum / ratingCount : null,
    ratingCount: ratingCount,
    recentSessions: recent.take(10).toList(),
  );
});

final failedOperationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchFailedOperations();
});

// Admin payout queue + notifications reuse the existing typed wallet/notification
// providers (activePayoutsProvider, notificationsFirstPageProvider,
// unreadNotificationsCountProvider, notificationActionsProvider).

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

/// Admin-scoped sessions stream.
///
/// [statusFilter] — null = all recent (ordered by sessionDate DESC, limit 100)
/// any other string — filtered by status, client-sorted by sessionDate DESC.
/// 'live' is a synthetic filter meaning pending+accepted.
final adminSessionsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, statusFilter) {
  final col = FirebaseFirestore.instance.collection('hafizSessions');

  // 'live' = all non-terminal statuses
  if (statusFilter == 'live') {
    return col
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(100)
        .snapshots()
        .map((s) {
          final docs = s.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList();
          docs.sort((a, b) => _compareTs(a['slotStart'], b['slotStart']));
          return docs;
        });
  }

  if (statusFilter != null) {
    return col
        .where('status', isEqualTo: statusFilter)
        .limit(100)
        .snapshots()
        .map((s) {
          final docs = s.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList();
          docs.sort((a, b) => _compareTs(b['sessionDate'], a['sessionDate']));
          return docs;
        });
  }

  // null → most recent 100 across all statuses
  return col
      .orderBy('sessionDate', descending: true)
      .limit(100)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList());
});

int _compareTs(dynamic a, dynamic b) {
  DateTime? toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  final da = toDate(a);
  final db = toDate(b);
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}

/// Recent broadcast notifications (most recent first).
final broadcastHistoryProvider =
    StreamProvider.autoDispose<List<BroadcastModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('broadcastHistory')
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map(BroadcastModel.fromFirestore).toList());
});

/// Live count of users who would receive a broadcast for [targetRole]
/// ('all' | 'student' | 'mohaffez'). Backed by the getBroadcastAudienceCount
/// callable, which counts users that have an FCM token.
final broadcastAudienceCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, targetRole) async {
  final callable = FirebaseFunctions.instance
      .httpsCallable('getBroadcastAudienceCount');
  final res = await callable.call(<String, dynamic>{'targetRole': targetRole});
  final data = res.data as Map?;
  return (data?['count'] as num?)?.toInt() ?? 0;
});

/// One row in the top-teachers leaderboard.
class TeacherRanking {
  final String mohaffezId;
  final String name;
  final int sessionCount;
  final double revenue;

  const TeacherRanking({
    required this.mohaffezId,
    required this.name,
    required this.sessionCount,
    required this.revenue,
  });
}

/// Top teachers by completed-session count over the last [days] days.
/// Aggregates `hafizSessions` client-side using the denormalized
/// `mohaffezName` / `sessionPrice` fields (no user join needed).
final topTeachersProvider =
    FutureProvider.autoDispose.family<List<TeacherRanking>, int>((ref, days) async {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final snap = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('status', isEqualTo: 'completed')
      .where('completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .get();

  final counts = <String, int>{};
  final revenue = <String, double>{};
  final names = <String, String>{};

  for (final doc in snap.docs) {
    final d = doc.data();
    final id = d['mohaffezId'] as String?;
    if (id == null || id.isEmpty) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    revenue[id] = (revenue[id] ?? 0) + ((d['sessionPrice'] as num?)?.toDouble() ?? 0);
    final name = d['mohaffezName'] as String?;
    if (name != null && name.isNotEmpty) names[id] = name;
  }

  final rankings = counts.entries
      .map((e) => TeacherRanking(
            mohaffezId: e.key,
            name: names[e.key] ?? e.key,
            sessionCount: e.value,
            revenue: revenue[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) {
      final byCount = b.sessionCount.compareTo(a.sessionCount);
      return byCount != 0 ? byCount : b.revenue.compareTo(a.revenue);
    });

  return rankings.take(10).toList();
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

  /// Approve a teacher's verification request: status pending_approval → active.
  Future<void> approveTeacher(String userId) async {
    await _callFunction('approveTeacher', {'userId': userId});
  }

  /// Reject a teacher's verification request: status → rejected.
  Future<void> rejectTeacher(String userId, String reason) async {
    await _callFunction('rejectTeacher', {
      'userId': userId,
      'reason': reason,
    });
  }

  Future<void> dismissFailedOperation(String operationId) async {
    await _runAction(() async {
      await _repository.dismissFailedOperation(operationId);
    });
  }

  // ── Payouts ────────────────────────────────────────────────────────────
  /// requested → processing (debits teacher wallet, then send the bank transfer).
  Future<void> startPayout(String payoutRequestId) async {
    await _callFunction('startPayout', {'payoutRequestId': payoutRequestId});
  }

  /// processing → completed (confirm the bank transfer succeeded).
  Future<void> completePayout(String payoutRequestId,
      {String? bankReference}) async {
    await _callFunction('completePayout', {
      'payoutRequestId': payoutRequestId,
      if (bankReference != null && bankReference.isNotEmpty)
        'bankReference': bankReference,
    });
  }

  /// processing → failed (reverses the ledger, refunds the teacher's wallet).
  Future<void> failPayout(String payoutRequestId, String reason) async {
    await _callFunction('failPayout', {
      'payoutRequestId': payoutRequestId,
      'reason': reason,
    });
  }

  // ── Wallet top-ups + manual credit ──────────────────────────────────────
  /// Approve a manual top-up request; credits the user's wallet.
  /// [paidAmountEgp] overrides the requested amount when the admin verified a
  /// different figure on the transfer proof.
  Future<void> verifyTopUp(String topUpRequestId,
      {double? paidAmountEgp}) async {
    await _callFunction('verifyWalletTopUp', {
      'topUpRequestId': topUpRequestId,
      if (paidAmountEgp != null) 'paidAmountEgp': paidAmountEgp,
    });
  }

  Future<void> rejectTopUp(String topUpRequestId, String reason) async {
    await _callFunction('rejectWalletTopUp', {
      'topUpRequestId': topUpRequestId,
      'reason': reason,
    });
  }

  /// Manually credit a user's wallet (e.g. goodwill / correction).
  Future<void> creditWallet({
    required String userId,
    required String ownerType, // 'student' | 'mohaffez'
    required double amountEgp,
    required String reason,
  }) async {
    await _callFunction('adminCreditWallet', {
      'userId': userId,
      'ownerType': ownerType,
      'amountEgp': amountEgp,
      'reason': reason,
    });
  }

  // ── Refunds ─────────────────────────────────────────────────────────────
  /// Refund a wallet-paid session. Reverses the original ledger legs and marks
  /// the session `refunded`. Admin-only; [reason] is required (≥ 3 chars).
  Future<void> refundSession(String sessionId, String reason) async {
    await _callFunction('refundSessionPayment', {
      'sessionId': sessionId,
      'reason': reason,
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
