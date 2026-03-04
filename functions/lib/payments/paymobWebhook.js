"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.paymobWebhook = void 0;
// ============================================================
// PAYMOB GATEWAY — DISABLED
// To re-enable:
//   1. Set PAYMOB_ENABLED = true in this file
//   2. Uncomment the export in src/index.ts
//   3. Set PAYMOB_HMAC_SECRET in Firebase environment config
// ============================================================
// Required Firestore index: payments collection on (idempotencyKey, status)
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const paymobVerification_1 = require("../utils/paymobVerification");
const PaymentOrchestrationService_1 = require("../services/PaymentOrchestrationService");
const EventStore_1 = require("../services/EventStore");
const NotificationService_1 = require("../services/NotificationService");
const payment_types_1 = require("../types/payment.types");
const events_types_1 = require("../types/events.types");
const PAYMOB_ENABLED = false;
const createEnabledPaymobWebhook = () => {
    const eventStore = new EventStore_1.EventStore();
    const notificationService = new NotificationService_1.NotificationService();
    const orchestrationService = new PaymentOrchestrationService_1.PaymentOrchestrationService(eventStore, notificationService);
    return functions.https.onRequest(async (req, res) => {
        var _a, _b;
        try {
            if (req.method !== 'POST') {
                res.status(405).send('Method not allowed');
                return;
            }
            const callback = req.body;
            if (!(callback === null || callback === void 0 ? void 0 : callback.obj) || !(callback === null || callback === void 0 ? void 0 : callback.hmac)) {
                res.status(400).send('Invalid payload');
                return;
            }
            const isValid = (0, paymobVerification_1.verifyPaymobHmac)(callback.obj, callback.hmac);
            if (!isValid) {
                functions.logger.warn('Invalid HMAC in webhook');
                res.status(400).send('Invalid HMAC');
                return;
            }
            const paymentId = callback.obj.order.merchant_order_id;
            const transactionId = callback.obj.id.toString();
            const amountEGP = callback.obj.amount_cents / 100;
            const success = callback.obj.success && !callback.obj.error_occured;
            functions.logger.info('Paymob callback received', {
                paymentId,
                transactionId,
                amountEGP,
                success,
                eventType: callback.type,
            });
            const lockResult = await lockPaymentForProcessing(paymentId, transactionId, amountEGP);
            if (lockResult.state === 'already_processed') {
                functions.logger.info('Payment already processed', {
                    paymentId,
                    transactionId,
                });
                res.status(200).send('OK - already processed');
                return;
            }
            if (lockResult.state === 'amount_mismatch') {
                functions.logger.error('Amount mismatch', {
                    paymentId,
                    expectedAmount: lockResult.payment.amount,
                    receivedAmount: amountEGP,
                });
                res.status(400).send('Amount mismatch');
                return;
            }
            await eventStore.appendPaymentEvent({
                eventType: events_types_1.PaymentEventType.PAYMENT_PROCESSING,
                paymentId,
                userId: lockResult.payment.studentId,
                data: {
                    transactionId,
                },
                metadata: {
                    source: 'webhook',
                    transactionId,
                    ipAddress: req.ip,
                },
            });
            if (!success) {
                await admin_1.db.collection('payments').doc(paymentId).update({
                    status: 'failed',
                    failureReason: 'Payment declined by gateway',
                    gatewayTransactionId: transactionId,
                    updatedAt: (0, payment_types_1.serverTimestamp)(),
                });
                await eventStore.appendPaymentEvent({
                    eventType: events_types_1.PaymentEventType.PAYMENT_FAILED,
                    paymentId,
                    userId: lockResult.payment.studentId,
                    data: {
                        reason: 'Payment declined by gateway',
                    },
                    metadata: {
                        source: 'webhook',
                        transactionId,
                        ipAddress: req.ip,
                    },
                });
                res.status(200).send('OK - payment failed');
                return;
            }
            const result = await orchestrationService.processSuccessfulPayment({
                paymentId,
                payment: lockResult.payment,
                transactionId,
                metadata: ((_a = lockResult.payment.metadata) !== null && _a !== void 0 ? _a : {}),
                ipAddress: req.ip,
            });
            if (!result.success) {
                res.status(500).send((_b = result.error) !== null && _b !== void 0 ? _b : 'Payment processing failed');
                return;
            }
            res.status(200).send('OK - payment processed');
        }
        catch (error) {
            const message = error instanceof Error ? error.message : 'Unknown webhook error';
            functions.logger.error('Webhook error', { error: message });
            res.status(500).send('Internal server error');
        }
    });
};
const createDisabledPaymobWebhook = () => functions.https.onRequest((_req, res) => {
    res.status(503).send('Paymob gateway is disabled');
});
exports.paymobWebhook = PAYMOB_ENABLED
    ? createEnabledPaymobWebhook()
    : createDisabledPaymobWebhook();
async function lockPaymentForProcessing(paymentId, transactionId, amountEGP) {
    return admin_1.db.runTransaction(async (transaction) => {
        const paymentRef = admin_1.db.collection('payments').doc(paymentId);
        const paymentSnap = await transaction.get(paymentRef);
        if (!paymentSnap.exists) {
            throw new Error('Payment not found');
        }
        const payment = paymentSnap.data();
        const expectedIdempotencyKey = `${paymentId}_${transactionId}`;
        if (payment.idempotencyKey === expectedIdempotencyKey) {
            return {
                state: 'already_processed',
                payment,
            };
        }
        if (payment.status === 'completed' || payment.status === 'processing') {
            return {
                state: 'already_processed',
                payment,
            };
        }
        if (payment.status !== 'pending') {
            return {
                state: 'already_processed',
                payment,
            };
        }
        if (Math.abs(payment.amount - amountEGP) > 0.01) {
            transaction.update(paymentRef, {
                status: 'failed',
                failureReason: 'Amount mismatch',
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            return {
                state: 'amount_mismatch',
                payment,
            };
        }
        transaction.update(paymentRef, {
            status: 'processing',
            gatewayTransactionId: transactionId,
            processingStartedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            idempotencyKey: expectedIdempotencyKey,
        });
        return {
            state: 'ready',
            payment,
        };
    });
}
//# sourceMappingURL=paymobWebhook.js.map