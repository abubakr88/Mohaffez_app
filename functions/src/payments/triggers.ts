import * as functions from 'firebase-functions';
import { EventStore } from '../services/EventStore';
import { PaymentEventType } from '../types/events.types';

const eventStore = new EventStore();

/**
 * Automatically log payment creation events when a payment document is created.
 * This ensures secure event creation on the server side rather than the client.
 */
export const onPaymentCreated = functions.firestore
  .document('payments/{paymentId}')
  .onCreate(async (snap, context) => {
    const paymentId = context.params.paymentId;
    const data = snap.data();

    try {
      await eventStore.appendPaymentEvent({
        eventType: PaymentEventType.PAYMENT_CREATED,
        paymentId: paymentId,
        userId: data.studentId,
        data: {
          amount: data.amount,
          planId: data.planId,
          mohaffezId: data.mohaffezId,
          planTitle: data.planTitle,
          mohaffezName: data.mohaffezName,
        },
        metadata: {
          source: 'client',
        },
      });

      functions.logger.info('Payment event logged', { paymentId });
    } catch (error) {
      functions.logger.error('Failed to log payment event', {
        paymentId,
        error,
      });
    }
  });
