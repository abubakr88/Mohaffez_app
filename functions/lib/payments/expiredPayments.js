"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkExpiredPayments = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
async function logFailedOperation(requestId, error) {
    await admin_1.db.collection('failedOperations').add({
        operationType: 'expired_payment_processing',
        requestId,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: admin_1.FieldValue.serverTimestamp(),
        retryCount: 0,
        status: 'pending_retry',
    });
}
async function sendExpirationNotifications(request) {
    var _a, _b;
    if (request.studentId) {
        await (0, notificationHelpers_1.createAndSendNotification)({
            userId: request.studentId,
            senderId: request.mohaffezId,
            title: 'انتهت مهلة الدفع ⏰',
            body: `انتهت مهلة دفع جلستك مع ${(_a = request.mohaffezName) !== null && _a !== void 0 ? _a : ''}. يمكنك طلب موعد جديد.`,
            type: 'paymentexpired',
            isRead: false,
            highPriority: true,
            data: { requestId: request.id },
        });
    }
    if (request.mohaffezId) {
        await (0, notificationHelpers_1.createAndSendNotification)({
            userId: request.mohaffezId,
            senderId: request.studentId,
            title: 'انتهت مهلة دفع الطالب',
            body: `${(_b = request.studentName) !== null && _b !== void 0 ? _b : 'الطالب'} لم يدفع في الوقت المحدد. الموعد ملغي.`,
            type: 'paymentexpired',
            isRead: false,
            highPriority: false,
            data: { requestId: request.id },
        });
    }
}
exports.checkExpiredPayments = functions.pubsub
    .schedule('every 1 hours')
    .onRun(async () => {
    const now = admin_1.default.firestore.Timestamp.now();
    const expiredRequests = await admin_1.db
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
            // FIX-2: Skip already-expired docs and atomically transition awaitingpayment -> expired
            if (data.status === 'expired') {
                continue;
            }
            const transitioned = await admin_1.db.runTransaction(async (transaction) => {
                const fresh = await transaction.get(doc.ref);
                if (!fresh.exists) {
                    return false;
                }
                const freshData = fresh.data();
                if ((freshData === null || freshData === void 0 ? void 0 : freshData.status) !== 'awaitingpayment') {
                    return false;
                }
                transaction.update(doc.ref, {
                    status: 'expired',
                    expiredAt: admin_1.FieldValue.serverTimestamp(),
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
                return true;
            });
            if (!transitioned) {
                continue;
            }
            await sendExpirationNotifications({
                id: doc.id,
                studentId: data.studentId,
                mohaffezId: data.mohaffezId,
                mohaffezName: data.mohaffezName,
                studentName: data.studentName,
            });
        }
        catch (error) {
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
//# sourceMappingURL=expiredPayments.js.map