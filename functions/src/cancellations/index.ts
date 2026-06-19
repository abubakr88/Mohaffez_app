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
// Penalties accumulate within the cycle. The accumulated penalty resets each cycle.
// For direct-payment sessions: student wallet is credited from system (admin collects from teacher).

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import {
  postLedgerEntry,
  postWalletEvent,
  egpToPiastres,
  walletIdForUser,
  SYSTEM_WALLETS,
} from '../wallet/walletUtils';
import { computeCancellationOutcome } from './cancellationPolicy';
import { resolveBaseRateFromData } from '../utils/commissionRate';

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

// Bundle detection extracted to bundleDetection.ts for unit testing. The
// trigger here provides a Firestore-backed sessionRequest lookup callback.
import { detectBundleContext as detectBundleContextPure } from './bundleDetection';

async function detectBundleContext(
  after: SessionDoc,
): Promise<{ isBundle: boolean; subscriptionId: string | null }> {
  return detectBundleContextPure(
    {
      subscriptionId: after.subscriptionId as string | undefined,
      paymentType: after.paymentType as string | undefined,
      paymentMethod: after.paymentMethod as string | undefined,
      requestId: after.requestId as string | undefined,
    },
    async (requestId) => {
      const reqSnap = await db.collection('sessionRequests').doc(requestId).get();
      if (!reqSnap.exists) return null;
      return {
        subscriptionId: reqSnap.data()?.subscriptionId as string | undefined,
      };
    },
  );
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

    // Use slotStart (precise start time) for the hours-until-session math.
    // sessionDate is a date-only field that normalizes to midnight — a 23:10
    // session would compute as "started -20h ago" relative to a 20:00 cancel,
    // wrongly pushing the penalty into the <1h bracket (1%) instead of the
    // correct 1-3h bracket (0.5%).
    const sessionStart =
      toDate(after.slotStart) ?? toDate(after.sessionDate);
    const cancelledAt = toDate(after.cancelledAt) ?? new Date();

    // ── Determine refund % and penalty % ─────────────────────────────────
    const { refundPercent, penaltyPercent } = computeCancellationOutcome({
      cancelledBy,
      teacherNoShow,
      sessionDate: sessionStart,
      cancelledAt,
    });

    const refundAmountEgp = Math.round(sessionPrice * refundPercent) / 100;
    const refundPiastres = refundAmountEgp > 0 ? egpToPiastres(refundAmountEgp) : 0;

    // ── Bundle session cancellation: restore the session credit, no money ─
    // For sessions that belong to a bundle subscription, we don't move
    // money on cancellation. The teacher was already paid the full bundle
    // amount up front, so refunding would double-charge. Instead, we
    // increment `subscription.remainingSessions` so the student can rebook.
    //
    // Restore rules:
    //   - Teacher cancel or no-show → always restore (student is made whole).
    //   - Student cancel → restore only when refundPercent === 100, matching
    //     the single-session refund policy (>3h before start). Late student
    //     cancellations lose the session as a punitive measure, same intent
    //     as the 0%/50% refund on singles.
    //
    // Teacher commission penalty still applies below (separate from refund).
    const bundleCtx = await detectBundleContext(after);
    if (bundleCtx.isBundle) {
      // Bundle signal present but subscription couldn't be resolved — log,
      // alert admin, and DO NOT fall through to the standard refund (it
      // would wrongly debit teacher pending/dues for a session that was
      // paid as part of the bundle).
      if (!bundleCtx.subscriptionId) {
        functions.logger.error(
          `[onSessionCancelled] bundle session ${sessionId} has no resolvable subscriptionId`,
        );
        await createAdminAlert({
          type: 'bundle_subscription_missing',
          sessionId, studentId, mohaffezId,
          paymentType: paymentType ?? 'unknown',
          cancelledBy,
          note: 'Session looked like a bundle (paymentType/paymentMethod) but '
              + 'no subscriptionId was on the session or its sessionRequest. '
              + 'Refund skipped — needs manual review.',
        });
        try {
          await change.after.ref.update({
            refundAmount: 0,
            refundPercent: 0,
            refundedAt: FieldValue.serverTimestamp(),
            bundleSessionLost: true,
            bundleLostReason: 'subscription_missing',
          });
        } catch (_err) { /* non-critical */ }
      } else {
        const subscriptionId = bundleCtx.subscriptionId;
        const shouldRestore =
          cancelledBy === 'teacher' || refundPercent === 100;
        if (shouldRestore) {
          try {
            await db.runTransaction(async (tx) => {
              const subRef = db.collection('subscriptions').doc(subscriptionId);
              const subSnap = await tx.get(subRef);
              const sessionSnap = await tx.get(change.after.ref);
              const s = sessionSnap.data() as SessionDoc;
              // Idempotency: either flag indicates this session has already
              // been processed by the bundle branch.
              if (s.bundleRestored || s.bundleSessionLost) return;

              if (!subSnap.exists) {
                tx.update(change.after.ref, {
                  refundAmount: 0,
                  refundPercent: 0,
                  refundedAt: FieldValue.serverTimestamp(),
                  bundleSessionLost: true,
                  bundleLostReason: 'subscription_doc_missing',
                });
                return;
              }
              const subData = subSnap.data() as Record<string, unknown>;
              const currentRemaining = (subData.remainingSessions as number) ?? 0;
              const currentStatus = (subData.status as string) ?? 'active';
              tx.update(subRef, {
                remainingSessions: currentRemaining + 1,
                // Reactivate if it had been drained to 0 — a restored credit
                // makes the subscription usable again.
                status: currentStatus === 'depleted' ? 'active' : currentStatus,
                updatedAt: FieldValue.serverTimestamp(),
              });
              tx.update(change.after.ref, {
                bundleRestored: true,
                subscriptionRestoredAt: FieldValue.serverTimestamp(),
                refundAmount: 0,
                refundPercent: 0,
              });
            });

            // Alert admin if the subscription doc was missing (handled above
            // by setting bundleSessionLost — re-check on freshest read).
            const freshSnap = await change.after.ref.get();
            if (freshSnap.data()?.bundleLostReason === 'subscription_doc_missing') {
              await createAdminAlert({
                type: 'bundle_subscription_missing',
                sessionId, subscriptionId, studentId, mohaffezId,
                cancelledBy,
                note: 'Subscription doc not found at cancellation time.',
              });
            }
          } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : String(err);
            functions.logger.error(`[onSessionCancelled] Bundle restore failed ${sessionId}: ${msg}`);
            await createAdminAlert({
              type: 'bundle_restore_failed',
              sessionId, subscriptionId, studentId, mohaffezId,
              cancelledBy,
              error: msg,
            });
          }
        } else {
          // Late student cancel of a bundle session: no restore, no refund.
          // bundleSessionLost flag disambiguates this from a restore.
          try {
            await change.after.ref.update({
              refundAmount: 0,
              refundPercent: 0,
              refundedAt: FieldValue.serverTimestamp(),
              bundleSessionLost: true,
              bundleLostReason: 'late_student_cancel',
            });
          } catch (_err) { /* non-critical */ }
        }
      }
      // Skip the standard single-session refund block below.
    } else if (refundPiastres > 0) {
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
            // Direct payment (cash/instapay): the teacher took the student's
            // cash off-platform, so there's no wallet `available` balance to
            // debit. Record the refund as a debt on the teacher's `dues`
            // bucket — cycle settlement drains dues from future on-platform
            // earnings, so the teacher repays the platform automatically.
            // Entry is balanced: student claim +refund offset by teacher
            // dues -refund (a receivable on the platform's books).
            legs = [
              { walletId: walletIdForUser(studentId), ownerType: 'student', amountPiastres: refundPiastres },
              { walletId: walletIdForUser(mohaffezId), ownerType: 'mohaffez', amountPiastres: -refundPiastres, target: 'dues' as const },
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

      // After a successful direct-payment refund, the teacher's dues may now
      // exceed their available balance. Surface this to admin so they can
      // chase repayment or trigger account restrictions. Read the wallet
      // OUTSIDE the transaction — this is a side effect, not money-moving.
      if (paymentType !== 'wallet') {
        try {
          const walletDoc = await db
            .collection('wallets')
            .doc(walletIdForUser(mohaffezId))
            .get();
          const wAvailable = (walletDoc.data()?.balancePiastres as number) ?? 0;
          const wDues = (walletDoc.data()?.directCommissionOwedPiastres as number) ?? 0;
          const wDebt = wDues < 0 ? -wDues : 0;
          if (wDebt > 0 && wAvailable - wDebt < 0) {
            await createAdminAlert({
              type: 'teacher_negative_account',
              sessionId, mohaffezId, studentId,
              availableEgp: wAvailable / 100,
              debtEgp: wDebt / 100,
              netEgp: (wAvailable - wDebt) / 100,
              triggeredBy: 'session_refund',
              cancelledBy,
              note: 'Teacher net (available − dues) is negative after refund.',
            });
          }
        } catch (alertErr) {
          functions.logger.warn(
            `[onSessionCancelled] negative-account alert failed ${sessionId}`,
            alertErr,
          );
        }
      }
    }

    // ── Apply teacher commission penalty (cumulative per cycle) ──────────
    // Each cancellation/no-show adds its penalty on top of existing ones.
    // The total resets to 0 at the end of every settlement cycle.
    if (cancelledBy === 'teacher' && penaltyPercent > 0) {
      const [teacherSnap, configSnap] = await Promise.all([
        db.collection('users').doc(mohaffezId).get(),
        db.collection('systemConfig').doc('global').get(),
      ]);
      const oldPenaltyPct = (teacherSnap.data()?.commissionPenaltyPercent as number | undefined) ?? 0;
      const baseRate = resolveBaseRateFromData(teacherSnap.data(), configSnap.data());
      const oldEffective = Math.min(baseRate + oldPenaltyPct / 100, 1.0);
      const newEffective = Math.min(baseRate + (oldPenaltyPct + penaltyPercent) / 100, 1.0);

      await db.collection('users').doc(mohaffezId).update({
        commissionPenaltyPercent: FieldValue.increment(penaltyPercent),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const reason = teacherNoShow
        ? `غياب: عقوبة +${penaltyPercent}% — معدل العمولة الفعلي: ${(oldEffective * 100).toFixed(1)}% → ${(newEffective * 100).toFixed(1)}%`
        : `إلغاء مبكر: عقوبة +${penaltyPercent}% — معدل العمولة الفعلي: ${(oldEffective * 100).toFixed(1)}% → ${(newEffective * 100).toFixed(1)}%`;
      await postWalletEvent(mohaffezId, {
        type: 'penalty_applied',
        eventId: `penalty_${sessionId}`,
        reason,
        metadata: {
          sessionId,
          cancelledBy,
          teacherNoShow,
          penaltyAddedPct: penaltyPercent,
          oldPenaltyPct,
          newPenaltyPct: oldPenaltyPct + penaltyPercent,
          baseRate,
          oldEffectiveRate: oldEffective,
          newEffectiveRate: newEffective,
        },
      });
    }

    // ── Increment warnings on the cancelling party ────────────────────────
    const warningUserId = cancelledBy === 'teacher' ? mohaffezId : studentId;
    await db.collection('users').doc(warningUserId).update({
      cancellationWarnings: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // ── Notifications ─────────────────────────────────────────────────────
    // Compute bundle context up front so both notifications can use it.
    const isBundleSession = bundleCtx.isBundle;
    const bundleRestored =
      isBundleSession && (cancelledBy === 'teacher' || refundPercent === 100);

    // Tell the cancelling party (warning notification) what happened. For
    // bundle sessions specifically, the student needs to know whether their
    // session credit was restored to the bundle or lost — without this they
    // see only the generic "إلغاء" message and can't tell the consequence.
    const cancellerTitle = 'تحذير: تسجيل إلغاء';
    let cancellerBody: string;
    if (cancelledBy === 'teacher') {
      cancellerBody = `تم تسجيل ${teacherNoShow ? 'غياب' : 'إلغاء'} على حسابك.`
        + (penaltyPercent > 0
          ? ` سيرتفع معدل عمولتك بنسبة ${penaltyPercent}% هذه الدورة.`
          : '');
    } else if (isBundleSession) {
      cancellerBody = bundleRestored
        ? 'تم إلغاء الجلسة وتمت إعادتها إلى رصيد باقتك.'
        : 'تم إلغاء الجلسة. فقدت هذه الحلقة من باقتك بسبب الإلغاء المتأخر.';
    } else if (refundAmountEgp > 0) {
      cancellerBody = `تم إلغاء الجلسة. تم استرداد ${refundAmountEgp} ج.م (${refundPercent}%) إلى محفظتك.`;
    } else {
      cancellerBody = 'تم إلغاء الجلسة. لا يوجد استرداد للإلغاء المتأخر.';
    }

    await sendNotif(warningUserId, cancellerTitle, cancellerBody, 'cancellation_warning',
      { sessionId, cancelledBy, penaltyPercent });

    // Notify the other party.
    const otherId = cancelledBy === 'teacher' ? studentId : mohaffezId;
    const otherTitle = cancelledBy === 'teacher'
      ? (teacherNoShow ? 'المحفظ لم يحضر الجلسة' : 'تم إلغاء جلستك من المحفظ')
      : 'الطالب ألغى الجلسة';
    const otherBody = isBundleSession
      ? (cancelledBy === 'teacher'
          ? `${teacherNoShow ? 'المحفظ لم يحضر.' : 'المحفظ ألغى الجلسة.'} تم إعادة الحلقة إلى رصيد باقتك.`
          : (bundleRestored
              ? 'الطالب ألغى الجلسة وتمت إعادتها إلى رصيد الباقة.'
              : 'الطالب ألغى الجلسة متأخراً — لن تُحتسب من الباقة وتم خصمها.'))
      : (cancelledBy === 'teacher'
          ? (refundAmountEgp > 0
              ? `${teacherNoShow ? 'المحفظ لم يحضر.' : 'المحفظ ألغى الجلسة.'} تم إضافة ${refundAmountEgp} ج.م إلى محفظتك.`
              : `${teacherNoShow ? 'المحفظ لم يحضر' : 'المحفظ ألغى الجلسة'}.`)
          : (refundAmountEgp > 0
              ? `الطالب ألغى الجلسة. تم استرداد ${refundAmountEgp} ج.م (${refundPercent}%) إلى محفظتك.`
              : 'الطالب ألغى الجلسة. لا يوجد استرداد.'));

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

// PHASE B step 2: reverse the direct-commission ledger entry posted at
    // confirmation time. Commission is reversed PROPORTIONALLY to the refund
    // percentage:
    //   - 100% refund (teacher cancel, student >3h cancel) → reverse 100%
    //   - 50%  refund (student 1-3h cancel)               → reverse 50%
    //   - 0%   refund (student <1h cancel)                → reverse 0%
    // This keeps platform revenue aligned with what the teacher actually got
    // to keep: if the teacher pocketed the cash (no refund), the platform
    // keeps its commission cut on that cash; if the teacher had to give the
    // cash back (full refund), the commission unwinds with it.
    //
    // Bundle commission entries are NEVER reversed here — a single bundle
    // session cancellation doesn't unwind the whole-bundle commission.
    //
    // Idempotent on `direct_commission_reversal_{directPaymentRequestId}`.
    // No-op if the original commission entry was never posted (e.g. pre-Phase-B
    // sessions, or sessions where commission was 0), or if refundPercent is 0.
    const dpReqId = after.directPaymentRequestId as string | undefined;
    if (paymentType === 'directpayment' && dpReqId && refundPercent > 0) {
      try {
        await db.runTransaction(async (tx) => {
          // Look up original commission entry by its group id. Only the
          // single-session entry — bundle commissions are intentionally not
          // reversed per individual session.
          const originalGroupRef = db
            .collection('walletTransactionGroups')
            .doc(`direct_commission_${dpReqId}`);
          const originalSnap = await tx.get(originalGroupRef);

          if (!originalSnap.exists) return; // nothing to reverse

          const meta = originalSnap.data() as { metadata?: { commissionEgp?: number } };
          const commissionEgp = meta?.metadata?.commissionEgp;
          if (typeof commissionEgp !== 'number' || commissionEgp <= 0) return;

          // Scale by refund percentage. Round to whole piastres.
          const fullCommissionPiastres = egpToPiastres(commissionEgp);
          const commissionPiastres = Math.round(
            fullCommissionPiastres * (refundPercent / 100),
          );
          if (commissionPiastres <= 0) return;

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
            reason: `Reverse ${refundPercent}% of direct-session commission — session cancelled (${cancelledBy})`,
            relatedSessionId: sessionId,
            groupId: `direct_commission_reversal_${dpReqId}`,
            createdBy: 'system',
            metadata: {
              directPaymentRequestId: dpReqId,
              cancelledBy,
              teacherNoShow,
              fullCommissionEgp: commissionEgp,
              reversedCommissionEgp: commissionPiastres / 100,
              refundPercent,
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

  // Validate: session must have started at least `lateSessionGraceMinutes`
  // ago. Reporting at the exact start time is premature — the teacher may
  // be 1-2 min late and joining now. Default 10 minutes, configurable in
  // systemConfig/global.lateSessionGraceMinutes.
  //
  // Prefer slotStart (precise start time) over sessionDate (date-only field
  // that normalizes to midnight). For a 23:10 session, sessionDate=00:00
  // would make the grace window evaluate against midnight, allowing the
  // report all day long — using slotStart anchors it to the real start.
  const startTime = toDate(s.slotStart) ?? toDate(s.sessionDate);
  if (!startTime) {
    throw new functions.https.HttpsError('failed-precondition', 'session has no start date');
  }
  const cfgSnap = await db.collection('systemConfig').doc('global').get();
  const graceMinutes =
    (cfgSnap.data()?.lateSessionGraceMinutes as number | undefined) ?? 10;
  const reportableAt = startTime.getTime() + graceMinutes * 60_000;
  if (Date.now() < reportableAt) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `يمكنك الإبلاغ عن غياب المعلم بعد ${graceMinutes} دقيقة من موعد بدء الجلسة`,
    );
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
