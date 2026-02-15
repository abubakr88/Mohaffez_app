"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendSessionReminders = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const notificationHelpers_1 = require("../utils/notificationHelpers");
function toTimestampRange(hoursFromNow) {
    const center = Date.now() + hoursFromNow * 60 * 60 * 1000;
    const start = new Date(center - 30 * 60 * 1000);
    const end = new Date(center + 30 * 60 * 1000);
    return {
        start: admin_1.default.firestore.Timestamp.fromDate(start),
        end: admin_1.default.firestore.Timestamp.fromDate(end),
    };
}
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
    const in24h = toTimestampRange(24);
    const in1h = toTimestampRange(1);
    const twentyFourHourSnapshot = await admin_1.db
        .collection('hafizSessions')
        .where('status', '==', 'accepted')
        .where('sessionDate', '>=', in24h.start)
        .where('sessionDate', '<=', in24h.end)
        .where('reminder24hSent', '==', false)
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
            await doc.ref.update({
                reminder24hSent: true,
                reminder24hSentAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
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
        .where('sessionDate', '>=', in1h.start)
        .where('sessionDate', '<=', in1h.end)
        .where('reminder1hSent', '==', false)
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
            await doc.ref.update({
                reminder1hSent: true,
                reminder1hSentAt: admin_1.FieldValue.serverTimestamp(),
                updatedAt: admin_1.FieldValue.serverTimestamp(),
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