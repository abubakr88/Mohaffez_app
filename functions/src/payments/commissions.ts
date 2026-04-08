// src/payments/commissions.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';
import { createAndSendNotification } from '../utils/notificationHelpers';

function deriveWeeklySummaryId(data: FirebaseFirestore.DocumentData): string {
  const year =
    typeof data.year === 'number'
      ? data.year
      : data.weekStart instanceof admin.firestore.Timestamp
        ? data.weekStart.toDate().getFullYear()
        : new Date().getFullYear();
  return `${data.mohaffezId}_${year}_w${data.weekNumber}`;
}

async function resolveWeeklySummaryRef(inputId: string): Promise<FirebaseFirestore.DocumentReference> {
  const summaryRef = db.collection('weeklyCommissionSummaries').doc(inputId);
  const summarySnap = await summaryRef.get();
  if (summarySnap.exists) return summaryRef;

  const legacyRef = db.collection('weeklyCommissions').doc(inputId);
  const legacySnap = await legacyRef.get();
  if (!legacySnap.exists) {
    throw new functions.https.HttpsError('not-found', 'لم يتم العثور على الملخص');
  }

  const legacy = legacySnap.data()!;
  const migratedSummaryRef = db
    .collection('weeklyCommissionSummaries')
    .doc(deriveWeeklySummaryId(legacy));

  await db.runTransaction(async (tx) => {
    const migratedSnap = await tx.get(migratedSummaryRef);
    if (!migratedSnap.exists) {
      tx.set(
        migratedSummaryRef,
        {
          mohaffezId: legacy.mohaffezId,
          mohaffezName: legacy.mohaffezName ?? '',
          weekNumber: legacy.weekNumber ?? 0,
          year: legacy.year ?? new Date().getFullYear(),
          totalSessions: legacy.totalSessions ?? 0,
          totalRevenue: legacy.totalRevenue ?? 0,
          commissionAmount: legacy.commissionAmount ?? 0,
          commissionRate: legacy.commissionRate ?? 0.05,
          status: legacy.status ?? 'pending',
          weekStart: legacy.weekStart ?? null,
          weekEnd: legacy.weekEnd ?? null,
          dueDate: legacy.dueDate ?? null,
          createdAt: legacy.createdAt ?? FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          migratedFromLegacyId: legacySnap.id,
        },
        { merge: true }
      );
    }
  });

  return migratedSummaryRef;
}

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

      // FIX: Use atomic transition guard to prevent double-notify on retry
      const transitioned = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (!fresh.exists) return false;
        if (fresh.data()!.status !== 'pending') return false; // already processed
        tx.update(doc.ref, {
          status: 'overdue',
          updatedAt: FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (!transitioned) {
        processed++;
        continue; // skip notification — this commission was already handled
      }

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

  const summaryRef = await resolveWeeklySummaryRef(weeklyCommissionSummaryId);
  const resolvedSummaryId = summaryRef.id;

  // FIX: Use transaction with idempotency guard to prevent double-pay
  let summaryData: FirebaseFirestore.DocumentData | undefined;

  const committed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(summaryRef);
    if (!snap.exists) return false;
    const d = snap.data()!;
    
    // Idempotency: if already paid, return false
    if (d.status === 'paid') return false;
    
    const allowedStatuses = ['pending', 'overdue', 'pendingVerification'];
    if (!allowedStatuses.includes(d.status)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cannot mark as paid: current status is '${d.status}'.`
      );
    }
    
    tx.update(summaryRef, {
      status: 'paid',
      paidAt: FieldValue.serverTimestamp(),
      markedPaidBy: context.auth!.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    
    summaryData = d;
    return true;
  });

  if (!committed) return { success: true }; // idempotent early return
  
  const s = summaryData!;

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
    data: { weeklyCommissionSummaryId: resolvedSummaryId },
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

    const summaryRef = await resolveWeeklySummaryRef(weeklyCommissionSummaryId);
    const resolvedSummaryId = summaryRef.id;

    // BUG-FIX-C: wrap status check + update atomically to prevent TOCTOU double-notify
    let summaryForNotification: FirebaseFirestore.DocumentData | undefined;

    const committed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(summaryRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', 'لم يتم العثور على الملخص');
      }
      const d = snap.data()!;

      // Ownership check (inside transaction)
      if (d.mohaffezId !== mohaffezId) {
        throw new functions.https.HttpsError('permission-denied', 'ليس لديك صلاحية');
      }

      // Idempotency (atomic — inside transaction)
      if (d.status === 'pendingVerification' || d.status === 'paid') {
        return false;
      }

      // Precondition: only pending/overdue can be reported
      const allowed = ['pending', 'overdue'];
      if (!allowed.includes(d.status)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `لا يمكن الإبلاغ عن دفعة بحالة: ${d.status}`
        );
      }

      tx.update(summaryRef, {
        status: 'pendingVerification',
        mohaffezReportedAt: FieldValue.serverTimestamp(),
        mohaffezNote: note ?? null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      summaryForNotification = d;
      return true;
    });

    if (!committed) {
      return { success: true, message: 'تم الإرسال مسبقاً' };
    }

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
          body: `${summaryForNotification!.mohaffezName} أرسل عمولة الأسبوع ${summaryForNotification!.weekNumber}: ${summaryForNotification!.commissionAmount?.toFixed(2)} ج.م`,
          type: 'commission_payment_reported',
          isRead: false,
          highPriority: true,
          data: {
            weeklyCommissionSummaryId: resolvedSummaryId,
            mohaffezId,
            commissionAmount: summaryForNotification!.commissionAmount?.toString(),
          },
        }).catch((err) =>
          // Admin FCM failure must not fail the callable for the mohaffez
          functions.logger.warn('Failed to notify admin', { adminId: adminDoc.id, err })
        )
      )
    );

    functions.logger.info('Commission payment reported by mohaffez', {
      weeklyCommissionSummaryId: resolvedSummaryId,
      mohaffezId,
      weekNumber: summaryForNotification!.weekNumber,
      amount: summaryForNotification!.commissionAmount,
    });

    return { success: true };
  }
);
