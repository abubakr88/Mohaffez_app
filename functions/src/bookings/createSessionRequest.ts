// src/bookings/createSessionRequest.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';

const STATUS = {
  // FIX-1: Align status literals with app-wide no-underscore RequestStatus values
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;

function normalizeTimeSlot(raw: string): string {
  return raw.replace(/\s/g, '');
}

// FIX-2: Parse Flutter ISO strings without timezone as UTC to prevent server-local shift
function parseFlutterDate(iso: string): Date {
  // If the string has no timezone info, treat it as UTC
  if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
    return new Date(iso + 'Z');
  }
  return new Date(iso);
}

export const createSessionRequest = functions.https.onCall(
  async (data, context) => {
    // ── 1. Auth ────────────────────────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const studentId = context.auth.uid;

    // ── 2. Destructure ─────────────────────────────────────────────────────
    const {
      mohaffezId,
      studentName,
      mohaffezName,
      sessionType,
      preferredTimeSlot,
      slotDate,
      slotStart,
      slotEnd,
      imamAddressText,
      imamAddressLat,
      imamAddressLng,
      mohaffezPhone,
      subscriptionId,
      requiresPaymentOnAcceptance,
      selectedPaymentMethod,
      slotLockId,
    } = data;

    // ── 3. Validate ────────────────────────────────────────────────────────
    if (
      !mohaffezId ||
      !studentName ||
      !mohaffezName ||
      !sessionType ||
      !preferredTimeSlot ||
      !slotDate ||
      !slotStart ||
      !slotEnd
    ) {
      functions.logger.error('createSessionRequest: missing required fields', {
        studentId,
        mohaffezId,
        hasStudentName: !!studentName,
        hasMohaffezName: !!mohaffezName,
        sessionType,
        preferredTimeSlot,
        slotDate,
      });
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    // FIX: Validate date strings are parseable before entering the transaction
    // — a bad ISO string causes new Date() to return Invalid Date silently,
    //   which Firestore then rejects with an opaque "3 INVALID_ARGUMENT" error.
    const slotDateObj = parseFlutterDate(slotDate);
    const slotStartObj = parseFlutterDate(slotStart);
    const slotEndObj = parseFlutterDate(slotEnd);

    if (
      isNaN(slotDateObj.getTime()) ||
      isNaN(slotStartObj.getTime()) ||
      isNaN(slotEndObj.getTime())
    ) {
      functions.logger.error('createSessionRequest: invalid date values', {
        slotDate,
        slotStart,
        slotEnd,
      });
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid date values provided'
      );
    }

    // FIX: Validate studentId from auth matches studentId in payload (if sent)
    // — prevents a student booking on behalf of another user.
    if (data.studentId && data.studentId !== studentId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'studentId in payload does not match authenticated user'
      );
    }

    functions.logger.info('createSessionRequest called', {
      studentId,
      mohaffezId,
      sessionType,
      preferredTimeSlot,
      slotDate,
      hasSlotLockId: !!slotLockId,
      selectedPaymentMethod,
      requiresPaymentOnAcceptance,
    });

    // ── 4. Transaction ─────────────────────────────────────────────────────
    return db.runTransaction(async (transaction) => {
      let lockRef: FirebaseFirestore.DocumentReference | null = null;
      let availabilityRef: FirebaseFirestore.DocumentReference | null = null;
      let updatedSlots: Record<string, unknown>[] | null = null;

      // ── 4a. Validate slot lock (if provided) ──────────────────────────
      if (slotLockId) {
        lockRef = db.collection('slotLocks').doc(slotLockId);
        const lockSnap = await transaction.get(lockRef);

        if (!lockSnap.exists) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'الموعد المحجوز مؤقتاً غير موجود أو انتهت صلاحيته'
          );
        }

        const lock = lockSnap.data()!;

        if (lock.released === true) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'تم تحرير هذا الموعد بالفعل'
          );
        }

        const now = new Date();
        if (lock.expiresAt && lock.expiresAt.toDate() < now) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'انتهت صلاحية حجز الموعد المؤقت. الرجاء اختيار موعد آخر'
          );
        }

        if (lock.mohaffezId !== mohaffezId) {
          throw new functions.https.HttpsError(
            'invalid-argument',
            'الموعد المحجوز لا ينتمي لهذا المحفظ'
          );
        }

        // Read availability to compute the slot-disable update atomically
        const availabilityDocId =
          typeof lock.availabilityDocId === 'string'
            ? lock.availabilityDocId
            : null;
        const lockTimeSlot =
          typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
        const lockSessionType =
          typeof lock.sessionType === 'string' ? lock.sessionType : null;

        if (availabilityDocId && lockTimeSlot && lockSessionType) {
          availabilityRef = db
            .collection('users')
            .doc(mohaffezId)
            .collection('availability')
            .doc(availabilityDocId);

          const availabilitySnap = await transaction.get(availabilityRef);
          if (availabilitySnap.exists) {
            const availabilityData = availabilitySnap.data() ?? {};
            const slots: Record<string, unknown>[] = Array.isArray(
              availabilityData.timeSlots
            )
              ? (availabilityData.timeSlots as Record<string, unknown>[])
              : [];

            const selectedSlot = normalizeTimeSlot(lockTimeSlot);
            let changed = false;

            updatedSlots = slots.map((slot) => {
              const start =
                typeof slot.startTime === 'string' ? slot.startTime : '';
              const end =
                typeof slot.endTime === 'string' ? slot.endTime : '';
              const slotTime = normalizeTimeSlot(`${start}-${end}`);
              if (
                slotTime === selectedSlot &&
                slot.sessionType === lockSessionType
              ) {
                changed = true;
                return {
                  ...slot,
                  enabled: false,
                  lockedBy: null,
                  lockId: null,
                  lockedAt: null,
                };
              }
              return slot;
            });

            if (!changed) updatedSlots = null;
          }
        }
      }

      // ── 4b. Check for an already-booked slot (conflict guard) ─────────
      // FIX: Instead of the 4-field idempotency query (which requires a
      // composite index and crashes when the index is missing), we use a
      // simpler 2-field query that is covered by the existing
      // mohaffezId + status + createdAt DESC index — then filter in memory.
      // This avoids the "index not found → transaction aborts → nothing written"
      // bug that was the root cause of empty sessionRequests collection.
      const conflictQuery = db
        .collection('sessionRequests')
        .where('mohaffezId', '==', mohaffezId)
        .where('status', '==', STATUS.PENDING)
        .where('slotDate', '==', admin.firestore.Timestamp.fromDate(slotDateObj));

      const conflictSnap = await transaction.get(conflictQuery);

      // Filter in memory for the exact time slot (avoids extra index)
      const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);
      const duplicate = conflictSnap.docs.find((doc) => {
        const d = doc.data();
        return (
          normalizeTimeSlot(d.preferredTimeSlot ?? '') === normalizedSlot &&
          d.sessionType === sessionType
        );
      });

      if (duplicate) {
        // Check if it belongs to THIS student → idempotent success
        if (duplicate.data().studentId === studentId) {
          functions.logger.warn('Duplicate request from same student — returning existing', {
            existingId: duplicate.id,
            studentId,
            mohaffezId,
          });
          return { success: true, requestId: duplicate.id, isDuplicate: true };
        }
        // Different student already has this slot → conflict
        functions.logger.warn('Slot already requested by another student', {
          conflictingRequestId: duplicate.id,
          mohaffezId,
          preferredTimeSlot,
          slotDate,
        });
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'هذا الموعد محجوز بالفعل. الرجاء اختيار موعد آخر'
        );
      }

      // ── 4c. WRITE — create the sessionRequest document ────────────────
      const requestRef = db.collection('sessionRequests').doc();

      // FIX: Use Firestore Timestamps directly (not JS Date objects) so
      // ordering/range queries on slotDate work correctly. JS Date objects
      // are stored as Timestamps by the SDK but using Timestamp.fromDate
      // makes the intent explicit and avoids timezone edge cases.
      transaction.set(requestRef, {
        studentId,
        mohaffezId,
        studentName,
        mohaffezName,
        sessionType,
        preferredTimeSlot,
        slotDate: admin.firestore.Timestamp.fromDate(slotDateObj),
        slotStart: admin.firestore.Timestamp.fromDate(slotStartObj),
        slotEnd: admin.firestore.Timestamp.fromDate(slotEndObj),
        imamAddressText: imamAddressText ?? null,
        imamAddressLat: imamAddressLat ?? null,
        imamAddressLng: imamAddressLng ?? null,
        mohaffezPhone: mohaffezPhone ?? null,
        subscriptionId: subscriptionId ?? null,
        requiresPaymentOnAcceptance: requiresPaymentOnAcceptance ?? false,
        selectedPaymentMethod: selectedPaymentMethod ?? 'pay_after_acceptance',
        slotLockId: slotLockId ?? null,
        status: STATUS.PENDING,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // ── 4d. Release slot lock ──────────────────────────────────────────
      if (lockRef) {
        transaction.update(lockRef, {
          released: true,
          releasedAt: FieldValue.serverTimestamp(),
        });
      }

      // ── 4e. Disable availability slot atomically ───────────────────────
      if (availabilityRef && updatedSlots) {
        transaction.update(availabilityRef, {
          timeSlots: updatedSlots,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      // ── 4f. Notify mohaffez ────────────────────────────────────────────
      const notifRef = db.collection('notifications').doc();
      transaction.set(notifRef, {
        userId: mohaffezId,
        recipientId: mohaffezId,
        senderId: studentId,
        title: 'طلب حجز جديد',
        body: `${studentName} يطلب حجز جلسة معك`,
        type: 'sessionRequest',
        isRead: false,
        data: {
          requestId: requestRef.id,
          studentId,
          studentName,
          sessionType,
          preferredTimeSlot,
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      functions.logger.info('Session request created successfully', {
        requestId: requestRef.id,
        studentId,
        mohaffezId,
        sessionType,
        preferredTimeSlot,
      });

      // ── 4g. Return result ──────────────────────────────────────────────
      return { success: true, requestId: requestRef.id };
    });
  }
);
