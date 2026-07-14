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

class AdminInsights {
  final DateTime? generatedAt;
  final String period;
  final GrowthInsights growth;
  final OperationsInsights operations;
  final FinanceInsights finance;
  final int activeTeachers30d;
  final List<MonthlyInsight> last12Months;

  const AdminInsights({
    required this.generatedAt,
    required this.period,
    required this.growth,
    required this.operations,
    required this.finance,
    required this.activeTeachers30d,
    required this.last12Months,
  });

  factory AdminInsights.empty() => AdminInsights(
        generatedAt: null,
        period: '',
        growth: GrowthInsights.empty(),
        operations: OperationsInsights.empty(),
        finance: FinanceInsights.empty(),
        activeTeachers30d: 0,
        last12Months: const [],
      );

  factory AdminInsights.fromMap(Map<String, dynamic> data) => AdminInsights(
        generatedAt: _toDateTime(data['generatedAt']),
        period: data['period'] as String? ?? '',
        growth: GrowthInsights.fromMap(_asMap(data['growth'])),
        operations: OperationsInsights.fromMap(_asMap(data['operations'])),
        finance: FinanceInsights.fromMap(_asMap(data['finance'])),
        activeTeachers30d: _toInt(_asMap(data['teachers'])['active30d']),
        last12Months: (data['last12Months'] as List? ?? const [])
            .map((item) => MonthlyInsight.fromMap(_asMap(item)))
            .toList(),
      );
}

class GrowthInsights {
  final int signups;
  final Map<String, int> signupsByRole;
  final int requestsCreated;
  final int requestsAccepted;
  final int paymentsCompleted;
  final int sessionsCompleted;
  final double requestAcceptanceRate;
  final double paymentConversionRate;
  final double sessionCompletionRate;

  const GrowthInsights({
    required this.signups,
    required this.signupsByRole,
    required this.requestsCreated,
    required this.requestsAccepted,
    required this.paymentsCompleted,
    required this.sessionsCompleted,
    required this.requestAcceptanceRate,
    required this.paymentConversionRate,
    required this.sessionCompletionRate,
  });

  factory GrowthInsights.empty() => const GrowthInsights(
        signups: 0,
        signupsByRole: {},
        requestsCreated: 0,
        requestsAccepted: 0,
        paymentsCompleted: 0,
        sessionsCompleted: 0,
        requestAcceptanceRate: 0,
        paymentConversionRate: 0,
        sessionCompletionRate: 0,
      );

  factory GrowthInsights.fromMap(Map<String, dynamic> data) => GrowthInsights(
        signups: _toInt(data['signups']),
        signupsByRole: _intMap(data['signupsByRole']),
        requestsCreated: _toInt(data['requestsCreated']),
        requestsAccepted: _toInt(data['requestsAccepted']),
        paymentsCompleted: _toInt(data['paymentsCompleted']),
        sessionsCompleted: _toInt(data['sessionsCompleted']),
        requestAcceptanceRate: _toDouble(data['requestAcceptanceRate']),
        paymentConversionRate: _toDouble(data['paymentConversionRate']),
        sessionCompletionRate: _toDouble(data['sessionCompletionRate']),
      );
}

class OperationsInsights {
  final int failedOperations;
  final int unresolvedAlerts;
  final int pendingPayments;
  final int pendingDirectPayments;
  final int failedPaymentsThisMonth;
  final int cancelledSessionsThisMonth;
  final int studentNoShowsThisMonth;
  final int teacherNoShowsThisMonth;

  const OperationsInsights({
    required this.failedOperations,
    required this.unresolvedAlerts,
    required this.pendingPayments,
    required this.pendingDirectPayments,
    required this.failedPaymentsThisMonth,
    required this.cancelledSessionsThisMonth,
    required this.studentNoShowsThisMonth,
    required this.teacherNoShowsThisMonth,
  });

  factory OperationsInsights.empty() => const OperationsInsights(
        failedOperations: 0,
        unresolvedAlerts: 0,
        pendingPayments: 0,
        pendingDirectPayments: 0,
        failedPaymentsThisMonth: 0,
        cancelledSessionsThisMonth: 0,
        studentNoShowsThisMonth: 0,
        teacherNoShowsThisMonth: 0,
      );

  factory OperationsInsights.fromMap(Map<String, dynamic> data) =>
      OperationsInsights(
        failedOperations: _toInt(data['failedOperations']),
        unresolvedAlerts: _toInt(data['unresolvedAlerts']),
        pendingPayments: _toInt(data['pendingPayments']),
        pendingDirectPayments: _toInt(data['pendingDirectPayments']),
        failedPaymentsThisMonth: _toInt(data['failedPaymentsThisMonth']),
        cancelledSessionsThisMonth: _toInt(data['cancelledSessionsThisMonth']),
        studentNoShowsThisMonth: _toInt(data['studentNoShowsThisMonth']),
        teacherNoShowsThisMonth: _toInt(data['teacherNoShowsThisMonth']),
      );
}

class FinanceInsights {
  final double grossRevenueEgp;
  final double netRevenueEgp;
  final double refundedAmountEgp;
  final double commissionAccruedEgp;
  final double commissionReversedEgp;
  final double walletTopUpsEgp;
  final Map<String, double> revenueByMethod;
  final Map<String, double> revenueByPlanType;

  const FinanceInsights({
    required this.grossRevenueEgp,
    required this.netRevenueEgp,
    required this.refundedAmountEgp,
    required this.commissionAccruedEgp,
    required this.commissionReversedEgp,
    required this.walletTopUpsEgp,
    required this.revenueByMethod,
    required this.revenueByPlanType,
  });

  factory FinanceInsights.empty() => const FinanceInsights(
        grossRevenueEgp: 0,
        netRevenueEgp: 0,
        refundedAmountEgp: 0,
        commissionAccruedEgp: 0,
        commissionReversedEgp: 0,
        walletTopUpsEgp: 0,
        revenueByMethod: {},
        revenueByPlanType: {},
      );

  factory FinanceInsights.fromMap(Map<String, dynamic> data) => FinanceInsights(
        grossRevenueEgp: _toDouble(data['grossRevenueEgp']),
        netRevenueEgp: _toDouble(data['netRevenueEgp']),
        refundedAmountEgp: _toDouble(data['refundedAmountEgp']),
        commissionAccruedEgp: _toDouble(data['commissionAccruedEgp']),
        commissionReversedEgp: _toDouble(data['commissionReversedEgp']),
        walletTopUpsEgp: _toDouble(data['walletTopUpsEgp']),
        revenueByMethod: _doubleMap(data['revenueByMethod']),
        revenueByPlanType: _doubleMap(data['revenueByPlanType']),
      );
}

class MonthlyInsight {
  final String month;
  final double grossRevenueEgp;
  final double netRevenueEgp;
  final int completedSessions;
  final int signups;

  const MonthlyInsight({
    required this.month,
    required this.grossRevenueEgp,
    required this.netRevenueEgp,
    required this.completedSessions,
    required this.signups,
  });

  factory MonthlyInsight.fromMap(Map<String, dynamic> data) => MonthlyInsight(
        month: data['month'] as String? ?? '',
        grossRevenueEgp: _toDouble(data['grossRevenueEgp']),
        netRevenueEgp: _toDouble(data['netRevenueEgp']),
        completedSessions: _toInt(data['completedSessions']),
        signups: _toInt(data['signups']),
      );
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

Map<String, int> _intMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), _toInt(item)));
  }
  return <String, int>{};
}

DateTime? _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
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

final adminInsightsStreamProvider =
    StreamProvider.autoDispose<AdminInsights>((ref) {
  return FirebaseFirestore.instance
      .collection('systemConfig')
      .doc('adminInsights')
      .snapshots()
      .map((snap) => snap.exists
          ? AdminInsights.fromMap(snap.data()!)
          : AdminInsights.empty());
});

/// Triggers the getAdminMetrics CF to recompute on demand. Returns the
/// fresh metrics; the cron also writes them to Firestore so the stream
/// will re-emit.
Future<AdminMetrics> refreshAdminMetricsNow() async {
  final result =
      await FirebaseFunctions.instance.httpsCallable('getAdminMetrics').call();
  return AdminMetrics.fromMap(_asMap(result.data));
}

Future<AdminInsights> refreshAdminInsightsNow() async {
  final result =
      await FirebaseFunctions.instance.httpsCallable('getAdminInsights').call();
  return AdminInsights.fromMap(_asMap(result.data));
}
