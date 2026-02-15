import * as functions from 'firebase-functions';

import admin, { db, FieldValue } from '../utils/admin';

function normalizeTimeSlot(raw: string): string {
  return raw.replace(/\s+/g, '');
}

export const releaseExpiredSlotLocks = functions.pubsub
  .schedule('every 10 minutes')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const snapshot = await db
      .collection('slotLocks')
      .where('released', '==', false)
      .where('expiresAt', '<=', now)
      .get();

    if (snapshot.empty) {
      return null;
    }

    for (const lockDoc of snapshot.docs) {
      const lock = lockDoc.data();
      const mohaffezId = typeof lock.mohaffezId === 'string' ? lock.mohaffezId : null;
      const availabilityDocId =
        typeof lock.availabilityDocId === 'string' ? lock.availabilityDocId : null;
      const timeSlot = typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
      const sessionType = typeof lock.sessionType === 'string' ? lock.sessionType : null;

      if (!mohaffezId || !availabilityDocId || !timeSlot || !sessionType) {
        await lockDoc.ref.update({
          released: true,
          releasedAt: FieldValue.serverTimestamp(),
          releaseReason: 'invalid_lock_payload',
        });
        continue;
      }

      const availabilityRef = db
        .collection('users')
        .doc(mohaffezId)
        .collection('availability')
        .doc(availabilityDocId);

      try {
        await db.runTransaction(async (transaction) => {
          const availabilityDoc = await transaction.get(availabilityRef);
          if (!availabilityDoc.exists) {
            transaction.update(lockDoc.ref, {
              released: true,
              releasedAt: FieldValue.serverTimestamp(),
              releaseReason: 'missing_availability_doc',
            });
            return;
          }

          const data = availabilityDoc.data() ?? {};
          const slots = Array.isArray(data.timeSlots)
            ? (data.timeSlots as Record<string, unknown>[])
            : [];

          let changed = false;
          const selectedSlot = normalizeTimeSlot(timeSlot);

          const updatedSlots = slots.map((slot) => {
            const start = typeof slot.startTime === 'string' ? slot.startTime : '';
            const end = typeof slot.endTime === 'string' ? slot.endTime : '';
            const slotTime = normalizeTimeSlot(`${start}-${end}`);

            if (
              slotTime === selectedSlot &&
              slot.sessionType === sessionType &&
              slot.lockId === lockDoc.id
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

          if (changed) {
            transaction.update(availabilityRef, {
              timeSlots: updatedSlots,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }

          transaction.update(lockDoc.ref, {
            released: true,
            releasedAt: FieldValue.serverTimestamp(),
            releaseReason: changed ? 'expired' : 'already_released',
          });
        });
      } catch (error) {
        functions.logger.error('Failed to release slot lock', {
          lockId: lockDoc.id,
          error,
        });

        await db.collection('failedOperations').add({
          operationType: 'slot_lock_release',
          lockId: lockDoc.id,
          error: error instanceof Error ? error.message : 'Unknown error',
          timestamp: FieldValue.serverTimestamp(),
          retryCount: 0,
          status: 'pending_retry',
        });
      }
    }

    functions.logger.info('Expired slot locks processed', {
      count: snapshot.size,
    });

    return null;
  });

