import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';
import {
  PaymentEvent,
  PaymentEventType,
  PaymentState,
} from '../types/events.types';

export class EventStore {
  async appendPaymentEvent(
    event: Omit<PaymentEvent, 'eventId' | 'timestamp'>
  ): Promise<string> {
    const eventRef = db.collection('paymentEvents').doc();
    await eventRef.set({
      ...event,
      eventId: eventRef.id,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Payment event appended', {
      eventId: eventRef.id,
      paymentId: event.paymentId,
      eventType: event.eventType,
    });

    return eventRef.id;
  }

  async getPaymentEvents(paymentId: string): Promise<PaymentEvent[]> {
    const snapshot = await db
      .collection('paymentEvents')
      .where('paymentId', '==', paymentId)
      .orderBy('timestamp', 'asc')
      .get();

    return snapshot.docs.map((doc) => doc.data() as PaymentEvent);
  }

  async rebuildPaymentState(paymentId: string): Promise<PaymentState> {
    const events = await this.getPaymentEvents(paymentId);

    let status: PaymentState['status'] = 'pending';
    let lastEventType: PaymentEventType | undefined;
    let updatedAt: FirebaseFirestore.Timestamp | undefined;

    for (const event of events) {
      lastEventType = event.eventType;
      updatedAt = event.timestamp;

      if (event.eventType === PaymentEventType.PAYMENT_PROCESSING) {
        status = 'processing';
      }
      if (event.eventType === PaymentEventType.PAYMENT_COMPLETED) {
        status = 'completed';
      }
      if (event.eventType === PaymentEventType.PAYMENT_FAILED) {
        status = 'failed';
      }
    }

    return {
      paymentId,
      status,
      lastEventType,
      updatedAt,
      eventCount: events.length,
    };
  }

  async appendFreeSessionCompletedEvent(params: {
    paymentId: string;
    userId: string;
    promoCode?: string;
  }): Promise<string> {
    return this.appendPaymentEvent({
      eventType: PaymentEventType.PAYMENT_COMPLETED,
      paymentId: params.paymentId,
      userId: params.userId,
      data: {
        amount: 0,
        method: 'free',
        promoCode: params.promoCode ?? null,
      },
      metadata: {
        source: 'client',
      },
    });
  }
}
