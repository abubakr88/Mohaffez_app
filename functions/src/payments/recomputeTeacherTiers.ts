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

import * as functions from "firebase-functions";
import admin, { db, FieldValue } from "../utils/admin";
import { createAndSendNotification } from "../utils/notificationHelpers";
import {
  postLedgerEntry,
  postWalletEvent,
  walletIdForUser,
  SYSTEM_WALLETS,
} from "../wallet/walletUtils";

export interface TierConfig {
  id: string;
  labelAr: string;
  minSessions: number;
  rate: number;
  badge?: string;
}

export const DEFAULT_TIERS: TierConfig[] = [
  {
    id: "starter",
    labelAr: "البداية",
    minSessions: 0,
    rate: 0.15,
    badge: "🌱",
  },
  { id: "active", labelAr: "نشط", minSessions: 8, rate: 0.12, badge: "⭐" },
  {
    id: "intermediate",
    labelAr: "متوسط",
    minSessions: 14,
    rate: 0.1,
    badge: "✨",
  },
  {
    id: "distinguished",
    labelAr: "متميز",
    minSessions: 20,
    rate: 0.08,
    badge: "🏆",
  },
  { id: "elite", labelAr: "نخبة", minSessions: 35, rate: 0.05, badge: "💎" },
];

/**
 * Effective commission rate = base tier rate + accumulated penalty.
 * Capped at 100% so the teacher never owes more than they earned.
 */
export function computeEffectiveRate(
  baseRate: number,
  penaltyPct: number,
): number {
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
const SETTLEMENT_TIME_ZONE = "Africa/Cairo";
const SETTLEMENT_HOUR = 0;
const SETTLEMENT_MINUTE = 5;

interface WalletLikeData {
  balancePiastres?: number;
  pendingCyclePiastres?: number;
  directCommissionOwedPiastres?: number;
}

async function loadTiers(): Promise<TierConfig[]> {
  const snap = await db.collection("systemConfig").doc("global").get();
  const raw = snap.data()?.commissionTiers as unknown[] | undefined;
  if (!raw || !Array.isArray(raw) || raw.length === 0) return DEFAULT_TIERS;
  const tiers = raw
    .map((entry) => {
      const e = entry as Record<string, unknown>;
      return {
        id: String(e.id ?? ""),
        labelAr: String(e.labelAr ?? ""),
        minSessions: Number(e.minSessions ?? 0),
        rate: Number(e.rate ?? 0.1),
        badge: e.badge ? String(e.badge) : undefined,
      } as TierConfig;
    })
    .filter((t) => t.id.length > 0);
  if (tiers.length === 0) return DEFAULT_TIERS;
  tiers.sort((a, b) => a.minSessions - b.minSessions);
  return tiers;
}

export function pickTier(
  tiers: TierConfig[],
  sessionCount: number,
): TierConfig {
  let current = tiers[0];
  for (const t of tiers) {
    if (sessionCount >= t.minSessions) current = t;
  }
  return current;
}

function timeZoneParts(
  date: Date,
  timeZone: string,
): {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
} {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);

  const value = (type: Intl.DateTimeFormatPartTypes): number => {
    const part = parts.find((p) => p.type === type)?.value;
    return Number(part ?? 0);
  };

  return {
    year: value("year"),
    month: value("month"),
    day: value("day"),
    hour: value("hour"),
    minute: value("minute"),
    second: value("second"),
  };
}

function zonedDateTimeToUtc(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  timeZone: string,
): Date {
  let utc = new Date(Date.UTC(year, month - 1, day, hour, minute));

  for (let i = 0; i < 3; i += 1) {
    const actual = timeZoneParts(utc, timeZone);
    const desiredMs = Date.UTC(year, month - 1, day, hour, minute);
    const actualMs = Date.UTC(
      actual.year,
      actual.month - 1,
      actual.day,
      actual.hour,
      actual.minute,
    );
    const diffMs = desiredMs - actualMs;
    if (diffMs === 0) break;
    utc = new Date(utc.getTime() + diffMs);
  }

  return utc;
}

function addMonth(
  year: number,
  month: number,
): { year: number; month: number } {
  if (month === 12) return { year: year + 1, month: 1 };
  return { year, month: month + 1 };
}

export function nextScheduledSettlementAt(from: Date = new Date()): Date {
  const nowInCairo = timeZoneParts(from, SETTLEMENT_TIME_ZONE);
  const nextMonth = addMonth(nowInCairo.year, nowInCairo.month);
  const candidates = [
    zonedDateTimeToUtc(
      nowInCairo.year,
      nowInCairo.month,
      1,
      SETTLEMENT_HOUR,
      SETTLEMENT_MINUTE,
      SETTLEMENT_TIME_ZONE,
    ),
    zonedDateTimeToUtc(
      nowInCairo.year,
      nowInCairo.month,
      15,
      SETTLEMENT_HOUR,
      SETTLEMENT_MINUTE,
      SETTLEMENT_TIME_ZONE,
    ),
    zonedDateTimeToUtc(
      nextMonth.year,
      nextMonth.month,
      1,
      SETTLEMENT_HOUR,
      SETTLEMENT_MINUTE,
      SETTLEMENT_TIME_ZONE,
    ),
  ].sort((a, b) => a.getTime() - b.getTime());

  return (
    candidates.find((candidate) => candidate.getTime() > from.getTime()) ??
    candidates[candidates.length - 1]
  );
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
    .collection("hafizSessions")
    .where("mohaffezId", "==", teacherId)
    .where("status", "==", "completed")
    .where("completedAt", ">=", admin.firestore.Timestamp.fromDate(windowStart))
    .get();

  let totalRevenueEgp = 0;
  let sessionCount = 0;
  let totalSessionsIncludingLate = 0;
  let lateSessionsCount = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.isPaid !== true) continue;
    const price =
      typeof data.sessionPrice === "number"
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

  const title = isUp
    ? "تهانينا — انتقلت إلى شريحة جديدة!"
    : "تحديث شريحة العمولة";
  const body = isUp
    ? `${next.badge ?? ""} انتقلت إلى شريحة ${next.labelAr}. عمولة المنصة الآن ${(next.rate * 100).toFixed(0)}%`
    : `شريحتك الحالية: ${next.labelAr} (عمولة ${(next.rate * 100).toFixed(0)}%). أكمل المزيد من الحلقات للعودة لشريحة أعلى.`;

  try {
    await createAndSendNotification({
      userId: teacherId,
      title,
      body,
      type: "tier_change",
      data: { tierId: next.id, rate: String(next.rate) },
    });
  } catch (err) {
    functions.logger.warn("tier-change notification failed", {
      teacherId,
      err,
    });
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

  const userRef = db.collection("users").doc(teacherId);
  const userSnap = await userRef.get();
  const previousTierId = userSnap.data()?.commissionTier as string | undefined;

  // Cancellation penalty: stored as percent points (e.g. 1.5 = 1.5%).
  // Only the highest penalty in the cycle applies (enforced by onSessionCancelled).
  // Converts to decimal and adds on top of the base tier rate.
  const penaltyPct =
    (userSnap.data()?.commissionPenaltyPercent as number | undefined) ?? 0;
  const effectiveRate = computeEffectiveRate(tier.rate, penaltyPct);

  const update: Record<string, unknown> = {
    commissionRate: tier.rate, // base tier rate (no penalty — for display)
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

  // Reset penalty only when we're actually settling the cycle. The real-time
  // refresh triggered by onSessionCompleted re-runs this function with
  // settleWallet: false purely to update tierStats display — if we cleared
  // the penalty there, the next completed session would wipe the cancellation
  // penalty before the bi-weekly cron ever got a chance to charge it.
  if (penaltyPct > 0 && options.settleWallet) {
    update.commissionPenaltyPercent = 0;
  }

  await userRef.set(update, { merge: true });

  const historyId = now.toISOString().slice(0, 10);
  await userRef.collection("commissionHistory").doc(historyId).set(
    {
      tier: tier.id,
      rate: tier.rate,
      effectiveRate, // actual rate used for settlement (base + penalty)
      penaltyPct, // penalty applied this cycle (0 if none)
      revenueEgp: stats.totalRevenueEgp,
      sessions: stats.sessionCount,
      computedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  // ── Record informational wallet events for tier/rate changes ────────────
  const oldTierSnap = previousTierId
    ? tiers.find((t) => t.id === previousTierId)
    : undefined;
  const oldBaseRate = oldTierSnap?.rate ?? tier.rate;
  const oldPenaltyPct =
    (userSnap.data()?.commissionPenaltyPercent as number | undefined) ?? 0;
  const oldEffective = Math.min(oldBaseRate + oldPenaltyPct / 100, 1.0);

  // Tier changed → record a commission_rate_change event.
  if (previousTierId && previousTierId !== tier.id) {
    const eventId = `tier_change_${teacherId}_${historyId}`;
    await postWalletEvent(teacherId, {
      type: "commission_rate_change",
      eventId,
      reason: `تغيير الشريحة: ${oldTierSnap?.labelAr ?? previousTierId} ← ${tier.labelAr} (${(oldBaseRate * 100).toFixed(0)}% → ${(tier.rate * 100).toFixed(0)}%)`,
      metadata: {
        oldTierId: previousTierId,
        newTierId: tier.id,
        oldBaseRate,
        newBaseRate: tier.rate,
        oldEffectiveRate: oldEffective,
        newEffectiveRate: effectiveRate,
        cycleId: historyId,
      },
    });
  }

  // Penalty was reset at settlement → record event showing rate dropping back to base.
  if (options.settleWallet && penaltyPct > 0) {
    const penaltyEventId = `penalty_reset_${teacherId}_${historyId}`;
    await postWalletEvent(teacherId, {
      type: "commission_rate_change",
      eventId: penaltyEventId,
      reason: `إعادة ضبط العقوبة عند التسوية: ${(effectiveRate * 100).toFixed(1)}% → ${(tier.rate * 100).toFixed(0)}%`,
      metadata: {
        tierId: tier.id,
        baseRate: tier.rate,
        penaltyResetPct: penaltyPct,
        oldEffectiveRate: effectiveRate,
        newEffectiveRate: tier.rate,
        cycleId: historyId,
      },
    });
  }

  // ── Cycle settlement: drain the teacher's `pending` bucket using the
  // effective rate (base tier + any cancellation penalty for this cycle).
  // Only runs during the scheduled bi-weekly job.
  if (options.settleWallet) {
    await settleCycleForTeacher(teacherId, effectiveRate, now, historyId);
  }

  await maybeNotifyTierChange(teacherId, previousTierId, tier);
}

/**
 * Two-step cycle settlement for a teacher:
 *
 *   1. Drain `pending` (online gross earnings) → `available` net of
 *      commission. Same as before.
 *   2. Drain `dues` (direct-payment commission owed) from `available`,
 *      capped by what's available so the wallet never goes negative.
 *      Any remaining debt stays in dues and rolls into the next cycle.
 *
 * Both steps run inside one transaction. Both are idempotent on their
 * own groupId, so a retry of step 1 doesn't re-run step 2 or vice versa.
 *
 * Phase B step 3. Settles teachers who have ONLY dues (no online
 * earnings), partially settles teachers with both, and leaves
 * unsettleable debt for next cycle.
 */
async function settleCycleForTeacher(
  teacherId: string,
  rate: number,
  now: Date,
  cycleId: string,
): Promise<void> {
  const walletRef = db.collection("wallets").doc(walletIdForUser(teacherId));
  const walletSnap = await walletRef.get();
  if (!walletSnap.exists) return;

  const pendingPiastres =
    (walletSnap.data()?.pendingCyclePiastres as number) ?? 0;
  const duesPiastres =
    (walletSnap.data()?.directCommissionOwedPiastres as number) ?? 0;

  // Nothing to settle either way: just stamp the timestamp.
  if (pendingPiastres <= 0 && duesPiastres >= 0) {
    await walletRef.update({
      lastSettledAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return;
  }

  // ── STEP 1: settle online pending → available + revenue ──
  if (pendingPiastres > 0) {
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(pendingPiastres, rate);

    try {
      await db.runTransaction(async (tx) => {
        await postLedgerEntry(tx, {
          type: "cycle_settlement",
          legs: [
            {
              walletId: walletIdForUser(teacherId),
              ownerType: "mohaffez",
              amountPiastres: -pendingPiastres,
              target: "pending",
            },
            ...(teacherNetPiastres > 0
              ? [
                  {
                    walletId: walletIdForUser(teacherId),
                    ownerType: "mohaffez" as const,
                    amountPiastres: teacherNetPiastres,
                  },
                ]
              : []),
            ...(commissionPiastres > 0
              ? [
                  {
                    walletId: SYSTEM_WALLETS.revenue,
                    ownerType: "system" as const,
                    amountPiastres: commissionPiastres,
                  },
                ]
              : []),
          ],
          reason: `Cycle settlement: pending=${pendingPiastres} rate=${rate}`,
          groupId: `settle_${teacherId}_${cycleId}`,
          createdBy: "system",
          metadata: { rate, cycleId, pendingPiastres, commissionPiastres },
        });
      });
    } catch (err) {
      functions.logger.error("settleCycleForTeacher: pending step failed", {
        teacherId,
        rate,
        pendingPiastres,
        err,
      });
    }
  }

  // ── STEP 2: drain direct-commission dues from available ──
  // `duesPiastres` is ≤ 0 (negative = owed). Try to wipe as much as the
  // teacher's available balance permits; leftover rolls forward.
  if (duesPiastres < 0) {
    try {
      await db.runTransaction(async (tx) => {
        // Re-read wallet (available may have just gone up from step 1)
        const freshSnap = await tx.get(walletRef);
        if (!freshSnap.exists) return;
        const fresh = freshSnap.data() as WalletLikeData;
        const currentAvailable = fresh.balancePiastres ?? 0;
        const currentDues = fresh.directCommissionOwedPiastres ?? 0;
        if (currentDues >= 0) return; // already cleared by a concurrent path
        const debt = -currentDues; // positive amount owed
        const drainable = Math.min(debt, Math.max(currentAvailable, 0));

        if (drainable <= 0) {
          // Teacher has no available balance to pay dues. Leave the debt
          // in dues to roll forward into next cycle. Admin alert so ops
          // can decide whether to follow up.
          await db.collection("adminAlerts").add({
            type: "teacher_dues_unsettled",
            mohaffezId: teacherId,
            duesOwedEgp: debt / 100,
            cycleId,
            note: "Available balance was 0 at settlement; debt rolls forward.",
            resolved: false,
            createdAt: FieldValue.serverTimestamp(),
          });
          return;
        }

        await postLedgerEntry(tx, {
          type: "cycle_settlement",
          legs: [
            // Take from teacher's available balance...
            {
              walletId: walletIdForUser(teacherId),
              ownerType: "mohaffez",
              amountPiastres: -drainable,
            },
            // ...and zero out (or reduce) the dues bucket.
            {
              walletId: walletIdForUser(teacherId),
              ownerType: "mohaffez",
              amountPiastres: drainable,
              target: "dues",
            },
          ],
          reason: `Direct-commission dues settlement: drained ${drainable} of ${debt}`,
          groupId: `settle_dues_${teacherId}_${cycleId}`,
          createdBy: "system",
          metadata: {
            cycleId,
            duesOwedPiastres: debt,
            drainedPiastres: drainable,
          },
        });

        // Partial-settle case: log so ops can see rolling debt.
        if (drainable < debt) {
          await db.collection("adminAlerts").add({
            type: "teacher_dues_partially_settled",
            mohaffezId: teacherId,
            settledEgp: drainable / 100,
            remainingOwedEgp: (debt - drainable) / 100,
            cycleId,
            note: "Partial settlement; remaining dues rolled forward.",
            resolved: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (err) {
      functions.logger.error("settleCycleForTeacher: dues step failed", {
        teacherId,
        duesPiastres,
        err,
      });
    }
  }

  // Stamp the settlement timestamp regardless of step outcomes.
  await walletRef.update({
    lastSettledAt: admin.firestore.Timestamp.fromDate(now),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function runRecompute(
  options: { settleWallet: boolean } = { settleWallet: true },
): Promise<{ teachersProcessed: number }> {
  const tiers = await loadTiers();
  const now = new Date();
  const windowStart = new Date(
    now.getTime() - ROLLING_WINDOW_DAYS * 86_400_000,
  );
  const nextEval = nextScheduledSettlementAt(now);

  let teachersProcessed = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  while (true) {
    let query = db
      .collection("users")
      .where("role", "==", "mohaffez")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(TEACHER_PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const page = await query.get();
    if (page.empty) break;

    for (const doc of page.docs) {
      try {
        await recomputeForTeacher(
          doc.id,
          tiers,
          now,
          windowStart,
          nextEval,
          options,
        );
        teachersProcessed += 1;
      } catch (err) {
        functions.logger.error("tier recompute failed for teacher", {
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
  .region("us-central1")
  .pubsub.schedule("5 0 1,15 * *")
  .timeZone("Africa/Cairo")
  .onRun(async () => {
    const result = await runRecompute();
    functions.logger.info("recomputeTeacherTiers complete", result);
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
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (context.auth?.token?.admin !== true) {
      throw new functions.https.HttpsError("permission-denied", "Admin only.");
    }
    const settleWallets =
      (data as { settleWallets?: boolean } | undefined)?.settleWallets === true;
    const result = await runRecompute({ settleWallet: settleWallets });
    return { ok: true, settleWallets, ...result };
  });

// Called by other triggers (e.g. onSessionCompleted) to refresh a single
// teacher's tier immediately, instead of waiting for the bi-weekly cron.
// Failures are logged but never thrown — recompute is best-effort and must
// not break the caller's primary flow.
export async function recomputeForTeacherById(
  teacherId: string,
): Promise<void> {
  if (!teacherId) return;
  try {
    const tiers = await loadTiers();
    const now = new Date();
    const windowStart = new Date(
      now.getTime() - ROLLING_WINDOW_DAYS * 86_400_000,
    );
    const nextEval = nextScheduledSettlementAt(now);
    await recomputeForTeacher(teacherId, tiers, now, windowStart, nextEval);
  } catch (err) {
    functions.logger.warn("recomputeForTeacherById failed", { teacherId, err });
  }
}
