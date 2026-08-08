import { describe, expect, it, vi } from 'vitest';
import {
  buildRecentPendingPaymentsQuery,
  PAYMOB_RECONCILIATION_BATCH_SIZE,
  PAYMOB_RECONCILIATION_LOOKBACK_MS,
  PAYMOB_RECONCILIATION_SCHEDULE,
  paymobReconciliationCutoffMillis,
} from '../reconciliationPolicy';

describe('Paymob reconciliation policy', () => {
  it('uses a five-minute fallback with a bounded recent batch', () => {
    expect(PAYMOB_RECONCILIATION_SCHEDULE).toBe('every 5 minutes');
    expect(PAYMOB_RECONCILIATION_BATCH_SIZE).toBe(10);
    expect(PAYMOB_RECONCILIATION_LOOKBACK_MS).toBe(24 * 60 * 60 * 1000);
    expect(paymobReconciliationCutoffMillis(200_000_000)).toBe(
      200_000_000 - 24 * 60 * 60 * 1000,
    );
  });

  it('filters stale payments in Firestore before applying the limit', () => {
    const finalQuery = { kind: 'recent-pending-payments' };
    const limit = vi.fn().mockReturnValue(finalQuery);
    const orderBy = vi.fn().mockReturnValue({ limit });
    const createdAtWhere = vi.fn().mockReturnValue({ orderBy });
    const statusWhere = vi.fn().mockReturnValue({ where: createdAtWhere });
    const collection = {
      where: statusWhere,
    } as unknown as FirebaseFirestore.CollectionReference;
    const cutoff = { seconds: 123 } as unknown as FirebaseFirestore.Timestamp;

    const result = buildRecentPendingPaymentsQuery(collection, cutoff);

    expect(statusWhere).toHaveBeenCalledWith('status', '==', 'pending');
    expect(createdAtWhere).toHaveBeenCalledWith('createdAt', '>=', cutoff);
    expect(orderBy).toHaveBeenCalledWith('createdAt', 'desc');
    expect(limit).toHaveBeenCalledWith(10);
    expect(result).toBe(finalQuery);
  });
});
