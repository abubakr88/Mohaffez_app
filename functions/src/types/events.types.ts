export enum PaymentEventType {
  PAYMENT_CREATED = 'payment_created',
  PAYMENT_PROCESSING = 'payment_processing',
  PAYMENT_COMPLETED = 'payment_completed',
  PAYMENT_FAILED = 'payment_failed',
  WEBHOOK_RECEIVED = 'webhook_received',
  SUBSCRIPTION_CREATED = 'subscription_created',
  BOOKING_CONFIRMED = 'booking_confirmed',
}

export enum BookingEventType {
  BOOKING_CONFIRMED = 'booking_confirmed',
  BOOKING_PAID = 'booking_paid',
}

export interface PaymentEvent {
  eventId: string;
  eventType: PaymentEventType;
  paymentId: string;
  timestamp: FirebaseFirestore.Timestamp;
  userId: string;
  data: Record<string, unknown>;
  metadata: {
    source: 'webhook' | 'client' | 'admin';
    transactionId?: string;
    ipAddress?: string;
  };
}

export interface BookingEvent {
  eventId: string;
  eventType: BookingEventType;
  bookingId: string;
  paymentId?: string;
  timestamp: FirebaseFirestore.Timestamp;
  userId: string;
  data: Record<string, unknown>;
  metadata: {
    source: 'webhook' | 'client' | 'admin';
    transactionId?: string;
  };
}

export interface PaymentState {
  paymentId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  lastEventType?: PaymentEventType;
  updatedAt?: FirebaseFirestore.Timestamp;
  eventCount: number;
}