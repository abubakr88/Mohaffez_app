"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onPaymentCreated = void 0;
const functions = require("firebase-functions");
const EventStore_1 = require("../services/EventStore");
const events_types_1 = require("../types/events.types");
const eventStore = new EventStore_1.EventStore();
/**
 * Automatically log payment creation events when a payment document is created.
 * This ensures secure event creation on the server side rather than the client.
 */
exports.onPaymentCreated = functions.firestore
    .document('payments/{paymentId}')
    .onCreate(async (snap, context) => {
    const paymentId = context.params.paymentId;
    const data = snap.data();
    try {
        await eventStore.appendPaymentEvent({
            eventType: events_types_1.PaymentEventType.PAYMENT_CREATED,
            paymentId: paymentId,
            userId: data.studentId,
            data: {
                amount: data.amount,
                planId: data.planId,
                mohaffezId: data.mohaffezId,
                planTitle: data.planTitle,
                mohaffezName: data.mohaffezName,
            },
            metadata: {
                source: 'client',
            },
        });
        functions.logger.info('Payment event logged', { paymentId });
    }
    catch (error) {
        functions.logger.error('Failed to log payment event', {
            paymentId,
            error,
        });
    }
});
//# sourceMappingURL=triggers.js.map