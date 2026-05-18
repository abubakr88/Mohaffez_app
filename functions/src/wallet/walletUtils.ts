// functions/src/wallet/walletUtils.ts
//
// Core wallet primitives. All wallet mutations go through `postLedgerEntry`
// inside a Firestore transaction. Single-entry writes are never allowed.

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';

export type OwnerType = 'student' | 'mohaffez' | 'system';

export type TxType =
  | 'topup'              // external money → user wallet (via system_topups)
  | 'session_payment'    // student wallet → teacher wallet + system_revenue
  | 'session_refund'     // reverse of session_payment
  | 'payout'             // teacher wallet → system_payouts (then bank)
  | 'payout_reversal'    // failed payout, money back to teacher
  | 'promo_credit'       // system → user (signup bonus, referral, etc.)
  | 'adjustment';        // admin manual fix; reason required

export interface WalletDoc {
  ownerId: string;
  ownerType: OwnerType;
  balancePiastres: number;
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

/**
 * Post a ledger entry atomically. All legs and wallet balance updates land
 * in the same Firestore transaction the caller passes in. Throws if legs
 * don't balance to zero.
 */
export async function postLedgerEntry(
  tx: FirebaseFirestore.Transaction,
  input: LedgerEntryInput,
): Promise<{ groupId: string; idempotent: boolean }> {
  if (!input.legs || input.legs.length < 2) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'ledger entry needs at least two legs',
    );
  }

  const net = input.legs.reduce((sum, l) => sum + l.amountPiastres, 0);
  if (net !== 0) {
    throw new functions.https.HttpsError(
      'internal',
      `ledger legs do not balance: net=${net}`,
    );
  }

  for (const leg of input.legs) {
    if (!Number.isInteger(leg.amountPiastres) || leg.amountPiastres === 0) {
      throw new functions.https.HttpsError(
        'internal',
        'leg amount must be non-zero integer piastres',
      );
    }
    if (!leg.walletId) {
      throw new functions.https.HttpsError('internal', 'leg missing walletId');
    }
  }

  // Idempotency: check if this groupId was already posted.
  const groupRef = db.collection('walletTransactionGroups').doc(input.groupId);
  const groupSnap = await tx.get(groupRef);
  if (groupSnap.exists) {
    return { groupId: input.groupId, idempotent: true };
  }

  // Read all affected wallets up front (Firestore: all reads before writes).
  const walletStates = await Promise.all(
    input.legs.map((leg) => readOrCreateWallet(tx, leg.walletId, leg.ownerType)),
  );

  // Apply balance changes and check non-negative for user wallets.
  for (let i = 0; i < input.legs.length; i++) {
    const leg = input.legs[i];
    const state = walletStates[i];
    const newBalance = state.data.balancePiastres + leg.amountPiastres;
    if (state.data.ownerType !== 'system' && newBalance < 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `insufficient balance in wallet ${leg.walletId}`,
      );
    }
    if (state.existed) {
      tx.update(state.ref, {
        balancePiastres: newBalance,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(state.ref, { ...state.data, balancePiastres: newBalance });
    }
  }

  // Write the group marker (idempotency lock).
  tx.set(groupRef, {
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

  // Write one walletTransactions row per leg. These are the queryable ledger
  // entries. The group marker exists only for idempotency + reason lookup.
  for (let i = 0; i < input.legs.length; i++) {
    const leg = input.legs[i];
    const txRef = db.collection('walletTransactions').doc();
    tx.set(txRef, {
      groupId: input.groupId,
      walletId: leg.walletId,
      ownerType: leg.ownerType,
      amountPiastres: leg.amountPiastres,
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

/** Guard: callable is admin (custom claim) or throws.
 *
 * Custom claim only — Firestore security rules also require the claim
 * (not a `users/{uid}.role` field). Keeping these two checks aligned
 * prevents the confusing state where an admin can call a callable but
 * can't read the data the callable produces. To make a user admin, call
 * the `setAdminClaim` Cloud Function.
 */
export async function requireAdmin(context: functions.https.CallableContext): Promise<string> {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'login required');
  }
  const isAdminClaim =
    context.auth.token.admin === true || context.auth.token.role === 'admin';
  if (!isAdminClaim) {
    throw new functions.https.HttpsError('permission-denied', 'admin only');
  }
  return context.auth.uid;
}
