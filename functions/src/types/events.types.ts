export enum PaymentEventType {
  PAYMENT_CREATED = 'payment_created',
  PAYMENT_PROCESSING = 'payment_processing',
  PAYMENT_COMPLETED = 'payment_completed',
  PAYMENT_FAILED = 'payment_failed',
  WEBHOOK_RECEIVED = 'webhook_received',
  SUBSCRIPTION_CREATED = 'subscription_created',
  BOOKING_CONFIRMED = 'booking_confirmed',
}

export enum SessionRequestEventType {
  REQUEST_CREATED = 'request_created',
  AWAITING_PAYMENT = 'awaiting_payment',
  AWAITING_DIRECT = 'awaiting_direct_payment',
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}

export enum SessionEventType {
  SESSION_CREATED = 'session_created',
  SESSION_COMPLETED = 'session_completed',
}

export interface SessionEvent {
  eventId: string;
  eventType: SessionRequestEventType | SessionEventType;
  requestId?: string;
  sessionId?: string;
  timestamp: FirebaseFirestore.Timestamp;
  actorId: string; // who triggered the change (studentId, mohaffezId, 'system')
  fromStatus?: string;
  toStatus: string;
  data: Record<string, unknown>;
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
