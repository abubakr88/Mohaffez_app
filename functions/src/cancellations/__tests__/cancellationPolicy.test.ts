// Tests for cancellation refund + commission penalty logic.
//
// Scenarios mirror docs/STUDENT_PAYMENT_GUIDE_AR.md (sections 3, 4)
// and docs/TEACHER_PAYMENT_GUIDE_AR.md (section 4).
//
// Run: npm test  (or `npm run test:watch` during development)

import { describe, it, expect } from 'vitest';
import { computeCancellationOutcome } from '../cancellationPolicy';

// Helper: build a session date N hours from `cancelledAt`.
const sessionInHours = (h: number, cancelledAt: Date) =>
  new Date(cancelledAt.getTime() + h * 3_600_000);

const NOW = new Date('2026-05-23T12:00:00Z');

describe('Student cancellation — refund schedule', () => {
  it('C1: > 3h before → 100% refund, no penalty', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: false,
      sessionDate: sessionInHours(4, NOW),
      cancelledAt: NOW,
    });
    expect(out).toEqual({ refundPercent: 100, penaltyPercent: 0 });
  });

  it('C1 boundary: exactly 3h01m → still 100%', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: false,
      sessionDate: sessionInHours(3 + 1 / 60, NOW),
      cancelledAt: NOW,
    });
    expect(out.refundPercent).toBe(100);
  });

  it('C2: 1h–3h before → 50% refund', () => {
    for (const h of [1, 1.5, 2, 3]) {
      const out = computeCancellationOutcome({
        cancelledBy: 'student',
        teacherNoShow: false,
        sessionDate: sessionInHours(h, NOW),
        cancelledAt: NOW,
      });
      expect(out, `at ${h}h`).toEqual({ refundPercent: 50, penaltyPercent: 0 });
    }
  });

  it('C2 boundary: exactly 3h → still 50% (≤ 3h, not > 3h)', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: false,
      sessionDate: sessionInHours(3, NOW),
      cancelledAt: NOW,
    });
    expect(out.refundPercent).toBe(50);
  });

  it('C3: < 1h before → 0% refund', () => {
    for (const h of [0.5, 0.1, 0.99]) {
      const out = computeCancellationOutcome({
        cancelledBy: 'student',
        teacherNoShow: false,
        sessionDate: sessionInHours(h, NOW),
        cancelledAt: NOW,
      });
      expect(out, `at ${h}h`).toEqual({ refundPercent: 0, penaltyPercent: 0 });
    }
  });

  it('C3 boundary: exactly 1h → 50% (≥ 1h)', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: false,
      sessionDate: sessionInHours(1, NOW),
      cancelledAt: NOW,
    });
    expect(out.refundPercent).toBe(50);
  });

  it('Cancelling after session start → 0% refund', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: false,
      sessionDate: sessionInHours(-1, NOW), // session was 1h ago
      cancelledAt: NOW,
    });
    expect(out.refundPercent).toBe(0);
  });

  it('Student cancel with missing sessionDate → 0% refund (defensive)', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: false,
      sessionDate: null,
      cancelledAt: NOW,
    });
    expect(out).toEqual({ refundPercent: 0, penaltyPercent: 0 });
  });
});

describe('Teacher cancellation — student always refunded 100%, penalty scales', () => {
  it('E1: > 3h before → 100% refund, no penalty', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'teacher',
      teacherNoShow: false,
      sessionDate: sessionInHours(5, NOW),
      cancelledAt: NOW,
    });
    expect(out).toEqual({ refundPercent: 100, penaltyPercent: 0 });
  });

  it('E2: 1h–3h before → 100% refund + 0.5% penalty', () => {
    for (const h of [1, 2, 3]) {
      const out = computeCancellationOutcome({
        cancelledBy: 'teacher',
        teacherNoShow: false,
        sessionDate: sessionInHours(h, NOW),
        cancelledAt: NOW,
      });
      expect(out, `at ${h}h`).toEqual({ refundPercent: 100, penaltyPercent: 0.5 });
    }
  });

  it('E3: < 1h before → 100% refund + 1% penalty', () => {
    for (const h of [0.5, 0.1, 0.99]) {
      const out = computeCancellationOutcome({
        cancelledBy: 'teacher',
        teacherNoShow: false,
        sessionDate: sessionInHours(h, NOW),
        cancelledAt: NOW,
      });
      expect(out, `at ${h}h`).toEqual({ refundPercent: 100, penaltyPercent: 1 });
    }
  });

  it('E3 boundary: cancelling after session start → still counts as < 1h (1% penalty)', () => {
    const out = computeCancellationOutcome({
      cancelledBy: 'teacher',
      teacherNoShow: false,
      sessionDate: sessionInHours(-2, NOW),
      cancelledAt: NOW,
    });
    expect(out).toEqual({ refundPercent: 100, penaltyPercent: 1 });
  });
});

describe('Teacher no-show — overrides everything', () => {
  it('F: teacherNoShow=true → 100% refund + 1.5% penalty regardless of time', () => {
    for (const h of [-2, 0.5, 2, 10]) {
      const out = computeCancellationOutcome({
        cancelledBy: 'teacher',
        teacherNoShow: true,
        sessionDate: sessionInHours(h, NOW),
        cancelledAt: NOW,
      });
      expect(out, `at ${h}h`).toEqual({ refundPercent: 100, penaltyPercent: 1.5 });
    }
  });

  it('F: teacherNoShow=true takes precedence even if cancelledBy=student', () => {
    // Defensive: if auto-detect sets teacherNoShow but cancelledBy is mis-set
    const out = computeCancellationOutcome({
      cancelledBy: 'student',
      teacherNoShow: true,
      sessionDate: sessionInHours(2, NOW),
      cancelledAt: NOW,
    });
    expect(out).toEqual({ refundPercent: 100, penaltyPercent: 1.5 });
  });
});

describe('Documentation consistency — sentinel values', () => {
  // These tests fail loudly if anyone changes the policy numbers without
  // also updating the docs. Cross-check vs:
  //   - docs/TEACHER_PAYMENT_GUIDE_AR.md  (section 4 + summary)
  //   - docs/STUDENT_PAYMENT_GUIDE_AR.md  (section 3 + summary)
  //   - packages/mohaffez_mobile/lib/screens/shared/session_details_screen.dart
  //   - packages/mohaffez_mobile/lib/screens/shared/cancellation_policy_screen.dart

  it('student refund tiers are 100 / 50 / 0', () => {
    const cases = [
      { hours: 10, expected: 100 },
      { hours: 2, expected: 50 },
      { hours: 0.5, expected: 0 },
    ];
    for (const c of cases) {
      const out = computeCancellationOutcome({
        cancelledBy: 'student',
        teacherNoShow: false,
        sessionDate: sessionInHours(c.hours, NOW),
        cancelledAt: NOW,
      });
      expect(out.refundPercent).toBe(c.expected);
    }
  });

  it('teacher penalty tiers are 0 / 0.5 / 1 / 1.5', () => {
    const penalties = new Set([
      computeCancellationOutcome({
        cancelledBy: 'teacher', teacherNoShow: false,
        sessionDate: sessionInHours(10, NOW), cancelledAt: NOW,
      }).penaltyPercent,
      computeCancellationOutcome({
        cancelledBy: 'teacher', teacherNoShow: false,
        sessionDate: sessionInHours(2, NOW), cancelledAt: NOW,
      }).penaltyPercent,
      computeCancellationOutcome({
        cancelledBy: 'teacher', teacherNoShow: false,
        sessionDate: sessionInHours(0.5, NOW), cancelledAt: NOW,
      }).penaltyPercent,
      computeCancellationOutcome({
        cancelledBy: 'teacher', teacherNoShow: true,
        sessionDate: sessionInHours(2, NOW), cancelledAt: NOW,
      }).penaltyPercent,
    ]);
    expect(penaltyPercentSetEquals(penalties, new Set([0, 0.5, 1, 1.5]))).toBe(true);
  });
});

function penaltyPercentSetEquals(a: Set<number>, b: Set<number>): boolean {
  if (a.size !== b.size) return false;
  for (const v of a) if (!b.has(v)) return false;
  return true;
}
