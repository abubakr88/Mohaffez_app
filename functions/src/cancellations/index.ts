// functions/src/cancellations/index.ts
//
// Cancellation & no-show policy enforcement:
//
// STUDENT CANCELS:
//   > 3h before  → 100% refund to student wallet
//   1–3h before  → 50% refund
//   < 1h before  → 0% refund
//   no-show      → 0% refund (teacher marks via onStudentNoShowReported)
//   Any cancel   → warning notification
//
// TEACHER CANCELS:
//   > 3h before  → 100% student refund, no penalty
//   1–3h before  → 100% student refund, +0.5% commission penalty
//   < 1h before  → 100% student refund, +1.0% commission penalty
//   no-show      → 100% student refund, +1.5% commission penalty
//   Any cancel   → warning notification + admin alert (if penalty)
//
// Only the HIGHEST penalty in a cycle applies (not cumulative). Resets each cycle.
// For direct-payment sessions: student wallet is credited from system (admin collects from teacher).

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import {
  postLedgerEntry,
  egpToPiastres,
  walletIdForUser,
  SYSTEM_WALLETS,
} from '../wallet/walletUtils';
import { computeCancellationOutcome } from './cancellationPolicy';

type SessionDoc = Record<string, unknown>;

function toDate(v: unknown): Date | null {
  if (!v) return null;
  if (v instanceof admin.firestore.Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string') { const d = new Date(v); return isNaN(d.getTime()) ? null : d; }
  return null;
}

async function sendNotif(userId: string, title: string, body: string, type: string, data: Record<string, unknown> = {}) {
  await db.collection('notifications').add({
    userId,
    recipientId: userId,
    senderId: 'system',
    title,
    body,
    type,
    isRead: false,
    data,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function createAdminAlert(payload: Record<string, unknown>) {
  await db.collection('adminAlerts').add({
    ...payload,
    resolved: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// onSessionCancelled — Firestore trigger
// ─────────────────────────────────────────────────────────────────────────────

export const onSessionCancelled = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as SessionDoc;
    const after = change.after.data() as SessionDoc;

    // Only act on status → 'cancelled' transition
    if (before.status === 'cancelled' || after.status !== 'cancelled') return;

    const sessionId = context.params.sessionId;
    const teacherNoShow = after.teacherNoShow === true;
    const rawCancelledBy = after.cancelledBy as string | undefined;
    const cancelledBy: 'student' | 'teacher' = teacherNoShow
      ? 'teacher'
      : rawCancelledBy === 'teacher' ? 'teacher' : 'student';

    const studentId = after.studentId as string;
    const mohaffezId = after.mohaffezId as string;
    const sessionPrice = (after.sessionPrice as number | undefined) ?? 0;
    const paymentType = (after.paymentType as string | undefined) ?? null;

    const sessionDate = toDate(after.sessionDate);
    const cancelledAt = toDate(after.cancelledAt) ?? new Date();

    // ── Determine refund % and penalty % ─────────────────────────────────
    const { refundPercent, penaltyPercent } = computeCancellationOutcome({
      cancelledBy,
      teacherNoShow,
      sessionDate,
      cancelledAt,
    });

    const refundAmountEgp = Math.round(sessionPrice * refundPercent) / 100;
    const refundPiastres = refundAmountEgp > 0 ? egpToPiastres(refundAmountEgp) : 0;

    // ── Post wallet ledger refund ─────────────────────────────────────────
    if (refundPiastres > 0) {
      try {
        await db.runTransaction(async (tx) => {
          const sessionSnap = await tx.get(change.after.ref);
          const s = sessionSnap.data() as SessionDoc;
          const settled = !!s.settledAt;
          const isWallet = paymentType === 'wallet';

          let legs: Parameters<typeof postLedgerEntry>[1]['legs'];

          if (isWallet && settled) {
            // After cycle settlement: reverse teacher available + system_revenue → student
            const rate = typeof s.settlementCommissionRate === 'number'
              ? (s.settlementCommissionRate as number) : 0.10;
            const commPiastres = Math.round(refundPiastres * rate);
            const teacherNet = refundPiastres - commPiastres;
            legs = [
              { walletId: walletIdForUser(studentId), ownerType: 'student', amountPiastres: refundPiastres },
              { walletId: walletIdForUser(mohaffezId), ownerType: 'mohaffez', amountPiastres: -teacherNet },
              { walletId: SYSTEM_WALLETS.revenue, ownerType: 'system', amountPiastres: -commPiastres },
            ];
          } else if (isWallet && !settled) {
            // Before settlement: teacher pending → student available
            legs = [
              { walletId: walletIdForUser(studentId), ownerType: 'student', amountPiastres: refundPiastres },
              { walletId: walletIdForUser(mohaffezId), ownerType: 'mohaffez', amountPiastres: -refundPiastres, target: 'pending' as const },
            ];
          } else {
            // Direct payment (cash/instapay): platform credits student from system
            // Admin is alerted separately to collect the amount from teacher
            legs = [
              { walletId: walletIdForUser(studentId), ownerType: 'student', amountPiastres: refundPiastres },
              { walletId: SYSTEM_WALLETS.revenue, ownerType: 'system', amountPiastres: -refundPiastres },
            ];
          }

          await postLedgerEntry(tx, {
            type: 'session_refund',
            legs,
            reason: `إلغاء جلسة — استرداد ${refundPercent}% — بواسطة ${cancelledBy === 'teacher' ? 'المحفظ' : 'الطالب'}`,
            relatedSessionId: sessionId,
            groupId: `refund_cancel_${sessionId}`,
            createdBy: 'system',
            metadata: { refundPercent, cancelledBy, paymentType, teacherNoShow },
          });

          tx.update(change.after.ref, {
            refundAmount: refundAmountEgp,
            refundPercent,
            refundedAt: FieldValue.serverTimestamp(),
          });
        });
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        functions.logger.error(`[onSessionCancelled] Refund failed ${sessionId}: ${msg}`);
        await createAdminAlert({
          type: 'refund_failed',
          sessionId, studentId, mohaffezId,
          refundAmountEgp, refundPercent, cancelledBy,
          paymentType: paymentType ?? 'unknown',
          error: msg,
        });
      }
    }

    // ── Apply teacher commission penalty (cumulative per cycle) ──────────
    // Each cancellation/no-show adds its penalty on top of existing ones.
    // The total resets to 0 at the end of every settlement cycle.
    if (cancelledBy === 'teacher' && penaltyPercent > 0) {
      await db.collection('users').doc(mohaffezId).update({
        commissionPenaltyPercent: FieldValue.increment(penaltyPercent),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // ── Increment warnings on the cancelling party ────────────────────────
    const warningUserId = cancelledBy === 'teacher' ? mohaffezId : studentId;
    await db.collection('users').doc(warningUserId).update({
      cancellationWarnings: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // ── Notifications ─────────────────────────────────────────────────────
    const cancellerTitle = 'تحذير: تسجيل إلغاء';
    const cancellerBody = cancelledBy === 'teacher'
      ? `تم تسجيل ${teacherNoShow ? 'غياب' : 'إلغاء'} على حسابك. ${penaltyPercent > 0 ? `سيرتفع معدل عمولتك بنسبة ${penaltyPercent}% هذه الدورة.` : ''}`
      : 'تم تسجيل إلغاء على حسابك.';

    await sendNotif(warningUserId, cancellerTitle, cancellerBody, 'cancellation_warning',
      { sessionId, cancelledBy, penaltyPercent });

    // Notify the other party
    const otherId = cancelledBy === 'teacher' ? studentId : mohaffezId;
    const otherTitle = cancelledBy === 'teacher'
      ? (teacherNoShow ? 'المحفظ لم يحضر الجلسة' : 'تم إلغاء جلستك من المحفظ')
      : 'الطالب ألغى الجلسة';
    const otherBody = cancelledBy === 'teacher'
      ? (refundAmountEgp > 0
          ? `${teacherNoShow ? 'المحفظ لم يحضر.' : 'المحفظ ألغى الجلسة.'} تم إضافة ${refundAmountEgp} ج.م إلى محفظتك.`
          : `${teacherNoShow ? 'المحفظ لم يحضر' : 'المحفظ ألغى الجلسة'}.`)
      : (refundAmountEgp > 0
          ? `الطالب ألغى الجلسة. تم استرداد ${refundAmountEgp} ج.م (${refundPercent}%) إلى محفظتك.`
          : 'الطالب ألغى الجلسة. لا يوجد استرداد.');

    await sendNotif(otherId, otherTitle, otherBody, 'session_cancelled',
      { sessionId, cancelledBy, refundPercent, refundAmountEgp });

    // ── Admin alerts ──────────────────────────────────────────────────────
    if (cancelledBy === 'teacher') {
      if (teacherNoShow) {
        await createAdminAlert({
          type: 'teacher_no_show',
          sessionId, mohaffezId, studentId,
          penaltyPercent: 1.5,
          refundAmountEgp,
          paymentType: paymentType ?? 'unknown',
        });
      } else if (penaltyPercent > 0) {
        await createAdminAlert({
          type: 'teacher_cancellation_penalty',
          sessionId, mohaffezId,
          penaltyPercent,
          paymentType: paymentType ?? 'unknown',
        });
      }
    }

    // For direct-payment refunds, admin needs to collect from teacher
    if (refundPiastres > 0 && paymentType !== 'wallet') {
      await createAdminAlert({
        type: 'direct_payment_refund_pending',
        sessionId, mohaffezId, studentId,
        refundAmountEgp,
        paymentType: paymentType ?? 'unknown',
        note: 'Student wallet credited from system. Collect refund amount from teacher manually.',
      });
    }

    // PHASE B step 2: reverse the direct-commission ledger entry posted at
    // confirmation time, so a cancelled session no longer counts as commission
    // owed by the teacher. Symmetric: any cancellation reverses the full
    // commission. The dual-write weeklyCommissionSummary doc is NOT reversed
    // here (parity with current behavior — that field is the legacy display).
    //
    // Idempotent on `direct_commission_reversal_{directPaymentRequestId}`.
    // No-op if the original commission entry was never posted (e.g. pre-Phase-B
    // sessions, or sessions where commission was 0).
    const dpReqId = after.directPaymentRequestId as string | undefined;
    if (paymentType === 'directpayment' && dpReqId) {
      try {
        await db.runTransaction(async (tx) => {
          // Look up original commission entry by its group id.
          const originalGroupRef = db
            .collection('walletTransactionGroups')
            .doc(`direct_commission_${dpReqId}`);
          const bundleGroupRef = db
            .collection('walletTransactionGroups')
            .doc(`direct_commission_bundle_${dpReqId}`);
          const [originalSnap, bundleSnap] = await Promise.all([
            tx.get(originalGroupRef),
            tx.get(bundleGroupRef),
          ]);

          // Pick whichever original exists; bundle wins if both somehow do.
          const originalSnapToUse = bundleSnap.exists ? bundleSnap : originalSnap;
          if (!originalSnapToUse.exists) return; // nothing to reverse

          const meta = originalSnapToUse.data() as { metadata?: { commissionEgp?: number } };
          const commissionEgp = meta?.metadata?.commissionEgp;
          if (typeof commissionEgp !== 'number' || commissionEgp <= 0) return;

          const commissionPiastres = egpToPiastres(commissionEgp);

          await postLedgerEntry(tx, {
            type: 'direct_session_commission_reversal',
            legs: [
              {
                walletId: walletIdForUser(mohaffezId),
                ownerType: 'mohaffez',
                amountPiastres: commissionPiastres,
                target: 'dues',
              },
              {
                walletId: SYSTEM_WALLETS.revenue,
                ownerType: 'system',
                amountPiastres: -commissionPiastres,
              },
            ],
            reason: `Reverse direct-session commission — session cancelled (${cancelledBy})`,
            relatedSessionId: sessionId,
            groupId: `direct_commission_reversal_${dpReqId}`,
            createdBy: 'system',
            metadata: {
              directPaymentRequestId: dpReqId,
              cancelledBy,
              teacherNoShow,
              commissionEgp,
            },
          });
        });
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        functions.logger.error(`[onSessionCancelled] commission reversal failed ${sessionId}: ${msg}`);
        // Don't throw — refund already posted, admin alert exists. A failed
        // reversal becomes a manual ops task (will show up as a teacher
        // still owing commission on a cancelled session).
      }
    }

    functions.logger.info('[onSessionCancelled]', {
      sessionId, cancelledBy, refundPercent, penaltyPercent, teacherNoShow,
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// onStudentNoShowReported — callable by teacher
// Teacher reports: student did not attend. Session counts as completed.
// ─────────────────────────────────────────────────────────────────────────────

export const onStudentNoShowReported = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'login required');
  }

  const { sessionId } = data as { sessionId: string };
  if (!sessionId) {
    throw new functions.https.HttpsError('invalid-argument', 'sessionId required');
  }

  const teacherUid = context.auth.uid;
  const sessionRef = db.collection('hafizSessions').doc(sessionId);
  const sessionSnap = await sessionRef.get();

  if (!sessionSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'session not found');
  }

  const s = sessionSnap.data() as SessionDoc;

  if (s.mohaffezId !== teacherUid) {
    throw new functions.https.HttpsError('permission-denied', 'not your session');
  }
  if (s.status === 'completed' || s.status === 'cancelled') {
    throw new functions.https.HttpsError('failed-precondition', 'session already ended');
  }
  if (s.studentNoShow === true) {
    return { success: true, message: 'already reported' };
  }

  // Validate: session must have already started (sessionDate in the past)
  const sessionDate = toDate(s.sessionDate);
  if (!sessionDate || sessionDate.getTime() > Date.now()) {
    throw new functions.https.HttpsError('failed-precondition', 'session has not started yet');
  }

  const studentId = s.studentId as string;

  // Mark as completed with no-show flag — teacher gets paid through normal cycle
  await sessionRef.update({
    studentNoShow: true,
    status: 'completed',
    completedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Warning notification to student
  await sendNotif(
    studentId,
    'تحذير: تسجيل غياب',
    'سجّل المحفظ غيابك عن الجلسة. هذا يُعدّ تحذيراً على حسابك.',
    'student_no_show_warning',
    { sessionId },
  );

  // Increment student warnings
  await db.collection('users').doc(studentId).update({
    cancellationWarnings: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Admin alert
  await createAdminAlert({
    type: 'student_no_show',
    sessionId,
    studentId,
    mohaffezId: teacherUid,
    reportedBy: 'teacher',
  });

  functions.logger.info('[onStudentNoShowReported]', { sessionId, teacherUid, studentId });
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// onTeacherNoShowReported — callable by student (in-person sessions)
// Student reports: teacher did not show up. Full refund + 1.5% penalty.
// This sets teacherNoShow=true + status='cancelled', triggering onSessionCancelled.
// ─────────────────────────────────────────────────────────────────────────────

export const onTeacherNoShowReported = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'login required');
  }

  const { sessionId } = data as { sessionId: string };
  if (!sessionId) {
    throw new functions.https.HttpsError('invalid-argument', 'sessionId required');
  }

  const studentUid = context.auth.uid;
  const sessionRef = db.collection('hafizSessions').doc(sessionId);
  const sessionSnap = await sessionRef.get();

  if (!sessionSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'session not found');
  }

  const s = sessionSnap.data() as SessionDoc;

  if (s.studentId !== studentUid) {
    throw new functions.https.HttpsError('permission-denied', 'not your session');
  }
  if (s.status === 'completed' || s.status === 'cancelled') {
    throw new functions.https.HttpsError('failed-precondition', 'session already ended');
  }
  if (s.teacherNoShow === true) {
    return { success: true, message: 'already reported' };
  }

  // Validate: session must have already started (sessionDate in the past)
  const sessionDate = toDate(s.sessionDate);
  if (!sessionDate || sessionDate.getTime() > Date.now()) {
    throw new functions.https.HttpsError('failed-precondition', 'session has not started yet');
  }

  // Set teacherNoShow=true + status='cancelled' + cancelledBy='teacher'
  // This triggers onSessionCancelled which applies full refund + 1.5% penalty
  await sessionRef.update({
    teacherNoShow: true,
    status: 'cancelled',
    cancelledBy: 'teacher',
    cancelledAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  functions.logger.info('[onTeacherNoShowReported]', { sessionId, studentUid });
  return { success: true };
});
