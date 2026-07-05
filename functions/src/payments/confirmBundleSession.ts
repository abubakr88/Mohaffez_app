// functions/src/payments/confirmBundleSession.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db } from '../utils/admin';
import { parseFlutterDate } from '../utils/dateHelpers';
import { consumeSubscriptionAndCreateSession, SlotInfo } from './handlers';
import { createAndSendNotification } from '../utils/notificationHelpers';
import { PaymentDocument } from '../types/payment.types';

const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;

function toDate(value: unknown, fieldName: string): Date {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date && !isNaN(value.getTime())) {
    return value;
  }
  if (typeof value === 'string' && value.length > 0) {
    return parseFlutterDate(value);
  }
  throw new functions.https.HttpsError(
    'invalid-argument',
    `حقل ${fieldName} غير صالح أو مفقود`
  );
}

export const confirmBundleSession = functions.https.onCall(
  async (data, context) => {
    functions.logger.info('confirmBundleSession: Starting', {
      timestamp: new Date().toISOString(),
    });

    // ── 1. Auth ─────────────────────────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'المستخدم غير مصادق عليه'
      );
    }
    const mohaffezId = context.auth.uid;

    // ── 2. Caller must be the mohaffez ───────────────────────────────────────
    if (context.auth.uid !== data.mohaffezId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'غير مصرح لك بتأكيد هذه الجلسة'
      );
    }

    // Declare variables for logging
    let requestId: string | undefined;
    let subscriptionId: string | undefined;

    try {
      // ── 3. Extract minimal caller params ──────────────────────────────────
      requestId = data.requestId as string;
      if (!requestId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'requestId مطلوب'
        );
      }

      // ── 4. Read the sessionRequest doc from Firestore ─────────────────────
      const requestRef = db.collection('sessionRequests').doc(requestId);
      const requestDoc = await requestRef.get();

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
      }

      const requestData = requestDoc.data()!;

      // ── 5. Read mohaffezName from the request document (not from client) ──
      const mohaffezName = requestData.mohaffezName as string;
      if (!mohaffezName) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'بيانات الطلب غير مكتملة (mohaffezName مفقود)'
        );
      }

      // subscriptionId must come from Firestore — never from caller payload.
      subscriptionId = requestData.subscriptionId as string | undefined;
      if (!subscriptionId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'لا يوجد اشتراك مرتبط بطلب الجلسة هذا'
        );
      }

      // Extract all remaining fields from the Firestore doc.
      const studentId         = requestData.studentId         as string;
      const studentName       = requestData.studentName       as string;
      const sessionType       = requestData.sessionType       as string;
      const preferredTimeSlot = requestData.preferredTimeSlot as string;
      const imamAddressText   = (requestData.imamAddressText  as string  | null)  ?? null;
      const imamAddressLat    = (requestData.imamAddressLat   as number  | null)  ?? null;
      const imamAddressLng    = (requestData.imamAddressLng   as number  | null)  ?? null;
      const mohaffezPhone     = (requestData.mohaffezPhone    as string  | null)  ?? null;
      const studentPhone      = (requestData.studentPhone     as string  | null)  ?? null;

      const rawAmount = requestData.paymentAmount;
      let amount: number =
        rawAmount != null && typeof rawAmount === 'number' ? rawAmount : 0;

      // ── 6. Validate required string fields ────────────────────────────────
      if (!studentId || !studentName || !sessionType || !preferredTimeSlot) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'بيانات الطلب غير مكتملة (studentId / studentName / sessionType / preferredTimeSlot)'
        );
      }

      // ── 7. Parse slot timestamps ──────────────────────────────────────────
      const sessionDateTs = admin.firestore.Timestamp.fromDate(
        toDate(requestData.slotDate, 'slotDate')
      );
      const slotStartTs = admin.firestore.Timestamp.fromDate(
        toDate(requestData.slotStart, 'slotStart')
      );
      const slotEndTs = admin.firestore.Timestamp.fromDate(
        toDate(requestData.slotEnd, 'slotEnd')
      );

      // ── 8. Build refs ─────────────────────────────────────────────────────
      const subRef = db.collection('subscriptions').doc(subscriptionId);
      const transactionId = `direct_sub_${subscriptionId}_${requestId}`;

      // ── 9. Parallel pre-validation reads (non-transactional fast-failure) ─
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

      const freshRequestData = requestSnap.data()!;
      const subscription     = subSnap.data()!;

      // For subscription sessions, calculate amount from bundle price.
      // `totalPaid` is the canonical field used by createSubscriptionFromPayment,
      // confirmBundleDirectPayment, and payFromWallet — keep the legacy
      // alternates as fallbacks for any old docs that used them.
      if (amount === 0 && subscription) {
        const bundlePrice = (subscription.totalPaid as number) ??
                           (subscription.bundlePrice as number) ??
                           (subscription.totalPrice as number) ??
                           (subscription.price as number) ?? 0;
        const totalSessions = (subscription.totalSessions as number) ??
                             (subscription.sessionCount as number) ??
                             (subscription.sessionsCount as number) ?? 1;
        if (bundlePrice > 0 && totalSessions > 0) {
          amount = bundlePrice / totalSessions;
        }
      }

      // Diagnostic log
      functions.logger.info('confirmBundleSession: slot fields resolved', {
        requestId,
        subscriptionId,
        slotDateType:  (requestData.slotDate  as any)?.constructor?.name ?? typeof requestData.slotDate,
        slotStartType: (requestData.slotStart as any)?.constructor?.name ?? typeof requestData.slotStart,
        slotEndType:   (requestData.slotEnd   as any)?.constructor?.name ?? typeof requestData.slotEnd,
        sessionDateTs: sessionDateTs.toDate().toISOString(),
        slotStartTs:   slotStartTs.toDate().toISOString(),
        slotEndTs:     slotEndTs.toDate().toISOString(),
        amount,
        bundlePrice: (subscription.bundlePrice as number) ?? (subscription.totalPrice as number) ?? (subscription.price as number) ?? 0,
        totalSessions: (subscription.totalSessions as number) ?? (subscription.sessionCount as number) ?? (subscription.sessionsCount as number) ?? 1,
      });

      // ── 10. Idempotency guard ───────────────────────────────────────────────
      if (freshRequestData.status === STATUS.ACCEPTED && freshRequestData.sessionId) {
        functions.logger.info('confirmBundleSession: idempotent', {
          requestId,
          sessionId: freshRequestData.sessionId,
        });
        return {
          success:   true,
          sessionId: freshRequestData.sessionId,
          message:   'Already confirmed',
        };
      }

      // ── 11. Status check ──────────────────────────────────────────────────
      const ALLOWED_STATUSES: string[] = [
        STATUS.PENDING,
        STATUS.AWAITING_PAYMENT,
        STATUS.AWAITING_DIRECT,
      ];

      if (!ALLOWED_STATUSES.includes(freshRequestData.status)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Request status is '${freshRequestData.status as string}', ` +
          `expected one of: ${ALLOWED_STATUSES.join(', ')}`
        );
      }

      // ── 12. Ownership check ───────────────────────────────────────────────
      if (
        subscription.studentId  !== studentId ||
        subscription.mohaffezId !== mohaffezId
      ) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'الاشتراك لا ينتمي للمستخدمين المحددين'
        );
      }

      // ── 13. sessionType uniqueness check ──────────────────────────────────
      if (
        subscription.sessionType &&
        (subscription.sessionType as string) !== sessionType
      ) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `نوع الجلسة المطلوبة '${sessionType}' لا يتطابق مع نوع جلسة الاشتراك ` +
          `'${subscription.sessionType as string}'. ` +
          `يجب استخدام اشتراك مطابق لنوع الجلسة.`
        );
      }

      // ── 14. Remaining sessions check ──────────────────────────────────────
      const remainingSessions = (subscription.remainingSessions as number) ?? 0;
      if (remainingSessions <= 0) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'لا توجد جلسات متبقية في هذا الاشتراك'
        );
      }

      // ── 15. Build sessionDetails for hafizSessions document ───────────────
      const reqPreferredProvider = requestData.preferredProvider as string | undefined;
      const sessionDetails = {
        requestId,
        mohaffezId,
        studentId,
        mohaffezName,
        studentName,
        sessionType,
        preferredProvider:
          sessionType === 'online' && reqPreferredProvider
            ? reqPreferredProvider
            : null,
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
        studentPhone:     studentPhone     ?? null,
        isPaid:           true,
        paymentMethod:    'subscription',
        // Per-session price (bundlePrice / totalSessions). Without this,
        // statsForTeacher in recomputeTeacherTiers skips the session because
        // its filter requires sessionPrice > 0, leaving bundle sessions out
        // of the teacher's tier/revenue calculation entirely.
        sessionPrice:     amount,
        subscriptionId,
        reminder24hSent:  false,
        reminder1hSent:   false,
        juzCount:         1,
        sessionRating:    10,
        notificationsAlreadySent: true,
      };

      // ── 16. Build synthetic PaymentDocument ───────────────────────────────
      const syntheticPayment: PaymentDocument = {
        studentId,
        studentName,
        mohaffezId,
        mohaffezName,
        amount,
        status: 'completed',
        metadata: {
          subscriptionId,
          requestId,
          sessionDetails,
        },
      };

      // ── 17. Build SlotInfo ─────────────────────────────────────────────────
      const slotInfo: SlotInfo = {
        mohaffezId,
        slotDate:    sessionDateTs,
        timeSlot:    preferredTimeSlot,
        sessionType,
      };

      // ── 18. Consume subscription + create session (atomic inside handler) ─
      const result = await consumeSubscriptionAndCreateSession(
        subscriptionId,
        syntheticPayment,
        transactionId,
        syntheticPayment.metadata!,
        slotInfo
      );

      functions.logger.info('confirmBundleSession: Session consumed', {
        subscriptionId,
        sessionId:         result.sessionId,
        remainingSessions: result.remainingSessions,
      });

      // ── 19. (Removed: legacy weeklyCommissionSummaries tracking)
      // Bundle/subscription session payment flows do not credit the teacher's
      // wallet ledger today (separate pre-existing gap — bundle purchase
      // money doesn't propagate into the teacher's pending bucket). The old
      // weeklyCommissionSummaries write was tracking-only and is removed
      // along with the rest of the legacy commission system. When the bundle
      // ledger flow is built, it should mirror walletPaySession's pattern:
      // post a `session_payment` ledger entry crediting the teacher's
      // pending bucket so settlement deducts commission correctly.

      // ── 20. Notification to student ───────────────────────────────────────
      await createAndSendNotification({
        userId:       studentId,
        senderId:     mohaffezId,
        title:        'تم تأكيد جلستك',
        body:         `تم تأكيد جلستك مع ${mohaffezName} وخصم جلسة من باقتك.`,
        type:         'subscription_session_consumed',
        highPriority: true,
        data: {
          subscriptionId,
          sessionId:         result.sessionId!,
          remainingSessions: String(result.remainingSessions),
          requestId,
        },
      });

      functions.logger.info('confirmBundleSession: Completed successfully', {
        subscriptionId,
        sessionId:         result.sessionId,
        remainingSessions: result.remainingSessions,
      });

      // ── 21. Return success ────────────────────────────────────────────────
      return {
        success:           true,
        sessionId:         result.sessionId,
        remainingSessions: result.remainingSessions,
      };

    } catch (error) {
      // Re-throw HttpsErrors directly so the Flutter client receives the
      // correct gRPC code (failed-precondition, permission-denied, etc.)
      // instead of a generic 'internal' error.
      if (error instanceof functions.https.HttpsError) {
        functions.logger.error('confirmBundleSession: HttpsError', {
          code:          error.code,
          message:       error.message,
          requestId,
          subscriptionId,
        });
        throw error;
      }

      // Unexpected errors (TypeErrors, network failures, etc.)
      const message = error instanceof Error ? error.message : 'Unknown error';
      const stack   = error instanceof Error ? error.stack   : undefined;
      functions.logger.error('confirmBundleSession: Unexpected error', {
        requestId,
        subscriptionId,
        error:  message,
        stack,
      });
      throw new functions.https.HttpsError('internal', message);
    }
  }
);
