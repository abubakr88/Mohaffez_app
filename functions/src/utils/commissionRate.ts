// Centralised resolution of the effective commission rate.
//
// Order of precedence:
//   1. users/{teacherId}.commissionRate  (set by recomputeTeacherTiers)
//   2. systemConfig/global.commissionRate
//   3. 0.05 hardcoded fallback (matches historical default)

import { db } from './admin';

const HARD_FALLBACK = 0.05;

export async function resolveCommissionRate(
  teacherId: string,
): Promise<number> {
  try {
    const [userSnap, configSnap] = await Promise.all([
      db.collection('users').doc(teacherId).get(),
      db.collection('systemConfig').doc('global').get(),
    ]);

    const perTeacher = userSnap.data()?.commissionRate;
    if (typeof perTeacher === 'number' && isFinite(perTeacher) && perTeacher >= 0) {
      return perTeacher;
    }

    const global = configSnap.data()?.commissionRate;
    if (typeof global === 'number' && isFinite(global) && global >= 0) {
      return global;
    }
  } catch (_err) {
    // fall through to hard fallback
  }
  return HARD_FALLBACK;
}
