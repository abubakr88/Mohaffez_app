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

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

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

        // 9a. Read system config for maxActiveSubscriptions + commissionRate
        const configSnap = await transaction.get(
          db.collection('systemConfig').doc('global')
        );
        const maxActive: number =
          (configSnap.data()?.maxActiveSubscriptions as number) ?? 3;
        // commissionRate retained for future per-bundle commission tracking parity
        // const commissionRate: number =
        //   (configSnap.data()?.commissionRate as number) ?? 0.05;

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
        );
        if (activeSubsSnap.size >= maxActive) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'لديك عدد كافٍ من الاشتراكات النشطة مع هذا المحفظ'
          );
        }

        // 9d. Compute expiry
        const now = new Date();
        const expiryDate =
          validityDays !== null
            ? admin.firestore.Timestamp.fromDate(
                new Date(now.getTime() + validityDays * 86400000)
              )
            : null;

        // 9e. Deterministic transaction tag — idempotency-safe (no Date.now)
        const transactionTag = `bundle-${paymentId}`;

        // 9f. Document refs
        const subscriptionRef = db.collection('subscriptions').doc();
        const sessionRef = isSlotCoupled
          ? db.collection('hafizSessions').doc()
          : null;
        const newRequestRef = isSlotCoupled
          ? db.collection('sessionRequests').doc()
          : null;

        // FIX-5: initialRemaining computed in-place; avoids a second write
        const initialRemaining = isSlotCoupled
          ? sessionsCount - 1
          : sessionsCount;

        // 9g. Write subscription
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
          status: 'active',
          directPaymentRequestId: paymentId,
          // WHY: preserves link back to the original bundle booking request
          sessionRequestId: dp.sessionRequestId ?? null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 9h. Slot-coupled: create first hafizSession + linked sessionRequest
        let createdSessionId: string | null = null;
        let createdRequestId: string | null = null;

        if (
          isSlotCoupled &&
          sessionRef &&
          newRequestRef &&
          slotDateTs &&
          slotStartTs &&
          slotEndTs
        ) {
          createdSessionId = sessionRef.id;
          createdRequestId = newRequestRef.id;

          transaction.set(sessionRef, {
            studentId,
            studentName: dp.studentName,
            mohaffezId,
            mohaffezName: dp.mohaffezName,
            sessionType: resolvedSessionType,
            preferredTimeSlot,
            sessionDate: slotDateTs,
            slotStart: slotStartTs,
            slotEnd: slotEndTs,
            status: 'accepted',
            isPaid: true,
            paymentType: 'bundle',
            subscriptionId: subscriptionRef.id,
            paymentTransactionId: transactionTag,
            requestId: newRequestRef.id,
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

        // 9i. Confirm the directPaymentRequest
        transaction.update(dpRef, {
          status: 'confirmed',
          subscriptionId: subscriptionRef.id,
          mohaffezConfirmedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 9j. Update the ORIGINAL bundle booking sessionRequest (created by
        //     createSessionRequest CF). dp.sessionRequestId links back to it.
        //     WHY: marks the teacher-facing request as fully resolved so it
        //     disappears from MohaffezRequestsScreen pending list.
        if (dp.sessionRequestId) {
          transaction.update(
            db.collection('sessionRequests').doc(dp.sessionRequestId as string),
            {
              status: 'accepted',
              isPaid: true,
              paidAt: FieldValue.serverTimestamp(),
              subscriptionId: subscriptionRef.id,
              directPaymentConfirmedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }
          );
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

      // 10. Post-transaction notifications (non-blocking for atomicity)
      let notificationBody =
        planType === 'bundle'
          ? `تم تفعيل حزمة "${planTitle}" · ${sessionsCount} جلسة`
          : `تم تفعيل اشتراك "${planTitle}" · ${sessionsCount} جلسة`;
      if (isSlotCoupled) {
        notificationBody += '\nتم حجز أول جلسة بنجاح ✅';
      }

      await createAndSendNotification({
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
