// functions/src/wallet/walletPayout.ts
//
// Teacher payout state machine:
//   requested → processing → completed | failed
//
// requestPayout:  teacher creates a payoutRequest; money is NOT debited yet
//                 (so balance still shows in-wallet until admin processes it).
// startPayout:    admin moves request to 'processing' AND debits teacher wallet
//                 → credits system_payouts. After this, admin sends the bank
//                 transfer offline.
// completePayout: admin confirms the bank transfer succeeded. Marks the
//                 request 'completed'. No ledger change (money already left
//                 the teacher's wallet at startPayout).
// failPayout:     admin marks bank transfer failed. Reverses the ledger leg
//                 (refund teacher wallet from system_payouts).

import * as functions from 'firebase-functions';
import { db, FieldValue } from '../utils/admin';
import {
  postLedgerEntry,
  egpToPiastres,
  walletIdForUser,
  SYSTEM_WALLETS,
  requireAdmin,
} from './walletUtils';

const MIN_PAYOUT_EGP = 50;

export const requestPayout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'login required');
  }
  const mohaffezId = context.auth.uid;

  const userDoc = await db.collection('users').doc(mohaffezId).get();
  if (userDoc.data()?.role !== 'mohaffez') {
    throw new functions.https.HttpsError('permission-denied', 'teachers only');
  }

  const { amountEgp, method, accountDetails } = data as {
    amountEgp: number;
    method: 'instapay' | 'vodafone_cash' | 'bank_transfer';
    accountDetails: string; // phone or IBAN, displayed to admin
  };

  if (amountEgp < MIN_PAYOUT_EGP) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `الحد الأدنى للسحب ${MIN_PAYOUT_EGP} ج.م`,
    );
  }
  if (!method || !accountDetails || accountDetails.trim().length < 5) {
    throw new functions.https.HttpsError('invalid-argument', 'method + accountDetails required');
  }

  const piastres = egpToPiastres(amountEgp);

  return db.runTransaction(async (tx) => {
    // Pre-check available balance only — pending (current-cycle) earnings
    // are NOT withdrawable until the bi-weekly settlement runs and moves
    // them into available. This is the "no mid-cycle withdrawals" rule.
    const walletRef = db.collection('wallets').doc(walletIdForUser(mohaffezId));
    const walletSnap = await tx.get(walletRef);
    const balance = (walletSnap.data()?.balancePiastres as number) ?? 0;
    const pending = (walletSnap.data()?.pendingCyclePiastres as number) ?? 0;
    if (balance < piastres) {
      const pendingNote = pending > 0
        ? ` (لديك ${(pending / 100).toFixed(2)} ج.م قيد التسوية — تُتاح بعد نهاية الدورة الحالية)`
        : '';
      throw new functions.https.HttpsError(
        'failed-precondition',
        `الرصيد المتاح للسحب ${(balance / 100).toFixed(2)} ج.م${pendingNote}`,
      );
    }

    const payoutRef = db.collection('payoutRequests').doc();
    tx.set(payoutRef, {
      mohaffezId,
      mohaffezName: userDoc.data()?.name ?? '',
      amountEgp,
      amountPiastres: piastres,
      method,
      accountDetails: accountDetails.trim(),
      status: 'requested',
      ledgerGroupId: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Notify admins.
    const adminSnap = await db.collection('users').where('role', '==', 'admin').get();
    for (const adminDoc of adminSnap.docs) {
      const notifRef = db.collection('notifications').doc();
      tx.set(notifRef, {
        userId: adminDoc.id,
        recipientId: adminDoc.id,
        senderId: mohaffezId,
        title: 'طلب سحب رصيد جديد',
        body: `${userDoc.data()?.name ?? 'محفظ'} طلب سحب ${amountEgp} ج.م`,
        type: 'payout_requested',
        isRead: false,
        data: {
          payoutRequestId: payoutRef.id,
          mohaffezId,
          amountEgp: amountEgp.toString(),
        },
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return { success: true, payoutRequestId: payoutRef.id };
  });
});

export const startPayout = functions.https.onCall(async (data, context) => {
  const adminUid = await requireAdmin(context);
  const { payoutRequestId } = data as { payoutRequestId: string };
  if (!payoutRequestId) {
    throw new functions.https.HttpsError('invalid-argument', 'payoutRequestId required');
  }

  return db.runTransaction(async (tx) => {
    const payoutRef = db.collection('payoutRequests').doc(payoutRequestId);
    const payoutSnap = await tx.get(payoutRef);
    if (!payoutSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'payout request not found');
    }
    const p = payoutSnap.data()!;
    if (p.status !== 'requested') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `cannot start payout with status: ${p.status}`,
      );
    }

    const result = await postLedgerEntry(tx, {
      type: 'payout',
      legs: [
        {
          walletId: walletIdForUser(p.mohaffezId as string),
          ownerType: 'mohaffez',
          amountPiastres: -(p.amountPiastres as number),
        },
        {
          walletId: SYSTEM_WALLETS.payouts,
          ownerType: 'system',
          amountPiastres: p.amountPiastres as number,
        },
      ],
      reason: `Payout via ${p.method as string}`,
      relatedPayoutId: payoutRequestId,
      groupId: `payout_${payoutRequestId}`,
      createdBy: adminUid,
    });

    tx.update(payoutRef, {
      status: 'processing',
      ledgerGroupId: result.groupId,
      startedAt: FieldValue.serverTimestamp(),
      startedBy: adminUid,
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { success: true, groupId: result.groupId };
  });
});

export const completePayout = functions.https.onCall(async (data, context) => {
  const adminUid = await requireAdmin(context);
  const { payoutRequestId, bankReference } = data as {
    payoutRequestId: string;
    bankReference?: string;
  };
  if (!payoutRequestId) {
    throw new functions.https.HttpsError('invalid-argument', 'payoutRequestId required');
  }

  return db.runTransaction(async (tx) => {
    const payoutRef = db.collection('payoutRequests').doc(payoutRequestId);
    const payoutSnap = await tx.get(payoutRef);
    if (!payoutSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'payout request not found');
    }
    const p = payoutSnap.data()!;
    if (p.status === 'completed') {
      return { success: true, message: 'already completed' };
    }
    if (p.status !== 'processing') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `cannot complete payout with status: ${p.status}`,
      );
    }

    tx.update(payoutRef, {
      status: 'completed',
      completedAt: FieldValue.serverTimestamp(),
      completedBy: adminUid,
      bankReference: bankReference ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Notify teacher.
    const notifRef = db.collection('notifications').doc();
    tx.set(notifRef, {
      userId: p.mohaffezId,
      recipientId: p.mohaffezId,
      senderId: adminUid,
      title: 'تم تحويل السحب',
      body: `تم تحويل مبلغ ${p.amountEgp} ج.م إلى ${p.accountDetails}`,
      type: 'payout_completed',
      isRead: false,
      data: { payoutRequestId, bankReference: bankReference ?? '' },
      createdAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
});

export const failPayout = functions.https.onCall(async (data, context) => {
  const adminUid = await requireAdmin(context);
  const { payoutRequestId, reason } = data as {
    payoutRequestId: string;
    reason: string;
  };
  if (!payoutRequestId || !reason) {
    throw new functions.https.HttpsError('invalid-argument', 'payoutRequestId + reason required');
  }

  return db.runTransaction(async (tx) => {
    const payoutRef = db.collection('payoutRequests').doc(payoutRequestId);
    const payoutSnap = await tx.get(payoutRef);
    if (!payoutSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'payout request not found');
    }
    const p = payoutSnap.data()!;
    if (p.status === 'failed') return { success: true, message: 'already failed' };
    if (p.status !== 'processing') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `cannot fail payout with status: ${p.status}`,
      );
    }

    // Reverse the original payout ledger entry.
    const result = await postLedgerEntry(tx, {
      type: 'payout_reversal',
      legs: [
        {
          walletId: walletIdForUser(p.mohaffezId as string),
          ownerType: 'mohaffez',
          amountPiastres: p.amountPiastres as number,
        },
        {
          walletId: SYSTEM_WALLETS.payouts,
          ownerType: 'system',
          amountPiastres: -(p.amountPiastres as number),
        },
      ],
      reason: `Payout failed: ${reason}`,
      relatedPayoutId: payoutRequestId,
      groupId: `payout_reversal_${payoutRequestId}`,
      createdBy: adminUid,
    });

    tx.update(payoutRef, {
      status: 'failed',
      failedAt: FieldValue.serverTimestamp(),
      failedBy: adminUid,
      failureReason: reason,
      reversalLedgerGroupId: result.groupId,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Notify teacher.
    const notifRef = db.collection('notifications').doc();
    tx.set(notifRef, {
      userId: p.mohaffezId,
      recipientId: p.mohaffezId,
      senderId: adminUid,
      title: 'تعذر تحويل السحب',
      body: `تعذر تحويل ${p.amountEgp} ج.م — رُجع المبلغ إلى محفظتك. السبب: ${reason}`,
      type: 'payout_failed',
      isRead: false,
      data: { payoutRequestId, reason },
      createdAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
});
