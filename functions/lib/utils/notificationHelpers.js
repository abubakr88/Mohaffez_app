"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getUserFcmToken = getUserFcmToken;
exports.createNotification = createNotification;
exports.sendFcmNotification = sendFcmNotification;
exports.createAndSendNotification = createAndSendNotification;
const functions = require("firebase-functions");
const admin_1 = require("./admin");
function sanitizeNotificationData(data) {
    return Object.entries(data !== null && data !== void 0 ? data : {}).reduce((acc, [key, value]) => {
        if (value !== undefined) {
            acc[key] = value;
        }
        return acc;
    }, {});
}
async function getUserFcmToken(userId) {
    var _a;
    const userDoc = await admin_1.db.collection('users').doc(userId).get();
    const token = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
    return typeof token === 'string' && token.trim().length > 0 ? token : null;
}
async function createNotification(params) {
    var _a, _b;
    const data = sanitizeNotificationData(params.data);
    await admin_1.db.collection('notifications').add(Object.assign({ userId: params.userId, recipientId: params.userId, senderId: (_a = params.senderId) !== null && _a !== void 0 ? _a : null, title: params.title, body: params.body, type: params.type, isRead: (_b = params.isRead) !== null && _b !== void 0 ? _b : false, createdAt: admin_1.FieldValue.serverTimestamp(), data }, data));
}
async function sendFcmNotification(params) {
    var _a;
    const token = await getUserFcmToken(params.userId);
    if (!token) {
        return;
    }
    const stringData = Object.entries((_a = params.data) !== null && _a !== void 0 ? _a : {}).reduce((acc, [key, value]) => {
        if (value !== undefined && value !== null) {
            acc[key] = String(value);
        }
        return acc;
    }, {});
    try {
        await admin_1.messaging.send({
            token,
            notification: {
                title: params.title,
                body: params.body,
            },
            data: Object.assign(Object.assign({}, stringData), { click_action: 'FLUTTER_NOTIFICATION_CLICK' }),
            android: {
                priority: params.highPriority ? 'high' : 'normal',
            },
        });
    }
    catch (error) {
        functions.logger.error('Failed to send FCM notification', {
            userId: params.userId,
            error: error instanceof Error ? error.message : 'Unknown error',
        });
    }
}
async function createAndSendNotification(params) {
    const data = sanitizeNotificationData(params.data);
    await createNotification(params);
    await sendFcmNotification({
        userId: params.userId,
        title: params.title,
        body: params.body,
        data: Object.entries(data).reduce((acc, [key, value]) => {
            if (value !== null) {
                acc[key] = String(value);
            }
            return acc;
        }, {}),
        highPriority: params.highPriority,
    });
}
//# sourceMappingURL=notificationHelpers.js.map