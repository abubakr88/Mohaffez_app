// functions/src/notifications/sendNotification.ts
import * as functions from 'firebase-functions';
import { getAppCheck } from 'firebase-admin/app-check';
import admin, { messaging } from '../utils/admin';

/**
 * HTTP endpoint to send FCM notifications
 */
// This endpoint requires Firebase App Check to be enabled in your project
export const sendNotification = functions.https.onRequest(
  async (req, res) => {
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
      await getAppCheck().verifyToken(appCheckToken);
    } catch (error) {
      res.status(401).json({ success: false, error: 'Invalid App Check token' });
      return;
    }

    try {
      const { token, notification, data } = req.body;

      if (!token) {
        res.status(400).json({ success: false, error: 'Token is required' });
        return;
      }

      const message: admin.messaging.Message = {
        token: token,
        notification: {
          title: notification?.title || 'إشعار جديد',
          body: notification?.body || '',
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

      const response = await messaging.send(message);
      functions.logger.info('Successfully sent message:', response);
      res.status(200).json({ success: true, messageId: response });
    } catch (error) {
      functions.logger.error('Error sending message:', error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }
);
