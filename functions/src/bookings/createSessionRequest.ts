// src/bookings/createSessionRequest.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';

const STATUS = {
  PENDING: 'pending',
  AWAITING_PAYMENT: 'awaitingpayment',
  AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
} as const;

function normalizeTimeSlot(raw: string): string {
  // FIXED: BUG-5 - strip both hyphens AND en-dashes
  return raw.replace(/\s/g, '').replace(/[\u2013\u2014]/g, '-');
}

function parseFlutterDate(iso: string): Date {
  if (!iso.endsWith('Z') && !/[+\-]\d{2}:\d{2}$/.test(iso)) {
    return new Date(iso + 'Z');
  }
  return new Date(iso);
}

export const createSessionRequest = functions.https.onCall(
  async (data, context) => {
    const fallbackIdToken =
      typeof data?.idToken === 'string' ? data.idToken : null;
    let studentId: string | null = context.auth?.uid ?? null;

    // ── 0. DIAGNOSTIC LOG (remove after issue resolved) ───────────────────
    functions.logger.info('createSessionRequest invoked', {
      hasAuth: !!context.auth,
      uid: context.auth?.uid ?? 'NONE',
      hasAppCheck: !!(context as any).app,
      rawAuthHeader: !!(context as any).rawRequest?.headers?.authorization,
      hasFallbackIdToken: !!fallbackIdToken,
    });

    // ── 1. Auth ────────────────────────────────────────────────────────────
    if (!studentId && fallbackIdToken) {
      try {
        const decoded = await admin.auth().verifyIdToken(fallbackIdToken);
        studentId = decoded.uid;
        functions.logger.warn('createSessionRequest: using fallback idToken verification', { uid: studentId });
      } catch (e) {
        functions.logger.error('createSessionRequest: fallback idToken verification failed', {
          error: e instanceof Error ? e.message : String(e),
        });
      }
    }

    if (!studentId) {
      functions.logger.error('createSessionRequest: UNAUTHENTICATED - no context.auth and no valid fallback token', {
        headers: JSON.stringify((context as any).rawRequest?.headers ?? {}),
      });
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

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

    if (data.studentId && data.studentId !== studentId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'studentId in payload does not match authenticated user'
      );
    }

    functions.logger.info('createSessionRequest: validation passed', {
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

      // ── 4a. Validate slot lock ─────────────────────────────────────────
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

            // FIXED: BUG-5 - Warn if slot disable was skipped due to mismatch
            if (!changed) {
              functions.logger.warn('createSessionRequest: slot disable skipped — no matching slot found', {
                lockTimeSlot,
                lockSessionType,
                availableSlots: slots.map((s: any) =>
                  `${s.startTime}-${s.endTime}:${s.sessionType}`
                ),
              });
              updatedSlots = null;
            }
          }
        }
      }

      // ── 4b. Conflict guard ─────────────────────────────────────────────
      // FIX-BOOKING-1: Guard against all live statuses, not just PENDING.
      // Required Firestore composite index: (mohaffezId ASC, status ASC, slotDate ASC)
      // Add this index to firestore.indexes.json if not already present.
      const LIVE_STATUSES = [
        STATUS.PENDING,
        STATUS.AWAITING_PAYMENT,
        STATUS.AWAITING_DIRECT,
        STATUS.ACCEPTED,
      ] as const;

      const conflictQuery = db
        .collection('sessionRequests')
        .where('mohaffezId', '==', mohaffezId)
        .where('status', 'in', [...LIVE_STATUSES])
        .where('slotDate', '==', admin.firestore.Timestamp.fromDate(slotDateObj));

      const conflictSnap = await transaction.get(conflictQuery);

      const normalizedSlot = normalizeTimeSlot(preferredTimeSlot);
      const duplicate = conflictSnap.docs.find((doc) => {
        const d = doc.data();
        return (
          normalizeTimeSlot(d.preferredTimeSlot ?? '') === normalizedSlot &&
          d.sessionType === sessionType
        );
      });

      if (duplicate) {
        if (duplicate.data().studentId === studentId) {
          functions.logger.warn(
            'Duplicate request from same student — returning existing',
            { existingId: duplicate.id, studentId, mohaffezId }
          );
          return { success: true, requestId: duplicate.id, isDuplicate: true };
        }
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

      // ── 4c. Write sessionRequest ───────────────────────────────────────
      const requestRef = db.collection('sessionRequests').doc();

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
        planId: (data.planId as string) ?? null,
        planTitle: (data.planTitle as string) ?? null,
        paymentAmount:
          typeof data.paymentAmount === 'number' ? data.paymentAmount : null,
        sessionsCount:
          typeof data.sessionsCount === 'number' ? data.sessionsCount : null,
        planType: (data.planType as string) ?? null,
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

      // ── 4e. Disable availability slot ─────────────────────────────────
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

      return { success: true, requestId: requestRef.id };
    });
  }
);

