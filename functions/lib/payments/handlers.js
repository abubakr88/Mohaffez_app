"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.confirmBookingAfterPayment = confirmBookingAfterPayment;
exports.consumeSubscriptionAndCreateSession = consumeSubscriptionAndCreateSession;
exports.createSubscriptionFromPayment = createSubscriptionFromPayment;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const parseNumber = (value, fallback) => {
    if (typeof value === 'number') {
        return value;
    }
    return fallback;
};
const parseString = (value, fallback) => {
    if (typeof value === 'string' && value.trim().length > 0) {
        return value;
    }
    return fallback;
};
async function confirmBookingAfterPayment(requestId, sessionDetails, payment, transactionId) {
    return admin_1.db.runTransaction(async (transaction) => {
        const requestRef = admin_1.db.collection('sessionRequests').doc(requestId);
        const requestSnap = await transaction.get(requestRef);
        if (!requestSnap.exists) {
            throw new Error('Session request not found');
        }
        const sessionRef = admin_1.db.collection('hafizSessions').doc();
        transaction.update(requestRef, {
            status: 'accepted',
            isPaid: true,
            paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            paymentTransactionId: transactionId,
            updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(sessionRef, Object.assign(Object.assign({}, sessionDetails), { requestId, status: 'accepted', isPaid: true, paymentTransactionId: transactionId, createdAt: admin_1.default.firestore.FieldValue.serverTimestamp(), acceptedAt: admin_1.default.firestore.FieldValue.serverTimestamp(), studentId: payment.studentId, mohaffezId: payment.mohaffezId }));
        functions.logger.info('Booking confirmed in transaction', {
            requestId,
            sessionId: sessionRef.id,
        });
        return { sessionId: sessionRef.id };
    });
}
async function consumeSubscriptionAndCreateSession(subscriptionId, payment, transactionId, metadata) {
    return admin_1.db.runTransaction(async (transaction) => {
        const subRef = admin_1.db.collection('subscriptions').doc(subscriptionId);
        const subSnap = await transaction.get(subRef);
        if (!subSnap.exists) {
            throw new Error('Subscription not found');
        }
        const subscription = subSnap.data();
        const remainingSessions = parseNumber(subscription.remainingSessions, 0);
        if (remainingSessions <= 0) {
            throw new Error('No sessions remaining');
        }
        const newRemaining = remainingSessions - 1;
        const status = newRemaining === 0
            ? 'depleted'
            : parseString(subscription.status, 'active');
        transaction.update(subRef, {
            remainingSessions: newRemaining,
            status,
            lastUsedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
        });
        let sessionId;
        if (metadata.requestId && metadata.sessionDetails) {
            const requestRef = admin_1.db.collection('sessionRequests').doc(metadata.requestId);
            const requestSnap = await transaction.get(requestRef);
            if (!requestSnap.exists) {
                throw new Error('Session request not found for subscription consumption');
            }
            const sessionRef = admin_1.db.collection('hafizSessions').doc();
            sessionId = sessionRef.id;
            transaction.update(requestRef, {
                status: 'accepted',
                isPaid: true,
                paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
                paymentTransactionId: transactionId,
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            transaction.set(sessionRef, Object.assign(Object.assign({}, metadata.sessionDetails), { requestId: metadata.requestId, status: 'accepted', isPaid: true, paymentTransactionId: transactionId, createdAt: admin_1.default.firestore.FieldValue.serverTimestamp(), acceptedAt: admin_1.default.firestore.FieldValue.serverTimestamp(), studentId: payment.studentId, mohaffezId: payment.mohaffezId }));
        }
        functions.logger.info('Subscription session consumed in transaction', {
            subscriptionId,
            remainingSessions: newRemaining,
            sessionId,
        });
        return { remainingSessions: newRemaining, sessionId };
    });
}
async function createSubscriptionFromPayment(payment, transactionId) {
    var _a;
    const metadata = (_a = payment.metadata) !== null && _a !== void 0 ? _a : {};
    const planTitle = parseString(metadata.planTitle, 'Payment Plan');
    const planType = parseString(metadata.planType, 'single');
    const sessionsCount = parseNumber(metadata.sessionsCount, 1);
    const validityDays = typeof metadata.validityDays === 'number'
        ? metadata.validityDays
        : undefined;
    return admin_1.db.runTransaction(async (transaction) => {
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
            planId: parseString(metadata.planId, ''),
            planTitle,
            planType,
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
        functions.logger.info('Subscription created in transaction', {
            subscriptionId: subscriptionRef.id,
            sessionsCount,
        });
        return { subscriptionId: subscriptionRef.id };
    });
}
//# sourceMappingURL=handlers.js.map