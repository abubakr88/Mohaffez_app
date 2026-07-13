import * as functions from 'firebase-functions';

import { db, FieldValue } from '../utils/admin';
import { sendFcmNotification } from '../utils/notificationHelpers';

type NotificationDoc = Record<string, unknown>;

function nonEmptyString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function pushData(
  notificationId: string,
  notification: NotificationDoc,
): Record<string, string> {
  const result: Record<string, string> = { notificationId };
  const nested = notification.data;
  const source = nested && typeof nested === 'object' && !Array.isArray(nested)
    ? nested as Record<string, unknown>
    : {};

  for (const [key, value] of Object.entries(source)) {
    if (
      typeof value === 'string' ||
      typeof value === 'number' ||
      typeof value === 'boolean'
    ) {
      result[key] = String(value);
    }
  }

  const type = nonEmptyString(notification.type);
  if (type) result.type = type;
  return result;
}

/**
 * Every in-app notification gets one best-effort FCM delivery attempt.
 * Business flows only need to write the notification document atomically with
 * their state change; push delivery stays outside those critical transactions.
 */
export const onNotificationCreated = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const notification = snapshot.data() as NotificationDoc;
    if (notification.pushHandledExternally === true) return;

    const userId =
      nonEmptyString(notification.userId) ||
      nonEmptyString(notification.recipientId);
    const title = nonEmptyString(notification.title);
    const body =
      nonEmptyString(notification.body) ||
      nonEmptyString(notification.message);

    if (!userId || !title) {
      await snapshot.ref.set({
        pushDeliveryStatus: 'invalid',
        pushDeliveryError: 'Missing recipient or title',
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return;
    }

    try {
      const config = await db.collection('systemConfig').doc('global').get();
      if (config.data()?.fcmEnabled === false) {
        await snapshot.ref.set({
          pushDeliveryStatus: 'disabled',
          pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        return;
      }

      const result = await sendFcmNotification({
        userId,
        title,
        body,
        data: pushData(context.params.notificationId, notification),
        highPriority: notification.highPriority === true,
      });

      await snapshot.ref.set({
        pushDeliveryStatus: result.sent ? 'sent' : 'unavailable',
        pushDeliveryError: result.error ?? null,
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
        ...(result.sent ? { pushSentAt: FieldValue.serverTimestamp() } : {}),
      }, { merge: true });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      functions.logger.error('Notification push dispatch failed', {
        notificationId: context.params.notificationId,
        userId,
        error: message,
      });
      await snapshot.ref.set({
        pushDeliveryStatus: 'failed',
        pushDeliveryError: message,
        pushDeliveryUpdatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });
