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
import { writeAdminAuditLog } from '../utils/auditLog';
import { resolveBaseRateFromData } from '../utils/commissionRate';

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
    //
    // Dues-vs-pending solvency: a teacher whose `available` is short of
    // their dues can still withdraw if the current cycle's net earnings
    // (pending − commission) will more than cover the dues at settlement.
    // The platform recovers the dues either way, so blocking would only
    // hurt liquidity. Only block when:
    //   available + pendingNet − dues < requested
    // (i.e., even after pending settles and pays the dues, the post-
    // settlement balance can't cover this withdrawal.)
    const [walletSnap, teacherSnap, cfgSnap] = await Promise.all([
      tx.get(db.collection('wallets').doc(walletIdForUser(mohaffezId))),
      tx.get(db.collection('users').doc(mohaffezId)),
      tx.get(db.collection('systemConfig').doc('global')),
    ]);
    const balance = (walletSnap.data()?.balancePiastres as number) ?? 0;
    const pending = (walletSnap.data()?.pendingCyclePiastres as number) ?? 0;
    // `directCommissionOwedPiastres` is ≤ 0 when teacher owes (debt = -dues).
    const dues = (walletSnap.data()?.directCommissionOwedPiastres as number) ?? 0;
    const debt = dues < 0 ? -dues : 0;

    // Effective commission rate: per-teacher tier rate + cycle penalty,
    // falling back to the starter tier. Mirrors resolveTeacherRate logic but inlined
    // because that helper does its own reads outside our transaction.
    const baseRate = resolveBaseRateFromData(teacherSnap.data(), cfgSnap.data());
    const rawPenalty = teacherSnap.data()?.commissionPenaltyPercent;
    const penaltyPct =
      typeof rawPenalty === 'number' && isFinite(rawPenalty) && rawPenalty >= 0
        ? rawPenalty
        : 0;
    const effectiveRate = Math.min(baseRate + penaltyPct / 100, 1.0);
    const pendingNet = Math.round(pending * (1 - effectiveRate));
    const projected = balance + pendingNet - debt; // post-settlement net

    if (balance < piastres) {
      const pendingNote = pending > 0
        ? ` (لديك ${(pending / 100).toFixed(2)} ج.م قيد التسوية — تُتاح بعد نهاية الدورة الحالية)`
        : '';
      throw new functions.https.HttpsError(
        'failed-precondition',
        `الرصيد المتاح للسحب ${(balance / 100).toFixed(2)} ج.م${pendingNote}`,
      );
    }

    if (debt > 0 && projected < piastres) {
      const projectedDisplay = (Math.max(projected, 0) / 100).toFixed(2);
      throw new functions.https.HttpsError(
        'failed-precondition',
        `لديك مستحقات للمنصة (${(debt / 100).toFixed(2)} ج.م) أكبر من ` +
          `الرصيد المتاح + صافي الدورة الحالية. الحد الأقصى للسحب: ` +
          `${projectedDisplay} ج.م. يمكنك شحن المحفظة لسداد المستحقات.`,
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

  const result = await db.runTransaction(async (tx) => {
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

  await writeAdminAuditLog({
    action: 'startPayout',
    actorId: adminUid,
    targetId: payoutRequestId,
    targetType: 'payout_request',
    data: { groupId: result.groupId },
    context,
  });

  return result;
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

  const result = await db.runTransaction(async (tx) => {
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

  await writeAdminAuditLog({
    action: 'completePayout',
    actorId: adminUid,
    targetId: payoutRequestId,
    targetType: 'payout_request',
    data: { bankReference: bankReference ?? null, result },
    context,
  });

  return result;
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

  const result = await db.runTransaction(async (tx) => {
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

  await writeAdminAuditLog({
    action: 'failPayout',
    actorId: adminUid,
    targetId: payoutRequestId,
    targetType: 'payout_request',
    reason,
    data: { reason, result },
    context,
  });

  return result;
});
