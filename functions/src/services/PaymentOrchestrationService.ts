import * as functions from 'firebase-functions';
import { db } from '../utils/admin';
import {
  PaymentContext,
  PaymentResult,
  serverTimestamp,
} from '../types/payment.types';
import {
  confirmBookingAfterPayment,
  consumeSubscriptionAndCreateSession,
  createSubscriptionFromPayment,
} from '../payments/handlers';
import { EventStore } from './EventStore';
import { PaymentEventType } from '../types/events.types';
import { NotificationService } from './NotificationService';

export class PaymentOrchestrationService {
  constructor(
    private readonly eventStore: EventStore,
    private readonly notificationService: NotificationService
  ) {}

  async processSuccessfulPayment(context: PaymentContext): Promise<PaymentResult> {
    await this.eventStore.appendPaymentEvent({
      eventType: PaymentEventType.WEBHOOK_RECEIVED,
      paymentId: context.paymentId,
      userId: context.payment.studentId,
      data: {
        transactionId: context.transactionId,
      },
      metadata: {
        source: 'webhook',
        transactionId: context.transactionId,
        ipAddress: context.ipAddress,
      },
    });

    let result: PaymentResult;

    try {
      if (context.metadata.confirmBooking && context.metadata.requestId) {
        result = await this.handleBookingConfirmation(context);
      } else if (context.metadata.subscriptionId) {
        result = await this.handleSubscriptionConsumption(context);
      } else {
        result = await this.handleSubscriptionCreation(context);
      }

      await db.collection('payments').doc(context.paymentId).update({
        status: 'completed',
        paidAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        idempotencyKey: `${context.paymentId}_${context.transactionId}`,
        processedAt: serverTimestamp(),
      });

      await this.eventStore.appendPaymentEvent({
        eventType: PaymentEventType.PAYMENT_COMPLETED,
        paymentId: context.paymentId,
        userId: context.payment.studentId,
        data: {
          sessionId: result.sessionId,
          subscriptionId: result.subscriptionId,
        },
        metadata: {
          source: 'webhook',
          transactionId: context.transactionId,
          ipAddress: context.ipAddress,
        },
      });

      functions.logger.info('Payment orchestration completed', {
        paymentId: context.paymentId,
        sessionId: result.sessionId,
        subscriptionId: result.subscriptionId,
      });

      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown payment processing error';

      await db.collection('payments').doc(context.paymentId).update({
        status: 'failed',
        failureReason: message,
        updatedAt: serverTimestamp(),
      });

      await this.eventStore.appendPaymentEvent({
        eventType: PaymentEventType.PAYMENT_FAILED,
        paymentId: context.paymentId,
        userId: context.payment.studentId,
        data: {
          error: message,
        },
        metadata: {
          source: 'webhook',
          transactionId: context.transactionId,
          ipAddress: context.ipAddress,
        },
      });

      functions.logger.error('Payment orchestration failed', {
        paymentId: context.paymentId,
        transactionId: context.transactionId,
        error: message,
      });

      return {
        success: false,
        error: message,
      };
    }
  }

  private async handleBookingConfirmation(context: PaymentContext): Promise<PaymentResult> {
    const requestId = context.metadata.requestId;
    const sessionDetails = context.metadata.sessionDetails;

    if (!requestId || !sessionDetails || typeof sessionDetails !== 'object') {
      throw new Error('Missing booking confirmation metadata');
    }

    const bookingResult = await confirmBookingAfterPayment(
      requestId,
      sessionDetails as Record<string, unknown>,
      context.payment,
      context.transactionId
    );

    await this.removeSlotFromAvailability({
      mohaffezId: context.payment.mohaffezId,
      slotDate: (sessionDetails as Record<string, unknown>).slotDate,
      timeSlot: (sessionDetails as Record<string, unknown>).preferredTimeSlot,
      sessionType: (sessionDetails as Record<string, unknown>).sessionType,
    });

    await this.notificationService.send({
      recipientId: context.payment.studentId,
      senderId: context.payment.mohaffezId,
      type: 'session_confirmed',
      title: 'Session Confirmed',
      message: `Your booking with ${context.payment.mohaffezName} is confirmed after payment.`,
      data: {
        sessionId: bookingResult.sessionId,
        requestId,
        mohaffezId: context.payment.mohaffezId,
      },
    });

    await this.eventStore.appendPaymentEvent({
      eventType: PaymentEventType.BOOKING_CONFIRMED,
      paymentId: context.paymentId,
      userId: context.payment.studentId,
      data: {
        requestId,
        sessionId: bookingResult.sessionId,
      },
      metadata: {
        source: 'webhook',
        transactionId: context.transactionId,
      },
    });

    return {
      success: true,
      sessionId: bookingResult.sessionId,
    };
  }

  private async handleSubscriptionCreation(context: PaymentContext): Promise<PaymentResult> {
    const subscriptionResult = await createSubscriptionFromPayment(
      context.payment,
      context.transactionId
    );

    await db.collection('payments').doc(context.paymentId).update({
      subscriptionId: subscriptionResult.subscriptionId,
      updatedAt: serverTimestamp(),
    });

    await this.notificationService.send({
      recipientId: context.payment.studentId,
      senderId: context.payment.mohaffezId,
      type: 'subscription_created',
      title: 'Subscription Activated',
      message: 'Your subscription purchase was completed successfully.',
      data: {
        subscriptionId: subscriptionResult.subscriptionId,
        mohaffezId: context.payment.mohaffezId,
      },
    });

    await this.eventStore.appendPaymentEvent({
      eventType: PaymentEventType.SUBSCRIPTION_CREATED,
      paymentId: context.paymentId,
      userId: context.payment.studentId,
      data: {
        subscriptionId: subscriptionResult.subscriptionId,
      },
      metadata: {
        source: 'webhook',
        transactionId: context.transactionId,
      },
    });

    return {
      success: true,
      subscriptionId: subscriptionResult.subscriptionId,
    };
  }

  private async handleSubscriptionConsumption(context: PaymentContext): Promise<PaymentResult> {
    const subscriptionId = context.metadata.subscriptionId;
    if (!subscriptionId) {
      throw new Error('Missing subscriptionId in payment metadata');
    }

    const consumptionResult = await consumeSubscriptionAndCreateSession(
      subscriptionId,
      context.payment,
      context.transactionId,
      context.metadata
    );

    if (consumptionResult.sessionId) {
      await this.removeSlotFromAvailability({
        mohaffezId: context.payment.mohaffezId,
        slotDate: context.metadata.sessionDetails?.slotDate,
        timeSlot: context.metadata.sessionDetails?.preferredTimeSlot,
        sessionType: context.metadata.sessionDetails?.sessionType,
      });
    }

    await this.notificationService.send({
      recipientId: context.payment.studentId,
      senderId: context.payment.mohaffezId,
      type: 'subscription_session_consumed',
      title: 'Session Booked',
      message: 'A session was booked using your active subscription.',
      data: {
        subscriptionId,
        sessionId: consumptionResult.sessionId,
        remainingSessions: consumptionResult.remainingSessions,
      },
    });

    return {
      success: true,
      sessionId: consumptionResult.sessionId,
      subscriptionId,
    };
  }

  private async removeSlotFromAvailability(params: {
    mohaffezId: string;
    slotDate: unknown;
    timeSlot: unknown;
    sessionType: unknown;
  }): Promise<void> {
    const { mohaffezId, slotDate, timeSlot, sessionType } = params;

    if (
      typeof mohaffezId !== 'string' ||
      !slotDate ||
      typeof timeSlot !== 'string' ||
      typeof sessionType !== 'string'
    ) {
      functions.logger.warn('Skipping slot removal: invalid booking metadata', params);
      return;
    }

    const slotTimestamp = slotDate as FirebaseFirestore.Timestamp;
    const date = slotTimestamp.toDate();
    const jsDay = date.getDay();
    const dayOfWeek = jsDay === 0 ? 7 : jsDay;

    const availabilitySnapshot = await db
      .collection('users')
      .doc(mohaffezId)
      .collection('availability')
      .where('dayOfWeek', '==', dayOfWeek)
      .limit(1)
      .get();

    if (availabilitySnapshot.empty) {
      functions.logger.warn('Availability document not found for slot removal', {
        mohaffezId,
        dayOfWeek,
      });
      return;
    }

    const availabilityDoc = availabilitySnapshot.docs[0];
    const data = availabilityDoc.data() as { timeSlots?: Array<Record<string, unknown>> };
    const timeSlots = [...(data.timeSlots ?? [])];

    let updated = false;
    for (const slot of timeSlots) {
      const slotTime = `${slot.startTime ?? ''}-${slot.endTime ?? ''}`;
      if (
        slotTime === timeSlot &&
        slot.sessionType === sessionType &&
        slot.enabled === true
      ) {
        slot.enabled = false;
        updated = true;
        break;
      }
    }

    if (!updated) {
      functions.logger.info('Slot not changed during post-payment removal', {
        mohaffezId,
        timeSlot,
        sessionType,
      });
      return;
    }

    await availabilityDoc.ref.update({
      timeSlots,
      updatedAt: serverTimestamp(),
    });
  }
}
