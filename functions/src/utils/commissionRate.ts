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

const HARD_FALLBACK = 0.05;

export interface ResolvedRate {
  baseRate: number;       // tier rate (no penalty)
  penaltyPct: number;     // accumulated penalty for the current cycle, in percent points
  effectiveRate: number;  // base + penalty (capped at 100%)
}

/**
 * Returns the effective commission rate for a teacher right now.
 * Use the `effectiveRate` field for billing; use `baseRate` for display
 * of "your tier rate" and `penaltyPct` separately if showing the penalty.
 */
export async function resolveTeacherRate(teacherId: string): Promise<ResolvedRate> {
  let baseRate = HARD_FALLBACK;
  let penaltyPct = 0;

  try {
    const [userSnap, configSnap] = await Promise.all([
      db.collection('users').doc(teacherId).get(),
      db.collection('systemConfig').doc('global').get(),
    ]);

    const perTeacher = userSnap.data()?.commissionRate;
    if (typeof perTeacher === 'number' && isFinite(perTeacher) && perTeacher >= 0) {
      baseRate = perTeacher;
    } else {
      const global = configSnap.data()?.commissionRate;
      if (typeof global === 'number' && isFinite(global) && global >= 0) {
        baseRate = global;
      }
    }

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
