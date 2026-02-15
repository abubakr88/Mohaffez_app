import * as functions from 'firebase-functions';
import admin, { db, FieldValue } from '../utils/admin';
import { createNotification } from '../utils/notificationHelpers';

interface ExpiredRequest {
  id: string;
  studentId?: string;
  mohaffezId?: string;
  mohaffezName?: string;
  studentName?: string;
}

async function logFailedOperation(requestId: string, error: unknown): Promise<void> {
  await db.collection('failedOperations').add({
    operationType: 'expired_payment_processing',
    requestId,
    error: error instanceof Error ? error.message : 'Unknown error',
    timestamp: FieldValue.serverTimestamp(),
    retryCount: 0,
    status: 'pending_retry',
  });
}

async function sendExpirationNotifications(request: ExpiredRequest): Promise<void> {
  if (request.studentId) {
    await createNotification({
      userId: request.studentId,
      senderId: request.mohaffezId,
      title: 'انتهت مهلة الدفع',
      body: 'انتهت مهلة الدفع ولم يتم تأكيد طلبك. يمكنك إرسال طلب جديد.',
      type: 'payment_expired',
      isRead: false,
      data: {
        requestId: request.id,
      },
    });
  }

  if (request.mohaffezId) {
    await createNotification({
      userId: request.mohaffezId,
      senderId: request.studentId,
      title: 'انتهت مهلة دفع الطالب',
      body: `لم يكتمل دفع الطالب ${request.studentName ?? ''} خلال المهلة المحددة.`,
      type: 'payment_expired',
      isRead: false,
      data: {
        requestId: request.id,
      },
    });
  }
}

export const checkExpiredPayments = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expiredRequests = await db
      .collection('sessionRequests')
      .where('status', '==', 'awaitingpayment')
      .where('paymentDeadline', '<=', now)
      .get();

    if (expiredRequests.empty) {
      return null;
    }

    for (const doc of expiredRequests.docs) {
      try {
        const data = doc.data();

        await doc.ref.update({
          status: 'expired',
          expiredAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        await sendExpirationNotifications({
          id: doc.id,
          studentId: data.studentId,
          mohaffezId: data.mohaffezId,
          mohaffezName: data.mohaffezName,
          studentName: data.studentName,
        });
      } catch (error) {
        functions.logger.error('Failed to process expired payment request', {
          requestId: doc.id,
          error,
        });

        await logFailedOperation(doc.id, error);
      }
    }

    functions.logger.info('Expired awaiting_payment requests processed', {
      count: expiredRequests.size,
    });

    return null;
  });
