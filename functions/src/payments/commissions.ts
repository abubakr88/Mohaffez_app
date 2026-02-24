import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

export async function processWeeklyCommissionsNow(): Promise<number> {
  const now = admin.firestore.Timestamp.now();
  const overdue = await db
    .collection('weeklyCommissionSummaries')
    .where('status', '==', 'pending')
    .where('dueDate', '<=', now)
    .get();

  for (const doc of overdue.docs) {
    const d = doc.data();
    await doc.ref.update({
      status: 'overdue',
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (d.mohaffezId && d.commissionAmount > 0) {
      await createAndSendNotification({
        userId: d.mohaffezId,
        senderId: 'system',
        title: '????? ??????',
        body: `???? ????? ?????? ${d.commissionAmount.toFixed(2)} ?.? ?? ??????? ${d.weekNumber}`,
        type: 'commission_overdue',
        isRead: false,
        data: {
          weeklyCommissionSummaryId: doc.id,
          commissionAmount: d.commissionAmount.toString(),
        },
        highPriority: true,
      });
    }
  }

  functions.logger.info('Weekly commissions processed', { count: overdue.size });
  return overdue.size;
}

// Runs every Monday at 09:00 Cairo time to send overdue reminders
export const processWeeklyCommissions = functions.pubsub
  .schedule('every monday 09:00')
  .timeZone('Africa/Cairo')
  .onRun(async () => {
    await processWeeklyCommissionsNow();
    return null;
  });

// Called by admin to mark a summary as paid
export const markCommissionPaid = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', '??? ????? ????');
  }

  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', '??? ???? ??');
  }

  const { weeklyCommissionSummaryId } = data;
  const summaryRef = db.collection('weeklyCommissionSummaries').doc(weeklyCommissionSummaryId);
  await summaryRef.update({
    status: 'paid',
    paidAt: FieldValue.serverTimestamp(),
    markedPaidBy: context.auth.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const summarySnap = await summaryRef.get();
  const s = summarySnap.data();
  if (!s) return { success: true };

  const pending = await db
    .collection('commissions')
    .where('mohaffezId', '==', s.mohaffezId)
    .where('weekNumber', '==', s.weekNumber)
    .where('status', '==', 'pending')
    .get();

  const batch = db.batch();
  for (const finalDoc of pending.docs) {
    batch.update(finalDoc.ref, {
      status: 'paid',
      paidAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  await createAndSendNotification({
    userId: s.mohaffezId,
    senderId: context.auth.uid,
    title: '?? ????? ???? ???????',
    body: `?? ????? ???? ?????? ??????? ${s.weekNumber}: ${s.commissionAmount.toFixed(2)} ?.?`,
    type: 'commission_paid',
    isRead: false,
    data: { weeklyCommissionSummaryId },
  });

  return { success: true };
});
