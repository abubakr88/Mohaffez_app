// Scheduled job: 1st and 15th of every month at 00:05 (Africa/Cairo).
// Roughly bi-weekly cadence — predictable dates, easier to communicate
// to teachers than "every other Sunday".
//
// For each teacher:
//   1. Count completed, paid, on-time hafizSessions within the last 14 days.
//   2. Look up the matching tier in systemConfig.commissionTiers (by session count).
//   3. Write { commissionRate, commissionTier, tierStats } to the user doc.
//   4. Append a history entry under users/{teacherId}/commissionHistory.
//   5. If the tier changed since last run, send a notification (up = celebratory,
//      down = soft informational).
//
// Idempotent: re-running on the same window produces the same writes.

import * as functions from 'firebase-functions';
import admin, { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';
import {
  postLedgerEntry,
  walletIdForUser,
  SYSTEM_WALLETS,
} from '../wallet/walletUtils';

export interface TierConfig {
  id: string;
  labelAr: string;
  minSessions: number;
  rate: number;
  badge?: string;
}

export const DEFAULT_TIERS: TierConfig[] = [
  { id: 'starter', labelAr: 'البداية', minSessions: 0, rate: 0.15, badge: '🌱' },
  { id: 'active', labelAr: 'نشط', minSessions: 8, rate: 0.12, badge: '⭐' },
  { id: 'intermediate', labelAr: 'متوسط', minSessions: 14, rate: 0.10, badge: '✨' },
  { id: 'distinguished', labelAr: 'متميز', minSessions: 20, rate: 0.08, badge: '🏆' },
  { id: 'elite', labelAr: 'نخبة', minSessions: 35, rate: 0.05, badge: '💎' },
];

/**
 * Effective commission rate = base tier rate + accumulated penalty.
 * Capped at 100% so the teacher never owes more than they earned.
 */
export function computeEffectiveRate(baseRate: number, penaltyPct: number): number {
  return Math.min(baseRate + penaltyPct / 100, 1.0);
}

/**
 * Cycle settlement math (in piastres = EGP × 100, integer-safe).
 * Returns the commission deducted and the teacher's net payout.
 */
export function computeSettlementPiastres(
  pendingPiastres: number,
  effectiveRate: number,
): { commissionPiastres: number; teacherNetPiastres: number } {
  const commissionPiastres = Math.round(pendingPiastres * effectiveRate);
  const teacherNetPiastres = pendingPiastres - commissionPiastres;
  return { commissionPiastres, teacherNetPiastres };
}

const ROLLING_WINDOW_DAYS = 14;
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
        minSessions: Number(e.minSessions ?? 0),
        rate: Number(e.rate ?? 0.10),
        badge: e.badge ? String(e.badge) : undefined,
      } as TierConfig;
    })
    .filter((t) => t.id.length > 0);
  if (tiers.length === 0) return DEFAULT_TIERS;
  tiers.sort((a, b) => a.minSessions - b.minSessions);
  return tiers;
}

export function pickTier(tiers: TierConfig[], sessionCount: number): TierConfig {
  let current = tiers[0];
  for (const t of tiers) {
    if (sessionCount >= t.minSessions) current = t;
  }
  return current;
}

interface TeacherStats {
  totalRevenueEgp: number;
  sessionCount: number;
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
      type: 'tier_change',
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
  options: { settleWallet: boolean } = { settleWallet: false },
): Promise<void> {
  const stats = await statsForTeacher(teacherId, windowStart);
  // Tier is determined by on-time session count, not revenue.
  const tier = pickTier(tiers, stats.sessionCount);

  const userRef = db.collection('users').doc(teacherId);
  const userSnap = await userRef.get();
  const previousTierId = userSnap.data()?.commissionTier as string | undefined;

  // Cancellation penalty: stored as percent points (e.g. 1.5 = 1.5%).
  // Only the highest penalty in the cycle applies (enforced by onSessionCancelled).
  // Converts to decimal and adds on top of the base tier rate.
  const penaltyPct = (userSnap.data()?.commissionPenaltyPercent as number | undefined) ?? 0;
  const effectiveRate = computeEffectiveRate(tier.rate, penaltyPct);

  const update: Record<string, unknown> = {
    commissionRate: tier.rate,          // base tier rate (no penalty — for display)
    commissionTier: tier.id,
    tierStats: {
      last14dRevenueEgp: stats.totalRevenueEgp,
      sessionsLast14d: stats.sessionCount,
      totalSessionsLast14d: stats.totalSessionsIncludingLate,
      lateSessionsLast14d: stats.lateSessionsCount,
      evaluatedAt: admin.firestore.Timestamp.fromDate(now),
      nextEvalAt: admin.firestore.Timestamp.fromDate(nextEval),
      windowStart: admin.firestore.Timestamp.fromDate(windowStart),
    },
  };

  // Reset penalty after applying it this cycle
  if (penaltyPct > 0) {
    update.commissionPenaltyPercent = 0;
  }

  await userRef.set(update, { merge: true });

  const historyId = now.toISOString().slice(0, 10);
  await userRef
    .collection('commissionHistory')
    .doc(historyId)
    .set(
      {
        tier: tier.id,
        rate: tier.rate,
        effectiveRate,           // actual rate used for settlement (base + penalty)
        penaltyPct,              // penalty applied this cycle (0 if none)
        revenueEgp: stats.totalRevenueEgp,
        sessions: stats.sessionCount,
        computedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  // ── Cycle settlement: drain the teacher's `pending` bucket using the
  // effective rate (base tier + any cancellation penalty for this cycle).
  // Only runs during the scheduled bi-weekly job.
  if (options.settleWallet) {
    await settleCycleForTeacher(teacherId, effectiveRate, now, historyId);
  }

  await maybeNotifyTierChange(teacherId, previousTierId, tier);
}

/**
 * Drain teacher's pending bucket → available (net of commission) + system
 * revenue (commission). Idempotent on `groupId = settle_{teacherId}_{cycleId}`
 * so a retry on the same cycle is a no-op. No-op if pending == 0.
 */
async function settleCycleForTeacher(
  teacherId: string,
  rate: number,
  now: Date,
  cycleId: string,
): Promise<void> {
  const walletRef = db.collection('wallets').doc(walletIdForUser(teacherId));
  const walletSnap = await walletRef.get();
  if (!walletSnap.exists) return;
  const pendingPiastres =
    (walletSnap.data()?.pendingCyclePiastres as number) ?? 0;
  if (pendingPiastres <= 0) {
    // Still stamp lastSettledAt so the teacher UI can show "settled at" even
    // for zero-pending cycles.
    await walletRef.update({
      lastSettledAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  const { commissionPiastres, teacherNetPiastres } = computeSettlementPiastres(
    pendingPiastres,
    rate,
  );

  try {
    await db.runTransaction(async (tx) => {
      await postLedgerEntry(tx, {
        type: 'cycle_settlement',
        legs: [
          // Drain pending bucket.
          {
            walletId: walletIdForUser(teacherId),
            ownerType: 'mohaffez',
            amountPiastres: -pendingPiastres,
            target: 'pending',
          },
          // Credit net to available bucket (skip leg if zero — e.g. 100% rate edge case).
          ...(teacherNetPiastres > 0
            ? [{
                walletId: walletIdForUser(teacherId),
                ownerType: 'mohaffez' as const,
                amountPiastres: teacherNetPiastres,
              }]
            : []),
          // Platform commission. Skip if zero (e.g. starter tier with 0% rate).
          ...(commissionPiastres > 0
            ? [{
                walletId: SYSTEM_WALLETS.revenue,
                ownerType: 'system' as const,
                amountPiastres: commissionPiastres,
              }]
            : []),
        ],
        reason: `Cycle settlement: pending=${pendingPiastres} rate=${rate}`,
        groupId: `settle_${teacherId}_${cycleId}`,
        createdBy: 'system',
        metadata: { rate, cycleId, pendingPiastres, commissionPiastres },
      });
      tx.update(walletRef, {
        lastSettledAt: admin.firestore.Timestamp.fromDate(now),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    functions.logger.error('settleCycleForTeacher failed', {
      teacherId, rate, pendingPiastres, err,
    });
  }
}

async function runRecompute(
  options: { settleWallet: boolean } = { settleWallet: true },
): Promise<{ teachersProcessed: number }> {
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
        await recomputeForTeacher(doc.id, tiers, now, windowStart, nextEval, options);
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
// for the next scheduled run. Restricted to admin custom-claim.
//
// By default this REFRESHES TIER STATS ONLY — it does NOT settle wallets.
// Settling would end the current commission cycle early (draining all
// teachers' pending balances). To force a full cycle close, pass
// `{ settleWallets: true }`.
export const recomputeTeacherTiersNow = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (context.auth?.token?.admin !== true) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Admin only.',
      );
    }
    const settleWallets = (data as { settleWallets?: boolean } | undefined)?.settleWallets === true;
    const result = await runRecompute({ settleWallet: settleWallets });
    return { ok: true, settleWallets, ...result };
  });

// Called by other triggers (e.g. onSessionCompleted) to refresh a single
// teacher's tier immediately, instead of waiting for the bi-weekly cron.
// Failures are logged but never thrown — recompute is best-effort and must
// not break the caller's primary flow.
export async function recomputeForTeacherById(teacherId: string): Promise<void> {
  if (!teacherId) return;
  try {
    const tiers = await loadTiers();
    const now = new Date();
    const windowStart = new Date(now.getTime() - ROLLING_WINDOW_DAYS * 86_400_000);
    const nextEval = new Date(now.getTime() + 14 * 86_400_000);
    await recomputeForTeacher(teacherId, tiers, now, windowStart, nextEval);
  } catch (err) {
    functions.logger.warn('recomputeForTeacherById failed', { teacherId, err });
  }
}
