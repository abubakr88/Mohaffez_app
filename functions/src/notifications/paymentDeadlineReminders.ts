import * as functions from 'firebase-functions';

import admin, { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

async function logFailedOperation(requestId: string, error: unknown): Promise<void> {
  await db.collection('failedOperations').add({
    operationType: 'payment_deadline_reminder',
    requestId,
    error: error instanceof Error ? error.message : 'Unknown error',
    timestamp: FieldValue.serverTimestamp(),
    retryCount: 0,
    status: 'pending_retry',
  });
}

export const sendPaymentDeadlineReminders = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const inTwoHours = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 2 * 60 * 60 * 1000),
    );

    const snapshot = await db
      .collection('sessionRequests')
      .where('status', '==', 'awaitingpayment')
      .where('paymentDeadline', '>=', now)
      .where('paymentDeadline', '<=', inTwoHours)
      .where('reminderSent', '==', false)
      .get();

    if (snapshot.empty) {
      return null;
    }

    for (const doc of snapshot.docs) {
      try {
        const data = doc.data();
        const studentId = typeof data.studentId === 'string' ? data.studentId : null;
        const teacherName =
          typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';

        if (!studentId) {
          continue;
        }

        // BUG-FIX-A: Claim the flag atomically BEFORE sending the notification.
        // This prevents duplicate sends if the transaction succeeds but FCM fails,
        // or if the cron fires again before the flag write completes.
        let shouldSend = false;
        try {
          await db.runTransaction(async (transaction) => {
            const fresh = await transaction.get(doc.ref);
            if (!fresh.exists) return;
            if (fresh.data()?.reminderSent === true) return; // already claimed
            transaction.update(doc.ref, {
              reminderSent: true,
              reminderSentAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
            shouldSend = true;
          });
        } catch (flagError) {
          functions.logger.error('Failed to claim reminderSent flag', {
            requestId: doc.id, error: flagError
          });
          // FIXED: BUG-7 - log to failedOperations for retry
          await logFailedOperation(doc.id, flagError);
          continue; // skip this doc safely — try again next cron tick
        }

        if (shouldSend) {
          await createAndSendNotification({
            userId: studentId,
            senderId: typeof data.mohaffezId === 'string' ? data.mohaffezId : null,
            title: '⏰ تذكير: باقي ساعتان للدفع',
            body: `سيتم إلغاء طلب جلستك مع ${teacherName} إذا لم تدفع`,
            type: 'payment_deadline_reminder',
            isRead: false,
            data: {
              type: 'payment_deadline_reminder',
              requestId: doc.id,
              route: '/payment',
            },
            highPriority: true,
          });
        }
      } catch (error) {
        functions.logger.error('Failed to process payment deadline reminder', {
          requestId: doc.id,
          error,
        });

        await logFailedOperation(doc.id, error);
      }
    }

    functions.logger.info('Payment deadline reminders sent', {
      count: snapshot.size,
    });

    return null;
  });
