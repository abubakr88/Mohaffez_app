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
  highPriority?: boolean;
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
    highPriority: params.highPriority ?? false,
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

/**
 * Fan a notification out to every admin user. Used for proactive payment/wallet
 * alerts (failed payments, wallet integrity breaches, etc.) so the admin bell
 * badges without anyone polling. Best-effort: a failed send for one admin does
 * not block the others.
 */
export async function notifyAllAdmins(
  params: Omit<CreateAndSendNotificationParams, 'userId'>
): Promise<void> {
  const adminSnap = await db.collection('users').where('role', '==', 'admin').get();
  if (adminSnap.empty) {
    functions.logger.warn('notifyAllAdmins: no admin users found', { type: params.type });
    return;
  }
  await Promise.all(
    adminSnap.docs.map((doc) =>
      createAndSendNotification({ ...params, userId: doc.id }).catch((err) =>
        functions.logger.warn('notifyAllAdmins: send failed', {
          adminId: doc.id,
          type: params.type,
          err,
        }),
      ),
    ),
  );
}

export async function createAndSendNotification(
  params: CreateAndSendNotificationParams
): Promise<void> {
  // onNotificationCreated owns FCM delivery for every persisted notification.
  // Keeping push outside the caller prevents payment/booking transactions from
  // failing or timing out because of a missing/expired device token.
  await createNotification(params);
}
