import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';
import { PaymentEventType } from '../types/events.types';

export const projectPaymentAnalytics = functions.firestore
  .document('paymentEvents/{eventId}')
  .onCreate(async (snap) => {
    const data = snap.data() as {
      paymentId?: string;
      eventType?: PaymentEventType;
      metadata?: { source?: string };
    };

    if (!data.paymentId || !data.eventType) {
      functions.logger.warn('Skipping analytics projection for invalid event', {
        eventId: snap.id,
      });
      return;
    }

    const analyticsRef = db.collection('paymentAnalytics').doc(data.paymentId);

    await analyticsRef.set(
      {
        paymentId: data.paymentId,
        lastEventType: data.eventType,
        source: data.metadata?.source ?? 'unknown',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (data.eventType === PaymentEventType.PAYMENT_COMPLETED) {
      await analyticsRef.set(
        {
          completedCount: admin.firestore.FieldValue.increment(1),
        },
        { merge: true }
      );
    }

    if (data.eventType === PaymentEventType.PAYMENT_FAILED) {
      await analyticsRef.set(
        {
          failedCount: admin.firestore.FieldValue.increment(1),
        },
        { merge: true }
      );
    }
  });