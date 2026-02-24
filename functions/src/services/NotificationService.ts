import { db } from '../utils/admin';
import { NotificationPayload, serverTimestamp } from '../types/payment.types';

export class NotificationService {
  async send(payload: NotificationPayload): Promise<void> {
    await db.collection('notifications').add({
      recipientId: payload.recipientId,
      senderId: payload.senderId,
      type: payload.type,
      title: payload.title,
      message: payload.message,
      body: payload.message,
      data: payload.data ?? {},
      isRead: false,
      createdAt: serverTimestamp(),
    });
  }
}
