"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.releaseExpiredSlotLocks = void 0;
exports.releaseExpiredSlotLocksNow = releaseExpiredSlotLocksNow;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
// WHY: slot-lock-fix - Added sessionRequestId to lock data and added logic to update
// linked sessionRequest to "expired" status when slot lock expires.
// This handles the case where student marks payment but mohaffez never confirms.
function normalizeTimeSlot(raw) {
    // FIXED: BUG-5 - strip both hyphens AND en-dashes
    return raw.replace(/\s/g, '').replace(/[\u2013\u2014]/g, '-');
}
async function releaseExpiredSlotLocksNow() {
    const now = admin_1.default.firestore.Timestamp.now();
    const snapshot = await admin_1.db
        .collection('slotLocks')
        .where('released', '==', false)
        .where('expiresAt', '<=', now)
        .get();
    if (snapshot.empty) {
        return 0;
    }
    async function releaseSingleLock(lockDoc) {
        const lock = lockDoc.data();
        const mohaffezId = typeof lock.mohaffezId === 'string' ? lock.mohaffezId : null;
        const availabilityDocId = typeof lock.availabilityDocId === 'string' ? lock.availabilityDocId : null;
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
                releasedAt: admin_1.FieldValue.serverTimestamp(),
                releaseReason: 'invalid_lock_payload',
            });
            return;
        }
        // FIX lock-expiry-3: Path B (buy-bundle) locks don't have availabilityDocId.
        // availabilityDocId may be absent but that's valid - we still need to expire
        // the linked sessionRequest.
        const hasAvailabilityInfo = !!(availabilityDocId && timeSlot && sessionType);
        try {
            await admin_1.db.runTransaction(async (transaction) => {
                var _a;
                // ALL READS FIRST (required by Firestore)
                let availabilityDoc = null;
                if (hasAvailabilityInfo) {
                    const availabilityRef = admin_1.db
                        .collection('users')
                        .doc(mohaffezId)
                        .collection('availability')
                        .doc(availabilityDocId);
                    availabilityDoc = await transaction.get(availabilityRef);
                }
                let reqSnap = null;
                if (sessionRequestId) {
                    const sessionReqRef = admin_1.db.collection('sessionRequests').doc(sessionRequestId);
                    reqSnap = await transaction.get(sessionReqRef);
                }
                // ALL WRITES AFTER (must be after all reads)
                if (hasAvailabilityInfo && availabilityDoc && availabilityDoc.exists) {
                    const data = (_a = availabilityDoc.data()) !== null && _a !== void 0 ? _a : {};
                    const slots = Array.isArray(data.timeSlots)
                        ? data.timeSlots
                        : [];
                    let changed = false;
                    const selectedSlot = normalizeTimeSlot(timeSlot);
                    const updatedSlots = slots.map((slot) => {
                        const start = typeof slot.startTime === 'string' ? slot.startTime : '';
                        const end = typeof slot.endTime === 'string' ? slot.endTime : '';
                        const slotTime = normalizeTimeSlot(`${start}-${end}`);
                        if (slotTime === selectedSlot &&
                            slot.sessionType === sessionType &&
                            slot.lockId === lockDoc.id) {
                            changed = true;
                            const updatedSlot = Object.assign({}, slot);
                            delete updatedSlot.lockedBy;
                            delete updatedSlot.lockId;
                            delete updatedSlot.lockedAt;
                            return updatedSlot;
                        }
                        return slot;
                    });
                    if (changed) {
                        const availabilityRef = admin_1.db
                            .collection('users')
                            .doc(mohaffezId)
                            .collection('availability')
                            .doc(availabilityDocId);
                        transaction.update(availabilityRef, {
                            timeSlots: updatedSlots,
                            updatedAt: admin_1.FieldValue.serverTimestamp(),
                        });
                    }
                }
                // Release the lock
                transaction.update(lockDoc.ref, {
                    released: true,
                    releasedAt: admin_1.FieldValue.serverTimestamp(),
                    releaseReason: hasAvailabilityInfo ? 'expired' : 'expired_no_availability',
                });
                // Expire the linked sessionRequest
                if (sessionRequestId && reqSnap && reqSnap.exists) {
                    const reqData = reqSnap.data();
                    if ((reqData === null || reqData === void 0 ? void 0 : reqData.status) === 'awaitingdirectpaymentconfirmation') {
                        const sessionReqRef = admin_1.db.collection('sessionRequests').doc(sessionRequestId);
                        transaction.update(sessionReqRef, {
                            status: 'expired',
                            updatedAt: admin_1.FieldValue.serverTimestamp(),
                        });
                    }
                }
            });
        }
        catch (error) {
            functions.logger.error('Failed to release slot lock', {
                lockId: lockDoc.id,
                error,
            });
            await admin_1.db.collection('failedOperations').add({
                operationType: 'slot_lock_release',
                lockId: lockDoc.id,
                error: error instanceof Error ? error.message : 'Unknown error',
                timestamp: admin_1.FieldValue.serverTimestamp(),
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
exports.releaseExpiredSlotLocks = functions.pubsub
    .schedule('every 10 minutes')
    .onRun(async () => {
    await releaseExpiredSlotLocksNow();
    return null;
});
//# sourceMappingURL=releaseExpiredSlotLocks.js.map