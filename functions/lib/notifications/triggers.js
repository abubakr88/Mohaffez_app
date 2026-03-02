"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onSessionRequestStatusChanged = exports.onSessionCompleted = exports.onPaymentCompleted = exports.onSessionCreated = exports.onSessionRequestAccepted = void 0;
const functions = require("firebase-functions");
const notificationHelpers_1 = require("../utils/notificationHelpers");
const SessionEventStore_1 = require("../services/SessionEventStore");
const events_types_1 = require("../types/events.types");
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
            // FIX-3: Use runtime-safe boolean coercion for duplicate-notification guard
            const alreadySent = asBoolean(after['notificationsAlreadySent'], false);
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
    var _a;
    const data = snapshot.data();
    const sessionId = context.params.sessionId;
    const studentId = asString(data.studentId, '');
    const mohaffezId = asString(data.mohaffezId, '');
    // Append creation event
    try {
        await sessionEventStore.appendEvent({
            eventType: events_types_1.SessionEventType.SESSION_CREATED,
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
                promoCode: (_a = data.promoCode) !== null && _a !== void 0 ? _a : null,
            },
        });
    }
    catch (error) {
        functions.logger.error('Failed to append session created event', {
            sessionId,
            error,
        });
    }
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
/**
 * FIX: BUG #3 - Firestore trigger for assignment update notification
 * Fires when hifzAssignment is set (non-empty) and status changes to "completed"
 * Sends notification to student about their new assignment
 */
exports.onSessionCompleted = functions.firestore
    .document('hafizSessions/{sessionId}')
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e;
    const before = change.before.data();
    const after = change.after.data();
    const beforeStatus = asString(before.status, '');
    const afterStatus = asString(after.status, '');
    if (beforeStatus === afterStatus)
        return;
    const sessionId = context.params.sessionId;
    const studentId = asString(after.studentId, '');
    const mohaffezId = asString(after.mohaffezId, '');
    // Always append a session event for ANY status change
    try {
        await sessionEventStore.appendEvent({
            eventType: events_types_1.SessionEventType.SESSION_COMPLETED,
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
                hifzAssignment: (_a = after.hifzAssignment) !== null && _a !== void 0 ? _a : null,
                murajaAssignment: (_b = after.murajaAssignment) !== null && _b !== void 0 ? _b : null,
                isLateCompletion: (_c = after.isLateCompletion) !== null && _c !== void 0 ? _c : false,
                tajweedMistakes: (_d = after.tajweedMistakesCount) !== null && _d !== void 0 ? _d : 0,
                pronunciationMistakes: (_e = after.pronunciationMistakesCount) !== null && _e !== void 0 ? _e : 0,
            },
        });
    }
    catch (error) {
        functions.logger.error('Failed to append session completed event', {
            sessionId, error,
        });
    }
    // Only send notifications when status becomes 'completed'
    if (afterStatus !== 'completed')
        return;
    if (!studentId) {
        functions.logger.warn('Missing studentId in completed session', { sessionId });
        return;
    }
    const mohaffezName = asString(after.mohaffezName, '');
    const hifzAssignment = asString(after.hifzAssignment, '');
    const hasAssignment = hifzAssignment.trim().length > 0;
    try {
        // Always notify student session was completed
        await (0, notificationHelpers_1.createAndSendNotification)({
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
            sessionId, studentId, mohaffezId, hasAssignment,
        });
    }
    catch (error) {
        functions.logger.error('Error sending session completed notification', {
            sessionId, studentId, mohaffezId, error,
        });
    }
});
const sessionEventStore = new SessionEventStore_1.SessionEventStore();
exports.onSessionRequestStatusChanged = functions.firestore
    .document('sessionRequests/{requestId}')
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e, _f, _g;
    const before = change.before.data();
    const after = change.after.data();
    const fromStatus = (_a = before.status) !== null && _a !== void 0 ? _a : '';
    const toStatus = (_b = after.status) !== null && _b !== void 0 ? _b : '';
    // Only run when status actually changed
    if (fromStatus === toStatus)
        return;
    const requestId = context.params.requestId;
    const studentId = (_c = after.studentId) !== null && _c !== void 0 ? _c : '';
    const mohaffezId = (_d = after.mohaffezId) !== null && _d !== void 0 ? _d : '';
    // Map status string -> enum value
    const eventTypeMap = {
        awaitingpayment: events_types_1.SessionRequestEventType.AWAITING_PAYMENT,
        awaitingdirectpaymentconfirmation: events_types_1.SessionRequestEventType.AWAITING_DIRECT,
        accepted: events_types_1.SessionRequestEventType.ACCEPTED,
        rejected: events_types_1.SessionRequestEventType.REJECTED,
        cancelled: events_types_1.SessionRequestEventType.CANCELLED,
        expired: events_types_1.SessionRequestEventType.EXPIRED,
    };
    const eventType = eventTypeMap[toStatus];
    if (!eventType) {
        functions.logger.warn('onSessionRequestStatusChanged: unknown toStatus', {
            requestId, fromStatus, toStatus,
        });
        return;
    }
    // Determine actorId heuristically:
    //   accepted/awaitingdirect = mohaffez acted
    //   cancelled/expired       = could be system or student
    //   awaitingpayment         = mohaffez accepted initially
    //   rejected                = mohaffez acted
    const actorId = ['accepted', 'rejected', 'awaitingdirectpaymentconfirmation'].includes(toStatus)
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
                promoCode: (_e = after.promoCode) !== null && _e !== void 0 ? _e : null,
                cancelledBy: (_f = after.cancelledBy) !== null && _f !== void 0 ? _f : null,
                rejectionReason: (_g = after.rejectionReason) !== null && _g !== void 0 ? _g : null,
            },
        });
    }
    catch (error) {
        functions.logger.error('Failed to append session request event', {
            requestId, fromStatus, toStatus, error,
        });
    }
});
//# sourceMappingURL=triggers.js.map