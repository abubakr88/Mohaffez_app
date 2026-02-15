"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.projectPaymentAnalytics = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const events_types_1 = require("../types/events.types");
exports.projectPaymentAnalytics = functions.firestore
    .document('paymentEvents/{eventId}')
    .onCreate(async (snap) => {
    var _a, _b;
    const data = snap.data();
    if (!data.paymentId || !data.eventType) {
        functions.logger.warn('Skipping analytics projection for invalid event', {
            eventId: snap.id,
        });
        return;
    }
    const analyticsRef = admin_1.db.collection('paymentAnalytics').doc(data.paymentId);
    await analyticsRef.set({
        paymentId: data.paymentId,
        lastEventType: data.eventType,
        source: (_b = (_a = data.metadata) === null || _a === void 0 ? void 0 : _a.source) !== null && _b !== void 0 ? _b : 'unknown',
        updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    if (data.eventType === events_types_1.PaymentEventType.PAYMENT_COMPLETED) {
        await analyticsRef.set({
            completedCount: admin_1.default.firestore.FieldValue.increment(1),
        }, { merge: true });
    }
    if (data.eventType === events_types_1.PaymentEventType.PAYMENT_FAILED) {
        await analyticsRef.set({
            failedCount: admin_1.default.firestore.FieldValue.increment(1),
        }, { merge: true });
    }
});
//# sourceMappingURL=projections.js.map