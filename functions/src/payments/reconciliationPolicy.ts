export const PAYMOB_RECONCILIATION_SCHEDULE = 'every 5 minutes';
export const PAYMOB_RECONCILIATION_LOOKBACK_MS = 24 * 60 * 60 * 1000;
export const PAYMOB_RECONCILIATION_BATCH_SIZE = 10;

export function paymobReconciliationCutoffMillis(
  nowMillis = Date.now(),
): number {
  return nowMillis - PAYMOB_RECONCILIATION_LOOKBACK_MS;
}

export function buildRecentPendingPaymentsQuery(
  collection: FirebaseFirestore.CollectionReference,
  cutoff: FirebaseFirestore.Timestamp,
): FirebaseFirestore.Query {
  return collection
    .where('status', '==', 'pending')
    .where('createdAt', '>=', cutoff)
    .orderBy('createdAt', 'desc')
    .limit(PAYMOB_RECONCILIATION_BATCH_SIZE);
}
