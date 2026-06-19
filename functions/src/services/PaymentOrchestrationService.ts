// src/services/PaymentOrchestrationService.ts

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
  SlotInfo,
} from '../payments/handlers';
import { EventStore }          from './EventStore';
import { PaymentEventType }    from '../types/events.types';
import { NotificationService } from './NotificationService';

// ─────────────────────────────────────────────────────────────────────────────

export class PaymentOrchestrationService {
  constructor(
    private readonly eventStore:          EventStore,
    private readonly notificationService: NotificationService,
  ) {}

  // ─── Public entry point ───────────────────────────────────────────────────

  async processSuccessfulPayment(context: PaymentContext): Promise<PaymentResult> {
    await this.eventStore.appendPaymentEvent({
      eventType: PaymentEventType.WEBHOOK_RECEIVED,
      paymentId: context.paymentId,
      userId:    context.payment.studentId,
      data:      { transactionId: context.transactionId },
      metadata:  {
        source:        'webhook',
        transactionId: context.transactionId,
        ipAddress:     context.ipAddress,
      },
    });

    let result: PaymentResult | undefined;

    try {
      if (context.metadata.confirmBooking && context.metadata.requestId) {
        result = await this.handleBookingConfirmation(context);
      } else if (context.metadata.subscriptionId) {
        result = await this.handleSubscriptionConsumption(context);
      } else {
        result = await this.handleSubscriptionCreation(context);
      }

      await this.eventStore.appendPaymentEvent({
        eventType: PaymentEventType.PAYMENT_COMPLETED,
        paymentId: context.paymentId,
        userId:    context.payment.studentId,
        data: {
          sessionId:      result.sessionId ?? null,
          subscriptionId: result.subscriptionId ?? null,
        },
        metadata: {
          source:        'webhook',
          transactionId: context.transactionId,
          ipAddress:     context.ipAddress,
        },
      });

      functions.logger.info('Payment orchestration completed', {
        paymentId:      context.paymentId,
        sessionId:      result.sessionId,
        subscriptionId: result.subscriptionId,
      });

      return result;

    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown payment processing error';

      const paymentAfterError = await db
        .collection('payments')
        .doc(context.paymentId)
        .get()
        .catch(() => null);
      const paymentStatus = paymentAfterError?.data()?.status;

      if (paymentStatus === 'completed') {
        functions.logger.error('Payment post-completion side effect failed', {
          paymentId:     context.paymentId,
          transactionId: context.transactionId,
          error:         message,
        });
        return result ?? { success: true };
      }

      await db.collection('payments').doc(context.paymentId).update({
        status:        'failed',
        failureReason: message,
        updatedAt:     serverTimestamp(),
      });

      await this.eventStore.appendPaymentEvent({
        eventType: PaymentEventType.PAYMENT_FAILED,
        paymentId: context.paymentId,
        userId:    context.payment.studentId,
        data:      { error: message },
        metadata: {
          source:        'webhook',
          transactionId: context.transactionId,
          ipAddress:     context.ipAddress,
        },
      });

      functions.logger.error('Payment orchestration failed', {
        paymentId:     context.paymentId,
        transactionId: context.transactionId,
        error:         message,
      });

      return { success: false, error: message };
    }
  }

  // ─── Private handlers ─────────────────────────────────────────────────────

  private async handleBookingConfirmation(
    context: PaymentContext,
  ): Promise<PaymentResult> {
    const requestId      = context.metadata.requestId;
    const sessionDetails = context.metadata.sessionDetails as Record<string, unknown>;

    if (!requestId || !sessionDetails || typeof sessionDetails !== 'object') {
      throw new Error('Missing booking confirmation metadata');
    }

    // Build SlotInfo so the slot is disabled INSIDE the same Firestore transaction
    // as the booking write — eliminates the double-booking race window entirely.
    const slotInfo = this.buildSlotInfo(
      context.payment.mohaffezId,
      (sessionDetails as Record<string, unknown>)['slotDate'],
      (sessionDetails as Record<string, unknown>)['preferredTimeSlot'],
      (sessionDetails as Record<string, unknown>)['sessionType'],
    );

    // ✅ FIX: slotInfo is passed in; slot removal is now atomic with the booking.
    const bookingResult = await confirmBookingAfterPayment(
      requestId,
      sessionDetails as Record<string, unknown>,
      context.payment,
      context.transactionId,
      slotInfo,
      {
        paymentId: context.paymentId,
        transactionId: context.transactionId,
      },
    );

    await this.notificationService.send({
      recipientId: context.payment.studentId,
      senderId:    context.payment.mohaffezId,
      type:        'session_confirmed',
      title:       'Session Confirmed',
      message:     `Your booking with ${context.payment.mohaffezName} is confirmed after payment.`,
      data: {
        sessionId:  bookingResult.sessionId,
        requestId,
        mohaffezId: context.payment.mohaffezId,
      },
    });

    await this.eventStore.appendPaymentEvent({
      eventType: PaymentEventType.BOOKING_CONFIRMED,
      paymentId: context.paymentId,
      userId:    context.payment.studentId,
      data: {
        requestId,
        sessionId: bookingResult.sessionId,
      },
      metadata: {
        source:        'webhook',
        transactionId: context.transactionId,
      },
    });

    return { success: true, sessionId: bookingResult.sessionId };
  }

  private async handleSubscriptionCreation(
    context: PaymentContext,
  ): Promise<PaymentResult> {
    const subscriptionResult = await createSubscriptionFromPayment(
      context.payment,
      context.transactionId,
      {
        paymentId: context.paymentId,
        transactionId: context.transactionId,
      },
    );

    await db.collection('payments').doc(context.paymentId).update({
      subscriptionId: subscriptionResult.subscriptionId,
      updatedAt:      serverTimestamp(),
    });

    await this.notificationService.send({
      recipientId: context.payment.studentId,
      senderId:    context.payment.mohaffezId,
      type:        'subscription_created',
      title:       'Subscription Activated',
      message:     'Your subscription purchase was completed successfully.',
      data: {
        subscriptionId: subscriptionResult.subscriptionId,
        mohaffezId:     context.payment.mohaffezId,
      },
    });

    await this.eventStore.appendPaymentEvent({
      eventType: PaymentEventType.SUBSCRIPTION_CREATED,
      paymentId: context.paymentId,
      userId:    context.payment.studentId,
      data:      { subscriptionId: subscriptionResult.subscriptionId },
      metadata: {
        source:        'webhook',
        transactionId: context.transactionId,
      },
    });

    return { success: true, subscriptionId: subscriptionResult.subscriptionId };
  }

  private async handleSubscriptionConsumption(
    context: PaymentContext,
  ): Promise<PaymentResult> {
    const subscriptionId = context.metadata.subscriptionId;
    if (!subscriptionId) {
      throw new Error('Missing subscriptionId in payment metadata');
    }

    const sd = context.metadata.sessionDetails as Record<string, unknown> | undefined;

    // Build SlotInfo so the slot is disabled INSIDE the same Firestore transaction
    // as the subscription decrement — no separate call needed after.
    const slotInfo = this.buildSlotInfo(
      context.payment.mohaffezId,
      sd?.['slotDate'],
      sd?.['preferredTimeSlot'],
      sd?.['sessionType'],
    );

    // ✅ FIX: slotInfo passed in; slot removal is now atomic with session creation.
    const consumptionResult = await consumeSubscriptionAndCreateSession(
      subscriptionId,
      context.payment,
      context.transactionId,
      context.metadata,
      slotInfo,
      {
        paymentId: context.paymentId,
        transactionId: context.transactionId,
      },
    );

    await this.notificationService.send({
      recipientId: context.payment.studentId,
      senderId:    context.payment.mohaffezId,
      type:        'subscription_session_consumed',
      title:       'Session Booked',
      message:     'A session was booked using your active subscription.',
      data: {
        subscriptionId,
        sessionId:         consumptionResult.sessionId,
        remainingSessions: consumptionResult.remainingSessions,
      },
    });

    return {
      success:       true,
      sessionId:     consumptionResult.sessionId,
      subscriptionId,
    };
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  /**
   * Constructs a SlotInfo object only when all four fields are valid.
   * Returns undefined (skips atomic slot removal) if any field is missing/invalid.
   */
  private buildSlotInfo(
    mohaffezId:  unknown,
    slotDate:    unknown,
    timeSlot:    unknown,
    sessionType: unknown,
  ): SlotInfo | undefined {
    if (
      typeof mohaffezId  !== 'string' || !mohaffezId  ||
      typeof timeSlot    !== 'string' || !timeSlot    ||
      typeof sessionType !== 'string' || !sessionType ||
      !slotDate
    ) {
      functions.logger.warn(
        'buildSlotInfo: incomplete slot data — slot will NOT be disabled atomically',
        { mohaffezId, timeSlot, sessionType, hasSlotDate: !!slotDate },
      );
      return undefined;
    }

    return {
      mohaffezId,
      slotDate,
      timeSlot,
      sessionType,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // removeSlotFromAvailability has been intentionally removed.
  //
  // Previously this was called AFTER confirmBookingAfterPayment / consumeSubscription
  // completed their own Firestore transactions, leaving a race window where two
  // concurrent payments could both confirm against the same slot before either
  // removal ran.
  //
  // The fix: slot removal is now done INSIDE handlers.ts transactions via
  // readAvailabilityInTransaction(), passed through the SlotInfo parameter above.
  // ─────────────────────────────────────────────────────────────────────────
}
