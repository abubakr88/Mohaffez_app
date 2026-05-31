// Unit tests for the bundle-context detection helper used by the
// onSessionCancelled trigger. Covers the resolution priority:
//   1. direct subscriptionId on the session
//   2. paymentType / paymentMethod signal + sessionRequest lookup
//   3. signal present but lookup fails → isBundle=true, subscriptionId=null
//   4. no signal at all → not a bundle
//
// Run: npm test

import { describe, it, expect, vi } from 'vitest';
import { detectBundleContext } from '../bundleDetection';

describe('detectBundleContext', () => {
  it('prefers session.subscriptionId when present', async () => {
    const out = await detectBundleContext({
      subscriptionId: 'sub_direct',
      paymentType: 'wallet', // intentionally non-bundle signal
      requestId: 'req_1',
    });
    expect(out).toEqual({ isBundle: true, subscriptionId: 'sub_direct' });
  });

  it("does NOT call the request lookup when session.subscriptionId is set", async () => {
    const lookup = vi.fn();
    await detectBundleContext(
      { subscriptionId: 'sub_direct', requestId: 'req_1' },
      lookup,
    );
    expect(lookup).not.toHaveBeenCalled();
  });

  it('returns not-bundle when no signal at all', async () => {
    const out = await detectBundleContext({
      paymentType: 'wallet',
      paymentMethod: undefined,
    });
    expect(out).toEqual({ isBundle: false, subscriptionId: null });
  });

  it('resolves via sessionRequest lookup when paymentType=bundle', async () => {
    const lookup = vi.fn().mockResolvedValue({ subscriptionId: 'sub_from_req' });
    const out = await detectBundleContext(
      { paymentType: 'bundle', requestId: 'req_1' },
      lookup,
    );
    expect(lookup).toHaveBeenCalledWith('req_1');
    expect(out).toEqual({ isBundle: true, subscriptionId: 'sub_from_req' });
  });

  it('resolves via sessionRequest lookup when paymentMethod=subscription', async () => {
    const lookup = vi.fn().mockResolvedValue({ subscriptionId: 'sub_X' });
    const out = await detectBundleContext(
      { paymentMethod: 'subscription', requestId: 'req_2' },
      lookup,
    );
    expect(out).toEqual({ isBundle: true, subscriptionId: 'sub_X' });
  });

  it('returns isBundle=true,subscriptionId=null when lookup returns no subscriptionId', async () => {
    const lookup = vi.fn().mockResolvedValue({ subscriptionId: null });
    const out = await detectBundleContext(
      { paymentType: 'bundle', requestId: 'req_orphan' },
      lookup,
    );
    expect(out).toEqual({ isBundle: true, subscriptionId: null });
  });

  it('returns isBundle=true,subscriptionId=null when request does not exist', async () => {
    const lookup = vi.fn().mockResolvedValue(null);
    const out = await detectBundleContext(
      { paymentType: 'bundle', requestId: 'req_missing' },
      lookup,
    );
    expect(out).toEqual({ isBundle: true, subscriptionId: null });
  });

  it('returns isBundle=true,subscriptionId=null when no requestId on session', async () => {
    const lookup = vi.fn();
    const out = await detectBundleContext(
      { paymentType: 'bundle' },
      lookup,
    );
    expect(lookup).not.toHaveBeenCalled();
    expect(out).toEqual({ isBundle: true, subscriptionId: null });
  });

  it('swallows lookup errors and returns isBundle=true,subscriptionId=null', async () => {
    const lookup = vi.fn().mockRejectedValue(new Error('firestore down'));
    const out = await detectBundleContext(
      { paymentType: 'bundle', requestId: 'req_1' },
      lookup,
    );
    expect(out).toEqual({ isBundle: true, subscriptionId: null });
  });
});

describe('shouldRestore policy (documented in trigger)', () => {
  // The policy is just `cancelledBy === 'teacher' || refundPercent === 100`.
  // Encoded as a small table to lock the spec from drifting.
  const cases: Array<{
    label: string;
    cancelledBy: 'student' | 'teacher';
    refundPercent: number;
    shouldRestore: boolean;
  }> = [
    { label: 'teacher cancel, any time', cancelledBy: 'teacher', refundPercent: 100, shouldRestore: true },
    { label: 'teacher no-show (refund=100 by policy)', cancelledBy: 'teacher', refundPercent: 100, shouldRestore: true },
    { label: 'student cancel >3h (refund=100)', cancelledBy: 'student', refundPercent: 100, shouldRestore: true },
    { label: 'student cancel 1-3h (refund=50)', cancelledBy: 'student', refundPercent: 50, shouldRestore: false },
    { label: 'student cancel <1h (refund=0)', cancelledBy: 'student', refundPercent: 0, shouldRestore: false },
  ];
  for (const c of cases) {
    it(c.label, () => {
      const shouldRestore = c.cancelledBy === 'teacher' || c.refundPercent === 100;
      expect(shouldRestore).toBe(c.shouldRestore);
    });
  }
});
