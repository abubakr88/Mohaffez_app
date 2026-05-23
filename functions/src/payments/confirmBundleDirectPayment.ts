// CHANGES vs original:
// 1. CHANGED: Auth → caller is now MOHAFFEZ (was student)
//    const mohaffezId = context.auth.uid  (was: const studentId = context.auth.uid)
// 2. CHANGED: Only paymentId comes from caller data; all other fields read from dp doc
//    (planId, planTitle, planType, sessionsCount, validityDays, slot fields, studentId)
// 3. NEW: Ownership check → if (dp.mohaffezId !== mohaffezId) throw permission-denied
// 4. CHANGED: studentId = dp.studentId (from doc, not from auth)
// 5. CHANGED: isSlotCoupled determined from dp doc Timestamps (not caller-provided strings)
//    WHY: studentMarkedDirectPayment stores slot Timestamps in the doc already
// All other logic (AlreadyConfirmedError, uniqueness constraint, commission config,
// sessionType resolution, subscription/session/request creation, 9j update of 
// pre-existing sessionRequest, idempotency, notifications) is PRESERVED 100%.

// WHY: slot-lock-fix - With the new slot-lock-fix in studentMarkedDirectPayment,
// dp.sessionRequestId is now ALWAYS set for bundle purchases (Path B). The sessionRequest
// is created atomically with the slotLock when student marks payment.
// CHANGES:
// 1. Step 9f: Only create new sessionRequest if dp.sessionRequestId is NULL (backwards compat)
// 2. Step 9h: UPDATE existing sessionRequest instead of creating new one when dp.sessionRequestId exists
// 3. NEW Step 9k: DELETE slotLocks/{slotLockId} after confirmation

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';
import {
  getWeekNumber,
  getWeekStart,
  getWeekEnd,
  getNextMonday,
} from '../utils/dateHelpers';

class AlreadyConfirmedError extends Error {
  constructor(public readonly existingSubscriptionId: string) {
    super('AlreadyConfirmed');
    this.name = 'AlreadyConfirmedError';
  }
}

export const confirmBundleDirectPayment = functions.https.onCall(
  async (data, context) => {
    functions.logger.info('confirmBundleDirectPayment Starting', {
      timestamp: new Date().toISOString(),
    });

    // 1. Auth — CHANGED: caller must be the MOHAFFEZ
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const mohaffezId = context.auth.uid; // CHANGED: was studentId = context.auth.uid

    // FIX BUG-NEW-3: Verify caller is a mohaffez
    const callerDoc = await db.collection('users').doc(mohaffezId).get();
    
    // DEBUG: Add diagnostic logs to expose actual values
    functions.logger.info('[DEBUG] confirmBundleDirectPayment callerUid:', mohaffezId);
    functions.logger.info('[DEBUG] confirmBundleDirectPayment paymentId received:', data?.paymentId);
    functions.logger.info('[DEBUG] confirmBundleDirectPayment all data keys:', data ? Object.keys(data) : []);
    functions.logger.info('[DEBUG] confirmBundleDirectPayment callerDoc exists:', callerDoc.exists);
    functions.logger.info('[DEBUG] confirmBundleDirectPayment caller role:', callerDoc.data()?.role);
    
    // FIX: Make role check case-insensitive to handle variations like 'Mohaffez', 'mohaffez', etc.
    const callerRole = callerDoc.data()?.role?.toLowerCase();
    if (!callerDoc.exists || (callerRole !== 'mohaffez' && callerRole !== 'teacher')) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Caller must be a mohaffez'
      );
    }

    // 2. Extract params — only paymentId from caller
    //    WHY: everything else is read from the dp doc to prevent payload injection
    const { paymentId } = data;
    if (!paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'paymentId is required');
    }

    // 3. Read directPaymentRequest — moved up so all fields come from here
    const dpRef = db.collection('directPaymentRequests').doc(paymentId);
    const dpSnap = await dpRef.get();
    if (!dpSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'directPaymentRequest not found');
    }
    const dp = dpSnap.data()!;

    // 4. NEW — OWNERSHIP CHECK: only the assigned mohaffez may confirm
    if (dp.mohaffezId !== mohaffezId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only the assigned teacher can confirm this payment'
      );
    }

    // 5. Extract all plan / slot / student fields from dp doc
    //    (previously these came from the data payload when student was the caller)
    const studentId = dp.studentId as string; // CHANGED: was context.auth.uid

    // Plan fields
    const planId = dp.planId as string;
    const planTitle = dp.planTitle as string;
    const planType = dp.planType as string;
    const sessionsCount = dp.sessionsCount as number;
    const validityDays: number | null =
      typeof dp.validityDays === 'number' ? (dp.validityDays as number) : null;

    // Slot fields — already stored as Timestamps by studentMarkedDirectPayment
    // WHY: no string-to-Date parsing needed; avoids timezone-shift bug
    const slotDateTs =
      dp.sessionDate instanceof admin.firestore.Timestamp
        ? (dp.sessionDate as admin.firestore.Timestamp)
        : null;
    const slotStartTs =
      dp.slotStart instanceof admin.firestore.Timestamp
        ? (dp.slotStart as admin.firestore.Timestamp)
        : null;
    const slotEndTs =
      dp.slotEnd instanceof admin.firestore.Timestamp
        ? (dp.slotEnd as admin.firestore.Timestamp)
        : null;
    const preferredTimeSlot = dp.preferredTimeSlot as string | undefined;
    const slotSessionType = dp.sessionType as string | undefined;
    const mohaffezPhone = dp.mohaffezPhone as string | undefined;
    const imamAddressText = dp.imamAddressText as string | undefined;
    const imamAddressLat = dp.imamAddressLat as number | undefined;
    const imamAddressLng = dp.imamAddressLng as number | undefined;

    // 6. Validate required plan fields (from dp doc)
    if (!planId || !planTitle || !planType || !sessionsCount) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'directPaymentRequest is missing required plan fields (planId/planTitle/planType/sessionsCount)'
      );
    }

    // 7. isSlotCoupled — all five slot fields present in the dp doc
    //    studentMarkedDirectPayment requires slot fields, so this is true in Path B
    const isSlotCoupled = !!(
      slotDateTs &&
      slotStartTs &&
      slotEndTs &&
      preferredTimeSlot &&
      slotSessionType
    );

    functions.logger.info('confirmBundleDirectPayment params', {
      paymentId,
      planType,
      sessionsCount,
      isSlotCoupled,
      mohaffezId,
    });

    try {
      // 8. Pre-transaction idempotency guard
      if (dp.status === 'confirmed' && dp.subscriptionId) {
        functions.logger.info(
          'confirmBundleDirectPayment already confirmed pre-tx check',
          { paymentId, subscriptionId: dp.subscriptionId }
        );
        return {
          success: true,
          subscriptionId: dp.subscriptionId,
          message: 'Already confirmed',
        };
      }

      // ── Step 8.5: Atomic claim — prevents concurrent triple-execution ──
      let claimedSubscriptionId: string | null = null;

      type ClaimResult = 'claimed' | 'already-confirmed' | 'already-confirming';

      const claimResult: ClaimResult = await db.runTransaction(async (tx) => {
        const snap = await tx.get(dpRef);
        if (!snap.exists) {
          throw new functions.https.HttpsError('not-found', 'directPaymentRequest not found');
        }
        const d = snap.data()!;

        if (d.status === 'confirmed' && d.subscriptionId) {
          claimedSubscriptionId = d.subscriptionId as string;
          return 'already-confirmed';
        }

        if (d.status === 'confirming') {
          return 'already-confirming';
        }

        tx.update(dpRef, {
          status: 'confirming',
          confirmingStartedAt: FieldValue.serverTimestamp(),
        });
        return 'claimed';
      });

      if (claimResult === 'already-confirmed') {
        functions.logger.info('confirmBundleDirectPayment: idempotent (already-confirmed)', { paymentId });
        return { success: true, subscriptionId: claimedSubscriptionId!, message: 'Already confirmed' };
      }

      if (claimResult === 'already-confirming') {
        functions.logger.info('confirmBundleDirectPayment: idempotent (already-confirming)', { paymentId });
        return { success: true, message: 'Confirmation already in progress' };
      }
      // claimResult === 'claimed' → fall through to main transaction (Step 9)

      // 9. Main transaction
      const result = await db.runTransaction(async (transaction) => {
        // Re-read dpRef inside transaction for consistency
        const dpSnapTx = await transaction.get(dpRef);
        if (!dpSnapTx.exists) {
          throw new functions.https.HttpsError('not-found', 'directPaymentRequest not found');
        }
        const dpTx = dpSnapTx.data()!;

        // Idempotency check inside transaction
        if (dpTx.status === 'confirmed' && dpTx.subscriptionId) {
          throw new AlreadyConfirmedError(dpTx.subscriptionId as string);
        }

        // Guard: only proceed if we own the 'confirming' status
        if (dpTx.status !== 'confirming') {
          throw new functions.https.HttpsError(
            'failed-precondition',
            `Unexpected status '${dpTx.status}' — expected 'confirming'`,
          );
        }

        // 9a. Read system config + effective commission rate.
        // Effective rate = tier rate + accumulated cycle penalty (capped at 100%).
        // Bundle commission must be consistent with single-session commission.
        const PER_SESSION_TYPE_LIMIT = 1; // one active bundle per studentId+mohaffezId+sessionType
        const [configSnap, teacherSnap] = await Promise.all([
          transaction.get(db.collection('systemConfig').doc('global')),
          transaction.get(db.collection('users').doc(mohaffezId as string)),
        ]);
        const teacherBase = teacherSnap.data()?.commissionRate;
        const globalRate = configSnap.data()?.commissionRate;
        const baseRate: number =
          typeof teacherBase === 'number' && teacherBase >= 0
            ? teacherBase
            : typeof globalRate === 'number' && globalRate >= 0
              ? globalRate
              : 0.05;
        const rawPenalty = teacherSnap.data()?.commissionPenaltyPercent;
        const penaltyPct =
          typeof rawPenalty === 'number' && isFinite(rawPenalty) && rawPenalty >= 0
            ? rawPenalty
            : 0;
        const commissionRate = Math.min(baseRate + penaltyPct / 100, 1.0);

        // 9b. FIX-3: Resolve sessionType with explicit priority order
        const resolvedSessionType: string = (() => {
          if (
            isSlotCoupled &&
            typeof slotSessionType === 'string' &&
            slotSessionType.trim()
          )
            return slotSessionType.trim();
          if (
            typeof dp.sessionType === 'string' &&
            (dp.sessionType as string).trim()
          )
            return (dp.sessionType as string).trim();
          const dpMetadata = (dp as Record<string, unknown>).metadata as
            | Record<string, unknown>
            | undefined;
          if (
            typeof dpMetadata?.sessionType === 'string' &&
            (dpMetadata.sessionType as string).trim()
          )
            return (dpMetadata.sessionType as string).trim();
          throw new functions.https.HttpsError(
            'invalid-argument',
            'sessionType could not be resolved from payment request or slot params'
          );
        })();

        // 9c. FIX-3: Uniqueness constraint — student + mohaffez + sessionType
        const activeSubsSnap = await transaction.get(
          db
            .collection('subscriptions')
            .where('studentId', '==', studentId)
            .where('mohaffezId', '==', mohaffezId)
            .where('sessionType', '==', resolvedSessionType)
            .where('status', '==', 'active')
            .where('remainingSessions', '>', 0)
        );
        if (activeSubsSnap.size >= PER_SESSION_TYPE_LIMIT) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'لديك باقة نشطة بالفعل لهذا النوع من الجلسات'
          );
        }

        // FIX: slot-lock-fix - NEW: Read existing sessionRequest if dp.sessionRequestId exists
        // This sessionRequest was created by studentMarkedDirectPayment for bundle purchases.
        // We need to get slotLockId to delete it after confirmation.
        let existingSlotLockId: string | null = null;
        if (dpTx.sessionRequestId) {
          const existingReqRef = db.collection('sessionRequests').doc(dpTx.sessionRequestId as string);
          const existingReqSnap = await transaction.get(existingReqRef);
          if (existingReqSnap.exists) {
            const existingReqData = existingReqSnap.data();
            existingSlotLockId = typeof existingReqData?.slotLockId === 'string' ? existingReqData.slotLockId : null;
          }
        }

        // 9d. Compute expiry
        const now = new Date();

        // Pre-read commission summary BEFORE any writes (Firestore transaction rule)
        const commissionDateObj = slotDateTs ? slotDateTs.toDate() : now;
        const weekNum = getWeekNumber(commissionDateObj);
        const commissionYear = commissionDateObj.getFullYear();
        const commissionAmount = (dp.amount as number) * commissionRate;
        const summaryId = `${mohaffezId}_${commissionYear}_w${weekNum}`;
        const summaryRef = db.collection('weeklyCommissionSummaries').doc(summaryId);
        const summarySnap = await transaction.get(summaryRef);
        const expiryDate =
          validityDays !== null
            ? admin.firestore.Timestamp.fromDate(
                new Date(now.getTime() + validityDays * 86400000)
              )
            : null;

        // 9e. Deterministic transaction tag — idempotency-safe (no Date.now)
        const transactionTag = `bundle-${paymentId}`;

        // 9f. Document refs
        // FIX: slot-lock-fix - Only create new sessionRequest if dp.sessionRequestId is null
        // (backwards compatibility for non-slot-lock flows)
        const subscriptionRef = db.collection('subscriptions').doc();
        const sessionRef = isSlotCoupled
          ? db.collection('hafizSessions').doc()
          : null;
        // Only create new requestRef if there's no existing sessionRequest (dp.sessionRequestId is null)
        const newRequestRef = isSlotCoupled && !dpTx.sessionRequestId
          ? db.collection('sessionRequests').doc()
          : null;

        // FIX-5: initialRemaining computed in-place; avoids a second write
        const initialRemaining = isSlotCoupled
          ? sessionsCount - 1
          : sessionsCount;

        // 9g. Write subscription
        const initialStatus = initialRemaining > 0 ? 'active' : 'depleted';

        transaction.set(subscriptionRef, {
          studentId,
          studentName: dp.studentName,
          mohaffezId,
          mohaffezName: dp.mohaffezName,
          planId,
          planTitle,
          planType,
          sessionType: resolvedSessionType, // FIX-3: stored for future queries
          totalSessions: sessionsCount,
          remainingSessions: initialRemaining, // FIX-5
          totalPaid: dp.amount,
          paymentTransactionId: transactionTag,
          startDate: FieldValue.serverTimestamp(),
          expiryDate,
          status: initialStatus,
          directPaymentRequestId: paymentId,
          // WHY: preserves link back to the original bundle booking request
          sessionRequestId: dp.sessionRequestId ?? null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 9h. Slot-coupled: create first hafizSession + linked sessionRequest
        // FIX: slot-lock-fix - If dp.sessionRequestId exists, UPDATE that request instead of creating new one
        let createdSessionId: string | null = null;
        let createdRequestId: string | null = null;

        if (
          isSlotCoupled &&
          sessionRef &&
          slotDateTs &&
          slotStartTs &&
          slotEndTs
        ) {
          createdSessionId = sessionRef.id;

          transaction.set(sessionRef, {
            studentId,
            studentName: dp.studentName,
            mohaffezId,
            mohaffezName: dp.mohaffezName,
            sessionType: resolvedSessionType,
            preferredProvider:
              resolvedSessionType === 'online' && typeof dp.preferredProvider === 'string' && dp.preferredProvider.length > 0
                ? dp.preferredProvider
                : null,
            preferredTimeSlot,
            sessionDate: slotDateTs,
            slotStart: slotStartTs,
            slotEnd: slotEndTs,
            status: 'accepted',
            isPaid: true,
            paymentType: 'bundle',
            subscriptionId: subscriptionRef.id,
            paymentTransactionId: transactionTag,
            requestId: dpTx.sessionRequestId ?? newRequestRef?.id ?? null,
            mohaffezPhone: mohaffezPhone ?? null,
            imamAddressText: imamAddressText ?? null,
            imamAddressLat: imamAddressLat ?? null,
            imamAddressLng: imamAddressLng ?? null,
            createdAt: FieldValue.serverTimestamp(),
            acceptedAt: FieldValue.serverTimestamp(),
            reminder24hSent: false,
            reminder1hSent: false,
            juzCount: 1,
            sessionRating: 10,
            // FIX-Bug4: prevents onSessionCreated Firestore trigger from
            // firing a duplicate push notification; this CF sends its own below
            notificationsAlreadySent: true,
          });

          // FIX: slot-lock-fix - If dp.sessionRequestId exists, UPDATE the existing request
          // Otherwise, create a new one (backwards compatibility)
          if (dpTx.sessionRequestId) {
            // Update existing sessionRequest created by studentMarkedDirectPayment
            createdRequestId = dpTx.sessionRequestId as string;
            transaction.update(
              db.collection('sessionRequests').doc(dpTx.sessionRequestId as string),
              {
                status: 'accepted',
                isPaid: true,
                paidAt: FieldValue.serverTimestamp(),
                subscriptionId: subscriptionRef.id,
                sessionId: sessionRef.id,
                paymentId,
                directPaymentConfirmedAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
              }
            );
          } else if (newRequestRef) {
            // Create new sessionRequest (backwards compatibility)
            createdRequestId = newRequestRef.id;
            transaction.set(newRequestRef, {
              studentId,
              studentName: dp.studentName,
              mohaffezId,
              mohaffezName: dp.mohaffezName,
              sessionType: resolvedSessionType,
              preferredTimeSlot,
              slotDate: slotDateTs,
              slotStart: slotStartTs,
              slotEnd: slotEndTs,
              status: 'accepted',
              paymentType: 'bundle',
              subscriptionId: subscriptionRef.id,
              sessionId: sessionRef.id,
              paymentId,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }

        // 9i. Confirm the directPaymentRequest
        transaction.update(dpRef, {
          status: 'confirmed',
          subscriptionId: subscriptionRef.id,
          mohaffezConfirmedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 9i-commission. Write bundle commission to weeklyCommissionSummaries.
        // summarySnap was pre-read above (before writes) to satisfy Firestore transaction ordering.
        if (summarySnap.exists) {
          transaction.update(summaryRef, {
            totalSessions:    FieldValue.increment(1),
            totalRevenue:     FieldValue.increment(dp.amount as number),
            commissionAmount: FieldValue.increment(commissionAmount),
            updatedAt:        FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(summaryRef, {
            mohaffezId,
            mohaffezName:    dp.mohaffezName,
            weekNumber:      weekNum,
            year:            commissionYear,
            totalSessions:   1,
            totalRevenue:    dp.amount,
            commissionAmount,
            commissionRate,
            status:          'pending',
            weekStart:       admin.firestore.Timestamp.fromDate(getWeekStart(commissionDateObj)),
            weekEnd:         admin.firestore.Timestamp.fromDate(getWeekEnd(commissionDateObj)),
            dueDate:         admin.firestore.Timestamp.fromDate(getNextMonday(commissionDateObj)),
            createdAt:       FieldValue.serverTimestamp(),
            updatedAt:       FieldValue.serverTimestamp(),
          });
        }

        // FIX double-write-2: DELETED step 9j - it was updating the same
        // sessionRequests/{sessionRequestId} document that step 9h already updated.
        // This caused "Transaction: modified document more than once" error.
        // Step 9h already contains all fields needed (status, isPaid, paidAt,
        // subscriptionId, sessionId, paymentId, directPaymentConfirmedAt, updatedAt).

        // FIX: slot-lock-fix - NEW Step 9k: Delete the slotLock after confirmation
        // This releases the slot so it's no longer reserved. The slot is now confirmed
        // and a hafizSession exists, so no lock is needed.
        if (existingSlotLockId) {
          transaction.delete(db.collection('slotLocks').doc(existingSlotLockId));
        }

        functions.logger.info('confirmBundleDirectPayment Subscription created', {
          paymentId,
          subscriptionId: subscriptionRef.id,
          isSlotCoupled,
          sessionId: createdSessionId,
        });

        return {
          subscriptionId: subscriptionRef.id,
          createdSessionId,
          createdRequestId,
        };
      });

      // 10. Post-transaction notifications — fire-and-forget.
      // WHY: the Firestore transaction already committed; a slow or failing FCM
      // call must never block this response. Awaiting it caused the teacher's
      // screen to stay in a loading state for the full 30-second client timeout
      // even though the subscription was already confirmed.
      let notificationBody =
        planType === 'bundle'
          ? `تم تفعيل حزمة "${planTitle}" · ${sessionsCount} جلسة`
          : `تم تفعيل اشتراك "${planTitle}" · ${sessionsCount} جلسة`;
      if (isSlotCoupled) {
        notificationBody += '\nتم حجز أول جلسة بنجاح ✅';
      }

      createAndSendNotification({
        userId: studentId,
        senderId: mohaffezId,
        title: planType === 'bundle' ? 'تم تأكيد الحزمة! ✅' : 'تم تأكيد الاشتراك! ✅',
        body: notificationBody,
        type: 'subscriptioncreated',
        highPriority: true,
        data: {
          subscriptionId: result.subscriptionId,
          planTitle,
          planType,
          sessionsCount: String(sessionsCount),
        },
      }).catch((err: unknown) => {
        functions.logger.error('confirmBundleDirectPayment: notification failed (non-blocking)', {
          paymentId,
          error: err instanceof Error ? err.message : String(err),
        });
      });

      functions.logger.info('confirmBundleDirectPayment Completed successfully', {
        paymentId,
        subscriptionId: result.subscriptionId,
      });

      // 11. Return success
      const response: Record<string, unknown> = {
        success: true,
        subscriptionId: result.subscriptionId,
        message:
          planType === 'bundle'
            ? `تم تفعيل حزمة ${sessionsCount} جلسة`
            : `تم تفعيل اشتراك ${sessionsCount} جلسة`,
      };
      if (isSlotCoupled && result.createdSessionId && result.createdRequestId) {
        response.sessionId = result.createdSessionId;
        response.requestId = result.createdRequestId;
      }
      return response;
    } catch (error) {
      // Idempotency shortcut thrown from inside the transaction
      if (error instanceof AlreadyConfirmedError) {
        functions.logger.info(
          'confirmBundleDirectPayment idempotent transaction path',
          { paymentId }
        );
        return {
          success: true,
          subscriptionId: error.existingSubscriptionId,
          message: 'Already confirmed',
        };
      }
      try {
        const dpSnap = await dpRef.get();
        if (dpSnap.exists) {
          const dpData = dpSnap.data();
          if (dpData?.status === 'confirming') {
            await dpRef.update({
              status: 'pendingconfirmation',
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (resetError) {
        functions.logger.error('confirmBundleDirectPayment failed to restore payment status', {
          paymentId,
          resetError: resetError instanceof Error ? resetError.message : 'Unknown reset error',
        });
      }
      // Re-throw HttpsErrors as-is — never wrap in 'internal'
      if (error instanceof functions.https.HttpsError) throw error;
      const message = error instanceof Error ? error.message : 'Unknown error';
      functions.logger.error('confirmBundleDirectPayment failed', {
        paymentId,
        error: message,
      });
      throw new functions.https.HttpsError('internal', message);
    }
  }
);
