"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EventStore = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const events_types_1 = require("../types/events.types");
class EventStore {
    async appendPaymentEvent(event) {
        const eventRef = admin_1.db.collection('paymentEvents').doc();
        await eventRef.set(Object.assign(Object.assign({}, event), { eventId: eventRef.id, timestamp: admin_1.default.firestore.FieldValue.serverTimestamp() }));
        functions.logger.info('Payment event appended', {
            eventId: eventRef.id,
            paymentId: event.paymentId,
            eventType: event.eventType,
        });
        return eventRef.id;
    }
    async getPaymentEvents(paymentId) {
        const snapshot = await admin_1.db
            .collection('paymentEvents')
            .where('paymentId', '==', paymentId)
            .orderBy('timestamp', 'asc')
            .get();
        return snapshot.docs.map((doc) => doc.data());
    }
    async rebuildPaymentState(paymentId) {
        const events = await this.getPaymentEvents(paymentId);
        let status = 'pending';
        let lastEventType;
        let updatedAt;
        for (const event of events) {
            lastEventType = event.eventType;
            updatedAt = event.timestamp;
            if (event.eventType === events_types_1.PaymentEventType.PAYMENT_PROCESSING) {
                status = 'processing';
            }
            if (event.eventType === events_types_1.PaymentEventType.PAYMENT_COMPLETED) {
                status = 'completed';
            }
            if (event.eventType === events_types_1.PaymentEventType.PAYMENT_FAILED) {
                status = 'failed';
            }
        }
        return {
            paymentId,
            status,
            lastEventType,
            updatedAt,
            eventCount: events.length,
        };
    }
    async appendFreeSessionCompletedEvent(params) {
        var _a;
        return this.appendPaymentEvent({
            eventType: events_types_1.PaymentEventType.PAYMENT_COMPLETED,
            paymentId: params.paymentId,
            userId: params.userId,
            data: {
                amount: 0,
                method: 'free',
                promoCode: (_a = params.promoCode) !== null && _a !== void 0 ? _a : null,
            },
            metadata: {
                source: 'client',
            },
        });
    }
}
exports.EventStore = EventStore;
//# sourceMappingURL=EventStore.js.map