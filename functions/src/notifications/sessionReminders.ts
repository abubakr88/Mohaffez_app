import * as functions from 'firebase-functions';

import admin, { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';
import {
  isValidTimeZone,
  TEACHER_TIME_ZONE_ID,
} from '../bookings/bookingTimeZone';

type SessionDoc = FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>;

async function reminderDocuments(
  flag: 'reminder24hSent' | 'reminder1hSent',
  lower: FirebaseFirestore.Timestamp,
  upper: FirebaseFirestore.Timestamp,
): Promise<SessionDoc[]> {
  const base = db
    .collection('hafizSessions')
    .where('status', '==', 'accepted')
    .where(flag, '==', false);
  const [legacy, timeZoneAware] = await Promise.all([
    base.where('sessionDate', '<=', upper).where('sessionDate', '>=', lower).get(),
    base.where('slotStart', '<=', upper).where('slotStart', '>=', lower).get(),
  ]);

  const docs = new Map<string, SessionDoc>();
  for (const doc of legacy.docs) {
    if (doc.data().bookingTimeZoneVersion !== 1) docs.set(doc.id, doc);
  }
  for (const doc of timeZoneAware.docs) {
    if (doc.data().bookingTimeZoneVersion === 1) docs.set(doc.id, doc);
  }
  return [...docs.values()];
}

async function userTimeZoneId(
  userId: string,
): Promise<string> {
  const user = await db.collection('users').doc(userId).get();
  const data = user.data() ?? {};
  return isValidTimeZone(data.timeZoneId)
    ? data.timeZoneId.trim()
    : TEACHER_TIME_ZONE_ID;
}

function formatSessionInstant(
  value: FirebaseFirestore.Timestamp,
  timeZoneId: string,
): string {
  return new Intl.DateTimeFormat('ar-EG', {
    timeZone: timeZoneId,
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    hour: 'numeric',
    minute: '2-digit',
  }).format(value.toDate());
}

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

    const twentyFourHourDocs = await reminderDocuments(
      'reminder24hSent',
      in24hLower,
      in24hUpper,
    );

    for (const doc of twentyFourHourDocs) {
      try {
        const data = doc.data();
        const studentId = typeof data.studentId === 'string' ? data.studentId : '';
        const mohaffezId = typeof data.mohaffezId === 'string' ? data.mohaffezId : '';
        const teacherName =
          typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';
        const studentName =
          typeof data.studentName === 'string' ? data.studentName : 'الطالب';
        let timeSlot =
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
          let teacherTimeSlot = timeSlot;
          if (
            data.bookingTimeZoneVersion === 1 &&
            data.slotStart instanceof admin.firestore.Timestamp
          ) {
            const studentTimeZone = await userTimeZoneId(studentId);
            timeSlot = formatSessionInstant(data.slotStart, studentTimeZone);
            teacherTimeSlot = formatSessionInstant(
              data.slotStart,
              TEACHER_TIME_ZONE_ID,
            );
          }
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

          timeSlot = teacherTimeSlot;
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

    const oneHourDocs = await reminderDocuments(
      'reminder1hSent',
      in1hLower,
      in1hUpper,
    );

    for (const doc of oneHourDocs) {
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
      sent24h: twentyFourHourDocs.length,
      sent1h: oneHourDocs.length,
    });

    return null;
  });
