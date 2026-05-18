// functions/src/wallet/walletTopUp.ts
//
// Admin marks a manual bank/wallet transfer as verified → credits the user's
// wallet. This is the "money comes in" entry point while there's no payment
// gateway integration. When Paymob is wired in, a webhook-triggered version
// will use the same postLedgerEntry primitive.

import * as functions from 'firebase-functions';
import { db } from '../utils/admin';
import {
  postLedgerEntry,
  egpToPiastres,
  walletIdForUser,
  SYSTEM_WALLETS,
  requireAdmin,
} from './walletUtils';

interface VerifyTopUpRequest {
  topUpRequestId: string;     // the pending top-up doc the user submitted
  paidAmountEgp?: number;     // override if admin verified a different amount
  adminNote?: string;
}

/**
 * Two-step flow:
 *  1. User submits a topUpRequest with proof (handled by a separate callable
 *     or direct write — out of scope here; the doc just needs to exist).
 *  2. Admin calls verifyWalletTopUp once they've confirmed the transfer.
 */
export const verifyWalletTopUp = functions.https.onCall(async (data, context) => {
  const adminUid = await requireAdmin(context);

  const { topUpRequestId, paidAmountEgp, adminNote } = data as VerifyTopUpRequest;
  if (!topUpRequestId) {
    throw new functions.https.HttpsError('invalid-argument', 'topUpRequestId required');
  }

  return db.runTransaction(async (tx) => {
    const reqRef = db.collection('topUpRequests').doc(topUpRequestId);
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'top-up request not found');
    }

    const req = reqSnap.data()!;
    if (req.status === 'verified') {
      return { success: true, message: 'already verified', groupId: req.ledgerGroupId };
    }
    if (req.status !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `cannot verify request with status: ${req.status}`,
      );
    }

    const userId = req.userId as string;
    const ownerType = req.ownerType as 'student' | 'mohaffez';
    const finalAmountEgp = (paidAmountEgp ?? req.amountEgp) as number;
    const piastres = egpToPiastres(finalAmountEgp);

    const result = await postLedgerEntry(tx, {
      type: 'topup',
      legs: [
        { walletId: SYSTEM_WALLETS.topups, ownerType: 'system', amountPiastres: -piastres },
        { walletId: walletIdForUser(userId), ownerType, amountPiastres: piastres },
      ],
      reason: adminNote || 'Manual transfer verified',
      relatedPaymentId: topUpRequestId,
      groupId: `topup_${topUpRequestId}`,
      createdBy: adminUid,
      metadata: {
        method: req.method ?? null,
        reference: req.referenceNumber ?? null,
      },
    });

    tx.update(reqRef, {
      status: 'verified',
      verifiedBy: adminUid,
      verifiedAt: new Date(),
      verifiedAmountEgp: finalAmountEgp,
      adminNote: adminNote ?? null,
      ledgerGroupId: result.groupId,
    });

    return { success: true, groupId: result.groupId, idempotent: result.idempotent };
  });
});

/**
 * Admin rejects a pending top-up request (e.g. couldn't find the transfer,
 * suspicious activity). No ledger movement — request is marked 'rejected'
 * with a reason so the user can see why.
 */
export const rejectWalletTopUp = functions.https.onCall(async (data, context) => {
  const adminUid = await requireAdmin(context);
  const { topUpRequestId, reason } = data as {
    topUpRequestId: string;
    reason: string;
  };
  if (!topUpRequestId || !reason || reason.trim().length < 3) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'topUpRequestId + reason required',
    );
  }

  return db.runTransaction(async (tx) => {
    const reqRef = db.collection('topUpRequests').doc(topUpRequestId);
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'top-up request not found');
    }
    const req = reqSnap.data()!;
    if (req.status === 'verified') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'cannot reject a verified top-up',
      );
    }
    if (req.status === 'rejected') {
      return { success: true, message: 'already rejected' };
    }

    tx.update(reqRef, {
      status: 'rejected',
      rejectedBy: adminUid,
      rejectedAt: new Date(),
      rejectionReason: reason.trim(),
    });

    // Notify user.
    const notifRef = db.collection('notifications').doc();
    tx.set(notifRef, {
      userId: req.userId,
      recipientId: req.userId,
      senderId: adminUid,
      title: 'تم رفض طلب الشحن',
      body: `لم يتم تأكيد تحويلك بقيمة ${req.amountEgp} ج.م. السبب: ${reason.trim()}`,
      type: 'topup_rejected',
      isRead: false,
      data: { topUpRequestId, reason: reason.trim() },
      createdAt: new Date(),
    });

    return { success: true };
  });
});

/**
 * Admin can also credit a wallet directly without a pending request doc
 * (e.g. promo, refund of an out-of-band issue). Always requires a reason.
 */
export const adminCreditWallet = functions.https.onCall(async (data, context) => {
  const adminUid = await requireAdmin(context);

  const { userId, ownerType, amountEgp, reason, type } = data as {
    userId: string;
    ownerType: 'student' | 'mohaffez';
    amountEgp: number;
    reason: string;
    type?: 'promo_credit' | 'adjustment';
  };

  if (!userId || !ownerType || !reason || reason.trim().length < 3) {
    throw new functions.https.HttpsError('invalid-argument', 'userId, ownerType, reason required');
  }

  const piastres = egpToPiastres(amountEgp);
  const sourceWallet = type === 'promo_credit' ? SYSTEM_WALLETS.promos : SYSTEM_WALLETS.topups;
  const txType = type === 'promo_credit' ? 'promo_credit' : 'adjustment';

  return db.runTransaction(async (tx) => {
    const result = await postLedgerEntry(tx, {
      type: txType,
      legs: [
        { walletId: sourceWallet, ownerType: 'system', amountPiastres: -piastres },
        { walletId: walletIdForUser(userId), ownerType, amountPiastres: piastres },
      ],
      reason: reason.trim(),
      groupId: `admin_credit_${Date.now()}_${userId}`,
      createdBy: adminUid,
    });
    return { success: true, groupId: result.groupId };
  });
});
