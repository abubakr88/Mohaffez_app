import * as functions from 'firebase-functions';
import { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';
import { SessionEventStore } from '../services/SessionEventStore';
import { SessionRequestEventType, SessionEventType } from '../types/events.types';
import { recomputeForTeacherById } from '../payments/recomputeTeacherTiers';
import {
  countsTowardTeacherRating,
  normalizeTeacherRating,
} from './teacherRatingPolicy';

type RequestDoc = Record<string, unknown>;

const asString = (value: unknown, fallback = ''): string =>
  typeof value === 'string' && value.trim().length > 0 ? value : fallback;

const asNumber = (value: unknown, fallback = 0): number =>
  typeof value === 'number' ? value : fallback;

const asBoolean = (value: unknown, fallback = false): boolean =>
  typeof value === 'boolean' ? value : fallback;

async function syncCompletedTrialRequest(
  sessionId: string,
  session: Record<string, unknown>,
) {
  const trialRequestId = asString(
    session.trialRequestId,
    asString(session.requestId),
  );
  if (!trialRequestId) {
    functions.logger.warn('Completed trial session is missing trial request id', {
      sessionId,
    });
    return;
  }

  try {
    await db.collection('trialSessionRequests').doc(trialRequestId).set(
      {
        status: session.studentNoShow === true ? 'student_no_show' : 'completed',
        sessionId,
        completedAt: session.completedAt ?? FieldValue.serverTimestamp(),
        studentNoShow: session.studentNoShow === true,
        closedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } catch (error) {
    functions.logger.error('Failed to sync completed trial request', {
      sessionId,
      trialRequestId,
      error,
    });
  }
}

/**
 * Firestore trigger: Send notifications when session request status changes
 * Handles: payment_required, bundle_awaiting_payment, accepted, and free session flows
 */
export const onSessionRequestAccepted = functions.firestore
  .document('sessionRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as RequestDoc;
    const after = change.after.data() as RequestDoc;

    const beforeStatus = asString(before.status);
    const afterStatus = asString(after.status);

    // Only trigger on status change
    if (beforeStatus === afterStatus) {
      return;
    }

    const studentId = asString(after.studentId);
    if (!studentId) {
      functions.logger.warn('Missing studentId in session request', {
        requestId: context.params.requestId,
      });
      return;
    }

    const mohaffezName = asString(after.mohaffezName, 'المحفظ');
    const mohaffezId = asString(after.mohaffezId);
    const requestId = context.params.requestId;

    // ============================================
    // Check if this is a free session
    // ============================================
    const isPaid = asBoolean(after.isPaid, false);
    const paymentAmount = asNumber(after.paymentAmount, 0);
    const promoDiscount = asNumber(after.promoDiscount, 0);
    const promoCode = asString(after.promoCode);

    const isFreeSession =
      isPaid === true &&
      (paymentAmount === 0 || promoDiscount >= 100) &&
      promoCode.length > 0;

    try {
      // ============================================
      // CASE 1: Awaiting Payment
      // ── UPDATED: differentiate bundle vs single ─
      // ============================================
      if (afterStatus === 'awaitingpayment') {
        // A rejected manual transfer returns the request to the payment step.
        // The dedicated rejection notification explains what happened; sending
        // another "payment required" push here would be misleading.
        if (
          !before.directPaymentRejectedAt &&
          after.directPaymentRejectedAt
        ) {
          return;
        }
        // Distinguish bundle / subscription from a plain single-session request
        const planType = asString(after.planType);
        const isBundlePlan =
          planType === 'bundle' || planType === 'subscription';

        await createAndSendNotification({
          userId: studentId,
          senderId: mohaffezId,
          title: isBundlePlan
            ? 'وافق المحفظ على طلب الباقة ✅'
            : 'جلسة مقبولة!',
          body: isBundlePlan
            ? `${mohaffezName} وافق على طلبك — يمكنك الآن إتمام الدفع.`
            : `${mohaffezName} قبل طلبك. يُرجى الدفع خلال الموعد المحدد.`,
          // Separate type so Flutter notification handler routes correctly:
          //   'bundle_awaiting_payment' → /booking/direct-payment (with plan context)
          //   'payment_required'        → StudentPaymentScreen (single session)
          type: isBundlePlan ? 'bundle_awaiting_payment' : 'payment_required',
          isRead: false,
          data: {
            requestId,
            mohaffezId,
            mohaffezName,
            sessionType: asString(after.sessionType),
            sessionDate: after.slotDate,
            preferredTimeSlot: asString(after.preferredTimeSlot),
            paymentDeadline: after.paymentDeadline,
            location: after.imamAddressText ?? after.location,
            // Plan fields — only included for bundle/subscription so Flutter
            // can hydrate bookingFlowProvider before pushing DirectPaymentScreen
            ...(isBundlePlan
              ? {
                  planType,
                  planId:        asString(after.planId),
                  planTitle:     asString(after.planTitle),
                  sessionsCount: String(asNumber(after.sessionsCount, 1)),
                  ...(typeof after.validityDays === 'number'
                    ? { validityDays: String(after.validityDays) }
                    : {}),
                }
              : {}),
          },
          highPriority: true,
        });

        functions.logger.info(
          isBundlePlan
            ? 'Bundle awaiting payment notification sent'
            : 'Payment required notification sent',
          { requestId, studentId, isBundlePlan }
        );
        return;
      }

      // ============================================
      // CASE 2: Accepted (with free session detection)
      // ============================================
      if (afterStatus === 'accepted') {
        // Guard: confirmFreeSession / confirmBundleDirectPayment already sent
        // notifications atomically — skip to avoid duplicates.
        // FIX-3: Use runtime-safe boolean coercion
        const alreadySent = asBoolean(after['notificationsAlreadySent'], false);
        if (alreadySent === true) {
          functions.logger.info(
            'Skipping duplicate notification: already sent by CF',
            { requestId: context.params.requestId }
          );
          return;
        }

        const notificationTitle = isFreeSession
          ? '🎉 جلسة مجانية مؤكدة!'
          : '✅ قبلت الجلسة! 🎉';

        const notificationBody = isFreeSession
          ? `تم تأكيد جلستك المجانية مع ${mohaffezName} بنجاح. لا حاجة للدفع!`
          : `${mohaffezName} قبل طلب جلستك بنجاح.`;

        const notificationType = isFreeSession
          ? 'session_accepted_free'
          : 'session_accepted';

        // Notify student
        await createAndSendNotification({
          userId: studentId,
          senderId: mohaffezId,
          title: notificationTitle,
          body: notificationBody,
          type: notificationType,
          isRead: false,
          data: {
            requestId,
            mohaffezId,
            mohaffezName,
            sessionType: after.sessionType,
            sessionDate: after.slotDate,
            preferredTimeSlot: after.preferredTimeSlot,
            location: after.imamAddressText ?? after.location,
            isFree: isFreeSession.toString(),
            promoCode: isFreeSession ? promoCode : undefined,
          },
          highPriority: true,
        });

        // Notify mohaffez
        if (mohaffezId) {
          const studentName = asString(after.studentName, 'الطالب');

          await createAndSendNotification({
            userId: mohaffezId,
            senderId: studentId,
            title: isFreeSession ? '🎉 جلسة مجانية جديدة' : 'جلسة جديدة',
            body: isFreeSession
              ? `جلسة مجانية مع ${studentName} تم حجزها بنجاح.`
              : `تم تأكيد جلسة مع ${studentName}.`,
            type: notificationType,
            isRead: false,
            data: {
              requestId,
              studentId,
              studentName,
              sessionType: after.sessionType,
              sessionDate: after.slotDate,
              preferredTimeSlot: after.preferredTimeSlot,
              isFree: isFreeSession.toString(),
            },
            highPriority: true,
          });
        }

        functions.logger.info('Session accepted notification sent', {
          requestId,
          studentId,
          mohaffezId,
          isFreeSession,
          promoCode: isFreeSession ? promoCode : undefined,
        });
      }

      // ============================================
      // CASE 3: Rejected
      // ============================================
      if (afterStatus === 'rejected') {
        const rejectionReason = asString(after.rejectionReason);
        await createAndSendNotification({
          userId: studentId,
          senderId: mohaffezId,
          title: 'تم رفض الطلب',
          body: rejectionReason
            ? `للأسف، ${mohaffezName} رفض طلب الجلسة. السبب: ${rejectionReason}`
            : `للأسف، ${mohaffezName} رفض طلب الجلسة. يمكنك محاولة حجز موعد آخر.`,
          type: 'session_rejected',
          isRead: false,
          data: {
            requestId,
            mohaffezId,
            mohaffezName,
            sessionType: after.sessionType,
            rejectionReason: rejectionReason || undefined,
          },
          highPriority: false,
        });

        functions.logger.info('Session rejected notification sent', {
          requestId,
          studentId,
        });
      }

      // ============================================
      // CASE 4: Cancelled
      // ============================================
      if (afterStatus === 'cancelled') {
        // Confirmed sessions are handled by onSessionCancelled, including the
        // refund or penalty outcome for both parties. This trigger only owns
        // cancellations that happen before a session exists.
        if (asString(after.sessionId)) {
          return;
        }

        if (mohaffezId) {
          const studentName = asString(after.studentName, 'الطالب');

          await createAndSendNotification({
            userId: mohaffezId,
            senderId: studentId,
            title: 'تم إلغاء الجلسة',
            body: `${studentName} ألغى طلب الجلسة.`,
            type: 'session_cancelled',
            isRead: false,
            data: {
              requestId,
              studentId,
              studentName,
              sessionType: after.sessionType,
            },
            highPriority: false,
          });
        }

        functions.logger.info('Session cancelled notification sent', {
          requestId,
          studentId,
          mohaffezId,
        });
      }
    } catch (error) {
      functions.logger.error('Error sending session request notification', {
        requestId,
        studentId,
        mohaffezId,
        status: afterStatus,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
    }
  });

/**
 * Firestore trigger for session creation
 * Logs session creation events; skips if notifications already sent by CF.
 */
export const onSessionCreated = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data() as Record<string, unknown>;
    const sessionId = context.params.sessionId;
    const studentId = asString(data.studentId, '');
    const mohaffezId = asString(data.mohaffezId, '');

    // FIXED: BUG-3
    const alreadySent = asBoolean(data['notificationsAlreadySent'], false);
    if (alreadySent) {
      functions.logger.info(
        'onSessionCreated: skipping — notifications already sent',
        { sessionId: context.params.sessionId }
      );
      return;
    }

    try {
      await sessionEventStore.appendEvent({
        eventType: SessionEventType.SESSION_CREATED,
        sessionId,
        requestId: asString(data.requestId, ''),
        toStatus: 'accepted',
        actorId: mohaffezId || 'system',
        data: {
          studentId,
          mohaffezId,
          sessionType: data.sessionType,
          preferredTimeSlot: data.preferredTimeSlot,
          sessionDate: data.sessionDate,
          isPaid: data.isPaid,
          sessionPrice: data.sessionPrice,
          paymentMethod: data.paymentMethod,
          promoCode: data.promoCode ?? null,
        },
      });
    } catch (error) {
      functions.logger.error('Failed to append session created event', {
        sessionId,
        error,
      });
    }
  });

/**
 * Firestore trigger for payment completion
 * Detects when a payment is completed and logs the event.
 */
export const onPaymentCompleted = functions.firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as RequestDoc;
    const after = change.after.data() as RequestDoc;

    const beforeStatus = asString(before.status);
    const afterStatus = asString(after.status);

    if (beforeStatus === afterStatus || afterStatus !== 'completed') {
      return;
    }

    const paymentId = context.params.paymentId;
    const studentId = asString(after.studentId);
    const amount = asNumber(after.amount, 0);
    const promoCode = asString(after.promoCode);

    functions.logger.info('Payment completed', {
      paymentId,
      studentId,
      amount,
      promoCode: promoCode.length > 0 ? promoCode : undefined,
      subscriptionId: after.subscriptionId,
      sessionId: after.sessionId,
    });
  });

/**
 * FIX: BUG #3 - Firestore trigger for session completion
 * Fires when status changes to "completed". Sends student notification.
 */
export const onSessionCompleted = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;

    const beforeStatus = asString(before.status, '');
    const afterStatus = asString(after.status, '');

    if (beforeStatus === afterStatus) return;

    const sessionId = context.params.sessionId;
    const studentId = asString(after.studentId, '');
    const mohaffezId = asString(after.mohaffezId, '');

    // Always append a session event for ANY status change
    try {
      await sessionEventStore.appendEvent({
        eventType: SessionEventType.SESSION_COMPLETED,
        sessionId,
        requestId: asString(after.requestId, ''),
        fromStatus: beforeStatus,
        toStatus: afterStatus,
        actorId: mohaffezId || 'system',
        data: {
          studentId,
          mohaffezId,
          sessionType: after.sessionType,
          sessionRating: after.sessionRating,
          hifzAssignment: after.hifzAssignment ?? null,
          murajaAssignment: after.murajaAssignment ?? null,
          isLateCompletion: after.isLateCompletion ?? false,
          tajweedMistakes: after.tajweedMistakesCount ?? 0,
          pronunciationMistakes: after.pronunciationMistakesCount ?? 0,
        },
      });
    } catch (error) {
      functions.logger.error('Failed to append session completed event', {
        sessionId,
        error,
      });
    }

    // Only send notifications when status becomes 'completed'
    if (afterStatus !== 'completed') return;
    const isTrial = after.isTrial === true || after.bookingKind === 'trial';

    if (isTrial) {
      await syncCompletedTrialRequest(sessionId, after);
    }

    // ── Refresh this teacher's commission tier in real-time ──────────
    // The bi-weekly cron (`recomputeTeacherTiers`) still owns the global
    // schedule, but waiting two weeks to reflect a freshly-completed
    // session is bad UX — the teacher's home card stays at the old count.
    // This call updates `users/{mohaffezId}.tierStats` immediately. Errors
    // are swallowed inside the helper so they can't break notification flow.
    if (mohaffezId && !isTrial) {
      await recomputeForTeacherById(mohaffezId);
    }

    // ── Increment student completed-session counter ──────────────────
    if (studentId && !isTrial) {
      try {
        await db
          .collection('users')
          .doc(studentId)
          .update({
            completedSessionsCount: FieldValue.increment(1),
            updatedAt:              FieldValue.serverTimestamp(),
          });
        functions.logger.info('Student session counter incremented', {
          sessionId,
          studentId,
        });
      } catch (counterError) {
        functions.logger.error(
          'Failed to increment student session counter',
          { sessionId, studentId, error: counterError }
        );
      }
    }
    // ─────────────────────────────────────────────────────────────────

    // ── Increment teacher completed-session and students-served counters ──
    if (mohaffezId && !isTrial) {
      try {
        // Check if this student has had any prior completed session with this teacher.
        // limit(2): one would be the session just completed, two means a repeat student.
        const priorSnap = await db
          .collection('hafizSessions')
          .where('mohaffezId', '==', mohaffezId)
          .where('studentId', '==', studentId)
          .where('status', '==', 'completed')
          .limit(2)
          .get();
        const isNewStudent = priorSnap.size <= 1;

        const teacherUpdate: Record<string, unknown> = {
          completedSessionsCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (isNewStudent) {
          teacherUpdate.studentsServedCount = FieldValue.increment(1);
        }

        await db.collection('users').doc(mohaffezId).update(teacherUpdate);
        functions.logger.info('Teacher counters incremented', {
          sessionId,
          mohaffezId,
          isNewStudent,
        });
      } catch (counterError) {
        functions.logger.error(
          'Failed to increment teacher counters',
          { sessionId, mohaffezId, error: counterError }
        );
      }
    }
    // ─────────────────────────────────────────────────────────────────

    if (!studentId) {
      functions.logger.warn('Missing studentId in completed session', {
        sessionId,
      });
      return;
    }

    const mohaffezName = asString(after.mohaffezName, '');
    const hifzAssignment = asString(after.hifzAssignment, '');
    const hasAssignment = hifzAssignment.trim().length > 0;

    try {
      await createAndSendNotification({
        userId: studentId,
        senderId: mohaffezId,
        title: 'انتهت الجلسة ✅',
        body: hasAssignment
          ? `${mohaffezName} أضاف واجبك الجديد.`
          : `جلستك مع ${mohaffezName} مكتملة.`,
        type: hasAssignment ? 'assignmentupdated' : 'sessioncompleted',
        isRead: false,
        highPriority: true,
        data: {
          sessionId,
          mohaffezId,
          mohaffezName,
          hifzAssignment: hifzAssignment || undefined,
          murajaAssignment: asString(after.murajaAssignment, '') || undefined,
          sessionRating: after.sessionRating,
        },
      });
      functions.logger.info('Session completed notification sent', {
        sessionId,
        studentId,
        mohaffezId,
        hasAssignment,
      });
    } catch (error) {
      functions.logger.error('Error sending session completed notification', {
        sessionId,
        studentId,
        mohaffezId,
        error,
      });
    }
  });

/**
 * Update the teacher's five-point public average on first rating submission.
 * Technical-only feedback remains available to support but is not counted.
 */
export const onTeacherRated = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;

    const beforeRating = asNumber(before.teacherRating, 0);
    const afterRating = normalizeTeacherRating(after);

    // Only process when a new rating is submitted (0 → non-zero)
    if (beforeRating !== 0 || afterRating == null) return;

    // Technical-only feedback remains on the session for support review but
    // must not change the teacher's public reputation.
    if (!countsTowardTeacherRating(after)) {
      functions.logger.info('Teacher rating excluded from public average', {
        sessionId: context.params.sessionId,
        reason: after.teacherRatingReason,
        technicalIssueSource: after.technicalIssueSource,
      });
      return;
    }

    const mohaffezId = asString(after.mohaffezId, '');
    const sessionId = context.params.sessionId;

    if (!mohaffezId) {
      functions.logger.warn('onTeacherRated: missing mohaffezId', { sessionId });
      return;
    }

    try {
      const teacherRef = db.collection('users').doc(mohaffezId);
      const sessionRef = change.after.ref;

      const applied = await db.runTransaction(async (transaction) => {
        const currentSession = await transaction.get(sessionRef);
        if (currentSession.data()?.teacherRatingAppliedAt != null) {
          return false;
        }

        const teacherDoc = await transaction.get(teacherRef);
        if (!teacherDoc.exists) {
          functions.logger.warn('onTeacherRated: teacher doc not found', { mohaffezId });
          return false;
        }

        const data = teacherDoc.data() as Record<string, unknown>;
        const usesCurrentPolicy = asNumber(data.ratingPolicyVersion, 0) === 2;
        const oldCount = usesCurrentPolicy
          ? asNumber(data.reviewCount, 0)
          : 0;
        const oldSum = usesCurrentPolicy
          ? asNumber(
              data.ratingSum,
              asNumber(data.rating, 0) * oldCount,
            )
          : 0;

        const newCount = oldCount + 1;
        const newSum = oldSum + afterRating;
        const newAvg = newSum / newCount;

        transaction.update(teacherRef, {
          rating: Math.round(newAvg * 10) / 10,
          ratingScale: 5,
          ratingSum: newSum,
          ratingPolicyVersion: 2,
          reviewCount: newCount,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(sessionRef, {
          teacherRatingAppliedAt: FieldValue.serverTimestamp(),
          teacherRatingAppliedValue: afterRating,
        });
        return true;
      });

      if (!applied) return;

      functions.logger.info('Teacher rating updated', {
        sessionId,
        mohaffezId,
        submittedRating: afterRating,
      });
    } catch (error) {
      functions.logger.error('Failed to update teacher rating', {
        sessionId,
        mohaffezId,
        error,
      });
    }
  });

const sessionEventStore = new SessionEventStore();

export const onSessionRequestStatusChanged = functions.firestore
  .document('sessionRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as Record<string, unknown>;
    const after = change.after.data() as Record<string, unknown>;

    const fromStatus = (before.status as string) ?? '';
    const toStatus = (after.status as string) ?? '';

    if (fromStatus === toStatus) return;

    const requestId = context.params.requestId;
    const studentId = (after.studentId as string) ?? '';
    const mohaffezId = (after.mohaffezId as string) ?? '';

    const eventTypeMap: Record<string, SessionRequestEventType> = {
      awaitingpayment:                   SessionRequestEventType.AWAITING_PAYMENT,
      awaitingdirectpaymentconfirmation: SessionRequestEventType.AWAITING_DIRECT,
      accepted:                          SessionRequestEventType.ACCEPTED,
      rejected:                          SessionRequestEventType.REJECTED,
      cancelled:                         SessionRequestEventType.CANCELLED,
      expired:                           SessionRequestEventType.EXPIRED,
    };

    const eventType = eventTypeMap[toStatus];
    if (!eventType) {
      functions.logger.warn(
        'onSessionRequestStatusChanged: unknown toStatus',
        { requestId, fromStatus, toStatus }
      );
      return;
    }

    const actorId = ['accepted', 'rejected', 'awaitingdirectpaymentconfirmation'].includes(
      toStatus
    )
      ? mohaffezId
      : toStatus === 'expired'
      ? 'system'
      : studentId;

    try {
      await sessionEventStore.appendEvent({
        eventType,
        requestId,
        toStatus,
        fromStatus,
        actorId,
        data: {
          studentId,
          mohaffezId,
          sessionType: after.sessionType,
          preferredTimeSlot: after.preferredTimeSlot,
          slotDate: after.slotDate,
          paymentMethod: after.selectedPaymentMethod,
          promoCode: after.promoCode ?? null,
          cancelledBy: after.cancelledBy ?? null,
          rejectionReason: after.rejectionReason ?? null,
        },
      });
    } catch (error) {
      functions.logger.error('Failed to append session request event', {
        requestId,
        fromStatus,
        toStatus,
        error,
      });
    }
  });
