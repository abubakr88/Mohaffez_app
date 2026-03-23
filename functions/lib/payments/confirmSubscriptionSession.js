"use strict";
// functions/src/payments/confirmSubscriptionSession.ts
// FIX #4:    sessionType uniqueness — subscription.sessionType must match requested sessionType
// FIX TOCTOU: requestRef + subRef reads parallelised; re-validated atomically inside
//             consumeSubscriptionAndCreateSession's own transaction
// FIX:       HttpsErrors re-thrown directly — never wrapped as 'internal'
// FIX:       parseFlutterDate used for all slot timestamps (avoids local-timezone shift)
// FIX:       Deterministic transactionId (removes Date.now() suffix → idempotency-safe)
// BUG #3:    maxActiveSubscriptions + commission tracking preserved
// ─────────────────────────────────────────────────────────────────────────────
// BUG-FIX-1: slotDate/slotStart/slotEnd are stored as Firestore Timestamps in
//            Firestore (not strings). parseFlutterDate(x as string) was called
//            on a Timestamp object → TypeError: iso.endsWith is not a function.
//            Fixed via toDate() helper that accepts Timestamp | string | Date.
// BUG-FIX-2: Steps 3-5 (Firestore read + validation + slot parsing) were
//            OUTSIDE the try/catch block, so any throw there became an
//            uncaught 400 with no error log. All logic now lives inside try.
// BUG-FIX-3: amount validation used typeof amount !== 'number' which rejects
//            amount=0 (valid for subscription-credit sessions) and also
//            rejects undefined (legacy requests without paymentAmount field).
//            Fixed: default to 0 when field is absent; 0 is explicitly allowed.
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
// BUG-FIX-1: Normalise Firestore Timestamp | ISO string | Date → Date.
// Firestore stores slotDate/slotStart/slotEnd as Timestamp objects.
// The old code cast them with `as string` and then called parseFlutterDate,
// which crashed with "iso.endsWith is not a function".
// ---------------------------------------------------------------------------
function toDate(value, fieldName) {
    if (value instanceof admin.firestore.Timestamp) {
        return value.toDate();
    }
    if (value instanceof Date && !isNaN(value.getTime())) {
        return value;
    }
    if (typeof value === 'string' && value.length > 0) {
        return parseFlutterDate(value);
    }
    throw new functions.https.HttpsError('invalid-argument', `حقل ${fieldName} غير صالح أو مفقود`);
}
// ---------------------------------------------------------------------------
// Main callable
// ---------------------------------------------------------------------------
exports.confirmSubscriptionSession = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p;
    functions.logger.info('confirmSubscriptionSession: Starting', {
        timestamp: new Date().toISOString(),
    });
    // ── 1. Auth ─────────────────────────────────────────────────────────────
    // These two checks are intentionally OUTSIDE the try so that
    // auth/permission errors still surface as proper HttpsErrors.
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'المستخدم غير مصادق عليه');
    }
    const mohaffezId = context.auth.uid;
    // ── 2. Caller must be the mohaffez ───────────────────────────────────────
    if (context.auth.uid !== data.mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'غير مصرح لك بتأكيد هذه الجلسة');
    }
    // BUG-FIX-2: All remaining logic (including every Firestore read,
    // field extraction, timestamp parsing, and business logic) is now
    // INSIDE the try/catch so that any unexpected error is logged properly
    // and returned as a typed HttpsError instead of a silent 400.
    // Declare these here so they are accessible in the catch block for logging.
    let requestId;
    let subscriptionId;
    try {
        // ── 3. Extract minimal caller params ──────────────────────────────────
        // NOTE: Only basic identity info is accepted from the caller.
        // All session/subscription fields are read from Firestore to prevent
        // payload injection attacks.
        requestId = data.requestId;
        const mohaffezName = data.mohaffezName;
        if (!requestId || !mohaffezName) {
            throw new functions.https.HttpsError('invalid-argument', 'requestId و mohaffezName مطلوبان');
        }
        // ── 4. Read the sessionRequest doc from Firestore ─────────────────────
        const requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
        const requestDoc = await requestRef.get();
        if (!requestDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
        }
        const requestData = requestDoc.data();
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
        // BUG-FIX-3: Subscription-credit sessions legitimately have amount = 0.
        // Legacy requests may not have the paymentAmount field at all (undefined).
        // The old code `amount == null || typeof amount !== 'number'` rejected both
        // cases. Now we default to 0 when the field is absent.
        const rawAmount = requestData.paymentAmount;
        const amount = rawAmount != null && typeof rawAmount === 'number' ? rawAmount : 0;
        // ── 5. Validate required string fields ────────────────────────────────
        if (!studentId || !studentName || !sessionType || !preferredTimeSlot) {
            throw new functions.https.HttpsError('invalid-argument', 'بيانات الطلب غير مكتملة (studentId / studentName / sessionType / preferredTimeSlot)');
        }
        // ── 6. Parse slot timestamps ──────────────────────────────────────────
        // BUG-FIX-1: Use toDate() which handles Firestore Timestamp OR ISO string.
        // The old code passed `slotDate as string` directly to parseFlutterDate,
        // crashing with "iso.endsWith is not a function" when the value is a
        // Firestore Timestamp (which is always the case for docs written by the app).
        const sessionDateTs = admin.firestore.Timestamp.fromDate(toDate(requestData.slotDate, 'slotDate'));
        const slotStartTs = admin.firestore.Timestamp.fromDate(toDate(requestData.slotStart, 'slotStart'));
        const slotEndTs = admin.firestore.Timestamp.fromDate(toDate(requestData.slotEnd, 'slotEnd'));
        // Diagnostic log — confirms the fix is working in production.
        functions.logger.info('confirmSubscriptionSession: slot fields resolved', {
            requestId,
            subscriptionId,
            slotDateType: (_g = (_f = (_e = requestData.slotDate) === null || _e === void 0 ? void 0 : _e.constructor) === null || _f === void 0 ? void 0 : _f.name) !== null && _g !== void 0 ? _g : typeof requestData.slotDate,
            slotStartType: (_k = (_j = (_h = requestData.slotStart) === null || _h === void 0 ? void 0 : _h.constructor) === null || _j === void 0 ? void 0 : _j.name) !== null && _k !== void 0 ? _k : typeof requestData.slotStart,
            slotEndType: (_o = (_m = (_l = requestData.slotEnd) === null || _l === void 0 ? void 0 : _l.constructor) === null || _m === void 0 ? void 0 : _m.name) !== null && _o !== void 0 ? _o : typeof requestData.slotEnd,
            sessionDateTs: sessionDateTs.toDate().toISOString(),
            slotStartTs: slotStartTs.toDate().toISOString(),
            slotEndTs: slotEndTs.toDate().toISOString(),
            amount,
        });
        // ── 7. Build refs ─────────────────────────────────────────────────────
        const subRef = admin_1.db.collection('subscriptions').doc(subscriptionId);
        // Deterministic transactionId — removes Date.now() so retries are idempotent.
        const transactionId = `direct_sub_${subscriptionId}_${requestId}`;
        // ── 8. Parallel pre-validation reads (non-transactional fast-failure) ─
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
        const freshRequestData = requestSnap.data();
        const subscription = subSnap.data();
        // ── 9. Idempotency guard ───────────────────────────────────────────────
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
        // ── 10. Status check ──────────────────────────────────────────────────
        // FIX: Also accept 'pending' status for subscription-credit requests
        // that were created with selectedPaymentMethod: 'subscriptioncredit'.
        const ALLOWED_STATUSES = [
            STATUS.PENDING,
            STATUS.AWAITING_PAYMENT,
            STATUS.AWAITING_DIRECT,
        ];
        if (!ALLOWED_STATUSES.includes(freshRequestData.status)) {
            throw new functions.https.HttpsError('failed-precondition', `Request status is '${freshRequestData.status}', ` +
                `expected one of: ${ALLOWED_STATUSES.join(', ')}`);
        }
        // ── 11. Ownership check ───────────────────────────────────────────────
        if (subscription.studentId !== studentId ||
            subscription.mohaffezId !== mohaffezId) {
            throw new functions.https.HttpsError('permission-denied', 'الاشتراك لا ينتمي للمستخدمين المحددين');
        }
        // ── 12. FIX #4: sessionType uniqueness check ──────────────────────────
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
        // ── 13. Remaining sessions check ──────────────────────────────────────
        const remainingSessions = (_p = subscription.remainingSessions) !== null && _p !== void 0 ? _p : 0;
        if (remainingSessions <= 0) {
            throw new functions.https.HttpsError('failed-precondition', 'لا توجد جلسات متبقية في هذا الاشتراك');
        }
        // ── 14. Build sessionDetails for hafizSessions document ───────────────
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
            // Prevents the Firestore trigger from sending a duplicate notification.
            notificationsAlreadySent: true,
        };
        // ── 15. Build synthetic PaymentDocument ───────────────────────────────
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
        // ── 16. Build SlotInfo ─────────────────────────────────────────────────
        const slotInfo = {
            mohaffezId,
            slotDate: sessionDateTs,
            timeSlot: preferredTimeSlot,
            sessionType,
        };
        // ── 17. Consume subscription + create session (atomic inside handler) ─
        const result = await (0, handlers_1.consumeSubscriptionAndCreateSession)(subscriptionId, syntheticPayment, transactionId, syntheticPayment.metadata, slotInfo);
        functions.logger.info('confirmSubscriptionSession: Session consumed', {
            subscriptionId,
            sessionId: result.sessionId,
            remainingSessions: result.remainingSessions,
        });
        // ── 18. Commission tracking (separate transaction) ────────────────────
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
        // ── 19. Notification to student ───────────────────────────────────────
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
        // ── 20. Return success ────────────────────────────────────────────────
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
            stack, // ← stack trace now logged for debugging
        });
        throw new functions.https.HttpsError('internal', message);
    }
});
//# sourceMappingURL=confirmSubscriptionSession.js.map