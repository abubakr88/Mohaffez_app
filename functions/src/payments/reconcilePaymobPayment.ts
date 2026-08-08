import * as functions from 'firebase-functions';
import * as https from 'https';
import { URL } from 'url';
import admin, { db } from '../utils/admin';
import { EventStore } from '../services/EventStore';
import { NotificationService } from '../services/NotificationService';
import { PaymentOrchestrationService } from '../services/PaymentOrchestrationService';
import { PaymentDocument, PaymentMetadata } from '../types/payment.types';
import {
  buildRecentPendingPaymentsQuery,
  PAYMOB_RECONCILIATION_SCHEDULE,
  paymobReconciliationCutoffMillis,
} from './reconciliationPolicy';

interface ReconcilePaymentData {
  paymentId?: unknown;
}

interface PaymobTransaction {
  id?: number;
  amount_cents?: number;
  currency?: string;
  integration_id?: number;
  pending?: boolean;
  success?: boolean;
  error_occured?: boolean;
  is_refunded?: boolean;
  is_voided?: boolean;
  order?: {
    merchant_order_id?: string;
  };
}

interface PaymobTransactionList {
  results?: PaymobTransaction[];
}

interface ReconcileResult {
  status: string;
  sessionId?: string | null;
  subscriptionId?: string | null;
}

interface PaymobContext {
  token: string;
  integrationId: number;
}

const paymobRuntime = functions.runWith({
  secrets: ['PAYMOB_API_KEY', 'PAYMOB_CARD_INTEGRATION_ID'],
});

function requiredEnv(name: string): string {
  const value = (process.env[name] ?? '').trim();
  if (!value) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `${name} is not configured`,
    );
  }
  return value;
}

function requestJson<T>(
  url: string,
  options: https.RequestOptions,
  body?: unknown,
): Promise<T> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const payload = body === undefined ? undefined : JSON.stringify(body);
    const request = https.request(
      {
        ...options,
        hostname: parsed.hostname,
        path: `${parsed.pathname}${parsed.search}`,
        headers: {
          ...options.headers,
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
        },
      },
      (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk: Buffer) => chunks.push(chunk));
        response.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          if (
            !response.statusCode ||
            response.statusCode < 200 ||
            response.statusCode >= 300
          ) {
            reject(
              new Error(
                `Paymob request failed (${response.statusCode ?? 'no-status'})`,
              ),
            );
            return;
          }

          try {
            resolve((text ? JSON.parse(text) : {}) as T);
          } catch {
            reject(new Error('Paymob returned an invalid response'));
          }
        });
      },
    );

    request.on('error', reject);
    if (payload) request.write(payload);
    request.end();
  });
}

async function createPaymobContext(): Promise<PaymobContext> {
  const apiKey = requiredEnv('PAYMOB_API_KEY');
  const integrationId = Number.parseInt(
    requiredEnv('PAYMOB_CARD_INTEGRATION_ID'),
    10,
  );
  if (!Number.isFinite(integrationId)) {
    throw new Error('PAYMOB_CARD_INTEGRATION_ID is invalid');
  }

  const auth = await requestJson<{ token?: string }>(
    'https://accept.paymob.com/api/auth/tokens',
    { method: 'POST' },
    { api_key: apiKey },
  );
  if (!auth.token) throw new Error('Paymob authentication failed');

  return { token: auth.token, integrationId };
}

async function getSuccessfulTransaction(
  paymentId: string,
  paymobContext: PaymobContext,
): Promise<PaymobTransaction | null> {
  const query = new URL(
    'https://accept.paymob.com/api/acceptance/transactions',
  );
  query.searchParams.set('merchant_order_id', paymentId);
  const response = await requestJson<PaymobTransactionList>(
    query.toString(),
    {
      method: 'GET',
      headers: { Authorization: `Bearer ${paymobContext.token}` },
    },
  );

  return (
    response.results?.find(
      (transaction) =>
        transaction.order?.merchant_order_id === paymentId &&
        transaction.integration_id === paymobContext.integrationId &&
        transaction.success === true &&
        transaction.pending !== true &&
        transaction.error_occured !== true &&
        transaction.is_refunded !== true &&
        transaction.is_voided !== true,
    ) ?? null
  );
}

async function reconcilePaymentDocument(
  paymentId: string,
  payment: PaymentDocument,
  ipAddress?: string,
  existingPaymobContext?: PaymobContext,
): Promise<ReconcileResult> {
  if (payment.status === 'completed') {
    return { status: 'completed' };
  }
  if (payment.status !== 'pending') {
    return { status: payment.status };
  }

  const paymentRef = db.collection('payments').doc(paymentId);
  const paymobContext =
    existingPaymobContext ?? (await createPaymobContext());
  const transaction = await getSuccessfulTransaction(paymentId, paymobContext);
  if (!transaction?.id || !transaction.amount_cents) {
    return { status: 'pending' };
  }

  const amountEGP = transaction.amount_cents / 100;
  if (
    transaction.currency !== 'EGP' ||
    Math.abs(payment.amount - amountEGP) > 0.01
  ) {
    functions.logger.error('Paymob reconciliation amount mismatch', {
      paymentId,
      expectedAmount: payment.amount,
      receivedAmount: amountEGP,
    });
    throw new Error('Payment amount mismatch');
  }

  const transactionId = transaction.id.toString();
  const locked = await db.runTransaction(async (firestoreTransaction) => {
    const latestSnap = await firestoreTransaction.get(paymentRef);
    const latest = latestSnap.data() as PaymentDocument | undefined;
    if (!latest) throw new Error('Payment not found');
    if (latest.status === 'completed') return false;
    if (latest.status !== 'pending') return false;

    firestoreTransaction.update(paymentRef, {
      status: 'processing',
      gatewayTransactionId: transactionId,
      processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey: `${paymentId}_${transactionId}`,
    });
    return true;
  });

  if (!locked) {
    const latest = await paymentRef.get();
    return { status: latest.data()?.status ?? 'pending' };
  }

  const orchestrationService = new PaymentOrchestrationService(
    new EventStore(),
    new NotificationService(),
  );
  const result = await orchestrationService.processSuccessfulPayment({
    paymentId,
    payment,
    transactionId,
    metadata: (payment.metadata ?? {}) as PaymentMetadata,
    ipAddress,
  });

  if (!result.success) {
    throw new Error(result.error ?? 'Payment processing failed');
  }

  functions.logger.info('Paymob payment reconciled', {
    paymentId,
    transactionId,
    sessionId: result.sessionId,
  });
  return {
    status: 'completed',
    sessionId: result.sessionId ?? null,
    subscriptionId: result.subscriptionId ?? null,
  };
}

export const reconcilePaymobPayment = paymobRuntime.https.onCall(
  async (data: ReconcilePaymentData | null, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    const paymentId =
      typeof data?.paymentId === 'string' ? data.paymentId.trim() : '';
    if (!paymentId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'paymentId required',
      );
    }

    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment not found');
    }

    const payment = paymentSnap.data() as PaymentDocument;
    if (payment.studentId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'This payment does not belong to the caller',
      );
    }

    try {
      return await reconcilePaymentDocument(
        paymentId,
        payment,
        context.rawRequest.ip,
      );
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Payment processing failed';
      functions.logger.error('Callable Paymob reconciliation failed', {
        paymentId,
        error: message,
      });
      throw new functions.https.HttpsError(
        'internal',
        message,
      );
    }
  },
);

export const reconcilePendingPaymobPayments = paymobRuntime.pubsub
  .schedule(PAYMOB_RECONCILIATION_SCHEDULE)
  .onRun(async () => {
    // Paymob's webhook is the primary completion path. This scheduled fallback
    // only needs recent payments and must filter them in Firestore; filtering
    // after get() repeatedly billed every stale pending document.
    const recentCutoff = admin.firestore.Timestamp.fromMillis(
      paymobReconciliationCutoffMillis(),
    );
    const pending = await buildRecentPendingPaymentsQuery(
      db.collection('payments'),
      recentCutoff,
    ).get();

    const newestPending = pending.docs;

    if (newestPending.length === 0) {
      functions.logger.info('Scheduled Paymob reconciliation finished', {
        checked: 0,
        completed: 0,
      });
      return null;
    }

    const paymobContext = await createPaymobContext();
    const results = await Promise.all(newestPending.map(async (document) => {
      try {
        return await reconcilePaymentDocument(
          document.id,
          document.data() as PaymentDocument,
          undefined,
          paymobContext,
        );
      } catch (error) {
        functions.logger.error('Scheduled Paymob reconciliation failed', {
          paymentId: document.id,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
        return { status: 'error' };
      }
    }));
    const completed = results.filter(
      (result) => result.status === 'completed',
    ).length;

    functions.logger.info('Scheduled Paymob reconciliation finished', {
      checked: newestPending.length,
      completed,
    });
    return null;
  },
);
