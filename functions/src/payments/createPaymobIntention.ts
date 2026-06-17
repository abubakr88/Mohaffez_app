import * as functions from 'firebase-functions';
import * as https from 'https';
import { URL } from 'url';
import admin, { db } from '../utils/admin';
import { PaymentDocument } from '../types/payment.types';

interface CreatePaymobIntentionData {
  paymentId?: unknown;
  amount?: unknown;
  integrationId?: unknown;
  studentEmail?: unknown;
  studentPhone?: unknown;
  studentName?: unknown;
}

interface PaymentRecord extends PaymentDocument {
  studentEmail?: string;
  studentPhone?: string;
  planId?: string;
  planTitle?: string;
  currency?: string;
}

interface PaymobIntentionResponse {
  id?: string | number;
  intention_id?: string | number;
  order?: string | number | { id?: string | number };
  client_secret?: string;
  payment_keys?: Array<{ key?: string; integration?: string | number }>;
}

const PAYMOB_BASE_URL = 'https://accept.paymob.com';
const DEFAULT_RETURN_URL = 'https://app.mohafezy.com/payment/return';
const paymobRuntime = functions.runWith({
  secrets: [
    'PAYMOB_SECRET_KEY',
    'PAYMOB_PUBLIC_KEY',
    'PAYMOB_CARD_INTEGRATION_ID',
  ],
});

async function isPaymobEnabled(): Promise<boolean> {
  try {
    const snap = await db.collection('systemConfig').doc('global').get();
    return snap.exists && snap.data()?.paymobEnabled === true;
  } catch (err) {
    functions.logger.error('Failed to read paymobEnabled flag', { err });
    return false;
  }
}

function getEnv(name: string): string {
  return (process.env[name] ?? '').replace(/[\r\n\t ]/g, '');
}

function resolveIntegrationId(requested: unknown): number {
  const configured = getEnv('PAYMOB_CARD_INTEGRATION_ID');
  const raw = configured || requested?.toString().trim() || '';
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'PAYMOB_CARD_INTEGRATION_ID is not configured'
    );
  }
  return parsed;
}

function requiredEnv(name: string): string {
  const value = getEnv(name);
  if (!value) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `${name} is not configured`
    );
  }
  return value;
}

function amountToCents(amount: number): number {
  return Math.round(amount * 100);
}

function safeString(value: unknown, fallback: string): string {
  if (typeof value !== 'string') return fallback;
  const trimmed = value.trim();
  return trimmed.length === 0 ? fallback : trimmed;
}

function safeEmail(value: unknown): string {
  const email = safeString(value, 'customer@mohafezy.com');
  return email.includes('@') ? email : 'customer@mohafezy.com';
}

function safePhone(value: unknown): string {
  const phone = safeString(value, '01000000000');
  return phone.length >= 8 ? phone : '01000000000';
}

function splitName(value: unknown): { first: string; last: string } {
  const parts = safeString(value, 'Student').split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { first: 'Student', last: 'Mohaffez' };
  if (parts.length === 1) return { first: parts[0], last: parts[0] };
  return { first: parts[0], last: parts.slice(1).join(' ') };
}

function truncate(value: string, maxLength: number): string {
  return value.length <= maxLength ? value : value.slice(0, maxLength);
}

function projectId(): string {
  return (
    process.env.GCLOUD_PROJECT ??
    process.env.GCP_PROJECT ??
    process.env.PROJECT_ID ??
    'mohaffez-ba2ec'
  );
}

function webhookUrl(): string {
  return (
    getEnv('PAYMOB_WEBHOOK_URL') ||
    `https://us-central1-${projectId()}.cloudfunctions.net/paymobWebhook`
  );
}

function returnUrl(): string {
  return getEnv('PAYMOB_RETURN_URL') || DEFAULT_RETURN_URL;
}

function buildUnifiedCheckoutUrl(publicKey: string, clientSecret: string): string {
  const url = new URL('/unifiedcheckout/', PAYMOB_BASE_URL);
  url.searchParams.set('publicKey', publicKey);
  url.searchParams.set('clientSecret', clientSecret);
  return url.toString();
}

function postJson<T>(url: string, token: string, body: unknown): Promise<T> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const payload = JSON.stringify(body);
    const request = https.request(
      {
        hostname: parsed.hostname,
        path: `${parsed.pathname}${parsed.search}`,
        method: 'POST',
        headers: {
          Authorization: `Token ${token}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (response) => {
        const chunks: Buffer[] = [];
        response.on('data', (chunk: Buffer) => chunks.push(chunk));
        response.on('end', () => {
          const text = Buffer.concat(chunks).toString('utf8');
          let parsedBody: unknown = {};
          if (text) {
            try {
              parsedBody = JSON.parse(text);
            } catch {
              parsedBody = { raw: text };
            }
          }

          if (!response.statusCode || response.statusCode < 200 || response.statusCode >= 300) {
            reject(
              new Error(
                `Paymob intention failed (${response.statusCode ?? 'no-status'}): ${text}`
              )
            );
            return;
          }

          resolve(parsedBody as T);
        });
      }
    );

    request.on('error', reject);
    request.write(payload);
    request.end();
  });
}

export const createPaymobIntention = paymobRuntime.https.onCall(
  async (data: CreatePaymobIntentionData | null, context) => {
    const rawData = data ?? {};

    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    if (!(await isPaymobEnabled())) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Paymob gateway is disabled'
      );
    }

    const paymentId = safeString(rawData.paymentId, '');
    if (!paymentId) {
      throw new functions.https.HttpsError('invalid-argument', 'paymentId required');
    }

    const secretKey = requiredEnv('PAYMOB_SECRET_KEY');
    const publicKey = requiredEnv('PAYMOB_PUBLIC_KEY');
    const integrationId = resolveIntegrationId(rawData.integrationId);

    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Payment not found');
    }

    const payment = paymentSnap.data() as PaymentRecord;
    if (payment.studentId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'This payment does not belong to the caller'
      );
    }

    if (payment.status !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Payment is not pending'
      );
    }

    const requestAmount = Number(rawData.amount);
    if (Number.isFinite(requestAmount) && Math.abs(payment.amount - requestAmount) > 0.01) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Payment amount mismatch'
      );
    }

    const amountCents = amountToCents(payment.amount);
    if (amountCents <= 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Payment amount must be positive'
      );
    }

    const studentName = payment.studentName || rawData.studentName;
    const names = splitName(studentName);
    const planTitle = safeString(payment.planTitle, 'Mohaffez session');
    const body = {
      amount: amountCents,
      currency: payment.currency || 'EGP',
      payment_methods: [integrationId],
      items: [
        {
          name: truncate(planTitle, 50),
          amount: amountCents,
          description: truncate(`Mohaffez booking ${paymentId}`, 255),
          quantity: 1,
        },
      ],
      billing_data: {
        first_name: names.first,
        last_name: names.last,
        email: safeEmail(payment.studentEmail || rawData.studentEmail),
        phone_number: safePhone(payment.studentPhone || rawData.studentPhone),
        country: 'EG',
      },
      special_reference: paymentId,
      notification_url: webhookUrl(),
      redirection_url: returnUrl(),
      expiration: 3600,
      extras: {
        paymentId,
        studentId: payment.studentId,
        mohaffezId: payment.mohaffezId,
      },
    };

    let paymobResponse: PaymobIntentionResponse;
    try {
      paymobResponse = await postJson<PaymobIntentionResponse>(
        `${PAYMOB_BASE_URL}/v1/intention/`,
        secretKey,
        body
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown Paymob error';
      functions.logger.error('Paymob intention creation failed', {
        paymentId,
        paymobError: message,
      });
      throw new functions.https.HttpsError(
        'internal',
        'Failed to create Paymob payment intention'
      );
    }

    const clientSecret = paymobResponse.client_secret;
    if (!clientSecret) {
      functions.logger.error('Paymob intention response missing client_secret', {
        paymentId,
        response: paymobResponse,
      });
      throw new functions.https.HttpsError(
        'internal',
        'Paymob did not return a checkout token'
      );
    }

    const orderId =
      typeof paymobResponse.order === 'object'
        ? paymobResponse.order.id?.toString()
        : paymobResponse.order?.toString();
    const intentionId = (
      paymobResponse.intention_id ??
      paymobResponse.id ??
      ''
    ).toString();
    const paymentUrl = buildUnifiedCheckoutUrl(publicKey, clientSecret);

    await paymentRef.update({
      gatewayOrderId: orderId ?? intentionId,
      transactionReference: clientSecret,
      gatewayResponse: {
        provider: 'paymob_flash',
        intentionId,
        orderId: orderId ?? null,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      paymentUrl,
      orderId: orderId ?? intentionId,
      clientSecret,
    };
  }
);
