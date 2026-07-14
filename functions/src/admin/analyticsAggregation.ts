import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { db, FieldValue } from '../utils/admin';
import { requireAdminAccess } from '../utils/adminPermissions';
import {
  NumericTree,
  dateKey,
  mergeNumericTrees,
  monthKey,
  pendingDateKeys,
} from './analyticsCore';

const ANALYTICS_ROOTS = [
  'growth',
  'funnel',
  'payments',
  'sessions',
  'finance',
  'operations',
] as const;

function numericTree(value: unknown): NumericTree {
  if (value == null || typeof value !== 'object') return {};
  const result: NumericTree = {};
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (typeof nested === 'number' && Number.isFinite(nested)) {
      result[key] = nested;
    } else if (nested != null && typeof nested === 'object') {
      const child = numericTree(nested);
      if (Object.keys(child).length > 0) result[key] = child;
    }
  }
  return result;
}

function analyticsTree(data: Record<string, unknown>): NumericTree {
  const result: NumericTree = {};
  for (const root of ANALYTICS_ROOTS) {
    const tree = numericTree(data[root]);
    if (Object.keys(tree).length > 0) result[root] = tree;
  }
  return result;
}

function nestedNumber(data: NumericTree, path: string): number {
  let current: number | NumericTree | undefined = data;
  for (const part of path.split('.')) {
    if (current == null || typeof current === 'number') return 0;
    current = current[part];
  }
  return typeof current === 'number' ? current : 0;
}

function nestedMap(data: NumericTree, path: string): Record<string, number> {
  let current: number | NumericTree | undefined = data;
  for (const part of path.split('.')) {
    if (current == null || typeof current === 'number') return {};
    current = current[part];
  }
  if (current == null || typeof current === 'number') return {};
  const result: Record<string, number> = {};
  for (const [key, value] of Object.entries(current)) {
    if (typeof value === 'number') result[key] = value;
  }
  return result;
}

function addMonths(date: Date, months: number): Date {
  return new Date(date.getFullYear(), date.getMonth() + months, 1);
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function monthKeys(now: Date, count: number): string[] {
  const keys: string[] = [];
  for (let offset = count - 1; offset >= 0; offset--) {
    keys.push(monthKey(addMonths(now, -offset)));
  }
  return keys;
}

async function consolidateDay(day: string): Promise<NumericTree | null> {
  const shards = await db
    .collection('_adminAnalyticsDailyShards')
    .doc(day)
    .collection('shards')
    .get();
  if (shards.empty) return null;

  const totals: NumericTree = {};
  for (const shard of shards.docs) {
    mergeNumericTrees(totals, analyticsTree(shard.data()));
  }
  await db.collection('adminAnalyticsDaily').doc(day).set({
    dateKey: day,
    ...totals,
    generatedAt: FieldValue.serverTimestamp(),
  });
  return totals;
}

async function consolidateMonth(month: string): Promise<NumericTree> {
  const start = `${month}-01`;
  const [year, monthNumber] = month.split('-').map(Number);
  const end = monthKey(new Date(year, monthNumber, 1));
  const days = await db
    .collection('adminAnalyticsDaily')
    .orderBy(admin.firestore.FieldPath.documentId())
    .startAt(start)
    .endBefore(`${end}-01`)
    .get();

  const totals: NumericTree = {};
  for (const day of days.docs) {
    mergeNumericTrees(totals, analyticsTree(day.data()));
  }
  await db.collection('adminAnalyticsMonthly').doc(month).set({
    monthKey: month,
    ...totals,
    generatedAt: FieldValue.serverTimestamp(),
  });
  return totals;
}

async function countQuery(
  query: FirebaseFirestore.Query,
): Promise<number> {
  const result = await query.count().get();
  return result.data().count;
}

function ratio(numerator: number, denominator: number): number {
  return denominator <= 0 ? 0 : numerator / denominator;
}

async function buildInsights(
  now: Date,
  projectionStartedAt: admin.firestore.Timestamp,
): Promise<Record<string, unknown>> {
  const keys = monthKeys(now, 12);
  const monthDocs = await db.getAll(
    ...keys.map((key) => db.collection('adminAnalyticsMonthly').doc(key)),
  );
  const monthly = new Map<string, NumericTree>();
  for (let i = 0; i < keys.length; i++) {
    monthly.set(keys[i], analyticsTree(monthDocs[i].data() ?? {}));
  }

  const currentMonthKey = monthKey(now);
  const current = monthly.get(currentMonthKey) ?? {};
  const last12Months = keys.map((key) => ({
    month: key,
    grossRevenueEgp: nestedNumber(
      monthly.get(key) ?? {},
      'payments.grossRevenueEgp',
    ),
    netRevenueEgp: nestedNumber(
      monthly.get(key) ?? {},
      'payments.netRevenueEgp',
    ),
    completedSessions: nestedNumber(
      monthly.get(key) ?? {},
      'sessions.completed',
    ),
    signups: nestedNumber(monthly.get(key) ?? {}, 'growth.signups'),
  }));

  const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
    addDays(now, -30),
  );
  const pendingPaymentStatuses = ['pending', 'processing', 'pending_retry'];
  const [
    failedOperations,
    unresolvedAlerts,
    pendingPayments,
    pendingDirectPayments,
    activeTeachers30d,
  ] = await Promise.all([
    countQuery(
      db
        .collection('failedOperations')
        .where('status', 'in', ['pending-retry', 'pending', 'failed']),
    ),
    countQuery(db.collection('adminAlerts').where('resolved', '==', false)),
    countQuery(
      db.collection('payments').where('status', 'in', pendingPaymentStatuses),
    ),
    countQuery(
      db
        .collection('directPaymentRequests')
        .where('status', '==', 'pendingconfirmation'),
    ),
    countQuery(
      db
        .collection('adminTeacherAnalytics')
        .where('lastCompletedAt', '>=', thirtyDaysAgo),
    ),
  ]);

  const requests = nestedNumber(current, 'funnel.requestsCreated');
  const accepted = nestedNumber(current, 'funnel.requestsAccepted');
  const paid = nestedNumber(current, 'funnel.paymentsCompleted');
  const completed = nestedNumber(current, 'funnel.sessionsCompleted');

  return {
    version: 2,
    period: currentMonthKey,
    growth: {
      signups: nestedNumber(current, 'growth.signups'),
      signupsByRole: nestedMap(current, 'growth.signupsByRole'),
      requestsCreated: requests,
      requestsAccepted: accepted,
      paymentsCompleted: paid,
      sessionsCompleted: completed,
      requestAcceptanceRate: ratio(accepted, requests),
      paymentConversionRate: ratio(paid, accepted),
      sessionCompletionRate: ratio(completed, paid),
    },
    operations: {
      failedOperations,
      unresolvedAlerts,
      pendingPayments,
      pendingDirectPayments,
      failedPaymentsThisMonth: nestedNumber(current, 'payments.failed'),
      cancelledSessionsThisMonth: nestedNumber(current, 'sessions.cancelled'),
      studentNoShowsThisMonth: nestedNumber(current, 'sessions.studentNoShows'),
      teacherNoShowsThisMonth: nestedNumber(current, 'sessions.teacherNoShows'),
    },
    finance: {
      grossRevenueEgp: nestedNumber(current, 'payments.grossRevenueEgp'),
      netRevenueEgp: nestedNumber(current, 'payments.netRevenueEgp'),
      refundedAmountEgp: nestedNumber(current, 'payments.refundedAmountEgp'),
      commissionAccruedEgp: nestedNumber(
        current,
        'finance.commissionAccruedEgp',
      ),
      commissionReversedEgp: nestedNumber(
        current,
        'finance.commissionReversedEgp',
      ),
      walletTopUpsEgp: nestedNumber(current, 'finance.walletTopUpsEgp'),
      revenueByMethod: nestedMap(current, 'payments.revenueByMethod'),
      revenueByPlanType: nestedMap(current, 'payments.revenueByPlanType'),
    },
    teachers: { active30d: activeTeachers30d },
    last12Months,
    projectionStartedAt,
    generatedAt: FieldValue.serverTimestamp(),
  };
}

export async function refreshAdminAnalyticsCache(): Promise<void> {
  const now = new Date();
  const insightsRef = db.collection('systemConfig').doc('adminInsights');
  const existingInsights = await insightsRef.get();
  const existingProjectionStart = existingInsights.data()?.projectionStartedAt;
  const projectionStartedAt =
    existingProjectionStart instanceof admin.firestore.Timestamp
      ? existingProjectionStart
      : admin.firestore.Timestamp.fromDate(now);
  const today = dateKey(now);
  const yesterday = dateKey(addDays(now, -1));
  await Promise.all([consolidateDay(today), consolidateDay(yesterday)]);

  const currentMonth = monthKey(now);
  const previousMonth = monthKey(addMonths(now, -1));
  await Promise.all([
    consolidateMonth(currentMonth),
    consolidateMonth(previousMonth),
  ]);

  const insights = await buildInsights(now, projectionStartedAt);
  await insightsRef.set(insights);
}

export const getAdminInsights = functions.https.onCall(async (_data, context) => {
  await requireAdminAccess(context);
  await refreshAdminAnalyticsCache();
  const doc = await db.collection('systemConfig').doc('adminInsights').get();
  return doc.data() ?? {};
});

export const refreshAdminInsights = functions.pubsub
  .schedule('every 60 minutes')
  .timeZone('Africa/Cairo')
  .onRun(async () => {
    try {
      await refreshAdminAnalyticsCache();
      functions.logger.info('Admin analytics insights refreshed');
    } catch (error) {
      functions.logger.error('Failed to refresh admin analytics insights', {
        error,
      });
    }
    return null;
  });

export const rolloffTeacherAnalyticsWindows = functions.pubsub
  .schedule('15 2 * * *')
  .timeZone('Africa/Cairo')
  .onRun(async () => {
    const stateRef = db.collection('systemConfig').doc('adminAnalyticsRolloff');
    const state = await stateRef.get();
    const stateData = state.data() ?? {};
    const windows = [30, 90, 365] as const;
    const processed: Record<string, string> = {};

    for (const days of windows) {
      const throughDay = dateKey(addDays(new Date(), -days));
      const stateField = `lastProcessed${days}d`;
      const expiredDays = pendingDateKeys(
        stateData[stateField],
        throughDay,
      );
      if (expiredDays.length === 0) continue;

      for (const expiredDay of expiredDays) {
        const expired = await db
          .collection('adminTeacherDaily')
          .where('dateKey', '==', expiredDay)
          .get();
        for (let offset = 0; offset < expired.docs.length; offset += 100) {
          const chunk = expired.docs.slice(offset, offset + 100);
          await Promise.all(
            chunk.map((doc) =>
              db.runTransaction(async (tx) => {
                const current = await tx.get(doc.ref);
                const data = current.data();
                const marker = `rolledOff${days}d`;
                if (data == null || data[marker] === true) return;

                const teacherId = data.teacherId as string | undefined;
                if (!teacherId) {
                  tx.update(doc.ref, { [marker]: true });
                  return;
                }
                const completed =
                  typeof data.completedSessions === 'number'
                    ? data.completedSessions
                    : 0;
                const revenue =
                  typeof data.sessionRevenueEgp === 'number'
                    ? data.sessionRevenueEgp
                    : 0;
                tx.set(
                  db.collection('adminTeacherAnalytics').doc(teacherId),
                  {
                    [`rolling${days}dCompletedSessions`]:
                      FieldValue.increment(-completed),
                    [`rolling${days}dRevenueEgp`]:
                      FieldValue.increment(-revenue),
                    rollingWindowUpdatedAt: FieldValue.serverTimestamp(),
                  },
                  { merge: true },
                );
                tx.update(doc.ref, {
                  [marker]: true,
                  [`${marker}At`]: FieldValue.serverTimestamp(),
                });
              }),
            ),
          );
        }
      }
      processed[stateField] = expiredDays[expiredDays.length - 1];
    }

    if (Object.keys(processed).length === 0) return null;
    await stateRef.set(
      {
        ...processed,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return null;
  });
