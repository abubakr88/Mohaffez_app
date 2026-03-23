"use strict";
// CHANGES vs original:
// 1. Added: validityDays extraction + rawPlanType/isBundlePlan computation after destructure
// 2. Fixed: initialStatus — bundle directpayment requests start at PENDING (not AWAITING_PAYMENT)
//    because teacher-first rule applies to all bundles regardless of payment method
// 3. Added: validityDays to transaction.set()
// 4. Updated: notification title/body in 4f to reflect bundle vs single
// FIX-TS6133: subscriptionId destructured variable now used in both diagnostic log
//             and transaction.set() — eliminates TS6133 'declared but never read' error.
// All other logic (slot lock, conflict guard, availability disable, etc.) is UNTOUCHED
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSessionRequest = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
function normalizeTimeSlot(raw) {
    // FIXED: BUG-5 - strip both hyphens AND en-dashes
    return raw.replace(/\s/g, '').replace(/[\u2013\u2014]/g, '-');
}
function parseFlutterDate(iso) {
    if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
        return new Date(iso + 'Z');
    }
    return new Date(iso);
}
exports.createSessionRequest = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const fallbackIdToken = typeof (data === null || data === void 0 ? void 0 : data.idToken) === 'string' ? data.idToken : null;
    let studentId = (_b = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid) !== null && _b !== void 0 ? _b : null;
    // ── 0. DIAGNOSTIC LOG (remove after issue resolved) ───────────────────
    functions.logger.info('createSessionRequest invoked', {
        hasAuth: !!context.auth,
        uid: (_d = (_c = context.auth) === null || _c === void 0 ? void 0 : _c.uid) !== null && _d !== void 0 ? _d : 'NONE',
        hasAppCheck: !!context.app,
        rawAuthHeader: !!((_f = (_e = context.rawRequest) === null || _e === void 0 ? void 0 : _e.headers) === null || _f === void 0 ? void 0 : _f.authorization),
        hasFallbackIdToken: !!fallbackIdToken,
    });
    // ── 1. Auth ────────────────────────────────────────────────────────────
    if (!studentId && fallbackIdToken) {
        try {
            const decoded = await admin.auth().verifyIdToken(fallbackIdToken);
            studentId = decoded.uid;
            functions.logger.warn('createSessionRequest: using fallback idToken verification', { uid: studentId });
        }
        catch (e) {
            functions.logger.error('createSessionRequest: fallback idToken verification failed', { error: e instanceof Error ? e.message : String(e) });
        }
    }
    if (!studentId) {
        functions.logger.error('createSessionRequest: UNAUTHENTICATED - no context.auth and no valid fallback token', { headers: JSON.stringify((_h = (_g = context.rawRequest) === null || _g === void 0 ? void 0 : _g.headers) !== null && _h !== void 0 ? _h : {}) });
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    // ── 2. Destructure ─────────────────────────────────────────────────────
    const { mohaffezId, studentName, mohaffezName, sessionType, preferredTimeSlot, slotDate, slotStart, slotEnd, imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone, subscriptionId, // FIX-TS6133: now consumed below (log + Firestore write)
    requiresPaymentOnAcceptance, selectedPaymentMethod, slotLockId, } = data;
    // ── NEW: plan fields with safe defaults ────────────────────────────────
    // rawPlanType / isBundlePlan used later for initialStatus and notification
    const rawPlanType = (_j = data.planType) !== null && _j !== void 0 ? _j : 'single';
    const isBundlePlan = rawPlanType === 'bundle' || rawPlanType === 'subscription';
    const validityDays = typeof data.validityDays === 'number' ? data.validityDays : null;
    // ──────────────────────────────────────────────────────────────────────
    // ── 3. Validate ────────────────────────────────────────────────────────
    if (!mohaffezId ||
        !studentName ||
        !mohaffezName ||
        !sessionType ||
        !preferredTimeSlot ||
        !slotDate ||
        !slotStart ||
        !slotEnd) {
        functions.logger.error('createSessionRequest: missing required fields', {
            studentId,
            mohaffezId,
            hasStudentName: !!studentName,
            hasMohaffezName: !!mohaffezName,
            sessionType,
            preferredTimeSlot,
            slotDate,
        });
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    const slotDateObj = parseFlutterDate(slotDate);
    const slotStartObj = parseFlutterDate(slotStart);
    const slotEndObj = parseFlutterDate(slotEnd);
    if (isNaN(slotDateObj.getTime()) ||
        isNaN(slotStartObj.getTime()) ||
        isNaN(slotEndObj.getTime())) {
        functions.logger.error('createSessionRequest: invalid date values', {
            slotDate,
            slotStart,
            slotEnd,
        });
        throw new functions.https.HttpsError('invalid-argument', 'Invalid date values provided');
    }
    if (data.studentId && data.studentId !== studentId) {
        throw new functions.https.HttpsError('permission-denied', 'studentId in payload does not match authenticated user');
    }
    functions.logger.info('createSessionRequest: validation passed', {
        studentId,
        mohaffezId,
        sessionType,
        preferredTimeSlot,
        slotDate,
        hasSlotLockId: !!slotLockId,
        selectedPaymentMethod,
        requiresPaymentOnAcceptance,
        rawPlanType,
        isBundlePlan,
    });
    // ── 4. Transaction ─────────────────────────────────────────────────────
    return admin_1.db.runTransaction(async (transaction) => {
        var _a, _b, _c, _d, _e;
        let lockRef = null;
        let availabilityRef = null;
        let updatedSlots = null;
        // ── 4a. Validate slot lock ─────────────────────────────────────────
        if (slotLockId) {
            lockRef = admin_1.db.collection('slotLocks').doc(slotLockId);
            const lockSnap = await transaction.get(lockRef);
            if (!lockSnap.exists) {
                throw new functions.https.HttpsError('failed-precondition', 'الموعد المحجوز مؤقتاً غير موجود أو انتهت صلاحيته');
            }
            const lock = lockSnap.data();
            if (lock.released === true) {
                throw new functions.https.HttpsError('failed-precondition', 'تم تحرير هذا الموعد بالفعل');
            }
            const now = new Date();
            if (lock.expiresAt && lock.expiresAt.toDate() < now) {
                throw new functions.https.HttpsError('failed-precondition', 'انتهت صلاحية حجز الموعد المؤقت. الرجاء اختيار موعد آخر');
            }
            if (lock.mohaffezId !== mohaffezId) {
                throw new functions.https.HttpsError('invalid-argument', 'الموعد المحجوز لا ينتمي لهذا المحفظ');
            }
            const availabilityDocId = typeof lock.availabilityDocId === 'string'
                ? lock.availabilityDocId
                : null;
            const lockTimeSlot = typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
            const lockSessionType = typeof lock.sessionType === 'string' ? lock.sessionType : null;
            if (availabilityDocId && lockTimeSlot && lockSessionType) {
                availabilityRef = admin_1.db
                    .collection('users')
                    .doc(mohaffezId)
                    .collection('availability')
                    .doc(availabilityDocId);
                const availabilitySnap = await transaction.get(availabilityRef);
                if (availabilitySnap.exists) {
                    const availabilityData = (_a = availabilitySnap.data()) !== null && _a !== void 0 ? _a : {};
                    const slots = Array.isArray(availabilityData.timeSlots)
                        ? availabilityData.timeSlots
                        : [];
                    const selectedSlot = normalizeTimeSlot(lockTimeSlot);
                    let changed = false;
                    updatedSlots = slots.map((slot) => {
                        const start = typeof slot.startTime === 'string' ? slot.startTime : '';
                        const end = typeof slot.endTime === 'string' ? slot.endTime : '';
                        const slotTime = normalizeTimeSlot(`${start}-${end}`);
                        if (slotTime === selectedSlot &&
                            slot.sessionType === lockSessionType) {
                            changed = true;
                            return Object.assign(Object.assign({}, slot), { enabled: false, lockedBy: null, lockId: null, lockedAt: null });
                        }
                        return slot;
                    });
                    // FIXED: BUG-5 - Warn if slot disable was skipped due to mismatch
                    if (!changed) {
                        functions.logger.warn('createSessionRequest: slot disable skipped — no matching slot found', {
                            lockTimeSlot,
                            lockSessionType,
                            availableSlots: slots.map((s) => `${s.startTime}-${s.endTime}:${s.sessionType}`),
                        });
                        updatedSlots = null;
                    }
                }
            }
        }
        // ── 4b. Conflict guard ─────────────────────────────────────────────
        // FIX-BOOKING-1: Guard against all live statuses, not just PENDING.
        // Required Firestore composite index: (mohaffezId ASC, status ASC, slotDate ASC)
        const LIVE_STATUSES = [
            STATUS.PENDING,
            STATUS.AWAITING_PAYMENT,
            STATUS.AWAITING_DIRECT,
            STATUS.ACCEPTED,
        ];
        const conflictQuery = admin_1.db
            .collection('sessionRequests')
            .where('mohaffezId', '==', mohaffezId)
            .where('status', 'in', [...LIVE_STATUSES])
            .where('slotDate', '==', admin.firestore.Timestamp.fromDate(slotDateObj));
        const conflictSnap = await transaction.get(conflictQuery);
        const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);
        const duplicate = conflictSnap.docs.find((doc) => {
            var _a;
            const d = doc.data();
            return (normalizeTimeSlot((_a = d.preferredTimeSlot) !== null && _a !== void 0 ? _a : '') === normalizedSlot &&
                d.sessionType === sessionType);
        });
        if (duplicate) {
            if (duplicate.data().studentId === studentId) {
                functions.logger.warn('Duplicate request from same student — returning existing', { existingId: duplicate.id, studentId, mohaffezId });
                return { success: true, requestId: duplicate.id, isDuplicate: true };
            }
            functions.logger.warn('Slot already requested by another student', {
                conflictingRequestId: duplicate.id,
                mohaffezId,
                preferredTimeSlot,
                slotDate,
            });
            throw new functions.https.HttpsError('resource-exhausted', 'هذا الموعد محجوز بالفعل. الرجاء اختيار موعد آخر');
        }
        // ── 4c. Write sessionRequest ───────────────────────────────────────
        const requestRef = admin_1.db.collection('sessionRequests').doc();
        // FIX-TS6133: use destructured `subscriptionId` variable (not data.subscriptionId)
        functions.logger.info('createSessionRequest saving fields', {
            selectedPaymentMethod,
            subscriptionId: subscriptionId !== null && subscriptionId !== void 0 ? subscriptionId : 'MISSING',
        });
        // ALL session requests start at PENDING regardless of payment method.
        // Teacher accepts the slot first (PendingRequestsScreen) → student is notified
        // → status transitions to AWAITINGPAYMENT → student transfers payment →
        // studentMarkedDirectPayment → mohaffezConfirmDirectPayment → hafizSession created.
        // This enforces the teacher-first rule for every path.
        const initialStatus = STATUS.PENDING;
        transaction.set(requestRef, {
            studentId,
            mohaffezId,
            studentName,
            mohaffezName,
            sessionType,
            preferredTimeSlot,
            slotDate: admin.firestore.Timestamp.fromDate(slotDateObj),
            slotStart: admin.firestore.Timestamp.fromDate(slotStartObj),
            slotEnd: admin.firestore.Timestamp.fromDate(slotEndObj),
            imamAddressText: imamAddressText !== null && imamAddressText !== void 0 ? imamAddressText : null,
            imamAddressLat: imamAddressLat !== null && imamAddressLat !== void 0 ? imamAddressLat : null,
            imamAddressLng: imamAddressLng !== null && imamAddressLng !== void 0 ? imamAddressLng : null,
            mohaffezPhone: mohaffezPhone !== null && mohaffezPhone !== void 0 ? mohaffezPhone : null,
            subscriptionId: subscriptionId !== null && subscriptionId !== void 0 ? subscriptionId : null, // FIX-TS6133: was (data.subscriptionId as string) ?? null
            planId: (_b = data.planId) !== null && _b !== void 0 ? _b : null,
            planTitle: (_c = data.planTitle) !== null && _c !== void 0 ? _c : null,
            planType: rawPlanType,
            paymentAmount: typeof data.paymentAmount === 'number' ? data.paymentAmount : null,
            sessionsCount: typeof data.sessionsCount === 'number' ? data.sessionsCount : null,
            validityDays: validityDays,
            requiresPaymentOnAcceptance: selectedPaymentMethod === 'directpayment' && !isBundlePlan
                ? true
                : (requiresPaymentOnAcceptance !== null && requiresPaymentOnAcceptance !== void 0 ? requiresPaymentOnAcceptance : false),
            selectedPaymentMethod: selectedPaymentMethod !== null && selectedPaymentMethod !== void 0 ? selectedPaymentMethod : 'pay_after_acceptance',
            slotLockId: slotLockId !== null && slotLockId !== void 0 ? slotLockId : null,
            status: initialStatus,
            createdAt: admin_1.FieldValue.serverTimestamp(),
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        // ── 4d. Release slot lock ──────────────────────────────────────────
        if (lockRef) {
            transaction.update(lockRef, {
                released: true,
                releasedAt: admin_1.FieldValue.serverTimestamp(),
            });
        }
        // ── 4e. Disable availability slot ─────────────────────────────────
        if (availabilityRef && updatedSlots) {
            transaction.update(availabilityRef, {
                timeSlots: updatedSlots,
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
        }
        // ── 4f. Notify mohaffez ────────────────────────────────────────────
        // NEW: bundle requests show plan name/count in the notification
        const notifRef = admin_1.db.collection('notifications').doc();
        transaction.set(notifRef, {
            userId: mohaffezId,
            recipientId: mohaffezId,
            senderId: studentId,
            title: isBundlePlan
                ? `طلب حزمة جديد من ${studentName}`
                : 'طلب حجز جديد',
            body: isBundlePlan
                ? `${(_d = data.planTitle) !== null && _d !== void 0 ? _d : ''} — ${(_e = data.sessionsCount) !== null && _e !== void 0 ? _e : ''} جلسة`
                : `${studentName} يطلب حجز جلسة معك`,
            type: 'sessionRequest',
            isRead: false,
            data: {
                requestId: requestRef.id,
                studentId,
                studentName,
                sessionType,
                preferredTimeSlot,
                planType: rawPlanType,
            },
            createdAt: admin_1.FieldValue.serverTimestamp(),
        });
        functions.logger.info('Session request created successfully', {
            requestId: requestRef.id,
            studentId,
            mohaffezId,
            sessionType,
            preferredTimeSlot,
            rawPlanType,
            initialStatus,
        });
        return { success: true, requestId: requestRef.id };
    });
});
//# sourceMappingURL=createSessionRequest.js.map