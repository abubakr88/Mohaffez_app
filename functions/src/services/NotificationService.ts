import { db } from '../utils/admin';
import { NotificationPayload, serverTimestamp } from '../types/payment.types';
import { sanitizeForFirestore } from '../utils/firestoreSanitizer';

export class NotificationService {
  async send(payload: NotificationPayload): Promise<void> {
    const cleanData = sanitizeForFirestore(payload.data ?? {});
    await db.collection('notifications').add({
      recipientId: payload.recipientId,
      senderId: payload.senderId,
      type: payload.type,
      title: payload.title,
      message: payload.message,
      body: payload.message,
      data: cleanData,
      isRead: false,
      createdAt: serverTimestamp(),
    });
  }
}
