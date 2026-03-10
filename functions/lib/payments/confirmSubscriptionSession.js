"use strict";
// functions/src/payments/confirmSubscriptionSession.ts
// BUG #3: Server-side subscription session consumption with commission tracking
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmSubscriptionSession = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const handlers_1 = require("./handlers");
const notificationHelpers_1 = require("../utils/notificationHelpers");
const COMMISSION_RATE = 0.05;
// Helper functions for commission tracking (copied from directPayment.ts)
function getWeekNumber(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
}
function getWeekStart(date) {
    const d = new Date(date);
    const day = d.getDay();
    d.setDate(d.getDate() - day + (day === 0 ? -6 : 1));
    d.setHours(0, 0, 0, 0);
    return d;
}
function getWeekEnd(date) {
    const ws = getWeekStart(date);
    ws.setDate(ws.getDate() + 6);
    ws.setHours(23, 59, 59, 999);
    return ws;
}
function getNextMonday(date) {
    const d = new Date(date);
    d.setDate(d.getDate() + 1);
    d.setHours(12, 0, 0, 0);
    return d;
}
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
exports.confirmSubscriptionSession = functions.https.onCall(async (data, context) => {
    var _a;
    functions.logger.info('confirmSubscriptionSession: Starting', { timestamp: new Date().toISOString() });
    // 1. Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'المستخدم غير مصادق عليه');
    }
    const mohaffezId = context.auth.uid;
    // 2. Verify caller is the mohaffez
    if (context.auth.uid !== data.mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'غير مصرح لك بتأكيد هذه الجلسة');
    }
    // Extract input data
    const { subscriptionId, requestId, mohaffezName, studentId, studentName, sessionType, preferredTimeSlot, slotDate, slotStart, slotEnd, imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone, amount, } = data;
    // Validate required fields
    if (!subscriptionId || !requestId || !mohaffezId || !studentId || !studentName || !sessionType || !preferredTimeSlot || !slotDate || !slotStart || !slotEnd || !amount) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات غير مكتملة');
    }
    try {
        // 3. Read sessionRequests/{requestId}
        const requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
        const requestSnap = await requestRef.get();
        if (!requestSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
        }
        const requestData = requestSnap.data();
        // 4. Idempotency guard - if already accepted, return success
        if ((requestData === null || requestData === void 0 ? void 0 : requestData.status) === STATUS.ACCEPTED && (requestData === null || requestData === void 0 ? void 0 : requestData.sessionId)) {
            functions.logger.info('confirmSubscriptionSession: Already confirmed (idempotent)', {
                requestId,
                sessionId: requestData.sessionId,
            });
            return {
                success: true,
                sessionId: requestData.sessionId,
                message: 'Already confirmed',
            };
        }
        // 5. Verify status is awaitingPayment or awaitingDirectPaymentConfirmation
        if ((requestData === null || requestData === void 0 ? void 0 : requestData.status) !== STATUS.AWAITING_PAYMENT && (requestData === null || requestData === void 0 ? void 0 : requestData.status) !== STATUS.AWAITING_DIRECT) {
            throw new functions.https.HttpsError('failed-precondition', `Request status is '${requestData === null || requestData === void 0 ? void 0 : requestData.status}', expected 'awaitingpayment' or 'awaitingdirectpaymentconfirmation'`);
        }
        // 6. Read subscriptions/{subscriptionId}
        const subRef = admin_1.db.collection('subscriptions').doc(subscriptionId);
        const subSnap = await subRef.get();
        if (!subSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'الاشتراك غير موجود');
        }
        const subscription = subSnap.data();
        // 7. Verify subscription ownership
        if ((subscription === null || subscription === void 0 ? void 0 : subscription.studentId) !== studentId || (subscription === null || subscription === void 0 ? void 0 : subscription.mohaffezId) !== mohaffezId) {
            throw new functions.https.HttpsError('permission-denied', 'الاشتراك لاbelongs للمستخدمين المحددين');
        }
        // 8. Verify remainingSessions > 0
        const remainingSessions = (_a = subscription === null || subscription === void 0 ? void 0 : subscription.remainingSessions) !== null && _a !== void 0 ? _a : 0;
        if (remainingSessions <= 0) {
            throw new functions.https.HttpsError('failed-precondition', 'No sessions remaining');
        }
        // 9. Build synthetic PaymentDocument
        const syntheticPayment = {
            studentId,
            studentName,
            mohaffezId,
            mohaffezName,
            amount,
            status: 'completed',
            metadata: {
                subscriptionId,
                requestId,
                sessionDetails: {},
            },
        };
        // 10. Build sessionDetails for hafizSession
        const sessionDetails = {
            requestId,
            mohaffezId,
            studentId,
            mohaffezName,
            studentName,
            sessionType,
            preferredTimeSlot,
            timeSlot: preferredTimeSlot,
            sessionDate: admin.firestore.Timestamp.fromDate(new Date(slotDate)),
            slotStart: admin.firestore.Timestamp.fromDate(new Date(slotStart)),
            slotEnd: admin.firestore.Timestamp.fromDate(new Date(slotEnd)),
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
            notificationsAlreadySent: true, // Critical: prevents duplicate notification from trigger
        };
        // Update metadata with sessionDetails
        syntheticPayment.metadata = {
            subscriptionId,
            requestId,
            sessionDetails,
        };
        // 11. Build SlotInfo
        const slotInfo = {
            mohaffezId,
            slotDate: admin.firestore.Timestamp.fromDate(new Date(slotDate)),
            timeSlot: preferredTimeSlot,
            sessionType,
        };
        // 12. Generate transaction ID
        const transactionId = `direct_sub_${subscriptionId}_${requestId}_${Date.now()}`;
        // 13. Consume subscription and create session
        const result = await (0, handlers_1.consumeSubscriptionAndCreateSession)(subscriptionId, syntheticPayment, transactionId, syntheticPayment.metadata, slotInfo);
        functions.logger.info('confirmSubscriptionSession: Session consumed', {
            subscriptionId,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        });
        // 14. Track commission in a separate transaction
        const now = new Date();
        const weekNumber = getWeekNumber(now);
        const weekStart = getWeekStart(now);
        const weekEnd = getWeekEnd(now);
        const commissionAmount = amount * COMMISSION_RATE;
        await admin_1.db.runTransaction(async (tx) => {
            // Create commission record
            const commRef = admin_1.db.collection('commissions').doc();
            tx.set(commRef, {
                id: commRef.id,
                mohaffezId,
                mohaffezName,
                studentId,
                sessionId: result.sessionId,
                subscriptionId,
                directPaymentRequestId: null, // No direct payment request for subscription
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
            // Upsert weekly summary
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
                dueDate: admin.firestore.Timestamp.fromDate(getNextMonday(weekEnd)),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            }, { merge: true });
        });
        functions.logger.info('confirmSubscriptionSession: Commission tracked', {
            subscriptionId,
            sessionId: result.sessionId,
            commissionAmount,
        });
        // 15. Send notification to student
        await (0, notificationHelpers_1.createAndSendNotification)({
            userId: studentId,
            senderId: mohaffezId,
            title: 'تم تأكيد جلستك',
            body: `تم تأكيد جلستك مع ${mohaffezName} وخصم جلسة من باقتك.`,
            type: 'subscription_session_consumed',
            highPriority: true,
            data: {
                subscriptionId,
                sessionId: result.sessionId,
                remainingSessions: String(result.remainingSessions),
                requestId,
            },
        });
        functions.logger.info('confirmSubscriptionSession: Completed successfully', {
            subscriptionId,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        });
        // 16. Return success
        return {
            success: true,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        };
    }
    catch (error) {
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