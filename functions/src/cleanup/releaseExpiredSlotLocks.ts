import * as functions from 'firebase-functions';

import admin, { db, FieldValue } from '../utils/admin';

// WHY: slot-lock-fix - Added sessionRequestId to lock data and added logic to update
// linked sessionRequest to "expired" status when slot lock expires.
// This handles the case where student marks payment but mohaffez never confirms.
function normalizeTimeSlot(raw: string): string {
  // FIXED: BUG-5 - strip both hyphens AND en-dashes
  return raw.replace(/\s/g, '').replace(/[\u2013\u2014]/g, '-');
}

export async function releaseExpiredSlotLocksNow(): Promise<number> {
  const now = admin.firestore.Timestamp.now();

  const snapshot = await db
    .collection('slotLocks')
    .where('released', '==', false)
    .where('expiresAt', '<=', now)
    .get();

  if (snapshot.empty) {
    return 0;
  }

  async function releaseSingleLock(
    lockDoc: FirebaseFirestore.QueryDocumentSnapshot,
  ): Promise<void> {
    const lock = lockDoc.data();
    const mohaffezId = typeof lock.mohaffezId === 'string' ? lock.mohaffezId : null;
    const availabilityDocId =
      typeof lock.availabilityDocId === 'string' ? lock.availabilityDocId : null;
    const timeSlot = typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
    const sessionType = typeof lock.sessionType === 'string' ? lock.sessionType : null;
    // FIX: slot-lock-fix - Get sessionRequestId from lock to update its status
    const sessionRequestId = typeof lock.sessionRequestId === 'string' ? lock.sessionRequestId : null;

    // FIX lock-expiry-3: Only bail out completely when mohaffezId is missing
    // (truly corrupt lock). Path B locks (created by studentMarkedDirectPayment
    // for bundle purchases) don't have availabilityDocId - that's valid, not an error.
    // We must still run the transaction to expire the linked sessionRequest.
    if (!mohaffezId) {
      await lockDoc.ref.update({
        released: true,
        releasedAt: FieldValue.serverTimestamp(),
        releaseReason: 'invalid_lock_payload',
      });
      return;
    }

    // FIX lock-expiry-3: Path B (buy-bundle) locks don't have availabilityDocId.
    // availabilityDocId may be absent but that's valid - we still need to expire
    // the linked sessionRequest.
    const hasAvailabilityInfo = !!(availabilityDocId && timeSlot && sessionType);

    try {
      await db.runTransaction(async (transaction) => {
        // FIX lock-expiry-3: Only re-enable availability slot when availability
        // info is present (Path A / createSessionRequest flow). Path B (buy-bundle)
        // locks don't have availabilityDocId.
        if (hasAvailabilityInfo) {
          const availabilityRef = db
            .collection('users')
            .doc(mohaffezId!)
            .collection('availability')
            .doc(availabilityDocId!);

          const availabilityDoc = await transaction.get(availabilityRef);
          if (availabilityDoc.exists) {
            const data = availabilityDoc.data() ?? {};
            const slots = Array.isArray(data.timeSlots)
              ? (data.timeSlots as Record<string, unknown>[])
              : [];

            let changed = false;
            const selectedSlot = normalizeTimeSlot(timeSlot!);

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
          }
        }

        // FIX lock-expiry-3: Always release the lock (not conditional on changed)
        transaction.update(lockDoc.ref, {
          released: true,
          releasedAt: FieldValue.serverTimestamp(),
          releaseReason: hasAvailabilityInfo ? 'expired' : 'expired_no_availability',
        });

        // FIX lock-expiry-3: ALWAYS expire the linked sessionRequest
        // Path B locks (buy-bundle) have sessionRequestId, Path A locks may not.
        // The sessionRequest should be expired when lock expires, regardless of
        // whether availabilityDocId was present.
        if (sessionRequestId) {
          const sessionReqRef = db.collection('sessionRequests').doc(sessionRequestId);
          const reqSnap = await transaction.get(sessionReqRef);
          if (reqSnap.exists) {
            const reqData = reqSnap.data();
            // Only update if status is awaitingdirectpaymentconfirmation (not already accepted)
            if (reqData?.status === 'awaitingdirectpaymentconfirmation') {
              transaction.update(sessionReqRef, {
                status: 'expired',
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
        }
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

  const chunkSize = 10;
  const docs = snapshot.docs;
  for (let i = 0; i < docs.length; i += chunkSize) {
    const chunk = docs.slice(i, i + chunkSize);
    await Promise.all(chunk.map(releaseSingleLock));
  }

  functions.logger.info('Expired slot locks processed', {
    count: snapshot.size,
  });

  return snapshot.size;
}

export const releaseExpiredSlotLocks = functions.pubsub
  .schedule('every 10 minutes')
  .onRun(async () => {
    await releaseExpiredSlotLocksNow();
    return null;
  });
