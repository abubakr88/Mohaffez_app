import * as functions from 'firebase-functions';

import admin, { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

async function logFailedOperation(
  sessionId: string,
  operationType: 'session_reminder_24h' | 'session_reminder_1h',
  error: unknown
): Promise<void> {
  await db.collection('failedOperations').add({
    operationType,
    sessionId,
    error: error instanceof Error ? error.message : 'Unknown error',
    timestamp: FieldValue.serverTimestamp(),
    retryCount: 0,
    status: 'pending_retry',
  });
}

export const sendSessionReminders = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async () => {
    // FIX-8: Switch to flag-based bounded windows to prevent overlap gaps/duplicates across runs
    const nowMs = Date.now();
    const in24hLower = admin.firestore.Timestamp.fromDate(
      new Date(nowMs + 23 * 60 * 60 * 1000)
    );
    const in24hUpper = admin.firestore.Timestamp.fromDate(
      new Date(nowMs + 25 * 60 * 60 * 1000)
    );
    const in1hLower = admin.firestore.Timestamp.fromDate(new Date(nowMs));
    const in1hUpper = admin.firestore.Timestamp.fromDate(
      new Date(nowMs + 2 * 60 * 60 * 1000)
    );

    const twentyFourHourSnapshot = await db
      .collection('hafizSessions')
      .where('status', '==', 'accepted')
      .where('reminder24hSent', '==', false)
      .where('sessionDate', '<=', in24hUpper)
      .where('sessionDate', '>=', in24hLower)
      .get();

    for (const doc of twentyFourHourSnapshot.docs) {
      try {
        const data = doc.data();
        const studentId = typeof data.studentId === 'string' ? data.studentId : '';
        const mohaffezId = typeof data.mohaffezId === 'string' ? data.mohaffezId : '';
        const teacherName =
          typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';
        const studentName =
          typeof data.studentName === 'string' ? data.studentName : 'الطالب';
        const timeSlot =
          typeof data.preferredTimeSlot === 'string'
            ? data.preferredTimeSlot
            : typeof data.timeSlot === 'string'
            ? data.timeSlot
            : '';

        if (!studentId || !mohaffezId) {
          continue;
        }

        // FIX-REMINDER-1: Claim the flag atomically BEFORE sending the notification.
        // This prevents duplicate sends if the transaction succeeds but FCM fails,
        // or if the cron fires again before the flag write completes.
        let shouldSend24h = false;
        try {
          await db.runTransaction(async (transaction) => {
            const fresh = await transaction.get(doc.ref);
            if (!fresh.exists) return;
            if (fresh.data()?.reminder24hSent === true) return; // already claimed
            transaction.update(doc.ref, {
              reminder24hSent: true,
              reminder24hSentAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
            shouldSend24h = true;
          });
        } catch (flagError) {
          functions.logger.error('Failed to claim reminder24h flag', {
            docId: doc.id, error: flagError
          });
          continue; // skip this doc safely — try again next cron tick
        }

        if (shouldSend24h) {
          await createAndSendNotification({
            userId: studentId,
            senderId: mohaffezId,
            title: '📅 تذكير: جلسة غداً',
            body: `جلستك مع ${teacherName} غداً ${timeSlot}`,
            type: 'session_reminder_24h',
            isRead: false,
            data: {
              type: 'session_reminder_24h',
              sessionId: doc.id,
            },
          });

          await createAndSendNotification({
            userId: mohaffezId,
            senderId: studentId,
            title: '📅 تذكير: جلسة غداً',
            body: `جلستك مع ${studentName} غداً ${timeSlot}`,
            type: 'session_reminder_24h',
            isRead: false,
            data: {
              type: 'session_reminder_24h',
              sessionId: doc.id,
            },
          });
        }
      } catch (error) {
        functions.logger.error('Failed to process 24h session reminder', {
          sessionId: doc.id,
          error,
        });

        await logFailedOperation(doc.id, 'session_reminder_24h', error);
      }
    }

    const oneHourSnapshot = await db
      .collection('hafizSessions')
      .where('status', '==', 'accepted')
      .where('reminder1hSent', '==', false)
      .where('sessionDate', '<=', in1hUpper)
      .where('sessionDate', '>=', in1hLower)
      .get();

    for (const doc of oneHourSnapshot.docs) {
      try {
        const data = doc.data();
        const studentId = typeof data.studentId === 'string' ? data.studentId : '';
        const mohaffezId = typeof data.mohaffezId === 'string' ? data.mohaffezId : '';
        const teacherName =
          typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';
        const studentName =
          typeof data.studentName === 'string' ? data.studentName : 'الطالب';
        const teacherPhone =
          typeof data.mohaffezPhone === 'string' ? data.mohaffezPhone : '';
        const location =
          typeof data.location === 'string'
            ? data.location
            : typeof data.imamAddressText === 'string'
            ? data.imamAddressText
            : '';

        if (!studentId || !mohaffezId) {
          continue;
        }

        const studentBody = `ستبدأ جلستك مع ${teacherName} خلال ساعة`;
        const teacherBody = `ستبدأ جلستك مع ${studentName} خلال ساعة`;

        const reminderData = {
          type: 'session_reminder_1h',
          sessionId: doc.id,
          teacherPhone,
          location,
        };

        // FIX-REMINDER-1: Claim the flag atomically BEFORE sending the notification.
        // This prevents duplicate sends if the transaction succeeds but FCM fails,
        // or if the cron fires again before the flag write completes.
        let shouldSend1h = false;
        try {
          await db.runTransaction(async (transaction) => {
            const fresh = await transaction.get(doc.ref);
            if (!fresh.exists) return;
            if (fresh.data()?.reminder1hSent === true) return; // already claimed
            transaction.update(doc.ref, {
              reminder1hSent: true,
              reminder1hSentAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
            shouldSend1h = true;
          });
        } catch (flagError) {
          functions.logger.error('Failed to claim reminder1h flag', {
            docId: doc.id, error: flagError
          });
          continue; // skip this doc safely — try again next cron tick
        }

        if (shouldSend1h) {
          await createAndSendNotification({
            userId: studentId,
            senderId: mohaffezId,
            title: '🔔 جلستك قريباً!',
            body: studentBody,
            type: 'session_reminder_1h',
            isRead: false,
            data: reminderData,
            highPriority: true,
          });

          await createAndSendNotification({
            userId: mohaffezId,
            senderId: studentId,
            title: '🔔 جلستك قريباً!',
            body: teacherBody,
            type: 'session_reminder_1h',
            isRead: false,
            data: reminderData,
            highPriority: true,
          });
        }
      } catch (error) {
        functions.logger.error('Failed to process 1h session reminder', {
          sessionId: doc.id,
          error,
        });

        await logFailedOperation(doc.id, 'session_reminder_1h', error);
      }
    }

    functions.logger.info('Session reminders completed', {
      sent24h: twentyFourHourSnapshot.size,
      sent1h: oneHourSnapshot.size,
    });

    return null;
  });
