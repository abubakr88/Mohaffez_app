"use strict";
// src/services/PaymentOrchestrationService.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentOrchestrationService = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const payment_types_1 = require("../types/payment.types");
const handlers_1 = require("../payments/handlers");
const events_types_1 = require("../types/events.types");
// ─────────────────────────────────────────────────────────────────────────────
class PaymentOrchestrationService {
    constructor(eventStore, notificationService) {
        this.eventStore = eventStore;
        this.notificationService = notificationService;
    }
    // ─── Public entry point ───────────────────────────────────────────────────
    async processSuccessfulPayment(context) {
        await this.eventStore.appendPaymentEvent({
            eventType: events_types_1.PaymentEventType.WEBHOOK_RECEIVED,
            paymentId: context.paymentId,
            userId: context.payment.studentId,
            data: { transactionId: context.transactionId },
            metadata: {
                source: 'webhook',
                transactionId: context.transactionId,
                ipAddress: context.ipAddress,
            },
        });
        let result;
        try {
            if (context.metadata.confirmBooking && context.metadata.requestId) {
                result = await this.handleBookingConfirmation(context);
            }
            else if (context.metadata.subscriptionId) {
                result = await this.handleSubscriptionConsumption(context);
            }
            else {
                result = await this.handleSubscriptionCreation(context);
            }
            await admin_1.db.collection('payments').doc(context.paymentId).update({
                status: 'completed',
                paidAt: (0, payment_types_1.serverTimestamp)(),
                updatedAt: (0, payment_types_1.serverTimestamp)(),
                idempotencyKey: `${context.paymentId}_${context.transactionId}`,
                processedAt: (0, payment_types_1.serverTimestamp)(),
            });
            await this.eventStore.appendPaymentEvent({
                eventType: events_types_1.PaymentEventType.PAYMENT_COMPLETED,
                paymentId: context.paymentId,
                userId: context.payment.studentId,
                data: {
                    sessionId: result.sessionId,
                    subscriptionId: result.subscriptionId,
                },
                metadata: {
                    source: 'webhook',
                    transactionId: context.transactionId,
                    ipAddress: context.ipAddress,
                },
            });
            functions.logger.info('Payment orchestration completed', {
                paymentId: context.paymentId,
                sessionId: result.sessionId,
                subscriptionId: result.subscriptionId,
            });
            return result;
        }
        catch (error) {
            const message = error instanceof Error ? error.message : 'Unknown payment processing error';
            await admin_1.db.collection('payments').doc(context.paymentId).update({
                status: 'failed',
                failureReason: message,
                updatedAt: (0, payment_types_1.serverTimestamp)(),
            });
            await this.eventStore.appendPaymentEvent({
                eventType: events_types_1.PaymentEventType.PAYMENT_FAILED,
                paymentId: context.paymentId,
                userId: context.payment.studentId,
                data: { error: message },
                metadata: {
                    source: 'webhook',
                    transactionId: context.transactionId,
                    ipAddress: context.ipAddress,
                },
            });
            functions.logger.error('Payment orchestration failed', {
                paymentId: context.paymentId,
                transactionId: context.transactionId,
                error: message,
            });
            return { success: false, error: message };
        }
    }
    // ─── Private handlers ─────────────────────────────────────────────────────
    async handleBookingConfirmation(context) {
        const requestId = context.metadata.requestId;
        const sessionDetails = context.metadata.sessionDetails;
        if (!requestId || !sessionDetails || typeof sessionDetails !== 'object') {
            throw new Error('Missing booking confirmation metadata');
        }
        // Build SlotInfo so the slot is disabled INSIDE the same Firestore transaction
        // as the booking write — eliminates the double-booking race window entirely.
        const slotInfo = this.buildSlotInfo(context.payment.mohaffezId, sessionDetails['slotDate'], sessionDetails['preferredTimeSlot'], sessionDetails['sessionType']);
        // ✅ FIX: slotInfo is passed in; slot removal is now atomic with the booking.
        const bookingResult = await (0, handlers_1.confirmBookingAfterPayment)(requestId, sessionDetails, context.payment, context.transactionId, slotInfo);
        await this.notificationService.send({
            recipientId: context.payment.studentId,
            senderId: context.payment.mohaffezId,
            type: 'session_confirmed',
            title: 'Session Confirmed',
            message: `Your booking with ${context.payment.mohaffezName} is confirmed after payment.`,
            data: {
                sessionId: bookingResult.sessionId,
                requestId,
                mohaffezId: context.payment.mohaffezId,
            },
        });
        await this.eventStore.appendPaymentEvent({
            eventType: events_types_1.PaymentEventType.BOOKING_CONFIRMED,
            paymentId: context.paymentId,
            userId: context.payment.studentId,
            data: {
                requestId,
                sessionId: bookingResult.sessionId,
            },
            metadata: {
                source: 'webhook',
                transactionId: context.transactionId,
            },
        });
        return { success: true, sessionId: bookingResult.sessionId };
    }
    async handleSubscriptionCreation(context) {
        const subscriptionResult = await (0, handlers_1.createSubscriptionFromPayment)(context.payment, context.transactionId);
        await admin_1.db.collection('payments').doc(context.paymentId).update({
            subscriptionId: subscriptionResult.subscriptionId,
            updatedAt: (0, payment_types_1.serverTimestamp)(),
        });
        await this.notificationService.send({
            recipientId: context.payment.studentId,
            senderId: context.payment.mohaffezId,
            type: 'subscription_created',
            title: 'Subscription Activated',
            message: 'Your subscription purchase was completed successfully.',
            data: {
                subscriptionId: subscriptionResult.subscriptionId,
                mohaffezId: context.payment.mohaffezId,
            },
        });
        await this.eventStore.appendPaymentEvent({
            eventType: events_types_1.PaymentEventType.SUBSCRIPTION_CREATED,
            paymentId: context.paymentId,
            userId: context.payment.studentId,
            data: { subscriptionId: subscriptionResult.subscriptionId },
            metadata: {
                source: 'webhook',
                transactionId: context.transactionId,
            },
        });
        return { success: true, subscriptionId: subscriptionResult.subscriptionId };
    }
    async handleSubscriptionConsumption(context) {
        const subscriptionId = context.metadata.subscriptionId;
        if (!subscriptionId) {
            throw new Error('Missing subscriptionId in payment metadata');
        }
        const sd = context.metadata.sessionDetails;
        // Build SlotInfo so the slot is disabled INSIDE the same Firestore transaction
        // as the subscription decrement — no separate call needed after.
        const slotInfo = this.buildSlotInfo(context.payment.mohaffezId, sd === null || sd === void 0 ? void 0 : sd['slotDate'], sd === null || sd === void 0 ? void 0 : sd['preferredTimeSlot'], sd === null || sd === void 0 ? void 0 : sd['sessionType']);
        // ✅ FIX: slotInfo passed in; slot removal is now atomic with session creation.
        const consumptionResult = await (0, handlers_1.consumeSubscriptionAndCreateSession)(subscriptionId, context.payment, context.transactionId, context.metadata, slotInfo);
        await this.notificationService.send({
            recipientId: context.payment.studentId,
            senderId: context.payment.mohaffezId,
            type: 'subscription_session_consumed',
            title: 'Session Booked',
            message: 'A session was booked using your active subscription.',
            data: {
                subscriptionId,
                sessionId: consumptionResult.sessionId,
                remainingSessions: consumptionResult.remainingSessions,
            },
        });
        return {
            success: true,
            sessionId: consumptionResult.sessionId,
            subscriptionId,
        };
    }
    // ─── Private helpers ──────────────────────────────────────────────────────
    /**
     * Constructs a SlotInfo object only when all four fields are valid.
     * Returns undefined (skips atomic slot removal) if any field is missing/invalid.
     */
    buildSlotInfo(mohaffezId, slotDate, timeSlot, sessionType) {
        if (typeof mohaffezId !== 'string' || !mohaffezId ||
            typeof timeSlot !== 'string' || !timeSlot ||
            typeof sessionType !== 'string' || !sessionType ||
            !slotDate) {
            functions.logger.warn('buildSlotInfo: incomplete slot data — slot will NOT be disabled atomically', { mohaffezId, timeSlot, sessionType, hasSlotDate: !!slotDate });
            return undefined;
        }
        return {
            mohaffezId,
            slotDate,
            timeSlot,
            sessionType,
        };
    }
}
exports.PaymentOrchestrationService = PaymentOrchestrationService;
//# sourceMappingURL=PaymentOrchestrationService.js.map