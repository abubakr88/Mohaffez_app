"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPaymentCompleted = exports.onSessionCreated = exports.onSessionRequestAccepted = void 0;
const functions = require("firebase-functions");
const notificationHelpers_1 = require("../utils/notificationHelpers");
const asString = (value, fallback = '') => typeof value === 'string' && value.trim().length > 0 ? value : fallback;
const asNumber = (value, fallback = 0) => typeof value === 'number' ? value : fallback;
const asBoolean = (value, fallback = false) => typeof value === 'boolean' ? value : fallback;
/**
 * Firestore trigger: Send notifications when session request status changes
 * Handles: payment_required, accepted, and free session flows
 */
exports.onSessionRequestAccepted = functions.firestore
    .document('sessionRequests/{requestId}')
    .onUpdate(async (change, context) => {
    var _a, _b;
    const before = change.before.data();
    const after = change.after.data();
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
    // NEW: Check if this is a free session
    // ============================================
    const isPaid = asBoolean(after.isPaid, false);
    const paymentAmount = asNumber(after.paymentAmount, 0);
    const promoDiscount = asNumber(after.promoDiscount, 0);
    const promoCode = asString(after.promoCode);
    const isFreeSession = isPaid === true &&
        (paymentAmount === 0 || promoDiscount >= 100) &&
        promoCode.length > 0;
    try {
        // ============================================
        // CASE 1: Awaiting Payment (regular flow)
        // ============================================
        if (afterStatus === 'awaitingpayment') {
            await (0, notificationHelpers_1.createAndSendNotification)({
                userId: studentId,
                senderId: mohaffezId,
                title: 'جلسة مقبولة!',
                body: `${mohaffezName} قبل طلبك. يُرجى الدفع خلال الموعد المحدد.`,
                type: 'payment_required',
                isRead: false,
                data: {
                    requestId,
                    mohaffezId,
                    mohaffezName,
                    sessionType: after.sessionType,
                    sessionDate: after.slotDate,
                    preferredTimeSlot: after.preferredTimeSlot,
                    paymentDeadline: after.paymentDeadline,
                    location: (_a = after.imamAddressText) !== null && _a !== void 0 ? _a : after.location,
                },
                highPriority: true,
            });
            functions.logger.info('Payment required notification sent', {
                requestId,
                studentId,
            });
            return;
        }
        // ============================================
        // CASE 2: Accepted (with free session detection)
        // ============================================
        if (afterStatus === 'accepted') {
            // Guard: confirmFreeSession already sent notifications atomically
            const alreadySent = after['notificationsAlreadySent'];
            if (alreadySent === true) {
                functions.logger.info('Skipping duplicate notification: already sent by confirmFreeSession', {
                    requestId: context.params.requestId,
                });
                return;
            }
            // Determine notification content based on free/paid status
            const notificationTitle = isFreeSession
                ? '🎉 جلسة مجانية مؤكدة!'
                : '✅ قبلت الجلسة! 🎉';
            const notificationBody = isFreeSession
                ? `تم تأكيد جلستك المجانية مع ${mohaffezName} بنجاح. لا حاجة للدفع!`
                : `${mohaffezName} قبل طلب جلستك بنجاح.`;
            const notificationType = isFreeSession
                ? 'session_accepted_free'
                : 'session_accepted';
            // Send notification to student
            await (0, notificationHelpers_1.createAndSendNotification)({
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
                    location: (_b = after.imamAddressText) !== null && _b !== void 0 ? _b : after.location,
                    isFree: isFreeSession.toString(),
                    promoCode: isFreeSession ? promoCode : undefined,
                },
                highPriority: true,
            });
            // NEW: Send notification to mohaffez as well
            if (mohaffezId) {
                const studentName = asString(after.studentName, 'الطالب');
                await (0, notificationHelpers_1.createAndSendNotification)({
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
        // CASE 3: Rejected (optional)
        // ============================================
        if (afterStatus === 'rejected') {
            await (0, notificationHelpers_1.createAndSendNotification)({
                userId: studentId,
                senderId: mohaffezId,
                title: 'تم رفض الطلب',
                body: `للأسف، ${mohaffezName} رفض طلب الجلسة. يمكنك محاولة حجز موعد آخر.`,
                type: 'session_rejected',
                isRead: false,
                data: {
                    requestId,
                    mohaffezId,
                    mohaffezName,
                    sessionType: after.sessionType,
                },
                highPriority: false,
            });
            functions.logger.info('Session rejected notification sent', {
                requestId,
                studentId,
            });
        }
        // ============================================
        // CASE 4: Cancelled (optional)
        // ============================================
        if (afterStatus === 'cancelled') {
            // Notify mohaffez if student cancelled
            if (mohaffezId) {
                const studentName = asString(after.studentName, 'الطالب');
                await (0, notificationHelpers_1.createAndSendNotification)({
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
    }
    catch (error) {
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
 * NEW: Firestore trigger for session creation
 * Logs session creation events and sends additional notifications if needed
 */
exports.onSessionCreated = functions.firestore
    .document('hafizSessions/{sessionId}')
    .onCreate(async (snapshot, context) => {
    const sessionData = snapshot.data();
    const sessionId = context.params.sessionId;
    const studentId = asString(sessionData.studentId);
    const mohaffezId = asString(sessionData.mohaffezId);
    const isPaid = asBoolean(sessionData.isPaid, false);
    const sessionPrice = asNumber(sessionData.sessionPrice, 0);
    const promoCode = asString(sessionData.promoCode);
    const isFreeSession = isPaid && sessionPrice === 0 && promoCode.length > 0;
    functions.logger.info('Session created', {
        sessionId,
        studentId,
        mohaffezId,
        isFreeSession,
        promoCode: isFreeSession ? promoCode : undefined,
        sessionType: sessionData.sessionType,
        sessionDate: sessionData.sessionDate,
    });
    // Optional: Send additional confirmation if needed
    // (Main notifications are sent by onSessionRequestAccepted)
});
/**
 * NEW: Firestore trigger for payment completion
 * Detects when a payment is completed and logs the event
 */
exports.onPaymentCompleted = functions.firestore
    .document('payments/{paymentId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const beforeStatus = asString(before.status);
    const afterStatus = asString(after.status);
    // Only trigger on status change to 'completed'
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
//# sourceMappingURL=triggers.js.map