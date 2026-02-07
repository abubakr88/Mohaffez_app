"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.paymobWebhook = void 0;
// functions/src/payments/paymobWebhook.ts
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const paymobVerification_1 = require("../utils/paymobVerification");
const handlers_1 = require("./handlers");
/**
 * Paymob webhook endpoint
 * Called by Paymob after payment success/failure
 */
exports.paymobWebhook = functions.https.onRequest(async (req, res) => {
    try {
        // Only accept POST
        if (req.method !== 'POST') {
            res.status(405).send('Method not allowed');
            return;
        }
        const data = req.body;
        const receivedHmac = data.hmac;
        // 1. Verify HMAC
        const isValid = (0, paymobVerification_1.verifyPaymobHmac)(data.obj, receivedHmac);
        if (!isValid) {
            functions.logger.warn('Invalid HMAC', { data });
            res.status(400).send('Invalid HMAC');
            return;
        }
        const paymentId = data.obj.order.merchant_order_id;
        const transactionId = data.obj.id.toString();
        const success = data.obj.success && !data.obj.error_occured;
        const amountEGP = data.obj.amount_cents / 100;
        functions.logger.info('Paymob callback received', {
            paymentId,
            transactionId,
            success,
            amountEGP,
        });
        // 2. Get payment document
        const paymentRef = admin_1.db.collection('payments').doc(paymentId);
        const paymentSnap = await paymentRef.get();
        if (!paymentSnap.exists) {
            functions.logger.error('Payment not found', { paymentId });
            res.status(404).send('Payment not found');
            return;
        }
        const payment = paymentSnap.data();
        // 3. Validate payment is still pending/processing (idempotency)
        if (payment.status === 'completed') {
            functions.logger.info('Payment already completed', { paymentId });
            res.status(200).send('OK - already processed');
            return;
        }
        // 4. Validate amount
        if (Math.abs(payment.amount - amountEGP) > 0.01) {
            functions.logger.error('Amount mismatch', {
                paymentId,
                expected: payment.amount,
                received: amountEGP,
            });
            await paymentRef.update({
                status: 'failed',
                failureReason: 'Amount mismatch',
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            res.status(400).send('Amount mismatch');
            return;
        }
        if (success) {
            // Payment successful - handle based on metadata
            await handleSuccessfulPayment(paymentId, payment, transactionId);
            res.status(200).send('OK - payment processed');
        }
        else {
            // Payment failed
            await paymentRef.update({
                status: 'failed',
                failureReason: 'Payment declined by gateway',
                gatewayTransactionId: transactionId,
                updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
            });
            functions.logger.info('Payment failed', { paymentId });
            res.status(200).send('OK - payment failed');
        }
    }
    catch (error) {
        functions.logger.error('Webhook error', error);
        res.status(500).send('Internal server error');
    }
});
/**
 * Handle successful payment based on metadata
 */
async function handleSuccessfulPayment(paymentId, payment, transactionId) {
    const batch = admin_1.db.batch();
    const paymentRef = admin_1.db.collection('payments').doc(paymentId);
    // Mark payment as completed
    batch.update(paymentRef, {
        status: 'completed',
        gatewayTransactionId: transactionId,
        paidAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin_1.default.firestore.FieldValue.serverTimestamp(),
    });
    const metadata = payment.metadata || {};
    // Route based on metadata
    if (metadata.confirmBooking && metadata.requestId) {
        // SCENARIO: Confirm existing booking request
        await (0, handlers_1.confirmBookingAfterPayment)(batch, metadata.requestId, metadata.sessionDetails || {}, payment, transactionId);
    }
    else if (metadata.subscriptionId) {
        // SCENARIO: Consume subscription credit and create session
        await (0, handlers_1.consumeSubscriptionAndCreateSession)(batch, metadata.subscriptionId, payment, transactionId);
    }
    else {
        // SCENARIO: Create new subscription from plan
        await (0, handlers_1.createSubscriptionFromPayment)(batch, payment, transactionId);
    }
    await batch.commit();
    functions.logger.info('Payment processed successfully', { paymentId });
}
//# sourceMappingURL=paymobWebhook.js.map