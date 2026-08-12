import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/broadcast_model.dart';
import '../repositories/admin_repository.dart';
import '../utils/admin_user_search.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});

final allUsersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, roleFilter) {
  return ref.watch(adminRepositoryProvider).getAllUsers(roleFilter: roleFilter);
});

const int adminUsersDefaultPageSize = 50;
const int adminUsersPageStep = 50;

enum AdminPermission {
  manageUsers('manageUsers', 'إدارة المستخدمين'),
  manageUserRoles('manageUserRoles', 'تغيير أدوار المستخدمين'),
  manageTeacherBadges('manageTeacherBadges', 'إدارة شارات المحفظين'),
  deleteUsers('deleteUsers', 'حذف المستخدمين'),
  manageAdminAccess('manageAdminAccess', 'إدارة صلاحيات الأدمنز'),
  reviewTeachers('reviewTeachers', 'مراجعة المحفظين'),
  manageFinance('manageFinance', 'العمليات المالية'),
  sendBroadcasts('sendBroadcasts', 'الإشعارات الجماعية'),
  runMaintenance('runMaintenance', 'تشغيل الصيانة');

  const AdminPermission(this.key, this.label);

  final String key;
  final String label;
}

const Map<AdminPermission, bool> defaultAdminPermissions = {
  AdminPermission.manageUsers: true,
  AdminPermission.manageUserRoles: false,
  AdminPermission.manageTeacherBadges: true,
  AdminPermission.deleteUsers: false,
  AdminPermission.manageAdminAccess: false,
  AdminPermission.reviewTeachers: true,
  AdminPermission.manageFinance: false,
  AdminPermission.sendBroadcasts: true,
  AdminPermission.runMaintenance: false,
};

class AdminAccessState {
  final String uid;
  final String adminRole;
  final Map<AdminPermission, bool> permissions;

  const AdminAccessState({
    required this.uid,
    required this.adminRole,
    required this.permissions,
  });

  bool get isSuperAdmin => adminRole == 'super_admin';
  bool can(AdminPermission permission) =>
      permission == AdminPermission.manageAdminAccess
          ? isSuperAdmin
          : permissions[permission] == true;

  static AdminAccessState none() => const AdminAccessState(
        uid: '',
        adminRole: 'none',
        permissions: {},
      );

  factory AdminAccessState.fromUserDoc(String uid, Map<String, dynamic>? data) {
    if (data?['role'] != 'admin') return AdminAccessState.none();

    final role = data?['adminRole'] == 'admin' ? 'admin' : 'super_admin';
    if (role == 'super_admin') {
      return AdminAccessState(
        uid: uid,
        adminRole: role,
        permissions: {
          for (final permission in AdminPermission.values) permission: true,
        },
      );
    }

    final raw = data?['adminPermissions'];
    final rawMap = raw is Map ? raw : const {};
    return AdminAccessState(
      uid: uid,
      adminRole: role,
      permissions: {
        for (final permission in AdminPermission.values)
          permission: rawMap[permission.key] is bool
              ? permission == AdminPermission.manageAdminAccess
                  ? false
                  : rawMap[permission.key] as bool
              : defaultAdminPermissions[permission] ?? false,
      },
    );
  }
}

final currentAdminAccessProvider =
    StreamProvider.autoDispose<AdminAccessState>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(AdminAccessState.none());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(
        (doc) => AdminAccessState.fromUserDoc(uid, doc.data()),
      );
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
  final String? statusFilter;
  final int pageSize;

  const UserFilterState({
    this.searchQuery = '',
    this.roleFilter,
    this.statusFilter,
    this.pageSize = adminUsersDefaultPageSize,
  });

  UserFilterState copyWith({
    String? searchQuery,
    Object? roleFilter = _sentinel,
    Object? statusFilter = _sentinel,
    int? pageSize,
  }) {
    return UserFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter:
          roleFilter == _sentinel ? this.roleFilter : roleFilter as String?,
      statusFilter: statusFilter == _sentinel
          ? this.statusFilter
          : statusFilter as String?,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Notifier for user filter state
class UserFilterNotifier extends StateNotifier<UserFilterState> {
  UserFilterNotifier() : super(const UserFilterState());

  void setSearch(String q) => state = state.copyWith(
        searchQuery: q,
        pageSize: adminUsersDefaultPageSize,
      );

  void setRole(String? role) => state = state.copyWith(
        roleFilter: role,
        pageSize: adminUsersDefaultPageSize,
      );

  void setStatus(String? status) => state = state.copyWith(
        statusFilter: status,
        pageSize: adminUsersDefaultPageSize,
      );

  void loadMore() => state = state.copyWith(
        pageSize: state.pageSize + adminUsersPageStep,
      );

  void reset() => state = const UserFilterState();
}

/// Provider for user filter state
final userFilterProvider =
    StateNotifierProvider<UserFilterNotifier, UserFilterState>(
  (ref) => UserFilterNotifier(),
);

class AdminUsersListResult {
  final List<Map<String, dynamic>> users;
  final bool hasMore;
  final int loadedCount;

  const AdminUsersListResult({
    required this.users,
    required this.hasMore,
    required this.loadedCount,
  });
}

/// Server-side filtered stream — applies role/status filters via Firestore .where().
/// Text search covers identity fields and the teacher pricing search projection.
final filteredUsersProvider =
    StreamProvider.autoDispose<AdminUsersListResult>((ref) {
  final filter = ref.watch(userFilterProvider);
  final searchTerms = adminUserSearchTerms(filter.searchQuery);

  Query<Map<String, dynamic>> query =
      FirebaseFirestore.instance.collection('users').orderBy('name');

  if (filter.roleFilter != null) {
    query = query.where('role', isEqualTo: filter.roleFilter);
  }
  if (filter.statusFilter != null) {
    query = query.where('status', isEqualTo: filter.statusFilter);
  }

  if (searchTerms.isNotEmpty) {
    return Stream.fromFuture(
      _searchAdminUsers(
        baseQuery: query,
        filter: filter,
        searchTerms: searchTerms,
      ),
    );
  }

  return query.limit(filter.pageSize + 1).snapshots().map((snap) {
    final docs = snap.docs;
    final hasMore = docs.length > filter.pageSize;
    final users = docs
        .take(filter.pageSize)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    return AdminUsersListResult(
      users: users,
      hasMore: hasMore,
      loadedCount:
          docs.length > filter.pageSize ? filter.pageSize : docs.length,
    );
  });
});

Future<AdminUsersListResult> _searchAdminUsers({
  required Query<Map<String, dynamic>> baseQuery,
  required UserFilterState filter,
  required List<String> searchTerms,
}) async {
  final usersCollection = FirebaseFirestore.instance.collection('users');
  final shouldSearchPricing =
      filter.roleFilter == null || filter.roleFilter == 'mohaffez';

  final baseFuture = baseQuery.limit(filter.pageSize + 1).get();
  final pricingFuture = shouldSearchPricing
      ? usersCollection
          .where(
            'pricingSearchKeywords',
            arrayContains: strongestAdminUserSearchTerm(searchTerms),
          )
          .limit(filter.pageSize + 1)
          .get()
      : null;

  final baseSnapshot = await baseFuture;
  final pricingSnapshot = await pricingFuture;
  final candidates = <String, Map<String, dynamic>>{};

  for (final doc in baseSnapshot.docs.take(filter.pageSize)) {
    candidates[doc.id] = {'id': doc.id, ...doc.data()};
  }

  if (pricingSnapshot != null) {
    for (final doc in pricingSnapshot.docs.take(filter.pageSize)) {
      final user = {'id': doc.id, ...doc.data()};
      if (!_matchesAdminFilters(user, filter)) continue;
      candidates[doc.id] = user;
    }
  }

  final users = candidates.values
      .where((user) => matchesAdminUserSearch(user, searchTerms))
      .toList()
    ..sort((a, b) {
      final aName = (a['name'] as String? ?? '').toLowerCase();
      final bName = (b['name'] as String? ?? '').toLowerCase();
      final byName = aName.compareTo(bName);
      if (byName != 0) return byName;
      return (a['id'] as String).compareTo(b['id'] as String);
    });

  final baseHasMore = baseSnapshot.docs.length > filter.pageSize;
  final pricingHasMore =
      pricingSnapshot != null && pricingSnapshot.docs.length > filter.pageSize;

  return AdminUsersListResult(
    users: users,
    hasMore: baseHasMore || pricingHasMore,
    loadedCount: candidates.length,
  );
}

bool _matchesAdminFilters(
  Map<String, dynamic> user,
  UserFilterState filter,
) {
  if (filter.roleFilter != null && user['role'] != filter.roleFilter) {
    return false;
  }
  if (filter.statusFilter != null && user['status'] != filter.statusFilter) {
    return false;
  }
  return true;
}

final pendingCredentialsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingCredentials();
});

/// Teachers awaiting account verification (status == 'pending_approval').
/// This is the real "طلبات التحقق" queue.
final pendingTeachersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingTeachers();
});

/// Users carrying any known review/risk flag for the admin dashboard queue.
final flaggedUsersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchFlaggedUsers();
});

/// A single pending teacher's submitted credentials (for the review card).
final teacherCredentialsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getUserCredentials(userId);
});

/// A pending teacher's pricing plans, including inactive ones, for review.
final teacherReviewPricingPlansProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getTeacherPricingPlans(userId);
});

/// A pending teacher's weekly availability, for review.
final teacherReviewAvailabilityProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getTeacherAvailability(userId);
});

/// A single user document by id (admin profile/detail page).
final adminUserProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getUserById(userId);
});

/// Recent sessions where this user is either student or teacher.
final adminUserSessionsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).getUserSessions(userId);
});

/// Payment events touching this user for finance review.
final adminUserPaymentEventsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).watchUserPaymentEvents(userId);
});

/// Recent notifications sent to a user for support review.
final adminUserNotificationsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(adminRepositoryProvider).watchUserNotifications(userId);
});

double? _teacherRatingOnFivePointScale(Map<String, dynamic> session) {
  final raw = (session['teacherRating'] as num?)?.toDouble();
  if (raw == null || raw <= 0) return null;
  final scale = (session['teacherRatingScale'] as num?)?.toInt();
  if (scale != 5) return null;
  return raw <= 5 ? raw : null;
}

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
  final List<Map<String, dynamic>> ratings; // newest rating first
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
    required this.ratings,
    required this.recentSessions,
  });
}

/// Teaching statistics for a mohaffez, for the admin profile page.
final teacherStatsProvider = FutureProvider.autoDispose
    .family<TeacherStats, String>((ref, teacherId) async {
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
    } else if (status.contains('cancel') ||
        status.contains('no_show') ||
        status.contains('noshow')) {
      cancelled++;
    }

    final r = _teacherRatingOnFivePointScale(s);
    if (r != null && s['teacherRatingReason'] != 'technical_only') {
      ratingSum += r;
      ratingCount++;
    }
  }

  final recent = [...sessions]..sort((a, b) => _compareTs(
      b['sessionDate'] ?? b['slotStart'], a['sessionDate'] ?? a['slotStart']));
  final ratings = sessions
      .where((s) => ((s['teacherRating'] as num?)?.toDouble() ?? 0) > 0)
      .toList()
    ..sort((a, b) => _compareTs(
          b['teacherRatedAt'] ??
              b['updatedAt'] ??
              b['completedAt'] ??
              b['sessionDate'] ??
              b['slotStart'],
          a['teacherRatedAt'] ??
              a['updatedAt'] ??
              a['completedAt'] ??
              a['sessionDate'] ??
              a['slotStart'],
        ));

  return TeacherStats(
    total: sessions.length,
    completed: completed,
    upcoming: upcoming,
    cancelled: cancelled,
    studentCount: students.length,
    revenue: revenue,
    avgRating: ratingCount > 0 ? ratingSum / ratingCount : null,
    ratingCount: ratingCount,
    ratings: ratings,
    recentSessions: recent.take(10).toList(),
  );
});

final failedOperationsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchFailedOperations();
});

// Admin payout queue + notifications reuse the existing typed wallet/notification
// providers (activePayoutsProvider, notificationsFirstPageProvider,
// unreadNotificationsCountProvider, notificationActionsProvider).

final allPromoCodesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllPromoCodes();
});

final activeSlotLocksProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
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
      .map((s) => s.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList());
});

/// Active trial-session requests shown alongside pending booked sessions.
///
/// This stays separate from [adminSessionsProvider] so Firestore only opens the
/// extra collection listener when the admin explicitly views the pending queue.
/// The limit protects the dashboard from unbounded reads; all data needed by
/// the table is denormalized on the request, so this does not trigger user-doc
/// lookups per row.
final adminPendingTrialRequestsProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, limit) {
  return FirebaseFirestore.instance
      .collection('trialSessionRequests')
      .where(
        'status',
        whereIn: const [
          'pending_teacher',
          'awaiting_student_confirmation',
        ],
      )
      .limit(limit)
      .snapshots()
      .map((snapshot) {
        final requests = snapshot.docs
            .map((doc) => <String, dynamic>{
                  'id': doc.id,
                  ...doc.data(),
                  '_adminRowKind': 'trialRequest',
                })
            .toList();
        requests.sort((a, b) => _compareTs(
              b['proposedStart'] ?? b['createdAt'],
              a['proposedStart'] ?? a['createdAt'],
            ));
        return requests;
      });
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
  final callable =
      FirebaseFunctions.instance.httpsCallable('getBroadcastAudienceCount');
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
/// Uses the low-cost rolling projection only after it contains a full window.
/// Until then, the legacy query preserves historical accuracy for existing
/// installations instead of displaying a partially populated leaderboard.
final topTeachersProvider = FutureProvider.autoDispose
    .family<List<TeacherRanking>, int>((ref, days) async {
  final safeDays = switch (days) {
    90 => 90,
    365 => 365,
    _ => 30,
  };
  final countField = 'rolling${safeDays}dCompletedSessions';
  final revenueField = 'rolling${safeDays}dRevenueEgp';
  final insights = await FirebaseFirestore.instance
      .collection('systemConfig')
      .doc('adminInsights')
      .get();
  final projectionStart = insights.data()?['projectionStartedAt'];
  final projectionAgeDays = projectionStart is Timestamp
      ? DateTime.now().difference(projectionStart.toDate()).inDays
      : 0;

  if (projectionAgeDays >= safeDays) {
    final snap = await FirebaseFirestore.instance
        .collection('adminTeacherAnalytics')
        .orderBy(countField, descending: true)
        .limit(10)
        .get();

    return snap.docs
        .map((doc) {
          final data = doc.data();
          return TeacherRanking(
            mohaffezId: doc.id,
            name: data['teacherName'] as String? ?? doc.id,
            sessionCount: (data[countField] as num?)?.toInt() ?? 0,
            revenue: (data[revenueField] as num?)?.toDouble() ?? 0,
          );
        })
        .where((ranking) => ranking.sessionCount > 0)
        .toList();
  }

  final cutoff = DateTime.now().subtract(Duration(days: safeDays));
  final sessions = await FirebaseFirestore.instance
      .collection('hafizSessions')
      .where('status', isEqualTo: 'completed')
      .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .get();
  final counts = <String, int>{};
  final revenue = <String, double>{};
  final names = <String, String>{};

  for (final doc in sessions.docs) {
    final data = doc.data();
    final teacherId = data['mohaffezId'] as String?;
    if (teacherId == null || teacherId.isEmpty) continue;
    counts[teacherId] = (counts[teacherId] ?? 0) + 1;
    revenue[teacherId] = (revenue[teacherId] ?? 0) +
        ((data['sessionPrice'] as num?)?.toDouble() ?? 0);
    final teacherName = data['mohaffezName'] as String?;
    if (teacherName != null && teacherName.isNotEmpty) {
      names[teacherId] = teacherName;
    }
  }

  final rankings = counts.entries
      .map((entry) => TeacherRanking(
            mohaffezId: entry.key,
            name: names[entry.key] ?? entry.key,
            sessionCount: entry.value,
            revenue: revenue[entry.key] ?? 0,
          ))
      .toList()
    ..sort((left, right) {
      final byCount = right.sessionCount.compareTo(left.sessionCount);
      return byCount != 0 ? byCount : right.revenue.compareTo(left.revenue);
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

  Future<void> deleteUserData(String userId, String reason) async {
    await _callFunction('deleteUserAccount', {
      'userId': userId,
      'reason': reason,
    });
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _callFunction('setUserRole', {
      'userId': userId,
      'newRole': newRole,
    });
  }

  Future<void> setTeacherFoundingBadge({
    required String teacherId,
    required bool enabled,
    String? reason,
  }) async {
    await _callFunction('setTeacherFoundingBadge', {
      'teacherId': teacherId,
      'enabled': enabled,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<void> updateAdminAccess({
    required String userId,
    required String adminRole,
    required Map<AdminPermission, bool> permissions,
  }) async {
    await _callFunction('updateAdminAccess', {
      'userId': userId,
      'adminRole': adminRole,
      'permissions': {
        for (final entry in permissions.entries) entry.key.key: entry.value,
      },
    });
  }

  Future<void> grantAdminAccessByEmail({
    required String email,
    required String adminRole,
    required Map<AdminPermission, bool> permissions,
  }) async {
    await _callFunction('setAdminClaim', {
      'targetEmail': email,
      'adminRole': adminRole,
      'permissions': {
        for (final entry in permissions.entries) entry.key.key: entry.value,
      },
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
