import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';
import { PaymentDocument, PaymentMetadata } from '../types/payment.types';

interface BookingConfirmationResult {
  sessionId: string;
}

interface SubscriptionCreationResult {
  subscriptionId: string;
}

interface SubscriptionConsumptionResult {
  remainingSessions: number;
  sessionId?: string;
}

const parseNumber = (value: unknown, fallback: number): number => {
  if (typeof value === 'number') {
    return value;
  }
  return fallback;
};

const parseString = (value: unknown, fallback: string): string => {
  if (typeof value === 'string' && value.trim().length > 0) {
    return value;
  }
  return fallback;
};

export async function confirmBookingAfterPayment(
  requestId: string,
  sessionDetails: Record<string, unknown>,
  payment: PaymentDocument,
  transactionId: string
): Promise<BookingConfirmationResult> {
  return db.runTransaction(async (transaction) => {
    const requestRef = db.collection('sessionRequests').doc(requestId);
    const requestSnap = await transaction.get(requestRef);

    if (!requestSnap.exists) {
      throw new Error('Session request not found');
    }

    const sessionRef = db.collection('hafizSessions').doc();

    transaction.update(requestRef, {
      status: 'accepted',
      isPaid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      paymentTransactionId: transactionId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(sessionRef, {
      ...sessionDetails,
      requestId,
      status: 'accepted',
      isPaid: true,
      paymentTransactionId: transactionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      studentId: payment.studentId,
      mohaffezId: payment.mohaffezId,
    });

    functions.logger.info('Booking confirmed in transaction', {
      requestId,
      sessionId: sessionRef.id,
    });

    return { sessionId: sessionRef.id };
  });
}

export async function consumeSubscriptionAndCreateSession(
  subscriptionId: string,
  payment: PaymentDocument,
  transactionId: string,
  metadata: PaymentMetadata
): Promise<SubscriptionConsumptionResult> {
  return db.runTransaction(async (transaction) => {
    const subRef = db.collection('subscriptions').doc(subscriptionId);
    const subSnap = await transaction.get(subRef);

    if (!subSnap.exists) {
      throw new Error('Subscription not found');
    }

    const subscription = subSnap.data() as Record<string, unknown>;
    const remainingSessions = parseNumber(subscription.remainingSessions, 0);

    if (remainingSessions <= 0) {
      throw new Error('No sessions remaining');
    }

    const newRemaining = remainingSessions - 1;
    const status = newRemaining === 0
      ? 'depleted'
      : parseString(subscription.status, 'active');

    transaction.update(subRef, {
      remainingSessions: newRemaining,
      status,
      lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    let sessionId: string | undefined;
    if (metadata.requestId && metadata.sessionDetails) {
      const requestRef = db.collection('sessionRequests').doc(metadata.requestId);
      const requestSnap = await transaction.get(requestRef);

      if (!requestSnap.exists) {
        throw new Error('Session request not found for subscription consumption');
      }

      const sessionRef = db.collection('hafizSessions').doc();
      sessionId = sessionRef.id;

      transaction.update(requestRef, {
        status: 'accepted',
        isPaid: true,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentTransactionId: transactionId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(sessionRef, {
        ...metadata.sessionDetails,
        requestId: metadata.requestId,
        status: 'accepted',
        isPaid: true,
        paymentTransactionId: transactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        studentId: payment.studentId,
        mohaffezId: payment.mohaffezId,
      });
    }

    functions.logger.info('Subscription session consumed in transaction', {
      subscriptionId,
      remainingSessions: newRemaining,
      sessionId,
    });

    return { remainingSessions: newRemaining, sessionId };
  });
}

export async function createSubscriptionFromPayment(
  payment: PaymentDocument,
  transactionId: string
): Promise<SubscriptionCreationResult> {
  const metadata = payment.metadata ?? {};

  const planTitle = parseString(metadata.planTitle, 'Payment Plan');
  const planType = parseString(metadata.planType, 'single');
  const sessionsCount = parseNumber(metadata.sessionsCount, 1);
  const validityDays = typeof metadata.validityDays === 'number'
    ? metadata.validityDays
    : undefined;

  return db.runTransaction(async (transaction) => {
    const subscriptionRef = db.collection('subscriptions').doc();

    let expiryDate: FirebaseFirestore.Timestamp | null = null;
    if (validityDays && validityDays > 0) {
      const expiry = new Date();
      expiry.setDate(expiry.getDate() + validityDays);
      expiryDate = admin.firestore.Timestamp.fromDate(expiry);
    }

    transaction.set(subscriptionRef, {
      studentId: payment.studentId,
      studentName: payment.studentName,
      mohaffezId: payment.mohaffezId,
      mohaffezName: payment.mohaffezName,
      planId: parseString(metadata.planId, ''),
      planTitle,
      planType,
      totalSessions: sessionsCount,
      remainingSessions: sessionsCount,
      totalPaid: payment.amount,
      paymentTransactionId: transactionId,
      startDate: admin.firestore.FieldValue.serverTimestamp(),
      expiryDate,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Subscription created in transaction', {
      subscriptionId: subscriptionRef.id,
      sessionsCount,
    });

    return { subscriptionId: subscriptionRef.id };
  });
}
