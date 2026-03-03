// src/payments/commissions.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL HELPER — also imported by adminActions.ts
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Marks all pending weeklyCommissionSummaries whose dueDate has passed as
 * 'overdue' and notifies each mohaffez.
 *
 * FIX: Each commission is processed in its own try/catch so a single
 * Firestore or FCM failure never silently aborts the rest of the run.
 */
export async function processWeeklyCommissionsNow(): Promise<number> {
  const now = admin.firestore.Timestamp.now();

  const overdue = await db
    .collection('weeklyCommissionSummaries')
    .where('status', '==', 'pending')
    .where('dueDate', '<=', now)
    .get();

  let processed = 0;

  for (const doc of overdue.docs) {
    try {
      const d = doc.data();

      await doc.ref.update({
        status: 'overdue',
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (d.mohaffezId && d.commissionAmount > 0) {
        await createAndSendNotification({
          userId: d.mohaffezId,
          senderId: 'system',
          title: 'عمولة متأخرة',
          body: `لديك عمولة متأخرة بقيمة ${d.commissionAmount.toFixed(2)} ج.م عن الأسبوع ${d.weekNumber}`,
          type: 'commission_overdue',
          isRead: false,
          data: {
            weeklyCommissionSummaryId: doc.id,
            commissionAmount: d.commissionAmount.toString(),
          },
          highPriority: true,
        });
      }

      processed++;
    } catch (error) {
      // Never let one failure block the rest of the batch
      functions.logger.error('Failed to process overdue commission', {
        docId: doc.id,
        error,
      });
    }
  }

  functions.logger.info('Weekly commissions processed', {
    total: overdue.size,
    processed,
    failed: overdue.size - processed,
  });

  return processed;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULED: every Monday 09:00 Cairo time
// ─────────────────────────────────────────────────────────────────────────────

export const processWeeklyCommissions = functions.pubsub
  .schedule('every monday 09:00')
  .timeZone('Africa/Cairo')
  .onRun(async () => {
    await processWeeklyCommissionsNow();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: admin marks a weekly summary as paid
// ─────────────────────────────────────────────────────────────────────────────

export const markCommissionPaid = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }

  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'للمسؤولين فقط');
  }

  const { weeklyCommissionSummaryId } = data as { weeklyCommissionSummaryId: string };

  if (!weeklyCommissionSummaryId) {
    throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
  }

  const summaryRef = db
    .collection('weeklyCommissionSummaries')
    .doc(weeklyCommissionSummaryId);

  await summaryRef.update({
    status: 'paid',
    paidAt: FieldValue.serverTimestamp(),
    markedPaidBy: context.auth.uid,
    updatedAt: FieldValue.serverTimestamp(),
  });

  const summarySnap = await summaryRef.get();
  const s = summarySnap.data();
  if (!s) return { success: true };

  // Mark all individual commission records for this week as paid
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
    title: 'تم تحويل عمولتك',
    body: `تم تحويل عمولة الأسبوع ${s.weekNumber}: ${s.commissionAmount.toFixed(2)} ج.م`,
    type: 'commission_paid',
    isRead: false,
    data: { weeklyCommissionSummaryId },
  });

  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: mohaffez reports they have sent their commission to the platform
//
// FIX (PERMISSION_DENIED bug from the UI): The Flutter client was doing a
// batch write that included weeklyCommissionSummaries (allow write: if false)
// alongside a notification. Firestore rejected the entire batch and the
// Android WriteStream surfaced the error on the notifications document,
// making it look like a notifications rule issue. All writes now go through
// Admin SDK here, which bypasses security rules entirely.
// ─────────────────────────────────────────────────────────────────────────────

export const mohaffezReportCommissionPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const mohaffezId = context.auth.uid;
    const { weeklyCommissionSummaryId, note } = data as {
      weeklyCommissionSummaryId: string;
      note?: string;
    };

    if (!weeklyCommissionSummaryId) {
      throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
    }

    const summaryRef = db
      .collection('weeklyCommissionSummaries')
      .doc(weeklyCommissionSummaryId);

    const summarySnap = await summaryRef.get();

    if (!summarySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'لم يتم العثور على الملخص');
    }

    const summary = summarySnap.data()!;

    // Ownership — mohaffez can only report their own commissions
    if (summary.mohaffezId !== mohaffezId) {
      throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية');
    }

    // Idempotency — already reported or already paid, return success silently
    if (summary.status === 'pendingVerification' || summary.status === 'paid') {
      return { success: true, message: 'تم الإرسال مسبقاً' };
    }

    // Only pending or overdue summaries can be reported
    if (!['pending', 'overdue'].includes(summary.status)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `لا يمكن الإبلاغ عن دفعة بحالة: ${summary.status}`
      );
    }

    // Admin SDK write — bypasses Firestore security rules
    await summaryRef.update({
      status: 'pendingVerification',
      mohaffezReportedAt: FieldValue.serverTimestamp(),
      mohaffezNote: note ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Fan-out notification to all admin users
    const adminSnap = await db
      .collection('users')
      .where('role', '==', 'admin')
      .get();

    await Promise.all(
      adminSnap.docs.map((adminDoc) =>
        createAndSendNotification({
          userId: adminDoc.id,
          senderId: mohaffezId,
          title: 'تحويل عمولة بانتظار التحقق',
          body: `${summary.mohaffezName} أرسل عمولة الأسبوع ${summary.weekNumber}: ${summary.commissionAmount?.toFixed(2)} ج.م`,
          type: 'commission_payment_reported',
          isRead: false,
          highPriority: true,
          data: {
            weeklyCommissionSummaryId,
            mohaffezId,
            commissionAmount: summary.commissionAmount?.toString(),
          },
        }).catch((err) =>
          // Admin FCM failure must not fail the callable for the mohaffez
          functions.logger.warn('Failed to notify admin', { adminId: adminDoc.id, err })
        )
      )
    );

    functions.logger.info('Commission payment reported by mohaffez', {
      weeklyCommissionSummaryId,
      mohaffezId,
      weekNumber: summary.weekNumber,
      amount: summary.commissionAmount,
    });

    return { success: true };
  }
);
