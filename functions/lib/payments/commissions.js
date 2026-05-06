"use strict";
// src/payments/commissions.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.rejectCommissionPayment = exports.mohaffezReportCommissionPayment = exports.markCommissionPaid = exports.processWeeklyCommissions = void 0;
exports.processWeeklyCommissionsNow = processWeeklyCommissionsNow;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
function deriveWeeklySummaryId(data) {
    const year = typeof data.year === 'number'
        ? data.year
        : data.weekStart instanceof admin.firestore.Timestamp
            ? data.weekStart.toDate().getFullYear()
            : new Date().getFullYear();
    return `${data.mohaffezId}_${year}_w${data.weekNumber}`;
}
async function resolveWeeklySummaryRef(inputId) {
    const summaryRef = admin_1.db.collection('weeklyCommissionSummaries').doc(inputId);
    const summarySnap = await summaryRef.get();
    if (summarySnap.exists)
        return summaryRef;
    const legacyRef = admin_1.db.collection('weeklyCommissions').doc(inputId);
    const legacySnap = await legacyRef.get();
    if (!legacySnap.exists) {
        throw new functions.https.HttpsError('not-found', 'لم يتم العثور على الملخص');
    }
    const legacy = legacySnap.data();
    const migratedSummaryRef = admin_1.db
        .collection('weeklyCommissionSummaries')
        .doc(deriveWeeklySummaryId(legacy));
    await admin_1.db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m;
        const migratedSnap = await tx.get(migratedSummaryRef);
        if (!migratedSnap.exists) {
            tx.set(migratedSummaryRef, {
                mohaffezId: legacy.mohaffezId,
                mohaffezName: (_a = legacy.mohaffezName) !== null && _a !== void 0 ? _a : '',
                weekNumber: (_b = legacy.weekNumber) !== null && _b !== void 0 ? _b : 0,
                year: (_c = legacy.year) !== null && _c !== void 0 ? _c : new Date().getFullYear(),
                totalSessions: (_d = legacy.totalSessions) !== null && _d !== void 0 ? _d : 0,
                totalRevenue: (_e = legacy.totalRevenue) !== null && _e !== void 0 ? _e : 0,
                commissionAmount: (_f = legacy.commissionAmount) !== null && _f !== void 0 ? _f : 0,
                commissionRate: (_g = legacy.commissionRate) !== null && _g !== void 0 ? _g : 0.05,
                status: (_h = legacy.status) !== null && _h !== void 0 ? _h : 'pending',
                weekStart: (_j = legacy.weekStart) !== null && _j !== void 0 ? _j : null,
                weekEnd: (_k = legacy.weekEnd) !== null && _k !== void 0 ? _k : null,
                dueDate: (_l = legacy.dueDate) !== null && _l !== void 0 ? _l : null,
                createdAt: (_m = legacy.createdAt) !== null && _m !== void 0 ? _m : admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
                migratedFromLegacyId: legacySnap.id,
            }, { merge: true });
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
    var _a, _b;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const callerDoc = await admin_1.db.collection('users').doc(context.auth.uid).get();
    if (((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'للمسؤولين فقط');
    }
    // Backwards-compat: old client builds sent the param as `commissionId`.
    const payload = data;
    const weeklyCommissionSummaryId = (_b = payload.weeklyCommissionSummaryId) !== null && _b !== void 0 ? _b : payload.commissionId;
    if (!weeklyCommissionSummaryId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
    }
    if (payload.paidAmount !== undefined &&
        (typeof payload.paidAmount !== 'number' || payload.paidAmount < 0)) {
        throw new functions.https.HttpsError('invalid-argument', 'المبلغ المدفوع غير صحيح');
    }
    const summaryRef = await resolveWeeklySummaryRef(weeklyCommissionSummaryId);
    const resolvedSummaryId = summaryRef.id;
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
        // Accept both legacy 'awaiting_confirmation' and current 'pendingVerification'
        const allowedStatuses = [
            'pending',
            'overdue',
            'pendingVerification',
            'awaiting_confirmation',
        ];
        if (!allowedStatuses.includes(d.status)) {
            throw new functions.https.HttpsError('failed-precondition', `Cannot mark as paid: current status is '${d.status}'.`);
        }
        const updates = {
            status: 'paid',
            paidAt: admin_1.FieldValue.serverTimestamp(),
            markedPaidBy: context.auth.uid,
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        };
        if (payload.paidAmount !== undefined)
            updates.paidAmount = payload.paidAmount;
        if (payload.adminNote !== undefined && payload.adminNote.length > 0) {
            updates.adminConfirmationNote = payload.adminNote;
        }
        tx.update(summaryRef, updates);
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
exports.mohaffezReportCommissionPayment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const mohaffezId = context.auth.uid;
    const { weeklyCommissionSummaryId, note, paymentReference, paymentMethod, paidAmount } = data;
    if (!weeklyCommissionSummaryId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
    }
    if (paidAmount !== undefined &&
        (typeof paidAmount !== 'number' || paidAmount <= 0)) {
        throw new functions.https.HttpsError('invalid-argument', 'المبلغ المرسل غير صحيح');
    }
    const summaryRef = await resolveWeeklySummaryRef(weeklyCommissionSummaryId);
    const resolvedSummaryId = summaryRef.id;
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
        if (d.status === 'pendingVerification' ||
            d.status === 'awaiting_confirmation' ||
            d.status === 'paid') {
            return false;
        }
        // Precondition: only pending/overdue can be reported
        const allowed = ['pending', 'overdue'];
        if (!allowed.includes(d.status)) {
            throw new functions.https.HttpsError('failed-precondition', `لا يمكن الإبلاغ عن دفعة بحالة: ${d.status}`);
        }
        const updates = {
            status: 'pendingVerification',
            mohaffezReportedAt: admin_1.FieldValue.serverTimestamp(),
            mohaffezNote: note !== null && note !== void 0 ? note : null,
            paymentReference: paymentReference !== null && paymentReference !== void 0 ? paymentReference : null,
            paymentMethod: paymentMethod !== null && paymentMethod !== void 0 ? paymentMethod : null,
            // Clear any previous rejection so a fresh report starts clean
            rejectionReason: admin_1.FieldValue.delete(),
            rejectedAt: admin_1.FieldValue.delete(),
            rejectedBy: admin_1.FieldValue.delete(),
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        };
        if (paidAmount !== undefined)
            updates.reportedAmount = paidAmount;
        tx.update(summaryRef, updates);
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
                weeklyCommissionSummaryId: resolvedSummaryId,
                mohaffezId,
                commissionAmount: (_b = summaryForNotification.commissionAmount) === null || _b === void 0 ? void 0 : _b.toString(),
            },
        }).catch((err) => 
        // Admin FCM failure must not fail the callable for the mohaffez
        functions.logger.warn('Failed to notify admin', { adminId: adminDoc.id, err }));
    }));
    functions.logger.info('Commission payment reported by mohaffez', {
        weeklyCommissionSummaryId: resolvedSummaryId,
        mohaffezId,
        weekNumber: summaryForNotification.weekNumber,
        amount: summaryForNotification.commissionAmount,
    });
    return { success: true };
});
// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: admin rejects a mohaffez's commission payment claim
// Bounces the summary back to 'pending' (or 'overdue' if still past due) and
// notifies the mohaffez so they can correct + resubmit.
// ─────────────────────────────────────────────────────────────────────────────
exports.rejectCommissionPayment = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }
    const callerDoc = await admin_1.db.collection('users').doc(context.auth.uid).get();
    if (((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'للمسؤولين فقط');
    }
    const { weeklyCommissionSummaryId, reason } = data;
    if (!weeklyCommissionSummaryId) {
        throw new functions.https.HttpsError('invalid-argument', 'معرّف الملخص مطلوب');
    }
    if (!reason || typeof reason !== 'string' || reason.trim().length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'سبب الرفض مطلوب');
    }
    const summaryRef = await resolveWeeklySummaryRef(weeklyCommissionSummaryId);
    const resolvedSummaryId = summaryRef.id;
    let summaryData;
    const committed = await admin_1.db.runTransaction(async (tx) => {
        const snap = await tx.get(summaryRef);
        if (!snap.exists)
            return false;
        const d = snap.data();
        // Only a claim that's currently awaiting verification can be rejected.
        const allowed = ['pendingVerification', 'awaiting_confirmation'];
        if (!allowed.includes(d.status)) {
            throw new functions.https.HttpsError('failed-precondition', `لا يمكن رفض دفعة بحالة: ${d.status}`);
        }
        // If due date has passed, return to 'overdue', otherwise 'pending'.
        const now = admin.firestore.Timestamp.now();
        const due = d.dueDate;
        const nextStatus = due && due.toMillis() <= now.toMillis() ? 'overdue' : 'pending';
        tx.update(summaryRef, {
            status: nextStatus,
            rejectionReason: reason.trim(),
            rejectedAt: admin_1.FieldValue.serverTimestamp(),
            rejectedBy: context.auth.uid,
            // Preserve the prior reported amount/reference for audit but clear
            // the active claim flag so the mohaffez can re-report.
            mohaffezReportedAt: admin_1.FieldValue.delete(),
            updatedAt: admin_1.FieldValue.serverTimestamp(),
        });
        summaryData = d;
        return true;
    });
    if (!committed)
        return { success: true };
    const s = summaryData;
    if (s.mohaffezId) {
        await (0, notificationHelpers_1.createAndSendNotification)({
            userId: s.mohaffezId,
            senderId: context.auth.uid,
            title: 'رُفض تأكيد العمولة',
            body: `لم يتم قبول إثبات الدفع للأسبوع ${s.weekNumber}. السبب: ${reason.trim()}`,
            type: 'commission_payment_rejected',
            isRead: false,
            highPriority: true,
            data: {
                weeklyCommissionSummaryId: resolvedSummaryId,
                reason: reason.trim(),
            },
        }).catch((err) => functions.logger.warn('Failed to notify mohaffez of rejection', {
            mohaffezId: s.mohaffezId,
            err,
        }));
    }
    functions.logger.info('Commission payment rejected by admin', {
        weeklyCommissionSummaryId: resolvedSummaryId,
        adminId: context.auth.uid,
        reason: reason.trim(),
    });
    return { success: true };
});
//# sourceMappingURL=commissions.js.map