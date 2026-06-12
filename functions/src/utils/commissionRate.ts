// Centralised resolution of the EFFECTIVE commission rate for a teacher
// at this moment in time. Includes the accumulated cancellation penalty
// for the current cycle, so direct-payment commission is fair vs. the
// wallet-settlement commission.
//
// Base rate precedence:
//   1. users/{teacherId}.commissionRate  (set by recomputeTeacherTiers — tier rate)
//   2. systemConfig/global.commissionRate (legacy global rate)
//   3. 0.05 hardcoded fallback
//
// Penalty: users/{teacherId}.commissionPenaltyPercent (default 0)
// Final: min(base + penaltyPct / 100, 1.0)  — capped at 100%

import { db } from './admin';
import { computeEffectiveRate } from '../payments/recomputeTeacherTiers';

const STARTER_FALLBACK = 0.15;

export interface ResolvedRate {
  baseRate: number;       // tier rate (no penalty)
  penaltyPct: number;     // accumulated penalty for the current cycle, in percent points
  effectiveRate: number;  // base + penalty (capped at 100%)
}

function isValidRate(value: unknown): value is number {
  return typeof value === 'number' && isFinite(value) && value >= 0 && value <= 1;
}

export function starterTierRateFromConfig(
  configData: FirebaseFirestore.DocumentData | undefined,
): number {
  const rawTiers = configData?.commissionTiers;
  if (Array.isArray(rawTiers) && rawTiers.length > 0) {
    const sorted = rawTiers
      .map((entry) => {
        const e = entry as Record<string, unknown>;
        const minSessions =
          typeof e.minSessions === 'number' && isFinite(e.minSessions)
            ? e.minSessions
            : 0;
        return { minSessions, rate: e.rate };
      })
      .filter((tier) => isValidRate(tier.rate))
      .sort((a, b) => a.minSessions - b.minSessions);

    if (sorted.length > 0) return sorted[0].rate as number;
  }

  return STARTER_FALLBACK;
}

export function resolveBaseRateFromData(
  teacherData: FirebaseFirestore.DocumentData | undefined,
  configData: FirebaseFirestore.DocumentData | undefined,
): number {
  const perTeacher = teacherData?.commissionRate;
  if (isValidRate(perTeacher)) return perTeacher;
  return starterTierRateFromConfig(configData);
}

/**
 * Returns the effective commission rate for a teacher right now.
 * Use the `effectiveRate` field for billing; use `baseRate` for display
 * of "your tier rate" and `penaltyPct` separately if showing the penalty.
 */
export async function resolveTeacherRate(teacherId: string): Promise<ResolvedRate> {
  let baseRate = STARTER_FALLBACK;
  let penaltyPct = 0;

  try {
    const [userSnap, configSnap] = await Promise.all([
      db.collection('users').doc(teacherId).get(),
      db.collection('systemConfig').doc('global').get(),
    ]);

    baseRate = resolveBaseRateFromData(userSnap.data(), configSnap.data());

    const rawPenalty = userSnap.data()?.commissionPenaltyPercent;
    if (typeof rawPenalty === 'number' && isFinite(rawPenalty) && rawPenalty >= 0) {
      penaltyPct = rawPenalty;
    }
  } catch (_err) {
    // fall through to defaults
  }

  return {
    baseRate,
    penaltyPct,
    effectiveRate: computeEffectiveRate(baseRate, penaltyPct),
  };
}

/**
 * @deprecated Use resolveTeacherRate() — this returns only the base rate
 * without the cycle penalty and undercharges teachers with cancellations.
 * Kept for callers that genuinely want the base rate (e.g. tier display).
 */
export async function resolveCommissionRate(teacherId: string): Promise<number> {
  const { baseRate } = await resolveTeacherRate(teacherId);
  return baseRate;
}
