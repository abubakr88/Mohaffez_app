// functions/src/payments/handlers.ts
import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';

/**
 * Confirm booking request and create session after payment
 */
export async function confirmBookingAfterPayment(
  batch: FirebaseFirestore.WriteBatch,
  requestId: string,
  sessionDetails: any,
  payment: any,
  transactionId: string
): Promise<void> {
  const requestRef = db.collection('sessionRequests').doc(requestId);
  const requestSnap = await requestRef.get();

  if (!requestSnap.exists) {
    throw new Error('Session request not found');
  }

  // Update request to accepted + paid
  batch.update(requestRef, {
    status: 'accepted',
    isPaid: true,
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    paymentTransactionId: transactionId,
  });

  // Create hafizSession
  const sessionRef = db.collection('hafizSessions').doc();
  batch.set(sessionRef, {
    ...sessionDetails,
    requestId,
    status: 'accepted',
    isPaid: true,
    paymentTransactionId: transactionId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send notification to student
  const notifRef = db.collection('notifications').doc();
  batch.set(notifRef, {
    recipientId: payment.studentId,
    senderId: payment.mohaffezId,
    type: 'session_confirmed',
    title: 'تم تأكيد الحجز ✅',
    message: `تم تأكيد حجزك مع ${payment.mohaffezName} بعد الدفع`,
    body: `تم تأكيد حجزك مع ${payment.mohaffezName} بعد الدفع`,
    data: { 
      sessionId: sessionRef.id, 
      requestId,
      mohaffezId: payment.mohaffezId,
    },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info('Booking confirmed after payment', { requestId, sessionId: sessionRef.id });
}

/**
 * Consume subscription session and create booking
 */
export async function consumeSubscriptionAndCreateSession(
  batch: FirebaseFirestore.WriteBatch,
  subscriptionId: string,
  payment: any,
  transactionId: string
): Promise<void> {
  const subRef = db.collection('subscriptions').doc(subscriptionId);
  const subSnap = await subRef.get();

  if (!subSnap.exists) {
    throw new Error('Subscription not found');
  }

  const subscription = subSnap.data()!;

  if (subscription.remainingSessions <= 0) {
    throw new Error('No sessions remaining');
  }

  const newRemaining = subscription.remainingSessions - 1;
  const newStatus = newRemaining === 0 ? 'depleted' : subscription.status;

  batch.update(subRef, {
    remainingSessions: newRemaining,
    status: newStatus,
    lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info('Subscription session consumed', { 
    subscriptionId, 
    remainingSessions: newRemaining 
  });
}

/**
 * Create subscription from plan purchase
 */
export async function createSubscriptionFromPayment(
  batch: FirebaseFirestore.WriteBatch,
  payment: any,
  transactionId: string
): Promise<void> {
  const metadata = payment.metadata || {};
  const planMetadata = {
    planId: metadata.planId,
    planTitle: metadata.planTitle || 'خطة دفع',
    planType: metadata.planType || 'single',
    sessionsCount: metadata.sessionsCount || 1,
    validityDays: metadata.validityDays,
  };

  const subscriptionRef = db.collection('subscriptions').doc();
  
  let expiryDate = null;
  if (planMetadata.validityDays) {
    const expiry = new Date();
    expiry.setDate(expiry.getDate() + planMetadata.validityDays);
    expiryDate = admin.firestore.Timestamp.fromDate(expiry);
  }

  batch.set(subscriptionRef, {
    studentId: payment.studentId,
    studentName: payment.studentName,
    mohaffezId: payment.mohaffezId,
    mohaffezName: payment.mohaffezName,
    planId: planMetadata.planId,
    planTitle: planMetadata.planTitle,
    planType: planMetadata.planType,
    totalSessions: planMetadata.sessionsCount,
    remainingSessions: planMetadata.sessionsCount,
    totalPaid: payment.amount,
    paymentTransactionId: transactionId,
    startDate: admin.firestore.FieldValue.serverTimestamp(),
    expiryDate: expiryDate,
    status: 'active',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Send notification to student
  const notifRef = db.collection('notifications').doc();
  batch.set(notifRef, {
    recipientId: payment.studentId,
    senderId: payment.mohaffezId,
    type: 'subscription_created',
    title: 'تم شراء الباقة بنجاح 🎉',
    message: `تم شراء ${planMetadata.planTitle} - ${planMetadata.sessionsCount} جلسة`,
    body: `تم شراء ${planMetadata.planTitle} - ${planMetadata.sessionsCount} جلسة`,
    data: { 
      subscriptionId: subscriptionRef.id,
      mohaffezId: payment.mohaffezId,
    },
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info('Subscription created from payment', { 
    subscriptionId: subscriptionRef.id, 
    sessions: planMetadata.sessionsCount 
  });
}
