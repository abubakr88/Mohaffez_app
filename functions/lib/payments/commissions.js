"use strict";
// src/payments/commissions.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.mohaffezReportCommissionPayment = exports.markCommissionPaid = exports.processWeeklyCommissions = void 0;
exports.processWeeklyCommissionsNow = processWeeklyCommissionsNow;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
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
async function processWeeklyCommissionsNow() {
    const now = admin.firestore.Timestamp.now();
    const overdue = await admin_1.db
        .collection('weeklyCommissionSummaries')
        .where('status', '==', 'pending')
        .where('dueDate', '<=', now)
        .get();
    let processed = 0;
    for (const doc of overdue.docs) {
        try {
            const d = doc.data();
            // FIX: Use atomic transition guard to prevent double-notify on retry
            const transitioned = await admin_1.db.runTransaction(async (tx) => {
                const fresh = await tx.get(doc.ref);
                if (!fresh.exists)
                    return false;
                if (fresh.data().status !== 'pending')
                    return false; // already processed
                tx.update(doc.ref, {
                    status: 'overdue',
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
                return true;
            });
            if (!transitioned) {
                processed++;
                continue; // skip notification — this commission was already handled
            }
            if (d.mohaffezId && d.commissionAmount > 0) {
                await (0, notificationHelpers_1.createAndSendNotification)({
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
        }
        catch (error) {
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
exports.processWeeklyCommissions = functions.pubsub
    .schedule('every monday 09:00')
    .timeZone('Africa/Cairo')
    .onRun(async () => {
    await processWeeklyCommissionsNow();
    return null;
});
// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: admin marks a weekly summary as paid
// ─────────────────────────────────────────────────────────────────────────────
exports.markCommissionPaid = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const callerDoc = await admin_1.db.collection('users').doc(context.auth.uid).get();
    if (((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'للمسؤولين فقط');
    }
    const { weeklyCommissionSummaryId } = data;
    if (!weeklyCommissionSummaryId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
    }
    const summaryRef = admin_1.db
        .collection('weeklyCommissionSummaries')
        .doc(weeklyCommissionSummaryId);
    // FIX: Use transaction with idempotency guard to prevent double-pay
    let summaryData;
    const committed = await admin_1.db.runTransaction(async (tx) => {
        const snap = await tx.get(summaryRef);
        if (!snap.exists)
            return false;
        const d = snap.data();
        // Idempotency: if already paid, return false
        if (d.status === 'paid')
            return false;
        const allowedStatuses = ['pending', 'overdue', 'pendingVerification'];
        if (!allowedStatuses.includes(d.status)) {
            throw new functions.https.HttpsError('failed-precondition', `Cannot mark as paid: current status is '${d.status}'.`);
        }
        tx.update(summaryRef, {
            status: 'paid',
            paidAt: admin_1.FieldValue.serverTimestamp(),
            markedPaidBy: context.auth.uid,
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        summaryData = d;
        return true;
    });
    if (!committed)
        return { success: true }; // idempotent early return
    const s = summaryData;
    // Mark all individual commission records for this week as paid
    const pending = await admin_1.db
        .collection('commissions')
        .where('mohaffezId', '==', s.mohaffezId)
        .where('weekNumber', '==', s.weekNumber)
        .where('status', '==', 'pending')
        .get();
    const batch = admin_1.db.batch();
    for (const finalDoc of pending.docs) {
        batch.update(finalDoc.ref, {
            status: 'paid',
            paidAt: admin_1.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
    await (0, notificationHelpers_1.createAndSendNotification)({
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
exports.mohaffezReportCommissionPayment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const mohaffezId = context.auth.uid;
    const { weeklyCommissionSummaryId, note } = data;
    if (!weeklyCommissionSummaryId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
    }
    const summaryRef = admin_1.db
        .collection('weeklyCommissionSummaries')
        .doc(weeklyCommissionSummaryId);
    // BUG-FIX-C: wrap status check + update atomically to prevent TOCTOU double-notify
    let summaryForNotification;
    const committed = await admin_1.db.runTransaction(async (tx) => {
        const snap = await tx.get(summaryRef);
        if (!snap.exists) {
            throw new functions.https.HttpsError('not-found', 'لم يتم العثور على الملخص');
        }
        const d = snap.data();
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
            throw new functions.https.HttpsError('failed-precondition', `لا يمكن الإبلاغ عن دفعة بحالة: ${d.status}`);
        }
        tx.update(summaryRef, {
            status: 'pendingVerification',
            mohaffezReportedAt: admin_1.FieldValue.serverTimestamp(),
            mohaffezNote: note !== null && note !== void 0 ? note : null,
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        summaryForNotification = d;
        return true;
    });
    if (!committed) {
        return { success: true, message: 'تم الإرسال مسبقاً' };
    }
    // Fan-out notification to all admin users
    const adminSnap = await admin_1.db
        .collection('users')
        .where('role', '==', 'admin')
        .get();
    await Promise.all(adminSnap.docs.map((adminDoc) => {
        var _a, _b;
        return (0, notificationHelpers_1.createAndSendNotification)({
            userId: adminDoc.id,
            senderId: mohaffezId,
            title: 'تحويل عمولة بانتظار التحقق',
            body: `${summaryForNotification.mohaffezName} أرسل عمولة الأسبوع ${summaryForNotification.weekNumber}: ${(_a = summaryForNotification.commissionAmount) === null || _a === void 0 ? void 0 : _a.toFixed(2)} ج.م`,
            type: 'commission_payment_reported',
            isRead: false,
            highPriority: true,
            data: {
                weeklyCommissionSummaryId,
                mohaffezId,
                commissionAmount: (_b = summaryForNotification.commissionAmount) === null || _b === void 0 ? void 0 : _b.toString(),
            },
        }).catch((err) => 
        // Admin FCM failure must not fail the callable for the mohaffez
        functions.logger.warn('Failed to notify admin', { adminId: adminDoc.id, err }));
    }));
    functions.logger.info('Commission payment reported by mohaffez', {
        weeklyCommissionSummaryId,
        mohaffezId,
        weekNumber: summaryForNotification.weekNumber,
        amount: summaryForNotification.commissionAmount,
    });
    return { success: true };
});
//# sourceMappingURL=commissions.js.map