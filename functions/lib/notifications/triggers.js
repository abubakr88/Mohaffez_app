"use strict";
// functions/src/notifications/triggers.ts
Object.defineProperty(exports, "__esModule", { value: true });
exports.onSessionRequestAccepted = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin"); // ✅ أضفنا FieldValue
/**
 * Auto-create notification on session request acceptance
 *
 * IMPORTANT: This should only send "payment required" notification
 * when requiresPaymentOnAcceptance is true. For paid bookings,
 * the payment webhook sends the "session confirmed" notification.
 */
exports.onSessionRequestAccepted = functions.firestore
    .document('sessionRequests/{requestId}')
    .onUpdate(async (change, context) => {
    var _a;
    const before = change.before.data();
    const after = change.after.data();
    // Check if status changed to 'accepted'
    if (before.status !== 'accepted' && after.status === 'accepted') {
        try {
            const studentId = after.studentId;
            const mohaffezName = after.mohaffezName || 'المحفظ';
            const requiresPayment = after.requiresPaymentOnAcceptance === true;
            const isPaid = after.isPaid === true;
            // Get student's FCM token
            const studentDoc = await admin_1.db.collection('users').doc(studentId).get();
            const fcmToken = (_a = studentDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
            // Route notification based on payment status
            if (requiresPayment && !isPaid) {
                // Payment required path
                await admin_1.db.collection('notifications').add({
                    userId: studentId,
                    recipientId: studentId,
                    senderId: after.mohaffezId,
                    title: 'الدفع مطلوب!',
                    body: `${mohaffezName} قبل طلبك. الرجاء إتمام الدفع لتأكيد الجلسة.`,
                    type: 'payment_required',
                    isRead: false,
                    createdAt: admin_1.FieldValue.serverTimestamp(), // ✅ مُصلّح
                    data: {
                        requestId: context.params.requestId,
                        mohaffezId: after.mohaffezId,
                        mohaffezName: mohaffezName,
                        sessionType: after.sessionType,
                        sessionDate: after.slotDate,
                        preferredTimeSlot: after.preferredTimeSlot,
                    },
                });
                if (fcmToken) {
                    await admin_1.messaging.send({
                        token: fcmToken,
                        notification: {
                            title: 'الدفع مطلوب!',
                            body: `${mohaffezName} قبل طلبك. اضغط للدفع.`,
                        },
                        data: {
                            type: 'payment_required',
                            requestId: context.params.requestId,
                            mohaffezId: after.mohaffezId,
                            click_action: 'FLUTTER_NOTIFICATION_CLICK',
                        },
                        android: {
                            priority: 'high',
                        },
                    });
                }
                functions.logger.info('✅ Payment required notification sent for request:', context.params.requestId);
            }
            else if (isPaid) {
                // Already paid (subscription or free session)
                await admin_1.db.collection('notifications').add({
                    userId: studentId,
                    recipientId: studentId,
                    senderId: after.mohaffezId,
                    title: 'تم قبول الجلسة! ✅',
                    body: `${mohaffezName} قبل طلبك وتم تأكيد الجلسة.`,
                    type: 'session_accepted',
                    isRead: false,
                    createdAt: admin_1.FieldValue.serverTimestamp(), // ✅ مُصلّح
                    data: {
                        requestId: context.params.requestId,
                        mohaffezId: after.mohaffezId,
                        mohaffezName: mohaffezName,
                        sessionType: after.sessionType,
                        sessionDate: after.slotDate,
                        preferredTimeSlot: after.preferredTimeSlot,
                    },
                });
                if (fcmToken) {
                    await admin_1.messaging.send({
                        token: fcmToken,
                        notification: {
                            title: 'تم قبول الجلسة! ✅',
                            body: `${mohaffezName} قبل طلبك وتم تأكيد الجلسة.`,
                        },
                        data: {
                            type: 'session_accepted',
                            requestId: context.params.requestId,
                            mohaffezId: after.mohaffezId,
                            click_action: 'FLUTTER_NOTIFICATION_CLICK',
                        },
                        android: {
                            priority: 'high',
                        },
                    });
                }
                functions.logger.info('✅ Session accepted notification sent for request:', context.params.requestId);
            }
        }
        catch (error) {
            functions.logger.error('❌ Error sending notification:', error);
        }
    }
});
//# sourceMappingURL=triggers.js.map