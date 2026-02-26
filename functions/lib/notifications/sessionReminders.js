"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendSessionReminders = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
async function logFailedOperation(sessionId, operationType, error) {
    await admin_1.db.collection('failedOperations').add({
        operationType,
        sessionId,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: admin_1.FieldValue.serverTimestamp(),
        retryCount: 0,
        status: 'pending_retry',
    });
}
exports.sendSessionReminders = functions.pubsub
    .schedule('every 30 minutes')
    .onRun(async () => {
    // FIX-8: Switch to flag-based bounded windows to prevent overlap gaps/duplicates across runs
    const nowMs = Date.now();
    const in24hLower = admin_1.default.firestore.Timestamp.fromDate(new Date(nowMs + 23 * 60 * 60 * 1000));
    const in24hUpper = admin_1.default.firestore.Timestamp.fromDate(new Date(nowMs + 25 * 60 * 60 * 1000));
    const in1hLower = admin_1.default.firestore.Timestamp.fromDate(new Date(nowMs));
    const in1hUpper = admin_1.default.firestore.Timestamp.fromDate(new Date(nowMs + 2 * 60 * 60 * 1000));
    const twentyFourHourSnapshot = await admin_1.db
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
            const teacherName = typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';
            const studentName = typeof data.studentName === 'string' ? data.studentName : 'الطالب';
            const timeSlot = typeof data.preferredTimeSlot === 'string'
                ? data.preferredTimeSlot
                : typeof data.timeSlot === 'string'
                    ? data.timeSlot
                    : '';
            if (!studentId || !mohaffezId) {
                continue;
            }
            await (0, notificationHelpers_1.createAndSendNotification)({
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
            await (0, notificationHelpers_1.createAndSendNotification)({
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
            await admin_1.db.runTransaction(async (transaction) => {
                const fresh = await transaction.get(doc.ref);
                if (!fresh.exists) {
                    return;
                }
                const freshData = fresh.data();
                if ((freshData === null || freshData === void 0 ? void 0 : freshData.reminder24hSent) === true) {
                    return;
                }
                transaction.update(doc.ref, {
                    reminder24hSent: true,
                    reminder24hSentAt: admin_1.FieldValue.serverTimestamp(),
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
            });
        }
        catch (error) {
            functions.logger.error('Failed to process 24h session reminder', {
                sessionId: doc.id,
                error,
            });
            await logFailedOperation(doc.id, 'session_reminder_24h', error);
        }
    }
    const oneHourSnapshot = await admin_1.db
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
            const teacherName = typeof data.mohaffezName === 'string' ? data.mohaffezName : 'المحفظ';
            const studentName = typeof data.studentName === 'string' ? data.studentName : 'الطالب';
            const teacherPhone = typeof data.mohaffezPhone === 'string' ? data.mohaffezPhone : '';
            const location = typeof data.location === 'string'
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
            await (0, notificationHelpers_1.createAndSendNotification)({
                userId: studentId,
                senderId: mohaffezId,
                title: '🔔 جلستك قريباً!',
                body: studentBody,
                type: 'session_reminder_1h',
                isRead: false,
                data: reminderData,
                highPriority: true,
            });
            await (0, notificationHelpers_1.createAndSendNotification)({
                userId: mohaffezId,
                senderId: studentId,
                title: '🔔 جلستك قريباً!',
                body: teacherBody,
                type: 'session_reminder_1h',
                isRead: false,
                data: reminderData,
                highPriority: true,
            });
            await admin_1.db.runTransaction(async (transaction) => {
                const fresh = await transaction.get(doc.ref);
                if (!fresh.exists) {
                    return;
                }
                const freshData = fresh.data();
                if ((freshData === null || freshData === void 0 ? void 0 : freshData.reminder1hSent) === true) {
                    return;
                }
                transaction.update(doc.ref, {
                    reminder1hSent: true,
                    reminder1hSentAt: admin_1.FieldValue.serverTimestamp(),
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
            });
        }
        catch (error) {
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
//# sourceMappingURL=sessionReminders.js.map