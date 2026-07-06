// src/payments/handlers.ts
import * as functions from 'firebase-functions';
import admin, { db } from '../utils/admin';
import { PaymentDocument, PaymentMetadata } from '../types/payment.types';
import { sanitizeForFirestore } from '../utils/firestoreSanitizer';

const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;


// ─── Interfaces ───────────────────────────────────────────────────────────────

interface BookingConfirmationResult  { sessionId: string; }
interface SubscriptionCreationResult { subscriptionId: string; }
interface SubscriptionConsumptionResult { remainingSessions: number; sessionId?: string; }

/** Pass this when you want slot disabling to happen atomically with the booking. */
export interface SlotInfo {
  mohaffezId: string;
  slotDate: unknown;       // FirebaseFirestore.Timestamp from sessionDetails
  timeSlot: string;        // "HH:mm-HH:mm"
  sessionType: string;
}

export interface PaymentStatusUpdate {
  paymentId: string;
  transactionId: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const parseNumber = (v: unknown, fb: number): number =>
  typeof v === 'number' ? v : fb;

const parseString = (v: unknown, fb: string): string =>
  typeof v === 'string' && v.trim().length > 0 ? v : fb;

const isPresent = (v: unknown): boolean =>
  v !== undefined && v !== null && v !== '';

const sessionFallbackFields = [
  'slotDate',
  'slotStart',
  'slotEnd',
  'preferredTimeSlot',
  'timeSlot',
  'sessionType',
  'location',
  'imamAddressText',
  'imamAddressLat',
  'imamAddressLng',
  'mohaffezPhone',
  'studentPhone',
  'preferredProvider',
];

function parseTimeRange(timeSlot: unknown):
  | { startHour: number; startMinute: number; endHour: number; endMinute: number }
  | null {
  if (typeof timeSlot !== 'string' || timeSlot.trim().length === 0) return null;

  const parts = timeSlot.split('-');
  const start = parts[0]?.trim().split(':') ?? [];
  const end = (parts[1]?.trim().split(':') ?? start);
  const startHour = Number.parseInt(start[0] ?? '', 10);
  const startMinute = Number.parseInt(start[1] ?? '0', 10);
  const endHour = Number.parseInt(end[0] ?? '', 10);
  const endMinute = Number.parseInt(end[1] ?? '0', 10);

  if (
    Number.isNaN(startHour) ||
    Number.isNaN(startMinute) ||
    Number.isNaN(endHour) ||
    Number.isNaN(endMinute)
  ) {
    return null;
  }

  return { startHour, startMinute, endHour, endMinute };
}

function toDate(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function buildSlotTimestamp(dayValue: unknown, hour: number, minute: number):
  admin.firestore.Timestamp | null {
  const day = toDate(dayValue);
  if (!day) return null;

  // Last-resort fallback only. Normal request docs already carry exact
  // slotStart/slotEnd timestamps, which preserve the user's local timezone.
  const date = new Date(day);
  date.setUTCHours(hour, minute, 0, 0);
  return admin.firestore.Timestamp.fromDate(date);
}

function normalizeSessionDetails(
  sessionDetails: Record<string, unknown>,
  requestData?: Record<string, unknown>,
): Record<string, unknown> {
  const normalized = { ...sessionDetails };

  if (requestData) {
    for (const field of sessionFallbackFields) {
      if (!isPresent(normalized[field]) && isPresent(requestData[field])) {
        normalized[field] = requestData[field];
      }
    }
  }

  const sessionDay = normalized['sessionDate'] ?? normalized['slotDate'];
  if (!isPresent(normalized['sessionDate']) && isPresent(sessionDay)) {
    normalized['sessionDate'] = sessionDay;
  }
  if (!isPresent(normalized['slotDate']) && isPresent(sessionDay)) {
    normalized['slotDate'] = sessionDay;
  }

  const timeSlot = normalized['preferredTimeSlot'] ?? normalized['timeSlot'];
  const range = parseTimeRange(timeSlot);
  if (range && isPresent(sessionDay)) {
    if (!isPresent(normalized['slotStart'])) {
      normalized['slotStart'] = buildSlotTimestamp(
        sessionDay,
        range.startHour,
        range.startMinute,
      );
    }
    if (!isPresent(normalized['slotEnd'])) {
      normalized['slotEnd'] = buildSlotTimestamp(
        sessionDay,
        range.endHour,
        range.endMinute,
      );
    }
  }

  return sanitizeForFirestore(normalized);
}

/**
 * READS the availability document for a slot inside an existing transaction
 * and COMPUTES the updated slots array.
 * Returns { doc, updatedSlots } when a change is needed, null otherwise.
 * Must be called before any transaction writes.
 */
async function readAvailabilityInTransaction(
  transaction: FirebaseFirestore.Transaction,
  slotInfo: SlotInfo,
): Promise<{ doc: FirebaseFirestore.QueryDocumentSnapshot; updatedSlots: Record<string, unknown>[] } | null> {
  const { mohaffezId, slotDate, timeSlot, sessionType } = slotInfo;

  if (!mohaffezId || !slotDate || !timeSlot || !sessionType) {
    functions.logger.warn('readAvailabilityInTransaction: missing slot params', slotInfo);
    return null;
  }

  const slotTs   = slotDate as FirebaseFirestore.Timestamp;
  const jsDay    = slotTs.toDate().getDay();
  const dayOfWeek = jsDay === 0 ? 7 : jsDay;

  const availQuery = db
    .collection('users').doc(mohaffezId)
    .collection('availability')
    .where('dayOfWeek', '==', dayOfWeek)
    .limit(1);

  const snap = await transaction.get(availQuery);

  if (snap.empty) {
    functions.logger.warn('readAvailabilityInTransaction: no availability doc', { mohaffezId, dayOfWeek });
    return null;
  }

  const doc  = snap.docs[0];
  const data = doc.data() as { timeSlots?: Record<string, unknown>[] };
  let changed = false;

  const updatedSlots = (data.timeSlots ?? []).map((slot) => {
    const st = `${slot['startTime'] ?? ''}-${slot['endTime'] ?? ''}`;
    if (st === timeSlot && slot['sessionType'] === sessionType && slot['enabled'] === true) {
      changed = true;
      return { ...slot, enabled: false };
    }
    return slot;
  });

  if (!changed) {
    functions.logger.info('readAvailabilityInTransaction: slot already disabled or not found',
      { mohaffezId, timeSlot, sessionType });
    return null;
  }

  return { doc, updatedSlots };
}

// ─── Exported Handlers ────────────────────────────────────────────────────────

/**
 * Accepts a booking request and creates the hafizSession in a single transaction.
 * ✅ FIX: slot disabling is now atomic — no more race window between booking and removal.
 */
export async function confirmBookingAfterPayment(
  requestId: string,
  sessionDetails: Record<string, unknown>,
  payment: PaymentDocument,
  transactionId: string,
  slotInfo?: SlotInfo,
  paymentUpdate?: PaymentStatusUpdate,
): Promise<BookingConfirmationResult> {
  return db.runTransaction(async (transaction) => {
    // ── READS (must all come before writes) ───────────────────────────────────
    const requestRef  = db.collection('sessionRequests').doc(requestId);
    const requestSnap = await transaction.get(requestRef);
    const paymentRef = paymentUpdate
      ? db.collection('payments').doc(paymentUpdate.paymentId)
      : null;
    if (paymentRef) {
      await transaction.get(paymentRef);
    }

    // Read availability inside the same transaction while still in read phase
    const availUpdate = slotInfo
      ? await readAvailabilityInTransaction(transaction, slotInfo)
      : null;

    // ── VALIDATE ──────────────────────────────────────────────────────────────
    if (!requestSnap.exists) throw new Error('Session request not found');
    const requestData = requestSnap.data() as Record<string, unknown>;
    const normalizedSessionDetails = normalizeSessionDetails(
      sessionDetails,
      requestData,
    );

    // ── WRITES ────────────────────────────────────────────────────────────────
    const sessionRef = db.collection('hafizSessions').doc();

    transaction.update(requestRef, {
      status: STATUS.ACCEPTED,
      isPaid: true,
      sessionId:            sessionRef.id,
      paidAt:               admin.firestore.FieldValue.serverTimestamp(),
      paymentTransactionId: transactionId,
      updatedAt:            admin.firestore.FieldValue.serverTimestamp(),
    });

    transaction.set(sessionRef, sanitizeForFirestore({
      ...normalizedSessionDetails,
      requestId,
      status:               STATUS.ACCEPTED,
      isPaid:               true,
      ...(paymentUpdate ? { paymentId: paymentUpdate.paymentId } : {}),
      paymentTransactionId: transactionId,
      createdAt:            admin.firestore.FieldValue.serverTimestamp(),
      acceptedAt:           admin.firestore.FieldValue.serverTimestamp(),
      studentId:            payment.studentId,
      studentName:          payment.studentName,
      mohaffezId:           payment.mohaffezId,
      mohaffezName:         payment.mohaffezName,
      sessionPrice:         payment.amount,
    }));

    if (availUpdate) {
      transaction.update(availUpdate.doc.ref, {
        timeSlots: availUpdate.updatedSlots,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      functions.logger.info('Slot disabled atomically with booking', {
        requestId, sessionId: sessionRef.id, timeSlot: slotInfo?.timeSlot,
      });
    }

    if (paymentUpdate && paymentRef) {
      transaction.update(paymentRef, {
        status: 'completed',
        sessionId: sessionRef.id,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        idempotencyKey: `${paymentUpdate.paymentId}:${paymentUpdate.transactionId}`,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info('Booking confirmed in transaction', { requestId, sessionId: sessionRef.id });
    return { sessionId: sessionRef.id };
  });
}

/**
 * Consumes one session from a subscription and creates the hafizSession.
 * ✅ FIX: slot disabling is now atomic — same transaction as subscription decrement.
 */
export async function consumeSubscriptionAndCreateSession(
  subscriptionId: string,
  payment: PaymentDocument,
  transactionId: string,
  metadata: PaymentMetadata,
  slotInfo?: SlotInfo,
  paymentUpdate?: PaymentStatusUpdate,
): Promise<SubscriptionConsumptionResult> {
  return db.runTransaction(async (transaction) => {
    // ── READS ─────────────────────────────────────────────────────────────────
    const subRef  = db.collection('subscriptions').doc(subscriptionId);
    const subSnap = await transaction.get(subRef);
    const paymentRef = paymentUpdate
      ? db.collection('payments').doc(paymentUpdate.paymentId)
      : null;
    if (paymentRef) {
      await transaction.get(paymentRef);
    }

    let requestRef:  FirebaseFirestore.DocumentReference | null = null;
    let requestSnap: FirebaseFirestore.DocumentSnapshot  | null = null;

    if (metadata.requestId && metadata.sessionDetails) {
      requestRef  = db.collection('sessionRequests').doc(metadata.requestId);
      requestSnap = await transaction.get(requestRef);
    }

    const availUpdate = slotInfo
      ? await readAvailabilityInTransaction(transaction, slotInfo)
      : null;

    // ── VALIDATE ──────────────────────────────────────────────────────────────
    if (!subSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'الاشتراك غير موجود'
      );
    }
    const subscription     = subSnap.data() as Record<string, unknown>;
    const remainingSessions = parseNumber(subscription['remainingSessions'], 0);
    if (remainingSessions <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'لا توجد جلسات متبقية في هذا الاشتراك'
      );
    }

    if (requestRef && requestSnap && !requestSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'طلب الجلسة غير موجود'
      );
    }

    // ── WRITES ────────────────────────────────────────────────────────────────
    const newRemaining = remainingSessions - 1;
    const status       = newRemaining === 0 ? 'depleted' : parseString(subscription['status'], 'active');

    transaction.update(subRef, {
      remainingSessions: newRemaining,
      status,
      lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt:  admin.firestore.FieldValue.serverTimestamp(),
    });

    let sessionId: string | undefined;

    if (requestRef && requestSnap && metadata.sessionDetails) {
      const sessionRef = db.collection('hafizSessions').doc();
      sessionId = sessionRef.id;
      const requestData = requestSnap.data() as Record<string, unknown>;
      const normalizedSessionDetails = normalizeSessionDetails(
        metadata.sessionDetails,
        requestData,
      );

      transaction.update(requestRef, {
        status:               STATUS.ACCEPTED,
        isPaid:               true,
        sessionId:            sessionRef.id,
        paidAt:               admin.firestore.FieldValue.serverTimestamp(),
        paymentTransactionId: transactionId,
        updatedAt:            admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.set(sessionRef, sanitizeForFirestore({
        ...normalizedSessionDetails,
        requestId:            metadata.requestId,
        status:               STATUS.ACCEPTED,
        isPaid:               true,
        ...(paymentUpdate ? { paymentId: paymentUpdate.paymentId } : {}),
        paymentTransactionId: transactionId,
        // Stamp subscriptionId so onSessionCancelled can detect bundle
        // sessions and restore a credit instead of refunding money.
        subscriptionId:       subscriptionId,
        createdAt:            admin.firestore.FieldValue.serverTimestamp(),
        acceptedAt:           admin.firestore.FieldValue.serverTimestamp(),
        studentId:            payment.studentId,
        studentName:          payment.studentName,
        mohaffezId:           payment.mohaffezId,
        mohaffezName:         payment.mohaffezName,
        sessionPrice:         payment.amount,
      }));
    }

    if (availUpdate) {
      transaction.update(availUpdate.doc.ref, {
        timeSlots: availUpdate.updatedSlots,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (paymentUpdate && paymentRef) {
      transaction.update(paymentRef, {
        status: 'completed',
        ...(sessionId ? { sessionId } : {}),
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        idempotencyKey: `${paymentUpdate.paymentId}:${paymentUpdate.transactionId}`,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info('Subscription session consumed in transaction', {
      subscriptionId, remainingSessions: newRemaining, sessionId,
    });
    return { remainingSessions: newRemaining, sessionId };
  });
}

export async function createSubscriptionFromPayment(
  payment: PaymentDocument,
  transactionId: string,
  paymentUpdate?: PaymentStatusUpdate,
): Promise<SubscriptionCreationResult> {
  const metadata     = payment.metadata ?? {};
  const planTitle    = parseString(metadata['planTitle'],    'Payment Plan');
  const planType     = parseString(metadata['planType'],     'single');
  const sessionsCount = parseNumber(metadata['sessionsCount'], 1);
  const validityDays  = typeof metadata['validityDays'] === 'number' ? metadata['validityDays'] : undefined;
  const sessionType   = parseString(metadata['sessionType'],   '');
  const pricingSnapshot = {
    studentCountryCode: parseString(metadata['studentCountryCode'], ''),
    studentCountryName: parseString(metadata['studentCountryName'], ''),
    displayCurrencyCode: parseString(metadata['displayCurrencyCode'], ''),
    displayCurrencyLabel: parseString(metadata['displayCurrencyLabel'], ''),
    displayAmount:
      typeof metadata['displayAmount'] === 'number' ? metadata['displayAmount'] : null,
    fxRateToEGP:
      typeof metadata['fxRateToEGP'] === 'number' ? metadata['fxRateToEGP'] : null,
    chargedAmountEGP:
      typeof metadata['chargedAmountEGP'] === 'number' ? metadata['chargedAmountEGP'] : null,
    sessionDurationMinutes:
      typeof metadata['sessionDurationMinutes'] === 'number'
        ? metadata['sessionDurationMinutes']
        : null,
  };

  return db.runTransaction(async (transaction) => {
    const PER_SESSION_TYPE_LIMIT = 1; // hard limit: one active bundle per studentId+mohaffezId+sessionType

    const studentId = payment.studentId;
    const mohaffezId = payment.mohaffezId;

    // CONSTRAINT: one active bundle per studentId+mohaffezId+sessionType
    const activeSubsQuery = db.collection('subscriptions')
      .where('studentId', '==', studentId)
      .where('mohaffezId', '==', mohaffezId)
      .where('sessionType', '==', sessionType)
      .where('status', '==', 'active');
    const activeSubs = await transaction.get(activeSubsQuery);

    if (activeSubs.size >= PER_SESSION_TYPE_LIMIT) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'لديك باقة نشطة بالفعل لهذا النوع من الجلسات'
      );
    }

    const subscriptionRef = db.collection('subscriptions').doc();
    let expiryDate: FirebaseFirestore.Timestamp | null = null;

    if (validityDays && validityDays > 0) {
      const expiry = new Date();
      expiry.setDate(expiry.getDate() + validityDays);
      expiryDate = admin.firestore.Timestamp.fromDate(expiry);
    }

    transaction.set(subscriptionRef, {
      studentId:           payment.studentId,
      studentName:         payment.studentName,
      mohaffezId:          payment.mohaffezId,
      mohaffezName:        payment.mohaffezName,
      planId:              parseString(metadata['planId'], ''),
      planTitle, planType,
      ...pricingSnapshot,
      totalSessions:       sessionsCount,
      remainingSessions:   sessionsCount,
      totalPaid:           payment.amount,
      paymentTransactionId: transactionId,
      startDate:           admin.firestore.FieldValue.serverTimestamp(),
      expiryDate,
      status:              'active',
      createdAt:           admin.firestore.FieldValue.serverTimestamp(),
      updatedAt:           admin.firestore.FieldValue.serverTimestamp(),
    });

    if (paymentUpdate) {
      const paymentRef = db.collection('payments').doc(paymentUpdate.paymentId);
      transaction.update(paymentRef, {
        status: 'completed',
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        idempotencyKey: `${paymentUpdate.paymentId}:${paymentUpdate.transactionId}`,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info('Subscription created in transaction',
      { subscriptionId: subscriptionRef.id, sessionsCount });
    return { subscriptionId: subscriptionRef.id };
  });
}
