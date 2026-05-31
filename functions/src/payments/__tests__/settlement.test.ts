// Tests for commission tier selection + cycle settlement math.
//
// Scenarios mirror docs/TEACHER_PAYMENT_GUIDE_AR.md sections 2, 3, 5
// and the worked examples in PAYMENT_TEST_CHECKLIST.md section I.
//
// Run: npm test

import { describe, it, expect } from 'vitest';
import {
  DEFAULT_TIERS,
  pickTier,
  computeEffectiveRate,
  computeSettlementPiastres,
} from '../recomputeTeacherTiers';

// EGP ↔ piastres helpers (mirror walletUtils.egpToPiastres).
const egp = (v: number) => Math.round(v * 100);
const fromPiastres = (v: number) => v / 100;

describe('Tier selection by session count', () => {
  it('0 on-time sessions → Starter (15%)', () => {
    const t = pickTier(DEFAULT_TIERS, 0);
    expect(t.id).toBe('starter');
    expect(t.rate).toBe(0.15);
  });

  it('7 on-time sessions → still Starter (boundary, needs 8 for Active)', () => {
    expect(pickTier(DEFAULT_TIERS, 7).id).toBe('starter');
  });

  it('8 on-time sessions → Active (12%)', () => {
    const t = pickTier(DEFAULT_TIERS, 8);
    expect(t.id).toBe('active');
    expect(t.rate).toBe(0.12);
  });

  it('14 on-time sessions → Intermediate (10%)', () => {
    const t = pickTier(DEFAULT_TIERS, 14);
    expect(t.id).toBe('intermediate');
    expect(t.rate).toBe(0.10);
  });

  it('20 on-time sessions → Distinguished (8%)', () => {
    const t = pickTier(DEFAULT_TIERS, 20);
    expect(t.id).toBe('distinguished');
    expect(t.rate).toBe(0.08);
  });

  it('35 on-time sessions → Elite (5%)', () => {
    const t = pickTier(DEFAULT_TIERS, 35);
    expect(t.id).toBe('elite');
    expect(t.rate).toBe(0.05);
  });

  it('100 on-time sessions → still Elite (no tier above)', () => {
    expect(pickTier(DEFAULT_TIERS, 100).id).toBe('elite');
  });

  it('negative input → Starter (defensive)', () => {
    expect(pickTier(DEFAULT_TIERS, -5).id).toBe('starter');
  });
});

describe('Effective rate = base + penalty (capped at 100%)', () => {
  it('No penalty → effective = base', () => {
    expect(computeEffectiveRate(0.08, 0)).toBe(0.08);
  });

  it('0.5% penalty on Distinguished (8%) → 8.5%', () => {
    expect(computeEffectiveRate(0.08, 0.5)).toBeCloseTo(0.085, 10);
  });

  it('1% penalty on Distinguished → 9%', () => {
    expect(computeEffectiveRate(0.08, 1)).toBeCloseTo(0.09, 10);
  });

  it('1.5% no-show penalty on Distinguished → 9.5%', () => {
    expect(computeEffectiveRate(0.08, 1.5)).toBeCloseTo(0.095, 10);
  });

  it('Cumulative: 1% + 0.5% on Starter (15%) → 16.5%', () => {
    // Cancellations accumulate via FieldValue.increment; this test asserts
    // the math compounds correctly when the running total is read back.
    expect(computeEffectiveRate(0.15, 1.5)).toBeCloseTo(0.165, 10);
  });

  it('Catastrophic penalty caps at 100% (no negative payouts)', () => {
    expect(computeEffectiveRate(0.15, 200)).toBe(1.0);
  });

  it('Exactly 100% rate is allowed (full revenue to platform)', () => {
    expect(computeEffectiveRate(1.0, 0)).toBe(1.0);
  });
});

describe('Settlement payout — worked examples from the checklist', () => {
  // Numbers match docs/PAYMENT_TEST_CHECKLIST.md section I.

  it('I1: 20 sessions × 100 EGP at Distinguished (8%) → teacher 1840, platform 160', () => {
    const tier = pickTier(DEFAULT_TIERS, 20);
    const rate = computeEffectiveRate(tier.rate, 0);
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(egp(2000), rate);
    expect(fromPiastres(commissionPiastres)).toBe(160);
    expect(fromPiastres(teacherNetPiastres)).toBe(1840);
  });

  it('I2: same as I1 but +1% penalty → teacher 1820, platform 180', () => {
    const tier = pickTier(DEFAULT_TIERS, 20);
    const rate = computeEffectiveRate(tier.rate, 1); // 9%
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(egp(2000), rate);
    expect(fromPiastres(commissionPiastres)).toBe(180);
    expect(fromPiastres(teacherNetPiastres)).toBe(1820);
  });

  it('I3: 7 on-time + 13 late = 2000 EGP at Starter (15%) → teacher 1700, platform 300', () => {
    // Late sessions still earn money but don't count toward tier — so 7 on-time
    // keeps the teacher in Starter. The pending balance still includes ALL 20.
    const tier = pickTier(DEFAULT_TIERS, 7);
    expect(tier.id).toBe('starter');
    const rate = computeEffectiveRate(tier.rate, 0);
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(egp(2000), rate);
    expect(fromPiastres(commissionPiastres)).toBe(300);
    expect(fromPiastres(teacherNetPiastres)).toBe(1700);
  });

  it('I4: 5 sessions × 100 EGP at Starter (15%) + 2.5% cumulative penalty → teacher 412.50', () => {
    const tier = pickTier(DEFAULT_TIERS, 5);
    const rate = computeEffectiveRate(tier.rate, 2.5); // 17.5%
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(egp(500), rate);
    expect(fromPiastres(commissionPiastres)).toBe(87.5);
    expect(fromPiastres(teacherNetPiastres)).toBe(412.5);
  });

  it('I5: 50 sessions × 100 EGP at Elite (5%) → teacher 4750, platform 250', () => {
    const tier = pickTier(DEFAULT_TIERS, 50);
    const rate = computeEffectiveRate(tier.rate, 0);
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(egp(5000), rate);
    expect(fromPiastres(commissionPiastres)).toBe(250);
    expect(fromPiastres(teacherNetPiastres)).toBe(4750);
  });

  it('I6: catastrophic penalty caps at 100% — teacher net = 0, never negative', () => {
    const rate = computeEffectiveRate(0.15, 999);
    expect(rate).toBe(1.0);
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(egp(1000), rate);
    expect(commissionPiastres).toBe(egp(1000));
    expect(teacherNetPiastres).toBe(0);
  });

  it('Zero pending → zero everything (no-op settlement is safe)', () => {
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(0, 0.10);
    expect(commissionPiastres).toBe(0);
    expect(teacherNetPiastres).toBe(0);
  });

  it('Integer-safe rounding: 333 piastres @ 33% → commission 110, net 223', () => {
    // 333 * 0.33 = 109.89 → rounds to 110. Verifies no off-by-one drift.
    const { commissionPiastres, teacherNetPiastres } =
      computeSettlementPiastres(333, 0.33);
    expect(commissionPiastres).toBe(110);
    expect(teacherNetPiastres).toBe(223);
    expect(commissionPiastres + teacherNetPiastres).toBe(333); // no piastres lost
  });
});

describe('Documentation consistency — default tier values', () => {
  // Fails if anyone edits DEFAULT_TIERS without updating the docs/UI.
  // Cross-check vs docs/TEACHER_PAYMENT_GUIDE_AR.md section 2.

  it('there are exactly 5 default tiers', () => {
    expect(DEFAULT_TIERS).toHaveLength(5);
  });

  it('thresholds are 0 / 8 / 14 / 20 / 35', () => {
    expect(DEFAULT_TIERS.map((t) => t.minSessions)).toEqual([0, 8, 14, 20, 35]);
  });

  it('rates are 15 / 12 / 10 / 8 / 5 percent', () => {
    expect(DEFAULT_TIERS.map((t) => t.rate)).toEqual([0.15, 0.12, 0.10, 0.08, 0.05]);
  });

  it('tier ids are starter / active / intermediate / distinguished / elite', () => {
    expect(DEFAULT_TIERS.map((t) => t.id)).toEqual([
      'starter', 'active', 'intermediate', 'distinguished', 'elite',
    ]);
  });
});
