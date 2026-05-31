// ============================================================
// PAYMOB GATEWAY
// Runtime kill-switch: systemConfig/global.paymobEnabled (Firestore).
// Admin can flip it from the web admin panel without redeploying.
// PAYMOB_HMAC_SECRET must still be set in Firebase environment config
// for HMAC verification to succeed.
// ============================================================
// Required Firestore index: payments collection on (idempotencyKey, status)
import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';
import { verifyPaymobHmac } from '../utils/paymobVerification';
import { PaymentOrchestrationService } from '../services/PaymentOrchestrationService';
import { EventStore } from '../services/EventStore';
import { NotificationService } from '../services/NotificationService';
import {
  PaymentDocument,
  PaymentMetadata,
  serverTimestamp,
} from '../types/payment.types';
import { PaymentEventType } from '../types/events.types';

async function isPaymobEnabled(): Promise<boolean> {
  try {
    const snap = await db.collection('systemConfig').doc('global').get();
    return snap.exists && snap.data()?.paymobEnabled === true;
  } catch (err) {
    functions.logger.error('Failed to read paymobEnabled flag', { err });
    return false;
  }
}

interface PaymobObject {
  id: number;
  pending: boolean;
  amount_cents: number;
  success: boolean;
  order: {
    id: number;
    merchant_order_id: string;
  };
  error_occured: boolean;
}

interface PaymobCallback {
  obj: PaymobObject;
  type: string;
  hmac: string;
}

interface PaymentLockResult {
  state: 'ready' | 'already_processed' | 'amount_mismatch';
  payment: PaymentDocument;
}

const buildPaymobWebhook = () => {
  const eventStore = new EventStore();
  const notificationService = new NotificationService();
  const orchestrationService = new PaymentOrchestrationService(
    eventStore,
    notificationService
  );

  return functions.https.onRequest(async (req, res) => {
    try {
      if (!(await isPaymobEnabled())) {
        res.status(503).send('Paymob gateway is disabled');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).send('Method not allowed');
        return;
      }

      const callback = req.body as PaymobCallback;
      if (!callback?.obj || !callback?.hmac) {
        res.status(400).send('Invalid payload');
        return;
      }

      const isValid = verifyPaymobHmac(callback.obj, callback.hmac);
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

      const lockResult = await lockPaymentForProcessing(
        paymentId,
        transactionId,
        amountEGP
      );

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
        eventType: PaymentEventType.PAYMENT_PROCESSING,
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
        await db.collection('payments').doc(paymentId).update({
          status: 'failed',
          failureReason: 'Payment declined by gateway',
          gatewayTransactionId: transactionId,
          updatedAt: serverTimestamp(),
        });

        await eventStore.appendPaymentEvent({
          eventType: PaymentEventType.PAYMENT_FAILED,
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
        metadata: (lockResult.payment.metadata ?? {}) as PaymentMetadata,
        ipAddress: req.ip,
      });

      if (!result.success) {
        res.status(500).send(result.error ?? 'Payment processing failed');
        return;
      }

      res.status(200).send('OK - payment processed');
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown webhook error';
      functions.logger.error('Webhook error', { error: message });
      res.status(500).send('Internal server error');
    }
  });
};

export const paymobWebhook = buildPaymobWebhook();

async function lockPaymentForProcessing(
  paymentId: string,
  transactionId: string,
  amountEGP: number
): Promise<PaymentLockResult> {
  return db.runTransaction(async (transaction) => {
    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentSnap = await transaction.get(paymentRef);

    if (!paymentSnap.exists) {
      throw new Error('Payment not found');
    }

    const payment = paymentSnap.data() as PaymentDocument;
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
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        state: 'amount_mismatch',
        payment,
      };
    }

    transaction.update(paymentRef, {
      status: 'processing',
      gatewayTransactionId: transactionId,
      processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey: expectedIdempotencyKey,
    });

    return {
      state: 'ready',
      payment,
    };
  });
}
