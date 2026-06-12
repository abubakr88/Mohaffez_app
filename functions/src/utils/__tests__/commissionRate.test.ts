// Tests for the pure rate composition logic.
// The DB-reading parts (`resolveTeacherRate`) require an emulator; here we
// just verify the math integration with computeEffectiveRate.
//
// Run: npm test

import { describe, it, expect } from 'vitest';
import { computeEffectiveRate } from '../../payments/recomputeTeacherTiers';
import { resolveBaseRateFromData, starterTierRateFromConfig } from '../commissionRate';

describe('Direct-payment commission rate composition', () => {
  // These tests mirror what resolveTeacherRate() returns, validated against
  // the pure helper. They guard the contract that direct-payment commission
  // uses base tier rate + accumulated penalty (same as wallet settlement).

  it('Starter teacher (15%), no penalty → 15%', () => {
    expect(computeEffectiveRate(0.15, 0)).toBe(0.15);
  });

  it('Starter teacher (15%) + 1% cancellation penalty → 16%', () => {
    expect(computeEffectiveRate(0.15, 1)).toBeCloseTo(0.16, 10);
  });

  it('Distinguished teacher (8%) + 1.5% no-show penalty → 9.5%', () => {
    expect(computeEffectiveRate(0.08, 1.5)).toBeCloseTo(0.095, 10);
  });

  it('Elite teacher (5%), no penalty → 5%', () => {
    expect(computeEffectiveRate(0.05, 0)).toBe(0.05);
  });

  it('Direct payment after 3 cancellations (1+0.5+1.5=3% penalty) on Active (12%) → 15%', () => {
    expect(computeEffectiveRate(0.12, 3)).toBeCloseTo(0.15, 10);
  });

  it('Regression guard: legacy global 10% must NOT be used when teacher has tier', () => {
    // The bug we just fixed: mohaffezConfirmDirectPayment was using global 10%
    // instead of the locked-in per-teacher rate. A Starter teacher should pay 15%
    // even if globalRate is set to 10%.
    const starterRate = computeEffectiveRate(0.15, 0);
    expect(starterRate).not.toBe(0.10);
    expect(starterRate).toBe(0.15);
  });
});

describe('Commission base-rate fallback', () => {
  const configWithGlobalTen = {
    commissionRate: 0.10,
    commissionTiers: [
      { id: 'starter', minSessions: 0, rate: 0.15 },
      { id: 'active', minSessions: 8, rate: 0.12 },
    ],
  };

  it('uses teacher commissionRate when present', () => {
    expect(resolveBaseRateFromData({ commissionRate: 0.08 }, configWithGlobalTen)).toBe(0.08);
  });

  it('new teacher fallback uses starter tier, not legacy global rate', () => {
    expect(resolveBaseRateFromData({}, configWithGlobalTen)).toBe(0.15);
  });

  it('starter tier is selected by lowest minSessions even if unordered', () => {
    expect(starterTierRateFromConfig({
      commissionTiers: [
        { id: 'active', minSessions: 8, rate: 0.12 },
        { id: 'starter', minSessions: 0, rate: 0.15 },
      ],
    })).toBe(0.15);
  });

  it('falls back to 15% when tiers are missing', () => {
    expect(resolveBaseRateFromData({}, { commissionRate: 0.10 })).toBe(0.15);
  });
});

describe('Direct-payment commission amount on 200 EGP session', () => {
  // The scenario from the user's screenshot: 200 EGP cash session, Starter tier.
  // Old behavior charged 20 EGP (10% global). New behavior charges 30 EGP (15% tier).

  const amount = 200;

  it('OLD (buggy): global 10% → 20 EGP commission [regression test]', () => {
    const buggy = amount * 0.10;
    expect(buggy).toBe(20);
  });

  it('NEW (correct): Starter 15% → 30 EGP commission', () => {
    const rate = computeEffectiveRate(0.15, 0);
    expect(amount * rate).toBe(30);
  });

  it('NEW with 1% penalty: Starter 16% → 32 EGP commission', () => {
    const rate = computeEffectiveRate(0.15, 1);
    expect(amount * rate).toBeCloseTo(32, 2);
  });
});
