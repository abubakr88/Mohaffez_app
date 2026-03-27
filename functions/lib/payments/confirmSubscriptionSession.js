"use strict";
// functions/src/payments/confirmSubscriptionSession.ts
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
function toDate(value, fieldName) {
    if (value instanceof admin.firestore.Timestamp) {
        return value.toDate();
    }
    if (value instanceof Date && !isNaN(value.getTime())) {
        return value;
    }
    if (typeof value === 'string' && value.length > 0) {
        return (0, dateHelpers_1.parseFlutterDate)(value);
    }
    throw new functions.https.HttpsError('invalid-argument', `حقل ${fieldName} غير صالح أو مفقود`);
}
exports.confirmSubscriptionSession = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1;
    functions.logger.info('confirmSubscriptionSession: Starting', {
        timestamp: new Date().toISOString(),
    });
    // ── 1. Auth ─────────────────────────────────────────────────────────────
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'المستخدم غير مصادق عليه');
    }
    const mohaffezId = context.auth.uid;
    // ── 2. Caller must be the mohaffez ───────────────────────────────────────
    if (context.auth.uid !== data.mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'غير مصرح لك بتأكيد هذه الجلسة');
    }
    // Declare variables for logging
    let requestId;
    let subscriptionId;
    try {
        // ── 3. Extract minimal caller params ──────────────────────────────────
        requestId = data.requestId;
        if (!requestId) {
            throw new functions.https.HttpsError('invalid-argument', 'requestId مطلوب');
        }
        // ── 4. Read the sessionRequest doc from Firestore ─────────────────────
        const requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
        const requestDoc = await requestRef.get();
        if (!requestDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
        }
        const requestData = requestDoc.data();
        // ── 5. Read mohaffezName from the request document (not from client) ──
        const mohaffezName = requestData.mohaffezName;
        if (!mohaffezName) {
            throw new functions.https.HttpsError('invalid-argument', 'بيانات الطلب غير مكتملة (mohaffezName مفقود)');
        }
        // subscriptionId must come from Firestore — never from caller payload.
        subscriptionId = requestData.subscriptionId;
        if (!subscriptionId) {
            throw new functions.https.HttpsError('failed-precondition', 'لا يوجد اشتراك مرتبط بطلب الجلسة هذا');
        }
        // Extract all remaining fields from the Firestore doc.
        const studentId = requestData.studentId;
        const studentName = requestData.studentName;
        const sessionType = requestData.sessionType;
        const preferredTimeSlot = requestData.preferredTimeSlot;
        const imamAddressText = (_a = requestData.imamAddressText) !== null && _a !== void 0 ? _a : null;
        const imamAddressLat = (_b = requestData.imamAddressLat) !== null && _b !== void 0 ? _b : null;
        const imamAddressLng = (_c = requestData.imamAddressLng) !== null && _c !== void 0 ? _c : null;
        const mohaffezPhone = (_d = requestData.mohaffezPhone) !== null && _d !== void 0 ? _d : null;
        const rawAmount = requestData.paymentAmount;
        let amount = rawAmount != null && typeof rawAmount === 'number' ? rawAmount : 0;
        // ── 6. Validate required string fields ────────────────────────────────
        if (!studentId || !studentName || !sessionType || !preferredTimeSlot) {
            throw new functions.https.HttpsError('invalid-argument', 'بيانات الطلب غير مكتملة (studentId / studentName / sessionType / preferredTimeSlot)');
        }
        // ── 7. Parse slot timestamps ──────────────────────────────────────────
        const sessionDateTs = admin.firestore.Timestamp.fromDate(toDate(requestData.slotDate, 'slotDate'));
        const slotStartTs = admin.firestore.Timestamp.fromDate(toDate(requestData.slotStart, 'slotStart'));
        const slotEndTs = admin.firestore.Timestamp.fromDate(toDate(requestData.slotEnd, 'slotEnd'));
        // ── 8. Build refs ─────────────────────────────────────────────────────
        const subRef = admin_1.db.collection('subscriptions').doc(subscriptionId);
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
        const freshRequestData = requestSnap.data();
        const subscription = subSnap.data();
        // For subscription sessions, calculate amount from bundle price
        if (amount === 0 && subscription) {
            const bundlePrice = (_g = (_f = (_e = subscription.bundlePrice) !== null && _e !== void 0 ? _e : subscription.totalPrice) !== null && _f !== void 0 ? _f : subscription.price) !== null && _g !== void 0 ? _g : 0;
            const totalSessions = (_k = (_j = (_h = subscription.totalSessions) !== null && _h !== void 0 ? _h : subscription.sessionCount) !== null && _j !== void 0 ? _j : subscription.sessionsCount) !== null && _k !== void 0 ? _k : 1;
            if (bundlePrice > 0 && totalSessions > 0) {
                amount = bundlePrice / totalSessions;
            }
        }
        // Diagnostic log
        functions.logger.info('confirmSubscriptionSession: slot fields resolved', {
            requestId,
            subscriptionId,
            slotDateType: (_o = (_m = (_l = requestData.slotDate) === null || _l === void 0 ? void 0 : _l.constructor) === null || _m === void 0 ? void 0 : _m.name) !== null && _o !== void 0 ? _o : typeof requestData.slotDate,
            slotStartType: (_r = (_q = (_p = requestData.slotStart) === null || _p === void 0 ? void 0 : _p.constructor) === null || _q === void 0 ? void 0 : _q.name) !== null && _r !== void 0 ? _r : typeof requestData.slotStart,
            slotEndType: (_u = (_t = (_s = requestData.slotEnd) === null || _s === void 0 ? void 0 : _s.constructor) === null || _t === void 0 ? void 0 : _t.name) !== null && _u !== void 0 ? _u : typeof requestData.slotEnd,
            sessionDateTs: sessionDateTs.toDate().toISOString(),
            slotStartTs: slotStartTs.toDate().toISOString(),
            slotEndTs: slotEndTs.toDate().toISOString(),
            amount,
            bundlePrice: (_x = (_w = (_v = subscription.bundlePrice) !== null && _v !== void 0 ? _v : subscription.totalPrice) !== null && _w !== void 0 ? _w : subscription.price) !== null && _x !== void 0 ? _x : 0,
            totalSessions: (_0 = (_z = (_y = subscription.totalSessions) !== null && _y !== void 0 ? _y : subscription.sessionCount) !== null && _z !== void 0 ? _z : subscription.sessionsCount) !== null && _0 !== void 0 ? _0 : 1,
        });
        // ── 10. Idempotency guard ───────────────────────────────────────────────
        if (freshRequestData.status === STATUS.ACCEPTED && freshRequestData.sessionId) {
            functions.logger.info('confirmSubscriptionSession: idempotent', {
                requestId,
                sessionId: freshRequestData.sessionId,
            });
            return {
                success: true,
                sessionId: freshRequestData.sessionId,
                message: 'Already confirmed',
            };
        }
        // ── 11. Status check ──────────────────────────────────────────────────
        const ALLOWED_STATUSES = [
            STATUS.PENDING,
            STATUS.AWAITING_PAYMENT,
            STATUS.AWAITING_DIRECT,
        ];
        if (!ALLOWED_STATUSES.includes(freshRequestData.status)) {
            throw new functions.https.HttpsError('failed-precondition', `Request status is '${freshRequestData.status}', ` +
                `expected one of: ${ALLOWED_STATUSES.join(', ')}`);
        }
        // ── 12. Ownership check ───────────────────────────────────────────────
        if (subscription.studentId !== studentId ||
            subscription.mohaffezId !== mohaffezId) {
            throw new functions.https.HttpsError('permission-denied', 'الاشتراك لا ينتمي للمستخدمين المحددين');
        }
        // ── 13. sessionType uniqueness check ──────────────────────────────────
        if (subscription.sessionType &&
            subscription.sessionType !== sessionType) {
            throw new functions.https.HttpsError('failed-precondition', `نوع الجلسة المطلوبة '${sessionType}' لا يتطابق مع نوع جلسة الاشتراك ` +
                `'${subscription.sessionType}'. ` +
                `يجب استخدام اشتراك مطابق لنوع الجلسة.`);
        }
        // ── 14. Remaining sessions check ──────────────────────────────────────
        const remainingSessions = (_1 = subscription.remainingSessions) !== null && _1 !== void 0 ? _1 : 0;
        if (remainingSessions <= 0) {
            throw new functions.https.HttpsError('failed-precondition', 'لا توجد جلسات متبقية في هذا الاشتراك');
        }
        // ── 15. Build sessionDetails for hafizSessions document ───────────────
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
            notificationsAlreadySent: true,
        };
        // ── 16. Build synthetic PaymentDocument ───────────────────────────────
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
                sessionDetails,
            },
        };
        // ── 17. Build SlotInfo ─────────────────────────────────────────────────
        const slotInfo = {
            mohaffezId,
            slotDate: sessionDateTs,
            timeSlot: preferredTimeSlot,
            sessionType,
        };
        // ── 18. Consume subscription + create session (atomic inside handler) ─
        const result = await (0, handlers_1.consumeSubscriptionAndCreateSession)(subscriptionId, syntheticPayment, transactionId, syntheticPayment.metadata, slotInfo);
        functions.logger.info('confirmSubscriptionSession: Session consumed', {
            subscriptionId,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        });
        // ── 19. Commission tracking (separate transaction) ────────────────────
        const now = new Date();
        const weekNumber = (0, dateHelpers_1.getWeekNumber)(now);
        const weekStart = (0, dateHelpers_1.getWeekStart)(now);
        const weekEnd = (0, dateHelpers_1.getWeekEnd)(now);
        const commissionAmount = amount * COMMISSION_RATE;
        await admin_1.db.runTransaction(async (tx) => {
            // Individual commission record.
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
            // Upsert weekly summary (merge:true makes this idempotent).
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
        // ── 20. Notification to student ───────────────────────────────────────
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
        // ── 21. Return success ────────────────────────────────────────────────
        return {
            success: true,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        };
    }
    catch (error) {
        // Re-throw HttpsErrors directly so the Flutter client receives the
        // correct gRPC code (failed-precondition, permission-denied, etc.)
        // instead of a generic 'internal' error.
        if (error instanceof functions.https.HttpsError) {
            functions.logger.error('confirmSubscriptionSession: HttpsError', {
                code: error.code,
                message: error.message,
                requestId,
                subscriptionId,
            });
            throw error;
        }
        // Unexpected errors (TypeErrors, network failures, etc.)
        const message = error instanceof Error ? error.message : 'Unknown error';
        const stack = error instanceof Error ? error.stack : undefined;
        functions.logger.error('confirmSubscriptionSession: Unexpected error', {
            requestId,
            subscriptionId,
            error: message,
            stack,
        });
        throw new functions.https.HttpsError('internal', message);
    }
});
//# sourceMappingURL=confirmSubscriptionSession.js.map