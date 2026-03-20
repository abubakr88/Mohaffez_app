"use strict";
// functions/src/payments/confirmSubscriptionSession.ts
// FIX #4:    sessionType uniqueness — subscription.sessionType must match requested sessionType
// FIX TOCTOU: requestRef + subRef reads parallelised; re-validated atomically inside
//             consumeSubscriptionAndCreateSession's own transaction
// FIX:       HttpsErrors re-thrown directly — never wrapped as 'internal'
// FIX:       parseFlutterDate used for all slot timestamps (avoids local-timezone shift)
// FIX:       Deterministic transactionId (removes Date.now() suffix → idempotency-safe)
// BUG #3:    maxActiveSubscriptions + commission tracking preserved
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmSubscriptionSession = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const dateHelpers_1 = require("../utils/dateHelpers");
const handlers_1 = require("./handlers");
const notificationHelpers_1 = require("../utils/notificationHelpers");
const COMMISSION_RATE = 0.05;
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
// ---------------------------------------------------------------------------
// FIX: Parse Flutter ISO strings that have no timezone suffix as UTC.
// new Date('2026-03-08T10:00:00') is interpreted as LOCAL time on Node.js,
// which shifts the stored Timestamp by the server's UTC offset.
// ---------------------------------------------------------------------------
function parseFlutterDate(iso) {
    if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
        return new Date(iso + 'Z');
    }
    return new Date(iso);
}
// ---------------------------------------------------------------------------
// Main callable
// ---------------------------------------------------------------------------
exports.confirmSubscriptionSession = functions.https.onCall(async (data, context) => {
    var _a;
    functions.logger.info('confirmSubscriptionSession: Starting', {
        timestamp: new Date().toISOString(),
    });
    // 1. Auth ----------------------------------------------------------------
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'المستخدم غير مصادق عليه');
    }
    const mohaffezId = context.auth.uid;
    // 2. Caller must be the mohaffez -----------------------------------------
    if (context.auth.uid !== data.mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'غير مصرح لك بتأكيد هذه الجلسة');
    }
    // 3. Extract params -------------------------------------------------------
    const { subscriptionId, requestId, mohaffezName, studentId, studentName, sessionType, preferredTimeSlot, slotDate, slotStart, slotEnd, imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone, amount, } = data;
    // 4. Validate required fields ---------------------------------------------
    if (!subscriptionId || !requestId || !mohaffezId ||
        !studentId || !studentName || !sessionType ||
        !preferredTimeSlot || !slotDate || !slotStart ||
        !slotEnd || !amount) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات غير مكتملة');
    }
    // 5. Pre-parse slot timestamps (pure — no I/O) ---------------------------
    // Done before any async work so the transaction body stays reads-then-writes.
    const sessionDateTs = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotDate));
    const slotStartTs = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotStart));
    const slotEndTs = admin.firestore.Timestamp.fromDate(parseFlutterDate(slotEnd));
    // Pre-build document refs
    const requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
    const subRef = admin_1.db.collection('subscriptions').doc(subscriptionId);
    // Deterministic transactionId — removes Date.now() so retries are idempotent
    const transactionId = `direct_sub_${subscriptionId}_${requestId}`;
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
        const requestData = requestSnap.data();
        const subscription = subSnap.data();
        // 7. Idempotency guard --------------------------------------------------
        if (requestData.status === STATUS.ACCEPTED && requestData.sessionId) {
            functions.logger.info('confirmSubscriptionSession: idempotent', {
                requestId,
                sessionId: requestData.sessionId,
            });
            return {
                success: true,
                sessionId: requestData.sessionId,
                message: 'Already confirmed',
            };
        }
        // 8. Status check -------------------------------------------------------
        // FIX: Also accept 'pending' status for subscription-credit requests
        // that were created with selectedPaymentMethod: 'subscriptioncredit'
        const ALLOWED_STATUSES = [STATUS.PENDING, STATUS.AWAITING_PAYMENT, STATUS.AWAITING_DIRECT];
        if (!ALLOWED_STATUSES.includes(requestData.status)) {
            throw new functions.https.HttpsError('failed-precondition', `Request status is '${requestData.status}', ` +
                `expected one of: ${ALLOWED_STATUSES.join(', ')}`);
        }
        // 9. Ownership check ----------------------------------------------------
        if (subscription.studentId !== studentId ||
            subscription.mohaffezId !== mohaffezId) {
            throw new functions.https.HttpsError('permission-denied', 'الاشتراك لا ينتمي للمستخدمين المحددين');
        }
        // 10. FIX #4: sessionType uniqueness check ------------------------------
        // A student must use a bundle/subscription that was created for the SAME
        // sessionType. Without this, an 'online' bundle could be used to book a
        // 'home' or 'mosque' session, bypassing the per-type uniqueness constraint.
        //
        // subscription.sessionType may be absent on legacy docs (created before
        // FIX #3 was deployed). In that case we skip the check to preserve
        // backward compatibility — new subscriptions always store sessionType.
        if (subscription.sessionType &&
            subscription.sessionType !== sessionType) {
            throw new functions.https.HttpsError('failed-precondition', `نوع الجلسة المطلوبة '${sessionType}' لا يتطابق مع نوع جلسة الاشتراك ` +
                `'${subscription.sessionType}'. ` +
                `يجب استخدام اشتراك مطابق لنوع الجلسة.`);
        }
        // 11. Remaining sessions check -----------------------------------------
        const remainingSessions = (_a = subscription.remainingSessions) !== null && _a !== void 0 ? _a : 0;
        if (remainingSessions <= 0) {
            throw new functions.https.HttpsError('failed-precondition', 'لا توجد جلسات متبقية في هذا الاشتراك');
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
            timeSlot: preferredTimeSlot,
            sessionDate: sessionDateTs,
            slotStart: slotStartTs,
            slotEnd: slotEndTs,
            location: imamAddressText !== null && imamAddressText !== void 0 ? imamAddressText : '',
            imamAddressText: imamAddressText !== null && imamAddressText !== void 0 ? imamAddressText : null,
            imamAddressLat: imamAddressLat !== null && imamAddressLat !== void 0 ? imamAddressLat : null,
            imamAddressLng: imamAddressLng !== null && imamAddressLng !== void 0 ? imamAddressLng : null,
            mohaffezPhone: mohaffezPhone !== null && mohaffezPhone !== void 0 ? mohaffezPhone : null,
            isPaid: true,
            paymentMethod: 'subscription',
            subscriptionId,
            reminder24hSent: false,
            reminder1hSent: false,
            juzCount: 1,
            sessionRating: 10,
            // Prevents the Firestore trigger from sending a duplicate notification
            notificationsAlreadySent: true,
        };
        // 13. Build synthetic PaymentDocument ------------------------------------
        const syntheticPayment = {
            studentId: studentId,
            studentName: studentName,
            mohaffezId,
            mohaffezName: mohaffezName,
            amount: amount,
            status: 'completed',
            metadata: {
                subscriptionId,
                requestId,
                sessionDetails,
            },
        };
        // 14. Build SlotInfo -----------------------------------------------------
        const slotInfo = {
            mohaffezId,
            slotDate: sessionDateTs,
            timeSlot: preferredTimeSlot,
            sessionType: sessionType,
        };
        // 15. Consume subscription + create session (atomic inside handler) -----
        const result = await (0, handlers_1.consumeSubscriptionAndCreateSession)(subscriptionId, syntheticPayment, transactionId, syntheticPayment.metadata, slotInfo);
        functions.logger.info('confirmSubscriptionSession: Session consumed', {
            subscriptionId,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        });
        // 16. Commission tracking (separate transaction — non-blocking for session) --
        const now = new Date();
        const weekNumber = (0, dateHelpers_1.getWeekNumber)(now);
        const weekStart = (0, dateHelpers_1.getWeekStart)(now);
        const weekEnd = (0, dateHelpers_1.getWeekEnd)(now);
        const commissionAmount = amount * COMMISSION_RATE;
        await admin_1.db.runTransaction(async (tx) => {
            // Individual commission record
            const commRef = admin_1.db.collection('commissions').doc();
            tx.set(commRef, {
                id: commRef.id,
                mohaffezId,
                mohaffezName,
                studentId,
                sessionId: result.sessionId,
                subscriptionId,
                directPaymentRequestId: null,
                sessionRequestId: requestId,
                amount,
                commissionAmount,
                commissionRate: COMMISSION_RATE,
                paymentMethod: 'subscription',
                status: 'pending',
                weekNumber,
                year: now.getFullYear(),
                weekStart: admin.firestore.Timestamp.fromDate(weekStart),
                weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
                createdAt: admin_1.FieldValue.serverTimestamp(),
                paidAt: null,
            });
            // Upsert weekly summary (merge:true makes this idempotent)
            const summaryId = `${mohaffezId}_${now.getFullYear()}_w${weekNumber}`;
            const summaryRef = admin_1.db.collection('weeklyCommissionSummaries').doc(summaryId);
            tx.set(summaryRef, {
                mohaffezId,
                mohaffezName,
                weekNumber,
                year: now.getFullYear(),
                weekStart: admin.firestore.Timestamp.fromDate(weekStart),
                weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
                totalSessions: admin_1.FieldValue.increment(1),
                totalRevenue: admin_1.FieldValue.increment(amount),
                commissionAmount: admin_1.FieldValue.increment(commissionAmount),
                commissionRate: COMMISSION_RATE,
                status: 'pending',
                dueDate: admin.firestore.Timestamp.fromDate((0, dateHelpers_1.getNextMonday)(weekEnd)),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        functions.logger.info('confirmSubscriptionSession: Commission tracked', {
            subscriptionId,
            sessionId: result.sessionId,
            commissionAmount,
        });
        // 17. Notification to student -------------------------------------------
        await (0, notificationHelpers_1.createAndSendNotification)({
            userId: studentId,
            senderId: mohaffezId,
            title: 'تم تأكيد جلستك',
            body: `تم تأكيد جلستك مع ${mohaffezName} وخصم جلسة من باقتك.`,
            type: 'subscription_session_consumed',
            highPriority: true,
            data: {
                subscriptionId: subscriptionId,
                sessionId: result.sessionId,
                remainingSessions: String(result.remainingSessions),
                requestId: requestId,
            },
        });
        functions.logger.info('confirmSubscriptionSession: Completed successfully', {
            subscriptionId,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        });
        // 18. Return success ----------------------------------------------------
        return {
            success: true,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        };
    }
    catch (error) {
        // FIX: Re-throw HttpsErrors directly so the client receives the correct
        // gRPC code (failed-precondition, permission-denied, etc.).
        // The original catch block wrapped every HttpsError as 'internal', which
        // caused the Flutter client to show a generic error for all failures.
        if (error instanceof functions.https.HttpsError)
            throw error;
        const message = error instanceof Error ? error.message : 'Unknown error';
        functions.logger.error('confirmSubscriptionSession failed', {
            requestId,
            subscriptionId,
            error: message,
        });
        throw new functions.https.HttpsError('internal', message);
    }
});
//# sourceMappingURL=confirmSubscriptionSession.js.map