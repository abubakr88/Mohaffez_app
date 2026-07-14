import { describe, expect, it } from 'vitest';
import {
  dateKey,
  mergeNumericTrees,
  paymentStatusDeltas,
  pendingDateKeys,
  requestStatusDeltas,
  safeDimension,
  sessionStatusDeltas,
  walletGroupDeltas,
} from '../analyticsCore';

describe('admin analytics projections', () => {
  it('uses Cairo calendar dates at the UTC day boundary', () => {
    expect(dateKey(new Date('2026-07-12T22:30:00.000Z'))).toBe('2026-07-13');
  });

  it('normalizes untrusted dimension keys', () => {
    expect(safeDimension(' Google Meet / Card ')).toBe('google_meet_card');
    expect(safeDimension('')).toBe('unknown');
  });

  it('projects a completed payment once with amount dimensions', () => {
    expect(
      paymentStatusDeltas(
        { status: 'processing' },
        {
          status: 'completed',
          amount: 125,
          paymentMethod: 'paymob',
          planType: 'bundle',
        },
      ),
    ).toEqual({
      funnel: { paymentsCompleted: 1 },
      payments: {
        completed: 1,
        grossRevenueEgp: 125,
        netRevenueEgp: 125,
        completedByMethod: { paymob: 1 },
        revenueByMethod: { paymob: 125 },
        completedByPlanType: { bundle: 1 },
        revenueByPlanType: { bundle: 125 },
      },
    });
  });

  it('does not project updates that keep the same status', () => {
    expect(
      requestStatusDeltas({ status: 'accepted' }, { status: 'accepted' }),
    ).toBeNull();
  });

  it('counts no-show flags independently from completed status', () => {
    expect(
      sessionStatusDeltas(
        { status: 'accepted', studentNoShow: false },
        { status: 'completed', studentNoShow: true },
      ),
    ).toEqual({
      funnel: { sessionsCompleted: 1 },
      sessions: { completed: 1, studentNoShows: 1 },
    });
  });

  it('reads commission from immutable wallet ledger metadata', () => {
    expect(
      walletGroupDeltas({
        type: 'cycle_settlement',
        metadata: { commissionPiastres: 1575 },
      }),
    ).toEqual({ finance: { commissionAccruedEgp: 15.75 } });
  });

  it('merges numeric trees without replacing sibling metrics', () => {
    expect(
      mergeNumericTrees(
        { payments: { completed: 2, grossRevenueEgp: 100 } },
        { payments: { completed: 1, refunded: 1 } },
      ),
    ).toEqual({
      payments: { completed: 3, grossRevenueEgp: 100, refunded: 1 },
    });
  });

  it('returns bounded catch-up days for rolling analytics', () => {
    expect(pendingDateKeys('2026-07-01', '2026-07-04')).toEqual([
      '2026-07-02',
      '2026-07-03',
      '2026-07-04',
    ]);
    expect(pendingDateKeys('2026-07-04', '2026-07-04')).toEqual([]);
    expect(pendingDateKeys(undefined, '2026-07-04')).toEqual(['2026-07-04']);
    expect(pendingDateKeys('2026-07-01', '2026-07-10', 2)).toEqual([
      '2026-07-02',
      '2026-07-03',
    ]);
  });
});
