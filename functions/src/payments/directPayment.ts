// functions/src/payments/directPayment.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import {
  getWeekNumber,
  getWeekStart,
  getWeekEnd,
  getNextMonday,
  parseFlutterDate,
} from '../utils/dateHelpers';

const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;


// ─────────────────────────────────────────────────────────────────────────────
// 1. studentMarkedDirectPayment
// ─────────────────────────────────────────────────────────────────────────────
export const studentMarkedDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const studentId = context.auth.uid;

    const {
      requestId,
      mohaffezId,
      mohaffezName,
      studentName,
      amount,
      sessionType,
      preferredTimeSlot,
      slotDate,
      slotStart,
      slotEnd,
      paymentMethod,
      studentNote,
      imamAddressText,
      imamAddressLat,
      imamAddressLng,
      mohaffezPhone,
      planType,
      planId,
      planTitle,
      sessionsCount,
      validityDays,
    } = data;

    if (typeof requestId !== 'string' || requestId.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'requestId required');
    }

    const finalPlanType: string = (planType as string | undefined) ?? 'single';
    const finalPlanId: string | null = (planId as string | undefined) ?? null;
    const finalPlanTitle: string | null = (planTitle as string | undefined) ?? null;
    const finalSessionsCount: number | null =
      typeof sessionsCount === 'number' ? sessionsCount : null;
    const finalValidityDays: number | null =
      typeof validityDays === 'number' ? validityDays : null;
    const isBundleOrSubscription =
      finalPlanType === 'bundle' || finalPlanType === 'subscription';

    const hasSlotFields =
      !!slotDate && !!slotStart && !!slotEnd && !!preferredTimeSlot;

    return db.runTransaction(async (tx) => {
      // ── READS ──
      const reqRef = db.collection('sessionRequests').doc(requestId);
      const reqSnap = await tx.get(reqRef);

      if (!reqSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Session request not found');
      }

      const reqData = reqSnap.data()!;

      if (reqData.status === STATUS.ACCEPTED) {
        throw new functions.https.HttpsError(
          'already-exists',
          JSON.stringify({ success: true, message: 'Already confirmed' })
        );
      }

      if (reqData.status === STATUS.AWAITING_DIRECT) {
        throw new functions.https.HttpsError(
          'already-exists',
          JSON.stringify({ success: true, message: 'Already marked as paid' })
        );
      }

      const isDirectPaymentPath = reqData.selectedPaymentMethod === 'directpayment';
      const acceptableStatuses: string[] = [STATUS.AWAITING_PAYMENT];
      if (isDirectPaymentPath) acceptableStatuses.push(STATUS.PENDING);

      if (!acceptableStatuses.includes(reqData.status as string)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Cannot mark payment: request status is ${reqData.status as string}.`
        );
      }

      const configSnap = await tx.get(db.collection('systemConfig').doc('global'));
      const commissionRate: number = (configSnap.data()?.commissionRate as number) ?? 0.05;

      const parsedSlotDate  = parseFlutterDate(slotDate  as string);
      const parsedSlotStart = parseFlutterDate(slotStart as string);
      const parsedSlotEnd   = parseFlutterDate(slotEnd   as string);
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 24 * 60 * 60 * 1000)
      );

      const newLockRef = db.collection('slotLocks').doc();
      const bundleSlotLockId = newLockRef.id;
      const newReqRef =
        isBundleOrSubscription && hasSlotFields
          ? db.collection('sessionRequests').doc()
          : null;
      const dpRef = db.collection('directPaymentRequests').doc();

      // WRITE A: slotLock
      tx.set(newLockRef, {
        id: newLockRef.id,
        mohaffezId,
        slotDate: admin.firestore.Timestamp.fromDate(parsedSlotDate),
        timeSlot: preferredTimeSlot,
        sessionType,
        lockedBy: studentId,
        lockedAt: FieldValue.serverTimestamp(),
        expiresAt,
        released: false,
        sessionRequestId:
          isBundleOrSubscription && hasSlotFields && newReqRef
            ? newReqRef.id
            : (requestId as string | undefined) ?? null,
      });

      // WRITE B: new sessionRequest for bundle/subscription (slot-coupled only)
      if (isBundleOrSubscription && hasSlotFields && newReqRef) {
        tx.set(newReqRef, {
          id: newReqRef.id,
          status: STATUS.AWAITING_DIRECT,
          studentId,
          studentName,
          mohaffezId,
          mohaffezName,
          sessionType,
          preferredTimeSlot,
          slotDate:  admin.firestore.Timestamp.fromDate(parsedSlotDate),
          slotStart: admin.firestore.Timestamp.fromDate(parsedSlotStart),
          slotEnd:   admin.firestore.Timestamp.fromDate(parsedSlotEnd),
          planType:       finalPlanType,
          planId:         finalPlanId,
          planTitle:      finalPlanTitle,
          sessionsCount:  finalSessionsCount,
          validityDays:   finalValidityDays,
          isPaid: false,
          selectedPaymentMethod: 'directpayment',
          directPaymentRequestId: null,
          slotLockId: newLockRef.id,
          paymentAmount: amount,
          requiresPaymentOnAcceptance: false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // WRITE C: directPaymentRequest
      tx.set(dpRef, {
        id: dpRef.id,
        // When this is a bundle/subscription purchase AND slot fields are present AND newReqRef exists:
        // - sessionRequestId  → newReqRef.id  (the new slot-lock sessionRequest)
        //   WHY: confirmBundleDirectPayment Step 9h updates dp.sessionRequestId → 'accepted',
        //        which removes req-B from the teacher's inbox. Step 9k reads slotLockId from it.
        // - originalSessionRequestId → requestId  (the original request from the client)
        //   WHY: confirmBundleDirectPayment Step 9h-b resolves req-A using this field.
        //
        // When this is a single-session purchase OR no slot fields OR no newReqRef:
        // - sessionRequestId  → requestId  (no change from current behavior)
        // - originalSessionRequestId → requestId  (same, Step 9h-b skips when equal)
        sessionRequestId: (isBundleOrSubscription && hasSlotFields && newReqRef)
          ? newReqRef.id
          : requestId,

        originalSessionRequestId: requestId,
        studentId,
        studentName,
        mohaffezId,
        mohaffezName,
        amount,
        commissionAmount: (amount as number) * commissionRate,
        commissionRate,
        sessionType,
        preferredTimeSlot,
        sessionDate: admin.firestore.Timestamp.fromDate(parsedSlotDate),
        slotStart:   admin.firestore.Timestamp.fromDate(parsedSlotStart),
        slotEnd:     admin.firestore.Timestamp.fromDate(parsedSlotEnd),
        imamAddressText: imamAddressText ?? null,
        imamAddressLat:  imamAddressLat  ?? null,
        imamAddressLng:  imamAddressLng  ?? null,
        mohaffezPhone:   mohaffezPhone   ?? null,
        paymentMethod,
        studentNote: studentNote ?? null,
        status: 'pendingconfirmation',
        studentConfirmedAt: FieldValue.serverTimestamp(),
        mohaffezConfirmedAt: null,
        sessionId: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        planType:      finalPlanType,
        planId:        finalPlanId,
        planTitle:     finalPlanTitle,
        sessionsCount: finalSessionsCount,
        validityDays:  finalValidityDays,
      });

      // WRITE D: update existing sessionRequest
      tx.update(reqRef, {
        status: STATUS.AWAITING_DIRECT,
        directPaymentRequestId: dpRef.id,
        slotLockId: newLockRef?.id ?? null,
        directPaymentMethod: paymentMethod,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // WRITE E: link bundle sessionRequest back to dpRef (slot-coupled only)
      if (isBundleOrSubscription && hasSlotFields && newReqRef) {
        tx.update(newReqRef, {
          directPaymentRequestId: dpRef.id,
        });
      }

      // WRITE F: notification to mohaffez
      const notifRef = db.collection('notifications').doc();
      tx.set(notifRef, {
        userId:      mohaffezId,
        recipientId: mohaffezId,
        senderId:    studentId,
        title: isBundleOrSubscription ? 'طلب دفع حزمة جديد' : 'طلب تأكيد دفع مباشر',
        body: isBundleOrSubscription
          ? `${studentName} حوّل ${amount} جنيه لـ ${finalPlanTitle} (${finalSessionsCount} جلسة) عبر ${paymentMethod}`
          : `${studentName} حوّل ${amount} جنيه عبر ${paymentMethod}`,
        type: 'directpaymentpending',
        isRead: false,
        data: {
          directPaymentRequestId: dpRef.id,
          sessionRequestId: requestId,
          studentId,
          studentName,
          amount:        (amount as number).toString(),
          paymentMethod,
          planType:      finalPlanType,
          planId:        finalPlanId,
          planTitle:     finalPlanTitle,
          sessionsCount: finalSessionsCount,
          validityDays:  finalValidityDays,
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        directPaymentRequestId: dpRef.id,
        sessionRequestId: requestId,
        slotLockId: bundleSlotLockId,
      };
    });
  }
);


// ─────────────────────────────────────────────────────────────────────────────
// 2. mohaffezConfirmDirectPayment  ← FIXED: Bug1 + Bug2
// ─────────────────────────────────────────────────────────────────────────────
export const mohaffezConfirmDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const mohaffezId = context.auth.uid;

    const callerDoc = await db.collection('users').doc(mohaffezId).get();
    if (!callerDoc.exists || callerDoc.data()?.role !== 'mohaffez') {
      throw new functions.https.HttpsError('permission-denied', 'Caller must be a mohaffez');
    }

    const directPaymentRequestId = data as string;
    if (!directPaymentRequestId) {
      throw new functions.https.HttpsError('invalid-argument', 'directPaymentRequestId required');
    }

    // ✅ FIX Bug2: try/catch instead of .catch() so raw errors are wrapped
    //    with their actual message, and HttpsErrors are re-thrown as-is.
    try {
      return await db.runTransaction(async (tx) => {
        // ── READS ──
        const dpRef  = db.collection('directPaymentRequests').doc(directPaymentRequestId);
        const dpSnap = await tx.get(dpRef);

        if (!dpSnap.exists) {
          throw new functions.https.HttpsError('not-found', 'Payment request not found');
        }

        const dp = dpSnap.data()!;

        if (dp.mohaffezId !== mohaffezId) {
          throw new functions.https.HttpsError('permission-denied', 'This payment is not for you');
        }

        if (dp.status === 'confirmed') {
          throw new functions.https.HttpsError(
            'already-exists',
            JSON.stringify({ success: true, sessionId: dp.sessionId, message: 'Already confirmed' })
          );
        }

        const sessionRequestId = dp.sessionRequestId as string | undefined;
        if (!sessionRequestId || sessionRequestId.trim().length === 0) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'directPaymentRequests doc is missing sessionRequestId.'
          );
        }

        const reqRef  = db.collection('sessionRequests').doc(sessionRequestId);
        const reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) {
          throw new functions.https.HttpsError('not-found', 'sessionRequest not found');
        }

        const reqData = reqSnap.data()!;

        const reqSessionType = reqData.sessionType as string | undefined;
        if (!reqSessionType || reqSessionType.trim().length === 0) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'sessionRequest is missing sessionType.'
          );
        }

        if (reqData.status === STATUS.ACCEPTED) {
          throw new functions.https.HttpsError(
            'already-exists',
            JSON.stringify({ success: true, message: 'Session already accepted' })
          );
        }

        const configSnap = await tx.get(db.collection('systemConfig').doc('global'));
        const commissionRate: number = (configSnap.data()?.commissionRate as number) ?? 0.05;

        // ✅ FIX Bug1: instanceof guard before .toDate() — prevents TypeError → INTERNAL
        if (!(dp.sessionDate instanceof admin.firestore.Timestamp)) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'directPaymentRequests doc has invalid or missing sessionDate.'
          );
        }
        const sessionDate   = dp.sessionDate as admin.firestore.Timestamp;
        const sessionDateObj = sessionDate.toDate(); // ✅ safe

        const weekNumber  = getWeekNumber(sessionDateObj);
        const year        = sessionDateObj.getFullYear();
        const commissionId = `${mohaffezId}${year}W${weekNumber}`;
        const commissionRef  = db.collection('weeklyCommissions').doc(commissionId);
        const commissionSnap = await tx.get(commissionRef);

        // ── WRITES ──
        const sessionRef = db.collection('hafizSessions').doc();
        const slotStart  = dp.slotStart as admin.firestore.Timestamp;
        const slotEnd    = dp.slotEnd   as admin.firestore.Timestamp;

        tx.set(sessionRef, {
          requestId:           (dp.sessionRequestId as string | null) ?? null,
          mohaffezId,
          studentId:           dp.studentId,
          mohaffezName:        dp.mohaffezName,
          studentName:         dp.studentName,
          sessionType:         dp.sessionType,
          preferredTimeSlot:   dp.preferredTimeSlot,
          sessionDate,
          slotStart,
          slotEnd,
          status:              'accepted',
          isPaid:              true,
          sessionPrice:        dp.amount,
          paymentType:         'directpayment',
          directPaymentRequestId,
          mohaffezPhone:       dp.mohaffezPhone       ?? null,
          imamAddressText:     dp.imamAddressText      ?? null,
          imamAddressLat:      dp.imamAddressLat       ?? null,
          imamAddressLng:      dp.imamAddressLng       ?? null,
          createdAt:           FieldValue.serverTimestamp(),
          acceptedAt:          FieldValue.serverTimestamp(),
          reminder24hSent:     false,
          reminder1hSent:      false,
          juzCount:            1,
          sessionRating:       10,
          notificationsAlreadySent: true,
        });

        tx.update(dpRef, {
          status:              'confirmed',
          sessionId:           sessionRef.id,
          mohaffezConfirmedAt: FieldValue.serverTimestamp(),
          updatedAt:           FieldValue.serverTimestamp(),
        });

        tx.update(reqRef, {
          status:                    STATUS.ACCEPTED,
          isPaid:                    true,
          paidAt:                    FieldValue.serverTimestamp(),
          sessionId:                 sessionRef.id,
          directPaymentConfirmedAt:  FieldValue.serverTimestamp(),
          updatedAt:                 FieldValue.serverTimestamp(),
        });

        const commissionAmount = (dp.amount as number) * commissionRate;
        const weekStart = getWeekStart(sessionDateObj);
        const weekEnd   = getWeekEnd(sessionDateObj);
        const dueDate   = getNextMonday(sessionDateObj);

        if (commissionSnap.exists) {
          tx.update(commissionRef, {
            totalSessions:   FieldValue.increment(1),
            totalRevenue:    FieldValue.increment(dp.amount as number),
            commissionAmount: FieldValue.increment(commissionAmount),
            updatedAt:       FieldValue.serverTimestamp(),
          });
        } else {
          tx.set(commissionRef, {
            mohaffezId,
            mohaffezName:    dp.mohaffezName,
            weekNumber,
            year,
            totalSessions:   1,
            totalRevenue:    dp.amount,
            commissionAmount,
            commissionRate,
            status:          'pending',
            weekStart:       admin.firestore.Timestamp.fromDate(weekStart),
            weekEnd:         admin.firestore.Timestamp.fromDate(weekEnd),
            dueDate:         admin.firestore.Timestamp.fromDate(dueDate),
            createdAt:       FieldValue.serverTimestamp(),
            updatedAt:       FieldValue.serverTimestamp(),
          });
        }

        const notifRef = db.collection('notifications').doc();
        tx.set(notifRef, {
          userId:      dp.studentId,
          recipientId: dp.studentId,
          senderId:    mohaffezId,
          title:       'تم تأكيد الدفع المباشر!',
          body:        `${dp.mohaffezName as string} أكد استلام المبلغ! تم تأكيد جلستك تلقائياً`,
          type:        'directpaymentconfirmed',
          isRead:      false,
          data: {
            sessionId:          sessionRef.id,
            sessionRequestId:   (dp.sessionRequestId as string | null) ?? null,
            directPaymentRequestId,
          },
          createdAt: FieldValue.serverTimestamp(),
        });

        return {
          success:   true,
          sessionId: sessionRef.id,
          message:   'تم تأكيد الدفع! تم إنشاء الجلسة تلقائياً',
        };
      });

    } catch (error) {
      // ✅ FIX Bug2 (continued): idempotency shortcut
      if ((error as { code?: string }).code === 'already-exists') {
        return JSON.parse((error as Error).message);
      }
      // Re-throw HttpsErrors as-is — never let Firebase wrap them as 'internal'
      if (error instanceof functions.https.HttpsError) throw error;
      // Wrap raw errors so the real message surfaces on the client
      const message = error instanceof Error ? error.message : 'Unknown error';
      functions.logger.error('mohaffezConfirmDirectPayment failed', {
        directPaymentRequestId,
        message,
        error,
      });
      throw new functions.https.HttpsError('internal', message);
    }
  }
);


// ─────────────────────────────────────────────────────────────────────────────
// 3. mohaffezRejectDirectPayment  ← unchanged
// ─────────────────────────────────────────────────────────────────────────────
export const mohaffezRejectDirectPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const mohaffezId = context.auth.uid;

    const callerDoc = await db.collection('users').doc(mohaffezId).get();
    if (!callerDoc.exists || callerDoc.data()?.role !== 'mohaffez') {
      throw new functions.https.HttpsError('permission-denied', 'Caller must be a mohaffez');
    }

    const { directPaymentRequestId, rejectionReason } = data;
    if (!directPaymentRequestId) {
      throw new functions.https.HttpsError('invalid-argument', 'directPaymentRequestId required');
    }

    return db
      .runTransaction(async (tx) => {
        // ── READS ──
        const dpRef  = db.collection('directPaymentRequests').doc(directPaymentRequestId);
        const dpSnap = await tx.get(dpRef);

        if (!dpSnap.exists) {
          throw new functions.https.HttpsError('not-found', 'Payment request not found');
        }

        const dp = dpSnap.data()!;

        if (dp.mohaffezId !== mohaffezId) {
          throw new functions.https.HttpsError('permission-denied', 'This payment is not for you');
        }

        if (dp.status === 'confirmed') {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Cannot reject confirmed payment'
          );
        }

        if (dp.status === 'rejected') {
          throw new functions.https.HttpsError(
            'already-exists',
            JSON.stringify({ success: true, message: 'Already rejected' })
          );
        }

        let reqRef: FirebaseFirestore.DocumentReference | null = null;
        if (dp.sessionRequestId) {
          reqRef = db.collection('sessionRequests').doc(dp.sessionRequestId as string);
          await tx.get(reqRef); // must read before write in Firestore transactions
        }

        // ── WRITES ──
        tx.update(dpRef, {
          status:               'rejected',
          rejectionReason:      rejectionReason ?? null,
          mohaffezRejectedAt:   FieldValue.serverTimestamp(),
          updatedAt:            FieldValue.serverTimestamp(),
        });

        if (reqRef) {
          const rejectedPlanType =
            typeof dp.planType === 'string' ? dp.planType : 'single';
          const isRejectedBundlePlan =
            rejectedPlanType === 'bundle' || rejectedPlanType === 'subscription';

          tx.update(reqRef, {
            status: isRejectedBundlePlan ? STATUS.PENDING : STATUS.AWAITING_PAYMENT,
            directPaymentRequestId:   null,
            directPaymentRejectedAt:  FieldValue.serverTimestamp(),
            updatedAt:                FieldValue.serverTimestamp(),
          });
        }

        // FIX[BUNDLE-ORPHAN]: Also reset the original session request (Request A) on rejection
        const originalSessionRequestId = dp.originalSessionRequestId as string | undefined;
        if (
          originalSessionRequestId &&
          originalSessionRequestId !== (dp.sessionRequestId as string | undefined)
        ) {
          const originalReqRef = db.collection('sessionRequests').doc(originalSessionRequestId);
          const originalReqSnap = await tx.get(originalReqRef);
          if (originalReqSnap.exists) {
            const prevStatus = originalReqSnap.data()?.status as string | undefined;
            const resolvableOnReject = [
              'awaitingdirectpaymentconfirmation',
              'awaitingPayment',
              'pending',
            ];
            if (prevStatus && resolvableOnReject.includes(prevStatus)) {
              tx.update(originalReqRef, {
                status: STATUS.PENDING,
                directPaymentRequestId: null,
                directPaymentRejectedAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
        }

        const notifRef = db.collection('notifications').doc();
        tx.set(notifRef, {
          userId:      dp.studentId,
          recipientId: dp.studentId,
          senderId:    mohaffezId,
          title:       'تم رفض الدفع',
          body: rejectionReason
            ? `${dp.mohaffezName} رفض الدفع: ${rejectionReason}`
            : `${dp.mohaffezName} لم يتمكن من تأكيد استلام المبلغ`,
          type:    'directpaymentrejected',
          isRead:  false,
          data: {
            sessionRequestId:      dp.sessionRequestId,
            directPaymentRequestId,
          },
          createdAt: FieldValue.serverTimestamp(),
        });

        return { success: true, message: 'تم رفض الدفع' };
      })
      .catch((e: unknown) => {
        if ((e as { code?: string }).code === 'already-exists') {
          return JSON.parse((e as Error).message);
        }
        throw e;
      });
  }
);
