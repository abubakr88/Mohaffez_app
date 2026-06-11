// functions/src/wallet/walletUtils.ts
//
// Core wallet primitives. All wallet mutations go through `postLedgerEntry`
// inside a Firestore transaction. Single-entry writes are never allowed.

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import {
  AdminPermission,
  requireAdminAccess,
} from '../utils/adminPermissions';

export type OwnerType = 'student' | 'mohaffez' | 'system';

export type TxType =
  | 'topup'              // external money → user wallet (via system_topups)
  | 'session_payment'    // student wallet → teacher wallet + system_revenue
  | 'session_refund'     // reverse of session_payment
  | 'cycle_settlement'   // teacher pending → teacher available + system_revenue
  | 'payout'             // teacher wallet → system_payouts (then bank)
  | 'payout_reversal'    // failed payout, money back to teacher
  | 'promo_credit'       // system → user (signup bonus, referral, etc.)
  | 'direct_session_commission'         // cash session: teacher pending -X, system +X
  | 'direct_session_commission_reversal' // cancelled cash session: reverse the above
  | 'adjustment'         // admin manual fix; reason required
  | 'commission_rate_change' // informational: tier changed or penalty reset at settlement
  | 'penalty_applied';   // informational: cancellation/no-show penalty incremented

/**
 * Which "bucket" of a wallet a ledger leg targets.
 * - 'available' (default): standard balance. Withdrawable. Past, settled
 *   earnings live here, plus refunds, top-ups, promo credits.
 * - 'pending': teacher-only, holds gross earnings of the CURRENT commission
 *   cycle. Not withdrawable. Drained to `available` (net of commission) by
 *   the bi-weekly `recomputeTeacherTiers` settlement step.
 * - 'dues': teacher-only, accumulates commission OWED to the platform from
 *   direct-payment (cash) sessions. Negative values mean the teacher owes.
 *   Drained at settlement against the teacher's available balance; any
 *   remaining debt rolls forward into the next cycle.
 */
export type LedgerTarget = 'available' | 'pending' | 'dues';

export interface WalletDoc {
  ownerId: string;
  ownerType: OwnerType;
  balancePiastres: number;
  /** Teacher-only. Gross earnings of current cycle, awaiting commission deduction. */
  pendingCyclePiastres?: number;
  /**
   * Teacher-only. Accumulated commission OWED to the platform from
   * direct-payment (cash) sessions this cycle. Negative when the teacher
   * owes; zeroed at settlement (debt drained from available, leftover
   * rolls forward as a still-negative value).
   */
  directCommissionOwedPiastres?: number;
  /** Teacher-only. Last time the cycle settlement ran on this wallet. */
  lastSettledAt?: admin.firestore.FieldValue | admin.firestore.Timestamp | null;
  currency: 'EGP';
  createdAt: admin.firestore.FieldValue | admin.firestore.Timestamp;
  updatedAt: admin.firestore.FieldValue | admin.firestore.Timestamp;
}

// Fixed system wallet IDs. Negative balances on these are normal and meaningful.
export const SYSTEM_WALLETS = {
  topups:   'system_topups',   // mirrors external money coming in
  revenue:  'system_revenue',  // platform commission accrual
  payouts:  'system_payouts',  // money queued/sent to teachers
  promos:   'system_promos',   // marketing/referral spend
} as const;

export type SystemWalletId = typeof SYSTEM_WALLETS[keyof typeof SYSTEM_WALLETS];

/** Convert EGP (as float from client) to integer piastres. Rejects bad input. */
export function egpToPiastres(amountEgp: number): number {
  if (typeof amountEgp !== 'number' || !Number.isFinite(amountEgp) || amountEgp <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'amount must be a positive number');
  }
  // Round to nearest piastre to absorb floating-point drift from the client.
  const piastres = Math.round(amountEgp * 100);
  if (piastres <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'amount too small');
  }
  return piastres;
}

export function walletIdForUser(userId: string): string {
  if (!userId || typeof userId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'userId required');
  }
  return userId;
}

/**
 * Read wallet inside a transaction; create it on first touch.
 * Always read before write — Firestore transaction rule.
 */
export async function readOrCreateWallet(
  tx: FirebaseFirestore.Transaction,
  walletId: string,
  ownerType: OwnerType,
): Promise<{ ref: FirebaseFirestore.DocumentReference; data: WalletDoc; existed: boolean }> {
  const ref = db.collection('wallets').doc(walletId);
  const snap = await tx.get(ref);
  if (snap.exists) {
    return { ref, data: snap.data() as WalletDoc, existed: true };
  }
  const fresh: WalletDoc = {
    ownerId: walletId,
    ownerType,
    balancePiastres: 0,
    pendingCyclePiastres: 0,
    directCommissionOwedPiastres: 0,
    lastSettledAt: null,
    currency: 'EGP',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  return { ref, data: fresh, existed: false };
}

export interface LedgerLeg {
  walletId: string;
  ownerType: OwnerType;
  /** Signed: negative = debit, positive = credit. */
  amountPiastres: number;
  /**
   * Which sub-balance to touch. Defaults to 'available'. Use 'pending' for
   * mid-cycle teacher session credits and for the settlement-time debit.
   */
  target?: LedgerTarget;
}

export interface LedgerEntryInput {
  type: TxType;
  /** All legs must net to zero. */
  legs: LedgerLeg[];
  reason: string;
  /** Optional cross-references for audit + UI. */
  relatedSessionId?: string | null;
  relatedPaymentId?: string | null;
  relatedPayoutId?: string | null;
  /**
   * Idempotency key. If a transaction with this groupId already exists, the
   * call returns early. Required for any operation triggered by user input
   * that could be replayed (network retry, double-tap).
   */
  groupId: string;
  /** UID of the actor (caller for callables, 'system' for triggers). */
  createdBy: string;
  /** Free-form metadata; do not put PII here. */
  metadata?: Record<string, unknown>;
}

/** Opaque result of the reads phase of a ledger entry. Pass to commitLedgerEntry. */
export interface LedgerPrep {
  groupRef: FirebaseFirestore.DocumentReference;
  walletStates: Array<{ ref: FirebaseFirestore.DocumentReference; data: WalletDoc; existed: boolean }>;
  alreadyPosted: boolean;
}

/**
 * Phase 1: perform all reads for a ledger entry (idempotency check + wallet
 * state). Must be called before any writes in the enclosing transaction.
 * Pass the returned LedgerPrep to commitLedgerEntry once all other reads are
 * done and before any writes start.
 */
export async function prepareLedgerEntry(
  tx: FirebaseFirestore.Transaction,
  input: LedgerEntryInput,
): Promise<LedgerPrep> {
  if (!input.legs || input.legs.length < 2) {
    throw new functions.https.HttpsError('invalid-argument', 'ledger entry needs at least two legs');
  }
  const net = input.legs.reduce((sum, l) => sum + l.amountPiastres, 0);
  if (net !== 0) {
    throw new functions.https.HttpsError('internal', `ledger legs do not balance: net=${net}`);
  }
  for (const leg of input.legs) {
    if (!Number.isInteger(leg.amountPiastres) || leg.amountPiastres === 0) {
      throw new functions.https.HttpsError('internal', 'leg amount must be non-zero integer piastres');
    }
    if (!leg.walletId) {
      throw new functions.https.HttpsError('internal', 'leg missing walletId');
    }
  }

  const groupRef = db.collection('walletTransactionGroups').doc(input.groupId);
  const groupSnap = await tx.get(groupRef);
  if (groupSnap.exists) {
    return { groupRef, walletStates: [], alreadyPosted: true };
  }

  const walletStates = await Promise.all(
    input.legs.map((leg) => readOrCreateWallet(tx, leg.walletId, leg.ownerType)),
  );
  return { groupRef, walletStates, alreadyPosted: false };
}

/**
 * Phase 2: apply all writes for a ledger entry using pre-read state from
 * prepareLedgerEntry. Call this after all reads in the transaction are done.
 */
export function commitLedgerEntry(
  tx: FirebaseFirestore.Transaction,
  input: LedgerEntryInput,
  prep: LedgerPrep,
): { groupId: string; idempotent: boolean } {
  if (prep.alreadyPosted) {
    return { groupId: input.groupId, idempotent: true };
  }

  for (let i = 0; i < input.legs.length; i++) {
    const leg = input.legs[i];
    const state = prep.walletStates[i];
    const target: LedgerTarget = leg.target ?? 'available';

    if ((target === 'pending' || target === 'dues') && state.data.ownerType !== 'mohaffez') {
      throw new functions.https.HttpsError(
        'internal',
        `${target} bucket only valid for mohaffez wallets (leg ${i} → ${leg.walletId})`,
      );
    }

    const currentAvailable = state.data.balancePiastres;
    const currentPending = state.data.pendingCyclePiastres ?? 0;
    const currentDues = state.data.directCommissionOwedPiastres ?? 0;
    const newAvailable =
      target === 'available' ? currentAvailable + leg.amountPiastres : currentAvailable;
    const newPending =
      target === 'pending' ? currentPending + leg.amountPiastres : currentPending;
    const newDues =
      target === 'dues' ? currentDues + leg.amountPiastres : currentDues;

    if (state.data.ownerType !== 'system' && newAvailable < 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `insufficient balance in wallet ${leg.walletId}`,
      );
    }
    if (newPending < 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `insufficient pending balance in wallet ${leg.walletId}`,
      );
    }
    // `dues` is allowed to be negative — that IS the debt.

    if (state.existed) {
      const update: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
      if (target === 'available') update.balancePiastres = newAvailable;
      if (target === 'pending') update.pendingCyclePiastres = newPending;
      if (target === 'dues') update.directCommissionOwedPiastres = newDues;
      tx.update(state.ref, update);
    } else {
      tx.set(state.ref, {
        ...state.data,
        balancePiastres: newAvailable,
        pendingCyclePiastres: newPending,
        directCommissionOwedPiastres: newDues,
      });
    }
  }

  tx.set(prep.groupRef, {
    type: input.type,
    reason: input.reason,
    legCount: input.legs.length,
    netPiastres: 0,
    relatedSessionId: input.relatedSessionId ?? null,
    relatedPaymentId: input.relatedPaymentId ?? null,
    relatedPayoutId: input.relatedPayoutId ?? null,
    createdBy: input.createdBy,
    createdAt: FieldValue.serverTimestamp(),
    metadata: input.metadata ?? null,
  });

  for (let i = 0; i < input.legs.length; i++) {
    const leg = input.legs[i];
    const txRef = db.collection('walletTransactions').doc();
    tx.set(txRef, {
      groupId: input.groupId,
      walletId: leg.walletId,
      ownerType: leg.ownerType,
      amountPiastres: leg.amountPiastres,
      target: leg.target ?? 'available',
      type: input.type,
      reason: input.reason,
      relatedSessionId: input.relatedSessionId ?? null,
      relatedPaymentId: input.relatedPaymentId ?? null,
      relatedPayoutId: input.relatedPayoutId ?? null,
      createdBy: input.createdBy,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return { groupId: input.groupId, idempotent: false };
}

/**
 * Post a ledger entry atomically. All legs and wallet balance updates land
 * in the same Firestore transaction the caller passes in. Throws if legs
 * don't balance to zero.
 *
 * NOTE: This function performs reads then writes internally. It is safe to
 * call only when no other writes have been issued in the transaction yet.
 * If you need to interleave ledger writes with other writes, use
 * prepareLedgerEntry + commitLedgerEntry separately.
 */
export async function postLedgerEntry(
  tx: FirebaseFirestore.Transaction,
  input: LedgerEntryInput,
): Promise<{ groupId: string; idempotent: boolean }> {
  const prep = await prepareLedgerEntry(tx, input);
  return commitLedgerEntry(tx, input, prep);
}

/**
 * Post an informational wallet event (no money movement).
 * Writes to walletTransactionGroups + walletTransactions with amountPiastres=0
 * so the teacher can see it in their transaction history.
 * Idempotent: a second call with the same eventId is a no-op.
 */
export async function postWalletEvent(
  teacherId: string,
  event: {
    type: 'commission_rate_change' | 'penalty_applied';
    eventId: string;
    reason: string;
    metadata: Record<string, unknown>;
  },
): Promise<void> {
  const groupRef = db.collection('walletTransactionGroups').doc(event.eventId);
  const txRef = db.collection('walletTransactions').doc();
  try {
    await db.runTransaction(async (tx) => {
      const groupSnap = await tx.get(groupRef);
      if (groupSnap.exists) return;
      tx.set(groupRef, {
        type: event.type,
        reason: event.reason,
        legCount: 1,
        netPiastres: 0,
        relatedSessionId: null,
        relatedPaymentId: null,
        relatedPayoutId: null,
        createdBy: 'system',
        createdAt: FieldValue.serverTimestamp(),
        metadata: event.metadata,
      });
      tx.set(txRef, {
        groupId: event.eventId,
        walletId: walletIdForUser(teacherId),
        ownerType: 'mohaffez',
        amountPiastres: 0,
        target: 'available',
        type: event.type,
        reason: event.reason,
        relatedSessionId: null,
        relatedPaymentId: null,
        relatedPayoutId: null,
        createdBy: 'system',
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    functions.logger.warn('postWalletEvent failed', { teacherId, eventId: event.eventId, err });
  }
}

/** Guard: callable is admin (custom claim) or throws.
 *
 * Custom claim only — Firestore security rules also require the claim
 * (not a `users/{uid}.role` field). Keeping these two checks aligned
 * prevents the confusing state where an admin can call a callable but
 * can't read the data the callable produces. To make a user admin, call
 * the `setAdminClaim` Cloud Function.
 */
export async function requireAdmin(
  context: functions.https.CallableContext,
  permission: AdminPermission = 'manageFinance',
): Promise<string> {
  return (await requireAdminAccess(context, permission)).uid;
}
