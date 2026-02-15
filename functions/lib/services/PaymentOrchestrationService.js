"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentOrchestrationService = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const payment_types_1 = require("../types/payment.types");
const handlers_1 = require("../payments/handlers");
const events_types_1 = require("../types/events.types");
class PaymentOrchestrationService {
    constructor(eventStore, notificationService) {
        this.eventStore = eventStore;
        this.notificationService = notificationService;
    }
    async processSuccessfulPayment(context) {
        await this.eventStore.appendPaymentEvent({
            eventType: events_types_1.PaymentEventType.WEBHOOK_RECEIVED,
            paymentId: context.paymentId,
            userId: context.payment.studentId,
            data: {
                transactionId: context.transactionId,
            },
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
                data: {
                    error: message,
                },
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
            return {
                success: false,
                error: message,
            };
        }
    }
    async handleBookingConfirmation(context) {
        const requestId = context.metadata.requestId;
        const sessionDetails = context.metadata.sessionDetails;
        if (!requestId || !sessionDetails || typeof sessionDetails !== 'object') {
            throw new Error('Missing booking confirmation metadata');
        }
        const bookingResult = await (0, handlers_1.confirmBookingAfterPayment)(requestId, sessionDetails, context.payment, context.transactionId);
        await this.removeSlotFromAvailability({
            mohaffezId: context.payment.mohaffezId,
            slotDate: sessionDetails.slotDate,
            timeSlot: sessionDetails.preferredTimeSlot,
            sessionType: sessionDetails.sessionType,
        });
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
        return {
            success: true,
            sessionId: bookingResult.sessionId,
        };
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
            data: {
                subscriptionId: subscriptionResult.subscriptionId,
            },
            metadata: {
                source: 'webhook',
                transactionId: context.transactionId,
            },
        });
        return {
            success: true,
            subscriptionId: subscriptionResult.subscriptionId,
        };
    }
    async handleSubscriptionConsumption(context) {
        var _a, _b, _c;
        const subscriptionId = context.metadata.subscriptionId;
        if (!subscriptionId) {
            throw new Error('Missing subscriptionId in payment metadata');
        }
        const consumptionResult = await (0, handlers_1.consumeSubscriptionAndCreateSession)(subscriptionId, context.payment, context.transactionId, context.metadata);
        if (consumptionResult.sessionId) {
            await this.removeSlotFromAvailability({
                mohaffezId: context.payment.mohaffezId,
                slotDate: (_a = context.metadata.sessionDetails) === null || _a === void 0 ? void 0 : _a.slotDate,
                timeSlot: (_b = context.metadata.sessionDetails) === null || _b === void 0 ? void 0 : _b.preferredTimeSlot,
                sessionType: (_c = context.metadata.sessionDetails) === null || _c === void 0 ? void 0 : _c.sessionType,
            });
        }
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
    async removeSlotFromAvailability(params) {
        var _a, _b, _c;
        const { mohaffezId, slotDate, timeSlot, sessionType } = params;
        if (typeof mohaffezId !== 'string' ||
            !slotDate ||
            typeof timeSlot !== 'string' ||
            typeof sessionType !== 'string') {
            functions.logger.warn('Skipping slot removal: invalid booking metadata', params);
            return;
        }
        const slotTimestamp = slotDate;
        const date = slotTimestamp.toDate();
        const jsDay = date.getDay();
        const dayOfWeek = jsDay === 0 ? 7 : jsDay;
        const availabilitySnapshot = await admin_1.db
            .collection('users')
            .doc(mohaffezId)
            .collection('availability')
            .where('dayOfWeek', '==', dayOfWeek)
            .limit(1)
            .get();
        if (availabilitySnapshot.empty) {
            functions.logger.warn('Availability document not found for slot removal', {
                mohaffezId,
                dayOfWeek,
            });
            return;
        }
        const availabilityDoc = availabilitySnapshot.docs[0];
        const data = availabilityDoc.data();
        const timeSlots = [...((_a = data.timeSlots) !== null && _a !== void 0 ? _a : [])];
        let updated = false;
        for (const slot of timeSlots) {
            const slotTime = `${(_b = slot.startTime) !== null && _b !== void 0 ? _b : ''}-${(_c = slot.endTime) !== null && _c !== void 0 ? _c : ''}`;
            if (slotTime === timeSlot &&
                slot.sessionType === sessionType &&
                slot.enabled === true) {
                slot.enabled = false;
                updated = true;
                break;
            }
        }
        if (!updated) {
            functions.logger.info('Slot not changed during post-payment removal', {
                mohaffezId,
                timeSlot,
                sessionType,
            });
            return;
        }
        await availabilityDoc.ref.update({
            timeSlots,
            updatedAt: (0, payment_types_1.serverTimestamp)(),
        });
    }
}
exports.PaymentOrchestrationService = PaymentOrchestrationService;
//# sourceMappingURL=PaymentOrchestrationService.js.map