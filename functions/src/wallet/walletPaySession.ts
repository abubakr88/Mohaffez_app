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
}

export const payFromWallet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'login required');
  }
  const studentId = context.auth.uid;

  const { sessionRequestId } = data as PayFromWalletRequest;
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

    const amountEgp = req.paymentAmount as number;
    if (!amountEgp || amountEgp <= 0) {
      throw new functions.https.HttpsError('failed-precondition', 'request has no paymentAmount');
    }
    const totalPiastres = egpToPiastres(amountEgp);

    const configSnap = await tx.get(db.collection('systemConfig').doc('global'));
    const commissionRate: number =
      (configSnap.data()?.commissionRate as number) ?? 0.05;
    const commissionPiastres = Math.round(totalPiastres * commissionRate);
    const teacherPiastres = totalPiastres - commissionPiastres;

    const mohaffezId = req.mohaffezId as string;

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

    // Post the ledger entry. Four legs:
    //  - debit student wallet (full amount)
    //  - credit teacher wallet (amount − commission)
    //  - credit system_revenue (commission)
    //  - The student paid the platform; teacher earned net. No fourth leg needed
    //    because student debit = teacher credit + revenue credit.
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
          amountPiastres: teacherPiastres,
        },
        {
          walletId: SYSTEM_WALLETS.revenue,
          ownerType: 'system',
          amountPiastres: commissionPiastres,
        },
      ],
      reason: `Session payment: ${req.planTitle ?? 'single session'}`,
      relatedSessionId: null, // set below after session created
      groupId: `paysession_${sessionRequestId}`,
      createdBy: studentId,
      metadata: {
        commissionRate,
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

    // Update or create weekly commission summary (kept for backward compatibility
    // with the existing teacher commission dashboard, even though the commission
    // is already collected via the ledger split — this summary is now informational).
    const commissionAmountEgp = commissionPiastres / 100;
    if (summarySnap.exists) {
      tx.update(summaryRef, {
        totalSessions: FieldValue.increment(1),
        totalRevenue: FieldValue.increment(amountEgp),
        commissionAmount: FieldValue.increment(commissionAmountEgp),
        status: 'paid', // wallet flow auto-settles
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
        commissionAmount: commissionAmountEgp,
        commissionRate,
        status: 'paid', // wallet flow auto-settles
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
      teacherCreditedPiastres: teacherPiastres,
      commissionPiastres,
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
    const commissionRate = 0.05; // TODO: store commissionRate on session for accuracy
    const commissionPiastres = Math.round(totalPiastres * commissionRate);
    const teacherPiastres = totalPiastres - commissionPiastres;

    const result = await postLedgerEntry(tx, {
      type: 'session_refund',
      legs: [
        // Reverse of session_payment.
        { walletId: walletIdForUser(s.studentId as string), ownerType: 'student', amountPiastres: totalPiastres },
        { walletId: walletIdForUser(s.mohaffezId as string), ownerType: 'mohaffez', amountPiastres: -teacherPiastres },
        { walletId: SYSTEM_WALLETS.revenue, ownerType: 'system', amountPiastres: -commissionPiastres },
      ],
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
