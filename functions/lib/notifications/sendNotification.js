"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendNotification = void 0;
// functions/src/notifications/sendNotification.ts
const functions = require("firebase-functions");
const app_check_1 = require("firebase-admin/app-check");
const admin_1 = require("../utils/admin");
/**
 * HTTP endpoint to send FCM notifications
 */
// This endpoint requires Firebase App Check to be enabled in your project
exports.sendNotification = functions.https.onRequest(async (req, res) => {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    const appCheckToken = req.header('X-Firebase-AppCheck');
    if (!appCheckToken) {
        res.status(401).json({ success: false, error: 'Missing App Check token' });
        return;
    }
    try {
        await (0, app_check_1.getAppCheck)().verifyToken(appCheckToken);
    }
    catch (error) {
        res.status(401).json({ success: false, error: 'Invalid App Check token' });
        return;
    }
    try {
        const { token, notification, data } = req.body;
        if (!token) {
            res.status(400).json({ success: false, error: 'Token is required' });
            return;
        }
        const message = {
            token: token,
            notification: {
                title: (notification === null || notification === void 0 ? void 0 : notification.title) || 'إشعار جديد',
                body: (notification === null || notification === void 0 ? void 0 : notification.body) || '',
            },
            data: data || {},
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'mohaffez_finder_channel',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };
        const response = await admin_1.messaging.send(message);
        functions.logger.info('Successfully sent message:', response);
        res.status(200).json({ success: true, messageId: response });
    }
    catch (error) {
        functions.logger.error('Error sending message:', error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
//# sourceMappingURL=sendNotification.js.map