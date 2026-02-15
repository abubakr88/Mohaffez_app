"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.releaseExpiredSlotLocks = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
function normalizeTimeSlot(raw) {
    return raw.replace(/\s+/g, '');
}
exports.releaseExpiredSlotLocks = functions.pubsub
    .schedule('every 10 minutes')
    .onRun(async () => {
    const now = admin_1.default.firestore.Timestamp.now();
    const snapshot = await admin_1.db
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
        const availabilityDocId = typeof lock.availabilityDocId === 'string' ? lock.availabilityDocId : null;
        const timeSlot = typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
        const sessionType = typeof lock.sessionType === 'string' ? lock.sessionType : null;
        if (!mohaffezId || !availabilityDocId || !timeSlot || !sessionType) {
            await lockDoc.ref.update({
                released: true,
                releasedAt: admin_1.FieldValue.serverTimestamp(),
                releaseReason: 'invalid_lock_payload',
            });
            continue;
        }
        const availabilityRef = admin_1.db
            .collection('users')
            .doc(mohaffezId)
            .collection('availability')
            .doc(availabilityDocId);
        try {
            await admin_1.db.runTransaction(async (transaction) => {
                var _a;
                const availabilityDoc = await transaction.get(availabilityRef);
                if (!availabilityDoc.exists) {
                    transaction.update(lockDoc.ref, {
                        released: true,
                        releasedAt: admin_1.FieldValue.serverTimestamp(),
                        releaseReason: 'missing_availability_doc',
                    });
                    return;
                }
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
                    transaction.update(availabilityRef, {
                        timeSlots: updatedSlots,
                        updatedAt: admin_1.FieldValue.serverTimestamp(),
                    });
                }
                transaction.update(lockDoc.ref, {
                    released: true,
                    releasedAt: admin_1.FieldValue.serverTimestamp(),
                    releaseReason: changed ? 'expired' : 'already_released',
                });
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
    functions.logger.info('Expired slot locks processed', {
        count: snapshot.size,
    });
    return null;
});
//# sourceMappingURL=releaseExpiredSlotLocks.js.map