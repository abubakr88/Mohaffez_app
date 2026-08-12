// src/admin/metrics.ts
//
// Admin platform-wide statistics. Two surfaces:
//   • getAdminMetrics — admin-only callable that returns fresh metrics.
//   • refreshAdminMetrics — scheduled hourly job that writes the same
//     aggregate to systemConfig/adminMetrics so the web admin can read
//     it directly without an extra round-trip.

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { requireAdminAccess } from '../utils/adminPermissions';

interface AdminMetrics {
  generatedAt: FirebaseFirestore.FieldValue;
  revenue: {
    thisMonth: number;
    lastMonth: number;
    ytd: number;
    last12Months: { month: string; total: number }[]; // 'YYYY-MM'
    byMethod: Record<string, number>;     // current month
    byType: Record<string, number>;        // current month: single | bundle | subscription
  };
  commissions: {
    outstanding: number;
    overdue: number;
    pendingVerification: number;
    paidThisMonth: number;
    paidLastMonth: number;
  };
  sessions: {
    completedThisMonth: number;
    completedLastMonth: number;
    cancelledThisMonth: number;
    pendingNow: number;
  };
  subscriptions: {
    active: number;
    cancelledThisMonth: number;
  };
  users: {
    totalStudents: number;
    totalTeachers: number;
    totalAdmins: number;
    activeTeachers30d: number;
    newSignupsThisMonth: number;
    pendingTeacherApprovals: number;
  };
}

function startOfMonth(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), 1);
}

function startOfYear(d: Date): Date {
  return new Date(d.getFullYear(), 0, 1);
}

function monthKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

async function computeAdminMetrics(): Promise<Omit<AdminMetrics, 'generatedAt'>> {
  const now = new Date();
  const thisMonthStart = startOfMonth(now);
  const lastMonthStart = startOfMonth(
    new Date(now.getFullYear(), now.getMonth() - 1, 1)
  );
  const ytdStart = startOfYear(now);
  const twelveMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 11, 1);
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  // ── PAYMENTS — completed only ──────────────────────────────────────────
  const completedPaymentsSnap = await db
    .collection('payments')
    .where('status', '==', 'completed')
    .where('paidAt', '>=', admin.firestore.Timestamp.fromDate(twelveMonthsAgo))
    .get();

  let revThisMonth = 0;
  let revLastMonth = 0;
  let revYtd = 0;
  const last12: Record<string, number> = {};
  const byMethod: Record<string, number> = {};
  const byType: Record<string, number> = {};

  for (const doc of completedPaymentsSnap.docs) {
    const d = doc.data();
    const ts = d.paidAt as admin.firestore.Timestamp | undefined;
    if (!ts) continue;
    const paidAt = ts.toDate();
    const amount = (d.amount as number) ?? 0;
    if (amount <= 0) continue;

    const mk = monthKey(paidAt);
    last12[mk] = (last12[mk] ?? 0) + amount;

    if (paidAt >= ytdStart) revYtd += amount;
    if (paidAt >= thisMonthStart) {
      revThisMonth += amount;
      const method = (d.method as string) ?? (d.paymentMethod as string) ?? 'unknown';
      const type = (d.type as string) ?? (d.planType as string) ?? 'single';
      byMethod[method] = (byMethod[method] ?? 0) + amount;
      byType[type] = (byType[type] ?? 0) + amount;
    } else if (paidAt >= lastMonthStart) {
      revLastMonth += amount;
    }
  }

  const last12Months: { month: string; total: number }[] = [];
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const k = monthKey(d);
    last12Months.push({ month: k, total: last12[k] ?? 0 });
  }

  // ── COMMISSIONS ────────────────────────────────────────────────────────
  // Legacy weeklyCommissionSummaries removed; commission now lives in the
  // wallet ledger (see Phase B). These dashboard fields are stubbed at 0
  // until the metrics are migrated to read from `walletTransactionGroups`
  // filtered by type ∈ {direct_session_commission, cycle_settlement}.
  // TODO: migrate to ledger-based aggregation.
  const outstanding = 0;
  const overdue = 0;
  const pendingVerif = 0;
  const paidThisMonth = 0;
  const paidLastMonth = 0;

  // ── SESSIONS ────────────────────────────────────────────────────────────
  const [
    completedThisMonthAgg,
    completedLastMonthAgg,
    cancelledThisMonthAgg,
    pendingSessionsAgg,
    pendingTrialRequestsAgg,
  ] =
    await Promise.all([
      db
        .collection('hafizSessions')
        .where('status', '==', 'completed')
        .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(thisMonthStart))
        .count()
        .get(),
      db
        .collection('hafizSessions')
        .where('status', '==', 'completed')
        .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(lastMonthStart))
        .where('completedAt', '<', admin.firestore.Timestamp.fromDate(thisMonthStart))
        .count()
        .get(),
      db
        .collection('hafizSessions')
        .where('status', '==', 'cancelled')
        .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(thisMonthStart))
        .count()
        .get(),
      db
        .collection('hafizSessions')
        .where('status', '==', 'pending')
        .count()
        .get(),
      db
        .collection('trialSessionRequests')
        .where('status', 'in', [
          'pending_teacher',
          'awaiting_student_confirmation',
        ])
        .count()
        .get(),
    ]);

  // ── SUBSCRIPTIONS ───────────────────────────────────────────────────────
  const [activeSubsAgg, cancelledSubsAgg] = await Promise.all([
    db.collection('subscriptions').where('status', '==', 'active').count().get(),
    db
      .collection('subscriptions')
      .where('status', '==', 'cancelled')
      .where('cancelledAt', '>=', admin.firestore.Timestamp.fromDate(thisMonthStart))
      .count()
      .get(),
  ]);

  // ── USERS ───────────────────────────────────────────────────────────────
  const [studentsAgg, teachersAgg, adminsAgg, newSignupsAgg, pendingApprovalsAgg] =
    await Promise.all([
      db.collection('users').where('role', '==', 'student').count().get(),
      db.collection('users').where('role', '==', 'mohaffez').count().get(),
      db.collection('users').where('role', '==', 'admin').count().get(),
      db
        .collection('users')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(thisMonthStart))
        .count()
        .get(),
      db
        .collection('users')
        .where('role', '==', 'mohaffez')
        .where('status', '==', 'pending_approval')
        .count()
        .get(),
    ]);

  // Active teachers = mohaffezId on a session completed in last 30d (distinct).
  const activeTeacherSessions = await db
    .collection('hafizSessions')
    .where('status', '==', 'completed')
    .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
    .select('mohaffezId')
    .get();
  const activeTeacherIds = new Set<string>();
  for (const doc of activeTeacherSessions.docs) {
    const id = doc.get('mohaffezId') as string | undefined;
    if (id) activeTeacherIds.add(id);
  }

  return {
    revenue: {
      thisMonth: revThisMonth,
      lastMonth: revLastMonth,
      ytd: revYtd,
      last12Months,
      byMethod,
      byType,
    },
    commissions: {
      outstanding,
      overdue,
      pendingVerification: pendingVerif,
      paidThisMonth,
      paidLastMonth,
    },
    sessions: {
      completedThisMonth: completedThisMonthAgg.data().count,
      completedLastMonth: completedLastMonthAgg.data().count,
      cancelledThisMonth: cancelledThisMonthAgg.data().count,
      pendingNow:
        pendingSessionsAgg.data().count + pendingTrialRequestsAgg.data().count,
    },
    subscriptions: {
      active: activeSubsAgg.data().count,
      cancelledThisMonth: cancelledSubsAgg.data().count,
    },
    users: {
      totalStudents: studentsAgg.data().count,
      totalTeachers: teachersAgg.data().count,
      totalAdmins: adminsAgg.data().count,
      activeTeachers30d: activeTeacherIds.size,
      newSignupsThisMonth: newSignupsAgg.data().count,
      pendingTeacherApprovals: pendingApprovalsAgg.data().count,
    },
  };
}

async function writeMetricsCache(
  metrics: Omit<AdminMetrics, 'generatedAt'>
): Promise<void> {
  await db
    .collection('systemConfig')
    .doc('adminMetrics')
    .set(
      {
        ...metrics,
        generatedAt: FieldValue.serverTimestamp(),
      },
      { merge: false }
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: admin pulls fresh metrics on demand
// ─────────────────────────────────────────────────────────────────────────────

export const getAdminMetrics = functions.https.onCall(async (_data, context) => {
  await requireAdminAccess(context);

  const metrics = await computeAdminMetrics();
  await writeMetricsCache(metrics).catch((err) =>
    functions.logger.warn('Failed to cache admin metrics', { err })
  );
  return metrics;
});

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: refresh the legacy full-scan cache once per day. The incremental
// adminInsights projection refreshes hourly and is the preferred dashboard
// source. Keeping this daily snapshot preserves historical compatibility while
// avoiding 24 repeated scans of payments and sessions every day.
// ─────────────────────────────────────────────────────────────────────────────

export const refreshAdminMetrics = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('Africa/Cairo')
  .onRun(async () => {
    try {
      const metrics = await computeAdminMetrics();
      await writeMetricsCache(metrics);
      functions.logger.info('Admin metrics refreshed');
    } catch (err) {
      functions.logger.error('Failed to refresh admin metrics', { err });
    }
    return null;
  });
