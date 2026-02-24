"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createSessionRequest = void 0;
const functions = require("firebase-functions");
const admin_1 = require("../utils/admin");
const STATUS = {
    PENDING: 'pending',
    AWAITING_PAYMENT: 'awaitingpayment',
    AWAITING_DIRECT: 'awaitingdirectpaymentconfirmation',
    ACCEPTED: 'accepted',
    REJECTED: 'rejected',
    CANCELLED: 'cancelled',
};
function normalizeTimeSlot(raw) {
    return raw.replace(/\s+/g, '');
}
exports.createSessionRequest = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    const studentId = context.auth.uid;
    const { mohaffezId, studentName, mohaffezName, sessionType, preferredTimeSlot, slotDate, slotStart, slotEnd, imamAddressText, imamAddressLat, imamAddressLng, mohaffezPhone, subscriptionId, requiresPaymentOnAcceptance, selectedPaymentMethod, slotLockId, } = data;
    if (!mohaffezId || !sessionType || !preferredTimeSlot || !slotDate) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    return admin_1.db.runTransaction(async (transaction) => {
        var _a;
        let lockRef = null;
        let availabilityRef = null;
        let updatedSlots = null;
        if (slotLockId) {
            lockRef = admin_1.db.collection('slotLocks').doc(slotLockId);
            const lockSnap = await transaction.get(lockRef);
            if (!lockSnap.exists) {
                throw new functions.https.HttpsError('failed-precondition', 'Slot lock not found or expired');
            }
            const lock = lockSnap.data();
            if (lock.released === true) {
                throw new functions.https.HttpsError('failed-precondition', 'Slot lock has already been released');
            }
            const now = new Date();
            if (lock.expiresAt && lock.expiresAt.toDate() < now) {
                throw new functions.https.HttpsError('failed-precondition', 'Slot lock has expired');
            }
            if (lock.mohaffezId !== mohaffezId) {
                throw new functions.https.HttpsError('invalid-argument', 'Lock does not belong to this mohaffez');
            }
            const availabilityDocId = typeof lock.availabilityDocId === 'string' ? lock.availabilityDocId : null;
            const lockMohaffezId = typeof lock.mohaffezId === 'string' ? lock.mohaffezId : null;
            const lockTimeSlot = typeof lock.timeSlot === 'string' ? lock.timeSlot : null;
            const lockSessionType = typeof lock.sessionType === 'string' ? lock.sessionType : null;
            if (availabilityDocId && lockMohaffezId && lockTimeSlot && lockSessionType) {
                availabilityRef = admin_1.db
                    .collection('users')
                    .doc(lockMohaffezId)
                    .collection('availability')
                    .doc(availabilityDocId);
                const availabilitySnap = await transaction.get(availabilityRef);
                if (availabilitySnap.exists) {
                    const availabilityData = (_a = availabilitySnap.data()) !== null && _a !== void 0 ? _a : {};
                    const slots = Array.isArray(availabilityData.timeSlots)
                        ? availabilityData.timeSlots
                        : [];
                    const selectedSlot = normalizeTimeSlot(lockTimeSlot);
                    let changed = false;
                    updatedSlots = slots.map((slot) => {
                        const start = typeof slot.startTime === 'string' ? slot.startTime : '';
                        const end = typeof slot.endTime === 'string' ? slot.endTime : '';
                        const slotTime = normalizeTimeSlot(`${start}-${end}`);
                        if (slotTime === selectedSlot &&
                            slot.sessionType === lockSessionType &&
                            slot.lockId === slotLockId) {
                            changed = true;
                            const updatedSlot = Object.assign({}, slot);
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
        const existingQuery = admin_1.db
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
        const requestRef = admin_1.db.collection('sessionRequests').doc();
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
            imamAddressText: imamAddressText !== null && imamAddressText !== void 0 ? imamAddressText : null,
            imamAddressLat: imamAddressLat !== null && imamAddressLat !== void 0 ? imamAddressLat : null,
            imamAddressLng: imamAddressLng !== null && imamAddressLng !== void 0 ? imamAddressLng : null,
            mohaffezPhone: mohaffezPhone !== null && mohaffezPhone !== void 0 ? mohaffezPhone : null,
            subscriptionId: subscriptionId !== null && subscriptionId !== void 0 ? subscriptionId : null,
            requiresPaymentOnAcceptance: requiresPaymentOnAcceptance !== null && requiresPaymentOnAcceptance !== void 0 ? requiresPaymentOnAcceptance : false,
            selectedPaymentMethod: selectedPaymentMethod !== null && selectedPaymentMethod !== void 0 ? selectedPaymentMethod : 'payAfterAcceptance',
            slotLockId: slotLockId !== null && slotLockId !== void 0 ? slotLockId : null,
            slotLockedAt: slotLockId ? admin_1.FieldValue.serverTimestamp() : null,
            status: STATUS.PENDING,
            isPaid: false,
            reminderSent: false,
            paymentDeadline: null,
            createdAt: admin_1.FieldValue.serverTimestamp(),
        });
        if (slotLockId && lockRef) {
            transaction.update(lockRef, {
                released: true,
                releasedAt: admin_1.FieldValue.serverTimestamp(),
                releaseReason: 'request-created',
            });
            if (availabilityRef && updatedSlots) {
                transaction.update(availabilityRef, {
                    timeSlots: updatedSlots,
                    updatedAt: admin_1.FieldValue.serverTimestamp(),
                });
            }
        }
        return { success: true, requestId: requestRef.id, isDuplicate: false };
    });
});
//# sourceMappingURL=createSessionRequest.js.map