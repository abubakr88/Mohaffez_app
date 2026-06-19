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
  amount_cents?: number;
  created_at?: string;
  currency?: string;
  error_occured?: boolean;
  has_parent_transaction?: boolean;
  id?: number;
  integration_id?: number;
  is_3d_secure?: boolean;
  is_auth?: boolean;
  is_capture?: boolean;
  is_refunded?: boolean;
  is_standalone_payment?: boolean;
  is_voided?: boolean;
  order?: {
    id?: number;
    merchant_order_id?: string;
  };
  owner?: number;
  pending?: boolean;
  source_data?: {
    pan?: string;
    sub_type?: string;
    type?: string;
  };
  special_reference?: string;
  success?: boolean;
}

interface PaymobCallback {
  obj: PaymobObject;
  type: string;
  hmac: string;
}

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function firstValue(value: unknown): unknown {
  return Array.isArray(value) ? value[0] : value;
}

function parseRecord(value: unknown): UnknownRecord | null {
  const first = firstValue(value);
  if (isRecord(first)) return first;
  if (typeof first !== 'string') return null;

  try {
    const parsed = JSON.parse(first);
    return isRecord(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function read(source: UnknownRecord, ...keys: string[]): unknown {
  for (const key of keys) {
    const value = firstValue(source[key]);
    if (value !== undefined && value !== null && value !== '') return value;
  }
  return undefined;
}

function asString(value: unknown): string | undefined {
  const first = firstValue(value);
  if (first === undefined || first === null) return undefined;
  const text = first.toString().trim();
  return text.length > 0 ? text : undefined;
}

function asNumber(value: unknown): number | undefined {
  const text = asString(value);
  if (text === undefined) return undefined;
  const numberValue = Number(text);
  return Number.isFinite(numberValue) ? numberValue : undefined;
}

function asBoolean(value: unknown): boolean | undefined {
  const first = firstValue(value);
  if (typeof first === 'boolean') return first;
  if (typeof first === 'number') return first === 1;
  if (typeof first !== 'string') return undefined;

  const normalized = first.trim().toLowerCase();
  if (normalized === 'true' || normalized === '1') return true;
  if (normalized === 'false' || normalized === '0') return false;
  return undefined;
}

function normalizeSourceData(source: UnknownRecord): PaymobObject['source_data'] {
  const nested = parseRecord(read(source, 'source_data')) ?? {};
  const pan = asString(read(nested, 'pan')) ?? asString(read(source, 'source_data.pan', 'source_data_pan'));
  const subType =
    asString(read(nested, 'sub_type')) ??
    asString(read(source, 'source_data.sub_type', 'source_data_sub_type'));
  const type = asString(read(nested, 'type')) ?? asString(read(source, 'source_data.type', 'source_data_type'));

  if (!pan && !subType && !type) return undefined;
  return {
    pan,
    sub_type: subType,
    type,
  };
}

function normalizeOrder(source: UnknownRecord): PaymobObject['order'] {
  const rawOrder = read(source, 'order');
  const orderRecord = parseRecord(rawOrder);
  const orderId =
    asNumber(read(orderRecord ?? {}, 'id')) ??
    asNumber(rawOrder) ??
    asNumber(read(source, 'order_id'));
  const merchantOrderId =
    asString(read(orderRecord ?? {}, 'merchant_order_id')) ??
    asString(read(source, 'merchant_order_id', 'special_reference'));

  if (orderId === undefined && !merchantOrderId) return undefined;
  return {
    id: orderId,
    merchant_order_id: merchantOrderId,
  };
}

function normalizePaymobObject(source: UnknownRecord): PaymobObject {
  return {
    amount_cents: asNumber(read(source, 'amount_cents')),
    created_at: asString(read(source, 'created_at')),
    currency: asString(read(source, 'currency')),
    error_occured: asBoolean(read(source, 'error_occured', 'error_occurred')),
    has_parent_transaction: asBoolean(read(source, 'has_parent_transaction')),
    id: asNumber(read(source, 'id')),
    integration_id: asNumber(read(source, 'integration_id')),
    is_3d_secure: asBoolean(read(source, 'is_3d_secure')),
    is_auth: asBoolean(read(source, 'is_auth')),
    is_capture: asBoolean(read(source, 'is_capture')),
    is_refunded: asBoolean(read(source, 'is_refunded')),
    is_standalone_payment: asBoolean(read(source, 'is_standalone_payment')),
    is_voided: asBoolean(read(source, 'is_voided')),
    order: normalizeOrder(source),
    owner: asNumber(read(source, 'owner')),
    pending: asBoolean(read(source, 'pending')),
    source_data: normalizeSourceData(source),
    special_reference: asString(read(source, 'special_reference', 'merchant_order_id')),
    success: asBoolean(read(source, 'success')),
  };
}

function normalizePaymobCallback(req: functions.https.Request): PaymobCallback | null {
  const body = isRecord(req.body) ? req.body : {};
  const query = isRecord(req.query) ? (req.query as UnknownRecord) : {};
  const merged: UnknownRecord = { ...query, ...body };
  const hmac = asString(read(merged, 'hmac'));
  const type = asString(read(merged, 'type')) ?? 'transaction';

  if (!hmac) return null;

  const wrappedObj = parseRecord(read(merged, 'obj'));
  if (wrappedObj) {
    return {
      obj: normalizePaymobObject(wrappedObj),
      type,
      hmac,
    };
  }

  return {
    obj: normalizePaymobObject(merged),
    type,
    hmac,
  };
}

function hasCallbackBasics(callback: PaymobCallback): boolean {
  return (
    callback.obj.id !== undefined &&
    callback.obj.amount_cents !== undefined &&
    callback.obj.success !== undefined
  );
}

function safeKeys(source: unknown): string[] {
  return isRecord(source) ? Object.keys(source).slice(0, 20).sort() : [];
}

async function resolvePaymentId(obj: PaymobObject): Promise<string> {
  const directPaymentId = obj.special_reference ?? obj.order?.merchant_order_id;
  if (directPaymentId) return directPaymentId;

  const orderId = obj.order?.id?.toString();
  if (orderId) {
    const byGatewayOrder = await db
      .collection('payments')
      .where('gatewayOrderId', '==', orderId)
      .limit(1)
      .get();

    if (!byGatewayOrder.empty) {
      return byGatewayOrder.docs[0].id;
    }

    const byGatewayResponse = await db
      .collection('payments')
      .where('gatewayResponse.orderId', '==', orderId)
      .limit(1)
      .get();

    if (!byGatewayResponse.empty) {
      return byGatewayResponse.docs[0].id;
    }
  }

  throw new Error('Payment reference not found in Paymob callback');
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
  const paymobRuntime = functions.runWith({
    secrets: ['PAYMOB_HMAC_SECRET'],
  });

  return paymobRuntime.https.onRequest(async (req, res) => {
    try {
      if (!(await isPaymobEnabled())) {
        res.status(503).send('Paymob gateway is disabled');
        return;
      }

      if (req.method !== 'POST' && req.method !== 'GET') {
        res.status(405).send('Method not allowed');
        return;
      }

      const callback = normalizePaymobCallback(req);
      if (!callback || !hasCallbackBasics(callback)) {
        functions.logger.warn('Invalid Paymob callback payload', {
          method: req.method,
          contentType: req.headers['content-type'],
          bodyKeys: safeKeys(req.body),
          queryKeys: safeKeys(req.query),
        });
        res.status(400).send('Invalid payload');
        return;
      }

      const isValid = verifyPaymobHmac(callback.obj, callback.hmac);
      if (!isValid) {
        functions.logger.warn('Invalid HMAC in webhook', {
          transactionId: callback.obj.id?.toString(),
          orderId: callback.obj.order?.id?.toString(),
        });
        res.status(400).send('Invalid HMAC');
        return;
      }

      const paymentId = await resolvePaymentId(callback.obj);
      const transactionId = callback.obj.id!.toString();
      const amountEGP = callback.obj.amount_cents! / 100;
      const success = callback.obj.success === true && callback.obj.error_occured !== true;

      functions.logger.info('Paymob callback received', {
        paymentId,
        transactionId,
        amountEGP,
        success,
        orderId: callback.obj.order?.id?.toString(),
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
