import admin from '../utils/admin';

export interface PaymentMetadata {
  confirmBooking?: boolean;
  requestId?: string;
  sessionDetails?: Record<string, unknown>;
  subscriptionId?: string;
  planId?: string;
  planTitle?: string;
  planType?: string;
  sessionsCount?: number;
  validityDays?: number;
  [key: string]: unknown;
}

export interface PaymentDocument {
  id?: string;
  amount: number;
  status: 'pending' | 'processing' | 'completed' | 'failed' | string;
  idempotencyKey?: string;
  studentId: string;
  studentName: string;
  mohaffezId: string;
  mohaffezName: string;
  metadata?: PaymentMetadata;
  subscriptionId?: string;
}

export interface PaymentContext {
  paymentId: string;
  payment: PaymentDocument;
  transactionId: string;
  metadata: PaymentMetadata;
  ipAddress?: string;
}

export interface PaymentResult {
  success: boolean;
  sessionId?: string;
  subscriptionId?: string;
  error?: string;
}

export interface NotificationPayload {
  recipientId: string;
  senderId: string;
  type: string;
  title: string;
  message: string;
  data?: Record<string, unknown>;
}

export const serverTimestamp = (): FirebaseFirestore.FieldValue =>
  admin.firestore.FieldValue.serverTimestamp();
