// functions/src/wallet/walletPaySession.ts
//
// Student pays for a session from their wallet. Splits the amount: teacher
// gets (price - commission), platform revenue wallet gets commission. All
// in one Firestore transaction with the session marked paid + accepted.
//
// Idempotent on sessionRequestId — if you call twice for the same request,
// the second call is a no-op.

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import {
  postLedgerEntry,
  egpToPiastres,
  walletIdForUser,
  SYSTEM_WALLETS,
} from './walletUtils';
import {
  getWeekNumber,
  getWeekStart,
  getWeekEnd,
  getNextMonday,
} from '../utils/dateHelpers';

interface PayFromWalletRequest {
  sessionRequestId: string;
  /** Required when the sessionRequest doc has no paymentAmount yet
   *  (early bookings only get the price computed client-side). */
  amountEgp?: number;
}

export const payFromWallet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'login required');
  }
  const studentId = context.auth.uid;

  const { sessionRequestId, amountEgp: clientAmountEgp } =
    data as PayFromWalletRequest;
  if (!sessionRequestId) {
    throw new functions.https.HttpsError('invalid-argument', 'sessionRequestId required');
  }

  return db.runTransaction(async (tx) => {
    const reqRef = db.collection('sessionRequests').doc(sessionRequestId);
    const reqSnap = await tx.get(reqRef);
    if (!reqSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'session request not found');
    }
    const req = reqSnap.data()!;

    if (req.studentId !== studentId) {
      throw new functions.https.HttpsError('permission-denied', 'not your request');
    }

    if (req.status === 'accepted' && req.isPaid === true) {
      return { success: true, message: 'already paid', sessionId: req.sessionId };
    }

    const allowedStatuses = ['pending', 'awaitingpayment'];
    if (!allowedStatuses.includes(req.status as string)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `cannot pay request with status: ${req.status}`,
      );
    }

    // Prefer the price already on the doc when it's a positive number
    // (set by an earlier flow); otherwise fall back to client-provided
    // amount. `||` (not `??`) so that an explicit 0 also falls through.
    const docAmount = req.paymentAmount as number | undefined | null;
    const amountEgp = ((docAmount && docAmount > 0)
      ? docAmount
      : clientAmountEgp) as number;
    if (!amountEgp || amountEgp <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'amount required: pass amountEgp or set paymentAmount on the request',
      );
    }
    const totalPiastres = egpToPiastres(amountEgp);

    const mohaffezId = req.mohaffezId as string;

    // Commission is NO LONGER deducted at session-payment time. The teacher
    // is credited the GROSS amount into their `pending` bucket, and the
    // bi-weekly settlement step (`recomputeTeacherTiers`) deducts commission
    // at the end of the cycle using THAT cycle's actual tier rate. This
    // ensures the rate a teacher earned by hitting a tier mid-cycle applies
    // to the same cycle's payout, not the next one.

    // Read weekly commission summary BEFORE writes.
    const sessionDate = (req.slotStart ?? req.slotDate) as admin.firestore.Timestamp | undefined;
    if (!(sessionDate instanceof admin.firestore.Timestamp)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'request has invalid slotStart/slotDate',
      );
    }
    const sessionDateObj = sessionDate.toDate();
    const weekNumber = getWeekNumber(sessionDateObj);
    const year = sessionDateObj.getFullYear();
    const summaryId = `${mohaffezId}_${year}_w${weekNumber}`;
    const summaryRef = db.collection('weeklyCommissionSummaries').doc(summaryId);
    const summarySnap = await tx.get(summaryRef);

    // Post the ledger entry. Two legs:
    //  - debit student wallet (full amount, available bucket)
    //  - credit teacher wallet (full amount, PENDING bucket)
    // Commission is deducted later by cycle settlement, not here.
    const ledger = await postLedgerEntry(tx, {
      type: 'session_payment',
      legs: [
        {
          walletId: walletIdForUser(studentId),
          ownerType: 'student',
          amountPiastres: -totalPiastres,
        },
        {
          walletId: walletIdForUser(mohaffezId),
          ownerType: 'mohaffez',
          amountPiastres: totalPiastres,
          target: 'pending',
        },
      ],
      reason: `Session payment: ${req.planTitle ?? 'single session'}`,
      relatedSessionId: null, // set below after session created
      groupId: `paysession_${sessionRequestId}`,
      createdBy: studentId,
      metadata: {
        grossPiastres: totalPiastres,
        planType: req.planType ?? 'single',
      },
    });

    if (ledger.idempotent) {
      // Re-entry: nothing to do, ledger already posted on a prior attempt.
      return { success: true, message: 'already posted', groupId: ledger.groupId };
    }

    // Create the session doc, marked paid + accepted.
    const sessionRef = db.collection('hafizSessions').doc();
    tx.set(sessionRef, {
      requestId: sessionRequestId,
      mohaffezId,
      studentId,
      mohaffezName: req.mohaffezName ?? '',
      studentName: req.studentName ?? '',
      sessionType: req.sessionType,
      preferredProvider: req.preferredProvider ?? null,
      preferredTimeSlot: req.preferredTimeSlot,
      sessionDate: req.slotDate ?? sessionDate,
      slotStart: req.slotStart,
      slotEnd: req.slotEnd,
      status: 'accepted',
      isPaid: true,
      sessionPrice: amountEgp,
      paymentType: 'wallet',
      walletLedgerGroupId: ledger.groupId,
      createdAt: FieldValue.serverTimestamp(),
      acceptedAt: FieldValue.serverTimestamp(),
      reminder24hSent: false,
      reminder1hSent: false,
      juzCount: 1,
      sessionRating: 10,
    });

    tx.update(reqRef, {
      status: 'accepted',
      isPaid: true,
      paidAt: FieldValue.serverTimestamp(),
      sessionId: sessionRef.id,
      paymentType: 'wallet',
      walletLedgerGroupId: ledger.groupId,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Weekly summary: aggregate gross revenue only. Commission is unknown
    // until the cycle settlement runs (using THAT cycle's tier rate), so we
    // leave commissionAmount at 0 here and let `recomputeTeacherTiers`
    // back-fill it during settlement.
    if (summarySnap.exists) {
      tx.update(summaryRef, {
        totalSessions: FieldValue.increment(1),
        totalRevenue: FieldValue.increment(amountEgp),
        status: 'pending_settlement',
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(summaryRef, {
        mohaffezId,
        mohaffezName: req.mohaffezName ?? '',
        weekNumber,
        year,
        totalSessions: 1,
        totalRevenue: amountEgp,
        commissionAmount: 0,
        commissionRate: null,
        status: 'pending_settlement',
        weekStart: admin.firestore.Timestamp.fromDate(getWeekStart(sessionDateObj)),
        weekEnd: admin.firestore.Timestamp.fromDate(getWeekEnd(sessionDateObj)),
        dueDate: admin.firestore.Timestamp.fromDate(getNextMonday(sessionDateObj)),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Notify teacher.
    const notifRef = db.collection('notifications').doc();
    tx.set(notifRef, {
      userId: mohaffezId,
      recipientId: mohaffezId,
      senderId: studentId,
      title: 'حجز جديد مؤكد',
      body: `${req.studentName ?? 'طالب'} حجز جلسة وتم خصم ${amountEgp} ج.م من محفظته`,
      type: 'session_paid_wallet',
      isRead: false,
      data: {
        sessionId: sessionRef.id,
        sessionRequestId,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      sessionId: sessionRef.id,
      groupId: ledger.groupId,
      debitedPiastres: totalPiastres,
      teacherPendingCreditedPiastres: totalPiastres,
    };
  });
});

/**
 * Refund a session payment. Reverses the original three legs. Reason required.
 * Admin-only — refund policy decisions don't belong on the client.
 */
export const refundSessionPayment = functions.https.onCall(async (data, context) => {
  // Lazy import to avoid circular at module init.
  const { requireAdmin } = await import('./walletUtils');
  const adminUid = await requireAdmin(context);

  const { sessionId, reason } = data as { sessionId: string; reason: string };
  if (!sessionId || !reason || reason.trim().length < 3) {
    throw new functions.https.HttpsError('invalid-argument', 'sessionId and reason required');
  }

  return db.runTransaction(async (tx) => {
    const sessionRef = db.collection('hafizSessions').doc(sessionId);
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'session not found');
    }
    const s = sessionSnap.data()!;

    if (s.paymentType !== 'wallet') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'session was not paid via wallet — refund manually',
      );
    }
    if (s.refundedAt) {
      return { success: true, message: 'already refunded' };
    }

    const totalEgp = s.sessionPrice as number;
    const totalPiastres = egpToPiastres(totalEgp);

    // Refund logic depends on whether the cycle settlement has already run
    // on this session:
    //  - BEFORE settlement: teacher's pending bucket holds the GROSS. Reverse
    //    with 2 legs (student credit + teacher pending debit).
    //  - AFTER settlement: pending has already been drained. Money lives in
    //    teacher's available + system_revenue. Reverse with 3 legs using
    //    the rate that was applied at settlement (stored on the session).
    const settled = s.settledAt != null;
    const legs = settled
      ? (() => {
          const rate =
            typeof s.settlementCommissionRate === 'number'
              ? (s.settlementCommissionRate as number)
              : 0.10;
          const commissionPiastres = Math.round(totalPiastres * rate);
          const teacherNet = totalPiastres - commissionPiastres;
          return [
            { walletId: walletIdForUser(s.studentId as string), ownerType: 'student' as const, amountPiastres: totalPiastres },
            { walletId: walletIdForUser(s.mohaffezId as string), ownerType: 'mohaffez' as const, amountPiastres: -teacherNet },
            { walletId: SYSTEM_WALLETS.revenue, ownerType: 'system' as const, amountPiastres: -commissionPiastres },
          ];
        })()
      : [
          { walletId: walletIdForUser(s.studentId as string), ownerType: 'student' as const, amountPiastres: totalPiastres },
          { walletId: walletIdForUser(s.mohaffezId as string), ownerType: 'mohaffez' as const, amountPiastres: -totalPiastres, target: 'pending' as const },
        ];

    const result = await postLedgerEntry(tx, {
      type: 'session_refund',
      legs,
      reason: reason.trim(),
      relatedSessionId: sessionId,
      groupId: `refund_${sessionId}`,
      createdBy: adminUid,
    });

    tx.update(sessionRef, {
      status: 'refunded',
      refundedAt: FieldValue.serverTimestamp(),
      refundedBy: adminUid,
      refundReason: reason.trim(),
      refundLedgerGroupId: result.groupId,
    });

    return { success: true, groupId: result.groupId };
  });
});
