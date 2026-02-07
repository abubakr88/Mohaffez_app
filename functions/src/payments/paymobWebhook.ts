// functions/src/payments/paymobWebhook.ts
import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';
import { verifyPaymobHmac } from '../utils/paymobVerification';
import {
  confirmBookingAfterPayment,
  consumeSubscriptionAndCreateSession,
  createSubscriptionFromPayment,
} from './handlers';

interface PaymobCallback {
  obj: {
    id: number;
    pending: boolean;
    amount_cents: number;
    success: boolean;
    is_auth: boolean;
    is_capture: boolean;
    is_standalone_payment: boolean;
    is_voided: boolean;
    is_refunded: boolean;
    is_3d_secure: boolean;
    integration_id: number;
    profile_id: number;
    has_parent_transaction: boolean;
    order: {
      id: number;
      merchant_order_id: string; // Our paymentId
    };
    created_at: string;
    currency: string;
    source_data: {
      type: string;
      sub_type: string;
      pan: string;
    };
    owner: number;
    error_occured: boolean;
  };
  type: string;
  hmac: string;
}

/**
 * Paymob webhook endpoint
 * Called by Paymob after payment success/failure
 */
export const paymobWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Only accept POST
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    const data: PaymobCallback = req.body;
    const receivedHmac = data.hmac;

    // 1. Verify HMAC
    const isValid = verifyPaymobHmac(data.obj, receivedHmac);
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
    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentSnap = await paymentRef.get();

    if (!paymentSnap.exists) {
      functions.logger.error('Payment not found', { paymentId });
      res.status(404).send('Payment not found');
      return;
    }

    const payment = paymentSnap.data()!;

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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(400).send('Amount mismatch');
      return;
    }

    if (success) {
      // Payment successful - handle based on metadata
      await handleSuccessfulPayment(paymentId, payment, transactionId);
      res.status(200).send('OK - payment processed');
    } else {
      // Payment failed
      await paymentRef.update({
        status: 'failed',
        failureReason: 'Payment declined by gateway',
        gatewayTransactionId: transactionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      functions.logger.info('Payment failed', { paymentId });
      res.status(200).send('OK - payment failed');
    }
  } catch (error) {
    functions.logger.error('Webhook error', error);
    res.status(500).send('Internal server error');
  }
});

/**
 * Handle successful payment based on metadata
 */
async function handleSuccessfulPayment(
  paymentId: string,
  payment: any,
  transactionId: string
): Promise<void> {
  const batch = db.batch();
  const paymentRef = db.collection('payments').doc(paymentId);

  // Mark payment as completed
  batch.update(paymentRef, {
    status: 'completed',
    gatewayTransactionId: transactionId,
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const metadata = payment.metadata || {};

  // Route based on metadata
  if (metadata.confirmBooking && metadata.requestId) {
    // SCENARIO: Confirm existing booking request
    await confirmBookingAfterPayment(
      batch,
      metadata.requestId,
      metadata.sessionDetails || {},
      payment,
      transactionId
    );
  } else if (metadata.subscriptionId) {
    // SCENARIO: Consume subscription credit and create session
    await consumeSubscriptionAndCreateSession(
      batch,
      metadata.subscriptionId,
      payment,
      transactionId
    );
  } else {
    // SCENARIO: Create new subscription from plan
    await createSubscriptionFromPayment(batch, payment, transactionId);
  }

  await batch.commit();
  functions.logger.info('Payment processed successfully', { paymentId });
}
