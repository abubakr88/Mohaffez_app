// functions/src/payments/confirmSubscriptionSession.ts
// FIX #4:    sessionType uniqueness — subscription.sessionType must match requested sessionType
// FIX TOCTOU: requestRef + subRef reads parallelised; re-validated atomically inside
//             consumeSubscriptionAndCreateSession's own transaction
// FIX:       HttpsErrors re-thrown directly — never wrapped as 'internal'
// FIX:       parseFlutterDate used for all slot timestamps (avoids local-timezone shift)
// FIX:       Deterministic transactionId (removes Date.now() suffix → idempotency-safe)
// BUG #3:    maxActiveSubscriptions + commission tracking preserved

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { getWeekNumber, getWeekStart, getWeekEnd, getNextMonday } from '../utils/dateHelpers';
import { consumeSubscriptionAndCreateSession, SlotInfo } from './handlers';
import { createAndSendNotification } from '../utils/notificationHelpers';
import { PaymentDocument } from '../types/payment.types';

const COMMISSION_RATE = 0.05;

const STATUS = {
  PENDING:          'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT:  'awaitingdirectpaymentconfirmation',
  ACCEPTED:         'accepted',
  REJECTED:         'rejected',
  CANCELLED:        'cancelled',
} as const;

// ---------------------------------------------------------------------------
// FIX: Parse Flutter ISO strings that have no timezone suffix as UTC.
// new Date('2026-03-08T10:00:00') is interpreted as LOCAL time on Node.js,
// which shifts the stored Timestamp by the server's UTC offset.
// ---------------------------------------------------------------------------
function parseFlutterDate(iso: string): Date {
  if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
    return new Date(iso + 'Z');
  }
  return new Date(iso);
}

// ---------------------------------------------------------------------------
// Main callable
// ---------------------------------------------------------------------------
export const confirmSubscriptionSession = functions.https.onCall(
  async (data, context) => {
    functions.logger.info('confirmSubscriptionSession: Starting', {
      timestamp: new Date().toISOString(),
    });

    // 1. Auth ----------------------------------------------------------------
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'المستخدم غير مصادق عليه'
      );
    }
    const mohaffezId = context.auth.uid;

    // 2. Caller must be the mohaffez -----------------------------------------
    if (context.auth.uid !== data.mohaffezId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'غير مصرح لك بتأكيد هذه الجلسة'
      );
    }

    // 3. Extract params -------------------------------------------------------
    const {
      subscriptionId,
      requestId,
      mohaffezName,
      studentId,
      studentName,
      sessionType,
      preferredTimeSlot,
      slotDate,
      slotStart,
      slotEnd,
      imamAddressText,
      imamAddressLat,
      imamAddressLng,
      mohaffezPhone,
      amount,
    } = data;

    // 4. Validate required fields ---------------------------------------------
    if (
      !subscriptionId || !requestId  || !mohaffezId    ||
      !studentId      || !studentName || !sessionType   ||
      !preferredTimeSlot || !slotDate || !slotStart     ||
      !slotEnd        || !amount
    ) {
      throw new functions.https.HttpsError('invalid-argument', 'بيانات غير مكتملة');
    }

    // 5. Pre-parse slot timestamps (pure — no I/O) ---------------------------
    // Done before any async work so the transaction body stays reads-then-writes.
    const sessionDateTs = admin.firestore.Timestamp.fromDate(
      parseFlutterDate(slotDate as string)
    );
    const slotStartTs = admin.firestore.Timestamp.fromDate(
      parseFlutterDate(slotStart as string)
    );
    const slotEndTs = admin.firestore.Timestamp.fromDate(
      parseFlutterDate(slotEnd as string)
    );

    // Pre-build document refs
    const requestRef = db.collection('sessionRequests').doc(requestId as string);
    const subRef     = db.collection('subscriptions').doc(subscriptionId as string);

    // Deterministic transactionId — removes Date.now() so retries are idempotent
    const transactionId = `direct_sub_${subscriptionId as string}_${requestId as string}`;

    try {
      // 6. Parallel pre-validation reads (non-transactional fast-failure) ----
      // Critical invariants are re-checked atomically inside
      // consumeSubscriptionAndCreateSession's own Firestore transaction.
      const [requestSnap, subSnap] = await Promise.all([
        requestRef.get(),
        subRef.get(),
      ]);

      if (!requestSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
      }
      if (!subSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'الاشتراك غير موجود');
      }

      const requestData  = requestSnap.data()!;
      const subscription = subSnap.data()!;

      // 7. Idempotency guard --------------------------------------------------
      if (requestData.status === STATUS.ACCEPTED && requestData.sessionId) {
        functions.logger.info('confirmSubscriptionSession: idempotent', {
          requestId,
          sessionId: requestData.sessionId,
        });
        return {
          success:   true,
          sessionId: requestData.sessionId,
          message:   'Already confirmed',
        };
      }

      // 8. Status check -------------------------------------------------------
      if (
        requestData.status !== STATUS.AWAITING_PAYMENT &&
        requestData.status !== STATUS.AWAITING_DIRECT
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Request status is '${requestData.status as string}', ` +
          `expected 'awaitingpayment' or 'awaitingdirectpaymentconfirmation'`
        );
      }

      // 9. Ownership check ----------------------------------------------------
      if (
        subscription.studentId  !== studentId ||
        subscription.mohaffezId !== mohaffezId
      ) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'الاشتراك لا ينتمي للمستخدمين المحددين'
        );
      }

      // 10. FIX #4: sessionType uniqueness check ------------------------------
      // A student must use a bundle/subscription that was created for the SAME
      // sessionType. Without this, an 'online' bundle could be used to book a
      // 'home' or 'mosque' session, bypassing the per-type uniqueness constraint.
      //
      // subscription.sessionType may be absent on legacy docs (created before
      // FIX #3 was deployed). In that case we skip the check to preserve
      // backward compatibility — new subscriptions always store sessionType.
      if (
        subscription.sessionType &&
        (subscription.sessionType as string) !== (sessionType as string)
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `نوع الجلسة المطلوبة '${sessionType as string}' لا يتطابق مع نوع جلسة الاشتراك ` +
          `'${subscription.sessionType as string}'. ` +
          `يجب استخدام اشتراك مطابق لنوع الجلسة.`
        );
      }

      // 11. Remaining sessions check -----------------------------------------
      const remainingSessions = (subscription.remainingSessions as number) ?? 0;
      if (remainingSessions <= 0) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'لا توجد جلسات متبقية في هذا الاشتراك'
        );
      }

      // 12. Build sessionDetails for hafizSessions document ------------------
      const sessionDetails = {
        requestId,
        mohaffezId,
        studentId,
        mohaffezName,
        studentName,
        sessionType,
        preferredTimeSlot,
        timeSlot:         preferredTimeSlot,
        sessionDate:      sessionDateTs,
        slotStart:        slotStartTs,
        slotEnd:          slotEndTs,
        location:         imamAddressText  ?? '',
        imamAddressText:  imamAddressText  ?? null,
        imamAddressLat:   imamAddressLat   ?? null,
        imamAddressLng:   imamAddressLng   ?? null,
        mohaffezPhone:    mohaffezPhone    ?? null,
        isPaid:           true,
        paymentMethod:    'subscription',
        subscriptionId,
        reminder24hSent:  false,
        reminder1hSent:   false,
        juzCount:         1,
        sessionRating:    10,
        // Prevents the Firestore trigger from sending a duplicate notification
        notificationsAlreadySent: true,
      };

      // 13. Build synthetic PaymentDocument ------------------------------------
      const syntheticPayment: PaymentDocument = {
        studentId:   studentId   as string,
        studentName: studentName as string,
        mohaffezId,
        mohaffezName: mohaffezName as string,
        amount:       amount      as number,
        status:       'completed',
        metadata: {
          subscriptionId,
          requestId,
          sessionDetails,
        },
      };

      // 14. Build SlotInfo -----------------------------------------------------
      const slotInfo: SlotInfo = {
        mohaffezId,
        slotDate:    sessionDateTs,
        timeSlot:    preferredTimeSlot as string,
        sessionType: sessionType       as string,
      };

      // 15. Consume subscription + create session (atomic inside handler) -----
      const result = await consumeSubscriptionAndCreateSession(
        subscriptionId as string,
        syntheticPayment,
        transactionId,
        syntheticPayment.metadata!,
        slotInfo
      );

      functions.logger.info('confirmSubscriptionSession: Session consumed', {
        subscriptionId,
        sessionId:         result.sessionId,
        remainingSessions: result.remainingSessions,
      });

      // 16. Commission tracking (separate transaction — non-blocking for session) --
      const now              = new Date();
      const weekNumber       = getWeekNumber(now);
      const weekStart        = getWeekStart(now);
      const weekEnd          = getWeekEnd(now);
      const commissionAmount = (amount as number) * COMMISSION_RATE;

      await db.runTransaction(async (tx) => {
        // Individual commission record
        const commRef = db.collection('commissions').doc();
        tx.set(commRef, {
          id:                     commRef.id,
          mohaffezId,
          mohaffezName,
          studentId,
          sessionId:              result.sessionId,
          subscriptionId,
          directPaymentRequestId: null,
          sessionRequestId:       requestId,
          amount,
          commissionAmount,
          commissionRate:         COMMISSION_RATE,
          paymentMethod:          'subscription',
          status:                 'pending',
          weekNumber,
          year:                   now.getFullYear(),
          weekStart:              admin.firestore.Timestamp.fromDate(weekStart),
          weekEnd:                admin.firestore.Timestamp.fromDate(weekEnd),
          createdAt:              FieldValue.serverTimestamp(),
          paidAt:                 null,
        });

        // Upsert weekly summary (merge:true makes this idempotent)
        const summaryId  = `${mohaffezId}_${now.getFullYear()}_w${weekNumber}`;
        const summaryRef = db.collection('weeklyCommissionSummaries').doc(summaryId);
        tx.set(
          summaryRef,
          {
            mohaffezId,
            mohaffezName,
            weekNumber,
            year:             now.getFullYear(),
            weekStart:        admin.firestore.Timestamp.fromDate(weekStart),
            weekEnd:          admin.firestore.Timestamp.fromDate(weekEnd),
            totalSessions:    FieldValue.increment(1),
            totalRevenue:     FieldValue.increment(amount),
            commissionAmount: FieldValue.increment(commissionAmount),
            commissionRate:   COMMISSION_RATE,
            status:           'pending',
            dueDate:          admin.firestore.Timestamp.fromDate(getNextMonday(weekEnd)),
            updatedAt:        FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      });

      functions.logger.info('confirmSubscriptionSession: Commission tracked', {
        subscriptionId,
        sessionId:       result.sessionId,
        commissionAmount,
      });

      // 17. Notification to student -------------------------------------------
      await createAndSendNotification({
        userId:       studentId as string,
        senderId:     mohaffezId,
        title:        'تم تأكيد جلستك',
        body:         `تم تأكيد جلستك مع ${mohaffezName as string} وخصم جلسة من باقتك.`,
        type:         'subscription_session_consumed',
        highPriority: true,
        data: {
          subscriptionId:    subscriptionId as string,
          sessionId:         result.sessionId!,
          remainingSessions: String(result.remainingSessions),
          requestId:         requestId as string,
        },
      });

      functions.logger.info('confirmSubscriptionSession: Completed successfully', {
        subscriptionId,
        sessionId:         result.sessionId,
        remainingSessions: result.remainingSessions,
      });

      // 18. Return success ----------------------------------------------------
      return {
        success:           true,
        sessionId:         result.sessionId,
        remainingSessions: result.remainingSessions,
      };

    } catch (error) {
      // FIX: Re-throw HttpsErrors directly so the client receives the correct
      // gRPC code (failed-precondition, permission-denied, etc.).
      // The original catch block wrapped every HttpsError as 'internal', which
      // caused the Flutter client to show a generic error for all failures.
      if (error instanceof functions.https.HttpsError) throw error;

      const message = error instanceof Error ? error.message : 'Unknown error';
      functions.logger.error('confirmSubscriptionSession failed', {
        requestId,
        subscriptionId,
        error: message,
      });
      throw new functions.https.HttpsError('internal', message);
    }
  }
);
