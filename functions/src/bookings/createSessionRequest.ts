import * as functions from 'firebase-functions';

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
  return raw.replace(/\s+/g, '');
}

export const createSessionRequest = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const studentId = context.auth.uid;
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

    if (!mohaffezId || !sessionType || !preferredTimeSlot || !slotDate) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields'
      );
    }

    return db.runTransaction(async (transaction) => {
      let lockRef: FirebaseFirestore.DocumentReference | null = null;
      let availabilityRef: FirebaseFirestore.DocumentReference | null = null;
      let updatedSlots: Record<string, unknown>[] | null = null;

      if (slotLockId) {
        lockRef = db.collection('slotLocks').doc(slotLockId);
        const lockSnap = await transaction.get(lockRef);
        if (!lockSnap.exists) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Slot lock not found or expired'
          );
        }
        const lock = lockSnap.data()!;
        if (lock.released === true) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Slot lock has already been released'
          );
        }
        const now = new Date();
        if (lock.expiresAt && lock.expiresAt.toDate() < now) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Slot lock has expired'
          );
        }
        if (lock.mohaffezId !== mohaffezId) {
          throw new functions.https.HttpsError(
            'invalid-argument',
            'Lock does not belong to this mohaffez'
          );
        }

        const availabilityDocId =
          typeof lock.availabilityDocId === 'string' ? lock.availabilityDocId : null;
        const lockMohaffezId = typeof lock.mohaffezId === 'string' ? lock.mohaffezId : null;
        const lockTimeSlot = typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
        const lockSessionType =
          typeof lock.sessionType === 'string' ? lock.sessionType : null;

        if (availabilityDocId && lockMohaffezId && lockTimeSlot && lockSessionType) {
          availabilityRef = db
            .collection('users')
            .doc(lockMohaffezId)
            .collection('availability')
            .doc(availabilityDocId);

          const availabilitySnap = await transaction.get(availabilityRef);
          if (availabilitySnap.exists) {
            const availabilityData = availabilitySnap.data() ?? {};
            const slots = Array.isArray(availabilityData.timeSlots)
              ? (availabilityData.timeSlots as Record<string, unknown>[])
              : [];

            const selectedSlot = normalizeTimeSlot(lockTimeSlot);
            let changed = false;

            updatedSlots = slots.map((slot) => {
              const start = typeof slot.startTime === 'string' ? slot.startTime : '';
              const end = typeof slot.endTime === 'string' ? slot.endTime : '';
              const slotTime = normalizeTimeSlot(`${start}-${end}`);

              if (
                slotTime === selectedSlot &&
                slot.sessionType === lockSessionType &&
                slot.lockId === slotLockId
              ) {
                changed = true;
                const updatedSlot = { ...slot };
                delete updatedSlot.lockedBy;
                delete updatedSlot.lockId;
                delete updatedSlot.lockedAt;
                return updatedSlot;
              }

              return slot;
            });

            if (!changed) {
              updatedSlots = null;
            }
          }
        }
      }

      const existingQuery = db
        .collection('sessionRequests')
        .where('studentId', '==', studentId)
        .where('mohaffezId', '==', mohaffezId)
        .where('preferredTimeSlot', '==', preferredTimeSlot)
        .where('slotDate', '==', new Date(slotDate))
        .where('status', 'in', [STATUS.PENDING, STATUS.AWAITING_PAYMENT])
        .limit(1);
      const existingSnap = await transaction.get(existingQuery);
      if (!existingSnap.empty) {
        const existing = existingSnap.docs[0];
        return { success: true, requestId: existing.id, isDuplicate: true };
      }

      const requestRef = db.collection('sessionRequests').doc();
      transaction.set(requestRef, {
        studentId,
        mohaffezId,
        studentName,
        mohaffezName,
        sessionType,
        preferredTimeSlot,
        slotDate: new Date(slotDate),
        slotStart: new Date(slotStart),
        slotEnd: new Date(slotEnd),
        imamAddressText: imamAddressText ?? null,
        imamAddressLat: imamAddressLat ?? null,
        imamAddressLng: imamAddressLng ?? null,
        mohaffezPhone: mohaffezPhone ?? null,
        subscriptionId: subscriptionId ?? null,
        requiresPaymentOnAcceptance: requiresPaymentOnAcceptance ?? false,
        selectedPaymentMethod: selectedPaymentMethod ?? 'payAfterAcceptance',
        slotLockId: slotLockId ?? null,
        slotLockedAt: slotLockId ? FieldValue.serverTimestamp() : null,
        status: STATUS.PENDING,
        isPaid: false,
        reminderSent: false,
        paymentDeadline: null,
        createdAt: FieldValue.serverTimestamp(),
      });

      if (slotLockId && lockRef) {
        transaction.update(lockRef, {
          released: true,
          releasedAt: FieldValue.serverTimestamp(),
          releaseReason: 'request-created',
        });

        if (availabilityRef && updatedSlots) {
          transaction.update(availabilityRef, {
            timeSlots: updatedSlots,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      return { success: true, requestId: requestRef.id, isDuplicate: false };
    });
  }
);
