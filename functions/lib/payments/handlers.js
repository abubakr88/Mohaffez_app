"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmBookingAfterPayment = confirmBookingAfterPayment;
exports.consumeSubscriptionAndCreateSession = consumeSubscriptionAndCreateSession;
exports.createSubscriptionFromPayment = createSubscriptionFromPayment;
// src/payments/handlers.ts
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
// ─── Helpers ──────────────────────────────────────────────────────────────────
const parseNumber = (v, fb) => typeof v === 'number' ? v : fb;
const parseString = (v, fb) => typeof v === 'string' && v.trim().length > 0 ? v : fb;
/**
 * READS the availability document for a slot inside an existing transaction
 * and COMPUTES the updated slots array.
 * Returns { doc, updatedSlots } when a change is needed, null otherwise.
 * Must be called before any transaction writes.
 */
async function readAvailabilityInTransaction(transaction, slotInfo) {
    var _a;
    const { mohaffezId, slotDate, timeSlot, sessionType } = slotInfo;
    if (!mohaffezId || !slotDate || !timeSlot || !sessionType) {
        functions.logger.warn('readAvailabilityInTransaction: missing slot params', slotInfo);
        return null;
    }
    const slotTs = slotDate;
    const jsDay = slotTs.toDate().getDay();
    const dayOfWeek = jsDay === 0 ? 7 : jsDay;
    const availQuery = admin_1.db
        .collection('users').doc(mohaffezId)
        .collection('availability')
        .where('dayOfWeek', '==', dayOfWeek)
        .limit(1);
    const snap = await transaction.get(availQuery);
    if (snap.empty) {
        functions.logger.warn('readAvailabilityInTransaction: no availability doc', { mohaffezId, dayOfWeek });
        return null;
    }
    const doc = snap.docs[0];
    const data = doc.data();
    let changed = false;
    const updatedSlots = ((_a = data.timeSlots) !== null && _a !== void 0 ? _a : []).map((slot) => {
        var _a, _b;
        const st = `${(_a = slot['startTime']) !== null && _a !== void 0 ? _a : ''}-${(_b = slot['endTime']) !== null && _b !== void 0 ? _b : ''}`;
        if (st === timeSlot && slot['sessionType'] === sessionType && slot['enabled'] === true) {
            changed = true;
            return Object.assign(Object.assign({}, slot), { enabled: false });
        }
        return slot;
    });
    if (!changed) {
        functions.logger.info('readAvailabilityInTransaction: slot already disabled or not found', { mohaffezId, timeSlot, sessionType });
        return null;
    }
    return { doc, updatedSlots };
}
// ─── Exported Handlers ────────────────────────────────────────────────────────
/**
 * Accepts a booking request and creates the hafizSession in a single transaction.
 * ✅ FIX: slot disabling is now atomic — no more race window between booking and removal.
 */
async function confirmBookingAfterPayment(requestId, sessionDetails, payment, transactionId, slotInfo, paymentUpdate) {
    return admin_1.db.runTransaction(async (transaction) => {
        // ── READS (must all come before writes) ───────────────────────────────────
        const requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
        const requestSnap = await transaction.get(requestRef);
        const paymentRef = paymentUpdate
            ? admin_1.db.collection('payments').doc(paymentUpdate.paymentId)
            : null;
        if (paymentRef) {
            await transaction.get(paymentRef);
        }
        // Read availability inside the same transaction while still in read phase
        const availUpdate = slotInfo
            ? await readAvailabilityInTransaction(transaction, slotInfo)
            : null;
        // ── VALIDATE ──────────────────────────────────────────────────────────────
        if (!requestSnap.exists)
            throw new Error('Session request not found');
        // ── WRITES ────────────────────────────────────────────────────────────────
        const sessionRef = admin_1.db.collection('hafizSessions').doc();
        transaction.update(requestRef, {
            status: STATUS.ACCEPTED,
            isPaid: true,
            paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            paymentTransactionId: transactionId,
            updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(sessionRef, Object.assign(Object.assign({}, sessionDetails), { requestId, status: STATUS.ACCEPTED, isPaid: true, paymentTransactionId: transactionId, createdAt: admin_1.default.firestore.FieldValue.serverTimestamp(), acceptedAt: admin_1.default.firestore.FieldValue.serverTimestamp(), studentId: payment.studentId, mohaffezId: payment.mohaffezId }));
        if (availUpdate) {
            transaction.update(availUpdate.doc.ref, {
                timeSlots: availUpdate.updatedSlots,
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            functions.logger.info('Slot disabled atomically with booking', {
                requestId, sessionId: sessionRef.id, timeSlot: slotInfo === null || slotInfo === void 0 ? void 0 : slotInfo.timeSlot,
            });
        }
        if (paymentUpdate && paymentRef) {
            transaction.update(paymentRef, {
                status: 'completed',
                paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                idempotencyKey: `${paymentUpdate.paymentId}:${paymentUpdate.transactionId}`,
                processedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
        }
        functions.logger.info('Booking confirmed in transaction', { requestId, sessionId: sessionRef.id });
        return { sessionId: sessionRef.id };
    });
}
/**
 * Consumes one session from a subscription and creates the hafizSession.
 * ✅ FIX: slot disabling is now atomic — same transaction as subscription decrement.
 */
async function consumeSubscriptionAndCreateSession(subscriptionId, payment, transactionId, metadata, slotInfo, paymentUpdate) {
    return admin_1.db.runTransaction(async (transaction) => {
        // ── READS ─────────────────────────────────────────────────────────────────
        const subRef = admin_1.db.collection('subscriptions').doc(subscriptionId);
        const subSnap = await transaction.get(subRef);
        const paymentRef = paymentUpdate
            ? admin_1.db.collection('payments').doc(paymentUpdate.paymentId)
            : null;
        if (paymentRef) {
            await transaction.get(paymentRef);
        }
        let requestRef = null;
        let requestSnap = null;
        if (metadata.requestId && metadata.sessionDetails) {
            requestRef = admin_1.db.collection('sessionRequests').doc(metadata.requestId);
            requestSnap = await transaction.get(requestRef);
        }
        const availUpdate = slotInfo
            ? await readAvailabilityInTransaction(transaction, slotInfo)
            : null;
        // ── VALIDATE ──────────────────────────────────────────────────────────────
        if (!subSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'الاشتراك غير موجود');
        }
        const subscription = subSnap.data();
        const remainingSessions = parseNumber(subscription['remainingSessions'], 0);
        if (remainingSessions <= 0) {
            throw new functions.https.HttpsError('failed-precondition', 'لا توجد جلسات متبقية في هذا الاشتراك');
        }
        if (requestRef && requestSnap && !requestSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'طلب الجلسة غير موجود');
        }
        // ── WRITES ────────────────────────────────────────────────────────────────
        const newRemaining = remainingSessions - 1;
        const status = newRemaining === 0 ? 'depleted' : parseString(subscription['status'], 'active');
        transaction.update(subRef, {
            remainingSessions: newRemaining,
            status,
            lastUsedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        let sessionId;
        if (requestRef && requestSnap && metadata.sessionDetails) {
            const sessionRef = admin_1.db.collection('hafizSessions').doc();
            sessionId = sessionRef.id;
            transaction.update(requestRef, {
                status: STATUS.ACCEPTED,
                isPaid: true,
                paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                paymentTransactionId: transactionId,
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            transaction.set(sessionRef, Object.assign(Object.assign({}, metadata.sessionDetails), { requestId: metadata.requestId, status: STATUS.ACCEPTED, isPaid: true, paymentTransactionId: transactionId, createdAt: admin_1.default.firestore.FieldValue.serverTimestamp(), acceptedAt: admin_1.default.firestore.FieldValue.serverTimestamp(), studentId: payment.studentId, mohaffezId: payment.mohaffezId }));
        }
        if (availUpdate) {
            transaction.update(availUpdate.doc.ref, {
                timeSlots: availUpdate.updatedSlots,
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
        }
        if (paymentUpdate && paymentRef) {
            transaction.update(paymentRef, {
                status: 'completed',
                paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                idempotencyKey: `${paymentUpdate.paymentId}:${paymentUpdate.transactionId}`,
                processedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
        }
        functions.logger.info('Subscription session consumed in transaction', {
            subscriptionId, remainingSessions: newRemaining, sessionId,
        });
        return { remainingSessions: newRemaining, sessionId };
    });
}
async function createSubscriptionFromPayment(payment, transactionId, paymentUpdate) {
    var _a;
    const metadata = (_a = payment.metadata) !== null && _a !== void 0 ? _a : {};
    const planTitle = parseString(metadata['planTitle'], 'Payment Plan');
    const planType = parseString(metadata['planType'], 'single');
    const sessionsCount = parseNumber(metadata['sessionsCount'], 1);
    const validityDays = typeof metadata['validityDays'] === 'number' ? metadata['validityDays'] : undefined;
    const sessionType = parseString(metadata['sessionType'], '');
    return admin_1.db.runTransaction(async (transaction) => {
        const PER_SESSION_TYPE_LIMIT = 1; // hard limit: one active bundle per studentId+mohaffezId+sessionType
        const studentId = payment.studentId;
        const mohaffezId = payment.mohaffezId;
        // CONSTRAINT: one active bundle per studentId+mohaffezId+sessionType
        const activeSubsQuery = admin_1.db.collection('subscriptions')
            .where('studentId', '==', studentId)
            .where('mohaffezId', '==', mohaffezId)
            .where('sessionType', '==', sessionType)
            .where('status', '==', 'active');
        const activeSubs = await transaction.get(activeSubsQuery);
        if (activeSubs.size >= PER_SESSION_TYPE_LIMIT) {
            throw new functions.https.HttpsError('resource-exhausted', 'لديك باقة نشطة بالفعل لهذا النوع من الجلسات');
        }
        const subscriptionRef = admin_1.db.collection('subscriptions').doc();
        let expiryDate = null;
        if (validityDays && validityDays > 0) {
            const expiry = new Date();
            expiry.setDate(expiry.getDate() + validityDays);
            expiryDate = admin_1.default.firestore.Timestamp.fromDate(expiry);
        }
        transaction.set(subscriptionRef, {
            studentId: payment.studentId,
            studentName: payment.studentName,
            mohaffezId: payment.mohaffezId,
            mohaffezName: payment.mohaffezName,
            planId: parseString(metadata['planId'], ''),
            planTitle, planType,
            totalSessions: sessionsCount,
            remainingSessions: sessionsCount,
            totalPaid: payment.amount,
            paymentTransactionId: transactionId,
            startDate: admin_1.default.firestore.FieldValue.serverTimestamp(),
            expiryDate,
            status: 'active',
            createdAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        if (paymentUpdate) {
            const paymentRef = admin_1.db.collection('payments').doc(paymentUpdate.paymentId);
            transaction.update(paymentRef, {
                status: 'completed',
                paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                idempotencyKey: `${paymentUpdate.paymentId}:${paymentUpdate.transactionId}`,
                processedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
        }
        functions.logger.info('Subscription created in transaction', { subscriptionId: subscriptionRef.id, sessionsCount });
        return { subscriptionId: subscriptionRef.id };
    });
}
//# sourceMappingURL=handlers.js.map