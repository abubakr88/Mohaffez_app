"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPaymentDeadlineReminders = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
async function logFailedOperation(requestId, error) {
    await admin_1.db.collection('failedOperations').add({
        operationType: 'payment_deadline_reminder',
        requestId,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: admin_1.FieldValue.serverTimestamp(),
        retryCount: 0,
        status: 'pending_retry',
    });
}
exports.sendPaymentDeadlineReminders = functions.pubsub
    .schedule('every 1 hours')
    .onRun(async () => {
    const now = admin_1.default.firestore.Timestamp.now();
    const inTwoHours = admin_1.default.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000));
    const snapshot = await admin_1.db
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
            const teacherName = typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';
            if (!studentId) {
                continue;
            }
            await (0, notificationHelpers_1.createAndSendNotification)({
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
            await doc.ref.update({
                reminderSent: true,
                reminderSentAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
            });
        }
        catch (error) {
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
//# sourceMappingURL=paymentDeadlineReminders.js.map