import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminMetrics {
  final DateTime? generatedAt;
  final RevenueMetrics revenue;
  final CommissionMetrics commissions;
  final SessionMetrics sessions;
  final SubscriptionMetrics subscriptions;
  final UserMetrics users;

  const AdminMetrics({
    required this.generatedAt,
    required this.revenue,
    required this.commissions,
    required this.sessions,
    required this.subscriptions,
    required this.users,
  });

  factory AdminMetrics.empty() => AdminMetrics(
        generatedAt: null,
        revenue: RevenueMetrics.empty(),
        commissions: CommissionMetrics.empty(),
        sessions: SessionMetrics.empty(),
        subscriptions: SubscriptionMetrics.empty(),
        users: UserMetrics.empty(),
      );

  factory AdminMetrics.fromMap(Map<String, dynamic> d) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return AdminMetrics(
      generatedAt: ts(d['generatedAt']),
      revenue: RevenueMetrics.fromMap(_asMap(d['revenue'])),
      commissions: CommissionMetrics.fromMap(_asMap(d['commissions'])),
      sessions: SessionMetrics.fromMap(_asMap(d['sessions'])),
      subscriptions: SubscriptionMetrics.fromMap(_asMap(d['subscriptions'])),
      users: UserMetrics.fromMap(_asMap(d['users'])),
    );
  }
}

class RevenueMetrics {
  final double thisMonth;
  final double lastMonth;
  final double ytd;
  final List<MonthlyRevenue> last12Months;
  final Map<String, double> byMethod;
  final Map<String, double> byType;

  const RevenueMetrics({
    required this.thisMonth,
    required this.lastMonth,
    required this.ytd,
    required this.last12Months,
    required this.byMethod,
    required this.byType,
  });

  factory RevenueMetrics.empty() => const RevenueMetrics(
        thisMonth: 0,
        lastMonth: 0,
        ytd: 0,
        last12Months: [],
        byMethod: {},
        byType: {},
      );

  factory RevenueMetrics.fromMap(Map<String, dynamic> d) => RevenueMetrics(
        thisMonth: _toDouble(d['thisMonth']),
        lastMonth: _toDouble(d['lastMonth']),
        ytd: _toDouble(d['ytd']),
        last12Months: (d['last12Months'] as List? ?? [])
            .map((m) => MonthlyRevenue.fromMap(_asMap(m)))
            .toList(),
        byMethod: _doubleMap(d['byMethod']),
        byType: _doubleMap(d['byType']),
      );
}

class MonthlyRevenue {
  final String month; // 'YYYY-MM'
  final double total;

  const MonthlyRevenue({required this.month, required this.total});

  factory MonthlyRevenue.fromMap(Map<String, dynamic> d) => MonthlyRevenue(
        month: (d['month'] as String?) ?? '',
        total: _toDouble(d['total']),
      );
}

class CommissionMetrics {
  final double outstanding;
  final double overdue;
  final double pendingVerification;
  final double paidThisMonth;
  final double paidLastMonth;

  const CommissionMetrics({
    required this.outstanding,
    required this.overdue,
    required this.pendingVerification,
    required this.paidThisMonth,
    required this.paidLastMonth,
  });

  factory CommissionMetrics.empty() => const CommissionMetrics(
        outstanding: 0,
        overdue: 0,
        pendingVerification: 0,
        paidThisMonth: 0,
        paidLastMonth: 0,
      );

  factory CommissionMetrics.fromMap(Map<String, dynamic> d) =>
      CommissionMetrics(
        outstanding: _toDouble(d['outstanding']),
        overdue: _toDouble(d['overdue']),
        pendingVerification: _toDouble(d['pendingVerification']),
        paidThisMonth: _toDouble(d['paidThisMonth']),
        paidLastMonth: _toDouble(d['paidLastMonth']),
      );
}

class SessionMetrics {
  final int completedThisMonth;
  final int completedLastMonth;
  final int cancelledThisMonth;
  final int pendingNow;

  const SessionMetrics({
    required this.completedThisMonth,
    required this.completedLastMonth,
    required this.cancelledThisMonth,
    required this.pendingNow,
  });

  factory SessionMetrics.empty() => const SessionMetrics(
        completedThisMonth: 0,
        completedLastMonth: 0,
        cancelledThisMonth: 0,
        pendingNow: 0,
      );

  factory SessionMetrics.fromMap(Map<String, dynamic> d) => SessionMetrics(
        completedThisMonth: _toInt(d['completedThisMonth']),
        completedLastMonth: _toInt(d['completedLastMonth']),
        cancelledThisMonth: _toInt(d['cancelledThisMonth']),
        pendingNow: _toInt(d['pendingNow']),
      );
}

class SubscriptionMetrics {
  final int active;
  final int cancelledThisMonth;

  const SubscriptionMetrics({
    required this.active,
    required this.cancelledThisMonth,
  });

  factory SubscriptionMetrics.empty() =>
      const SubscriptionMetrics(active: 0, cancelledThisMonth: 0);

  factory SubscriptionMetrics.fromMap(Map<String, dynamic> d) =>
      SubscriptionMetrics(
        active: _toInt(d['active']),
        cancelledThisMonth: _toInt(d['cancelledThisMonth']),
      );
}

class UserMetrics {
  final int totalStudents;
  final int totalTeachers;
  final int totalAdmins;
  final int activeTeachers30d;
  final int newSignupsThisMonth;
  final int pendingTeacherApprovals;

  const UserMetrics({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalAdmins,
    required this.activeTeachers30d,
    required this.newSignupsThisMonth,
    required this.pendingTeacherApprovals,
  });

  factory UserMetrics.empty() => const UserMetrics(
        totalStudents: 0,
        totalTeachers: 0,
        totalAdmins: 0,
        activeTeachers30d: 0,
        newSignupsThisMonth: 0,
        pendingTeacherApprovals: 0,
      );

  factory UserMetrics.fromMap(Map<String, dynamic> d) => UserMetrics(
        totalStudents: _toInt(d['totalStudents']),
        totalTeachers: _toInt(d['totalTeachers']),
        totalAdmins: _toInt(d['totalAdmins']),
        activeTeachers30d: _toInt(d['activeTeachers30d']),
        newSignupsThisMonth: _toInt(d['newSignupsThisMonth']),
        pendingTeacherApprovals: _toInt(d['pendingTeacherApprovals']),
      );
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return 0.0;
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  return 0;
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

Map<String, double> _doubleMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), _toDouble(val)));
  }
  return <String, double>{};
}

/// Reads cached admin metrics doc from systemConfig/adminMetrics. Streams,
/// so updates from the hourly cron land instantly. Admin-only by rules.
final adminMetricsStreamProvider =
    StreamProvider.autoDispose<AdminMetrics>((ref) {
  return FirebaseFirestore.instance
      .collection('systemConfig')
      .doc('adminMetrics')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return AdminMetrics.empty();
    return AdminMetrics.fromMap(snap.data()!);
  });
});

/// Triggers the getAdminMetrics CF to recompute on demand. Returns the
/// fresh metrics; the cron also writes them to Firestore so the stream
/// will re-emit.
Future<AdminMetrics> refreshAdminMetricsNow() async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('getAdminMetrics')
      .call();
  return AdminMetrics.fromMap(_asMap(result.data));
}
