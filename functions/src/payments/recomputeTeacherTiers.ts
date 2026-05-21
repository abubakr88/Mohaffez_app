// Scheduled job: 1st and 15th of every month at 00:05 (Africa/Cairo).
// Roughly bi-weekly cadence — predictable dates, easier to communicate
// to teachers than "every other Sunday".
//
// For each teacher:
//   1. Sum sessionPrice of hafizSessions where mohaffezId == teacher
//      AND status == 'completed' AND isPaid == true AND completedAt within
//      the last 30 days.
//   2. Look up the matching tier in systemConfig.commissionTiers.
//   3. Write { commissionRate, commissionTier, tierStats } to the user doc.
//   4. Append a history entry under users/{teacherId}/commissionHistory.
//   5. If the tier changed since last run, send a notification (up = celebratory,
//      down = soft informational).
//
// Idempotent: re-running on the same window produces the same writes.

import * as functions from 'firebase-functions';
import admin, { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

interface TierConfig {
  id: string;
  labelAr: string;
  minRevenueEgp: number;
  rate: number;
  badge?: string;
}

const DEFAULT_TIERS: TierConfig[] = [
  { id: 'starter', labelAr: 'البداية', minRevenueEgp: 0, rate: 0.15, badge: '🌱' },
  { id: 'active', labelAr: 'نشط', minRevenueEgp: 2000, rate: 0.12, badge: '⭐' },
  { id: 'distinguished', labelAr: 'متميز', minRevenueEgp: 5000, rate: 0.08, badge: '🏆' },
  { id: 'elite', labelAr: 'نخبة', minRevenueEgp: 10000, rate: 0.05, badge: '💎' },
];

const ROLLING_WINDOW_DAYS = 30;
const TEACHER_PAGE_SIZE = 200;

async function loadTiers(): Promise<TierConfig[]> {
  const snap = await db.collection('systemConfig').doc('global').get();
  const raw = snap.data()?.commissionTiers as unknown[] | undefined;
  if (!raw || !Array.isArray(raw) || raw.length === 0) return DEFAULT_TIERS;
  const tiers = raw
    .map((entry) => {
      const e = entry as Record<string, unknown>;
      return {
        id: String(e.id ?? ''),
        labelAr: String(e.labelAr ?? ''),
        minRevenueEgp: Number(e.minRevenueEgp ?? 0),
        rate: Number(e.rate ?? 0.10),
        badge: e.badge ? String(e.badge) : undefined,
      } as TierConfig;
    })
    .filter((t) => t.id.length > 0);
  if (tiers.length === 0) return DEFAULT_TIERS;
  tiers.sort((a, b) => a.minRevenueEgp - b.minRevenueEgp);
  return tiers;
}

function pickTier(tiers: TierConfig[], revenueEgp: number): TierConfig {
  let current = tiers[0];
  for (const t of tiers) {
    if (revenueEgp >= t.minRevenueEgp) current = t;
  }
  return current;
}

interface TeacherStats {
  totalRevenueEgp: number;
  sessionCount: number;
  /// On-time + late together — used for display only ("منها X متأخرة").
  totalSessionsIncludingLate: number;
  lateSessionsCount: number;
}

async function statsForTeacher(
  teacherId: string,
  windowStart: Date,
): Promise<TeacherStats> {
  // We deliberately don't filter on isPaid in the Firestore query to keep
  // the index simple — payment-cleared check happens in-memory below.
  const snap = await db
    .collection('hafizSessions')
    .where('mohaffezId', '==', teacherId)
    .where('status', '==', 'completed')
    .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(windowStart))
    .get();

  let totalRevenueEgp = 0;
  let sessionCount = 0;
  let totalSessionsIncludingLate = 0;
  let lateSessionsCount = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.isPaid !== true) continue;
    const price =
      typeof data.sessionPrice === 'number'
        ? data.sessionPrice
        : Number(data.sessionPrice ?? 0);
    if (!isFinite(price) || price <= 0) continue;

    totalSessionsIncludingLate += 1;
    const isLate = data.startedLate === true;
    if (isLate) {
      // Counted toward "displayed total" but excluded from tier math —
      // the teacher still gets paid for the session, just no progression.
      lateSessionsCount += 1;
      continue;
    }
    totalRevenueEgp += price;
    sessionCount += 1;
  }
  return {
    totalRevenueEgp,
    sessionCount,
    totalSessionsIncludingLate,
    lateSessionsCount,
  };
}

async function maybeNotifyTierChange(
  teacherId: string,
  previousTierId: string | undefined,
  next: TierConfig,
): Promise<void> {
  if (!previousTierId || previousTierId === next.id) return;
  const isPromotion = previousTierId !== next.id; // up vs down handled by tier order
  // We don't track direction explicitly; copy is celebratory for any change
  // up, neutral for changes down. Determine direction by re-loading tiers.
  // (Cheap: tiers are <10 items.)
  const tiers = await loadTiers();
  const oldIdx = tiers.findIndex((t) => t.id === previousTierId);
  const newIdx = tiers.findIndex((t) => t.id === next.id);
  const isUp = newIdx > oldIdx;

  const title = isUp ? 'تهانينا — انتقلت إلى شريحة جديدة!' : 'تحديث شريحة العمولة';
  const body = isUp
    ? `${next.badge ?? ''} انتقلت إلى شريحة ${next.labelAr}. عمولة المنصة الآن ${(next.rate * 100).toFixed(0)}%`
    : `شريحتك الحالية: ${next.labelAr} (عمولة ${(next.rate * 100).toFixed(0)}%). أكمل المزيد من الحلقات للعودة لشريحة أعلى.`;

  try {
    await createAndSendNotification({
      userId: teacherId,
      title,
      body,
      type: isPromotion ? 'tier_change' : 'tier_change',
      data: { tierId: next.id, rate: String(next.rate) },
    });
  } catch (err) {
    functions.logger.warn('tier-change notification failed', { teacherId, err });
  }
}

async function recomputeForTeacher(
  teacherId: string,
  tiers: TierConfig[],
  now: Date,
  windowStart: Date,
  nextEval: Date,
): Promise<void> {
  const stats = await statsForTeacher(teacherId, windowStart);
  const tier = pickTier(tiers, stats.totalRevenueEgp);

  const userRef = db.collection('users').doc(teacherId);
  const userSnap = await userRef.get();
  const previousTierId = userSnap.data()?.commissionTier as string | undefined;

  const update = {
    commissionRate: tier.rate,
    commissionTier: tier.id,
    tierStats: {
      last30dRevenueEgp: stats.totalRevenueEgp,
      // sessionsLast30d intentionally counts ONLY on-time sessions —
      // matches the number used for tier math and motivation copy.
      sessionsLast30d: stats.sessionCount,
      totalSessionsLast30d: stats.totalSessionsIncludingLate,
      lateSessionsLast30d: stats.lateSessionsCount,
      evaluatedAt: admin.firestore.Timestamp.fromDate(now),
      nextEvalAt: admin.firestore.Timestamp.fromDate(nextEval),
      windowStart: admin.firestore.Timestamp.fromDate(windowStart),
    },
  };

  await userRef.set(update, { merge: true });

  // History entry keyed by ISO date so re-runs on the same day overwrite,
  // not duplicate.
  const historyId = now.toISOString().slice(0, 10);
  await userRef
    .collection('commissionHistory')
    .doc(historyId)
    .set(
      {
        tier: tier.id,
        rate: tier.rate,
        revenueEgp: stats.totalRevenueEgp,
        sessions: stats.sessionCount,
        computedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await maybeNotifyTierChange(teacherId, previousTierId, tier);
}

async function runRecompute(): Promise<{ teachersProcessed: number }> {
  const tiers = await loadTiers();
  const now = new Date();
  const windowStart = new Date(now.getTime() - ROLLING_WINDOW_DAYS * 86_400_000);
  const nextEval = new Date(now.getTime() + 14 * 86_400_000);

  let teachersProcessed = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  while (true) {
    let query = db
      .collection('users')
      .where('role', '==', 'mohaffez')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(TEACHER_PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const page = await query.get();
    if (page.empty) break;

    for (const doc of page.docs) {
      try {
        await recomputeForTeacher(doc.id, tiers, now, windowStart, nextEval);
        teachersProcessed += 1;
      } catch (err) {
        functions.logger.error('tier recompute failed for teacher', {
          teacherId: doc.id,
          err,
        });
      }
    }

    if (page.size < TEACHER_PAGE_SIZE) break;
    lastDoc = page.docs[page.docs.length - 1];
  }

  return { teachersProcessed };
}

// Scheduled — bi-weekly: 1st and 15th of each month at 00:05 Africa/Cairo.
export const recomputeTeacherTiers = functions
  .region('us-central1')
  .pubsub.schedule('5 0 1,15 * *')
  .timeZone('Africa/Cairo')
  .onRun(async () => {
    const result = await runRecompute();
    functions.logger.info('recomputeTeacherTiers complete', result);
    return null;
  });

// Callable — lets admin force a recompute from the panel without waiting
// a week. Restricted to admin custom-claim.
export const recomputeTeacherTiersNow = functions
  .region('us-central1')
  .https.onCall(async (_data, context) => {
    if (context.auth?.token?.admin !== true) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Admin only.',
      );
    }
    const result = await runRecompute();
    return { ok: true, ...result };
  });
