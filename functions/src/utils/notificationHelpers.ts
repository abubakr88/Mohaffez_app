import * as functions from 'firebase-functions';
import { db, messaging, FieldValue } from './admin';

interface CreateNotificationParams {
  userId: string;
  senderId?: string | null;
  title: string;
  body: string;
  type: string;
  isRead?: boolean;
  data?: Record<string, unknown>;
}

interface SendFcmNotificationParams {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  highPriority?: boolean;
}

interface CreateAndSendNotificationParams extends CreateNotificationParams {
  highPriority?: boolean;
}

function sanitizeNotificationData(
  data?: Record<string, unknown>
): Record<string, unknown> {
  return Object.entries(data ?? {}).reduce<Record<string, unknown>>(
    (acc, [key, value]) => {
      if (value !== undefined) {
        acc[key] = value;
      }
      return acc;
    },
    {}
  );
}

export async function getUserFcmToken(userId: string): Promise<string | null> {
  const userDoc = await db.collection('users').doc(userId).get();
  const token = userDoc.data()?.fcmToken;
  return typeof token === 'string' && token.trim().length > 0 ? token : null;
}

export async function createNotification(
  params: CreateNotificationParams
): Promise<void> {
  const data = sanitizeNotificationData(params.data);

  await db.collection('notifications').add({
    userId: params.userId,
    recipientId: params.userId,
    senderId: params.senderId ?? null,
    title: params.title,
    body: params.body,
    type: params.type,
    isRead: params.isRead ?? false,
    createdAt: FieldValue.serverTimestamp(),
    data,
    ...data,
  });
}

export async function sendFcmNotification(
  params: SendFcmNotificationParams
): Promise<{ sent: boolean; error?: string }> {
  // FIX-7: Return explicit FCM send status so callers can detect push delivery failures
  const token = await getUserFcmToken(params.userId);
  if (!token) {
    return { sent: false, error: 'Missing FCM token' };
  }

  const stringData = Object.entries(params.data ?? {}).reduce<Record<string, string>>(
    (acc, [key, value]) => {
      if (value !== undefined && value !== null) {
        acc[key] = String(value);
      }
      return acc;
    },
    {}
  );

  try {
    await messaging.send({
      token,
      notification: {
        title: params.title,
        body: params.body,
      },
      data: {
        ...stringData,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: params.highPriority ? 'high' : 'normal',
      },
    });
    return { sent: true };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    functions.logger.error('Failed to send FCM notification', {
      userId: params.userId,
      error: message,
    });
    return { sent: false, error: message };
  }
}

export async function createAndSendNotification(
  params: CreateAndSendNotificationParams
): Promise<void> {
  const data = sanitizeNotificationData(params.data);

  await createNotification(params);
  const result = await sendFcmNotification({
    userId: params.userId,
    title: params.title,
    body: params.body,
    data: Object.entries(data).reduce<Record<string, string>>(
      (acc, [key, value]) => {
        if (value !== null) {
          acc[key] = String(value);
        }
        return acc;
      },
      {}
    ),
    highPriority: params.highPriority,
  });

  if (result.sent === false) {
    functions.logger.warn('FCM push failed', { userId: params.userId, error: result.error });
  }
}
